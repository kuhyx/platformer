#include "trace.h"
#include "util.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Position just after the `[` that opens the array under `"key":`.
static const char *array_after(const char *json, const char *key) {
    char quoted[32];
    snprintf(quoted, sizeof quoted, "\"%s\"", key);
    const char *at = strstr(json, quoted);
    at = at != NULL ? strchr(at, '[') : NULL;
    return at != NULL ? at + 1 : NULL;
}

static const char *skip(const char *p, const char *set) {
    while (*p != '\0' && strchr(set, *p) != NULL) {
        p++;
    }
    return p;
}

static const char *read_int(const char *p, int *out) {
    char *end;
    *out = (int)strtol(skip(p, " \n\t,"), &end, 10);
    return end;
}

static const char *read_name(const char *p, char *out) {
    p = strchr(skip(p, " \n\t,"), '"');
    const char *close = p != NULL ? strchr(p + 1, '"') : NULL;
    if (close == NULL) {
        return NULL;
    }
    size_t len = (size_t)(close - p - 1);
    len = len < TRACE_NAME_LEN - 1 ? len : TRACE_NAME_LEN - 1;
    memcpy(out, p + 1, len);
    out[len] = '\0';
    return close + 1;
}

static bool read_events(const char *p, Trace *t) {
    while (p != NULL && *(p = skip(p, " \n\t,")) == '[') {
        if (t->event_count >= TRACE_MAX_EVENTS) {
            return false;
        }
        TraceEvent *e = &t->events[t->event_count++];
        p = read_int(p + 1, &e->tick);
        p = read_name(p, e->name);
        p = p != NULL ? read_int(p, &e->room) : NULL;
        p = p != NULL ? strchr(p, ']') : NULL;
        p = p != NULL ? p + 1 : NULL;
    }
    return p != NULL;
}

static bool read_segs(const char *p, Trace *t) {
    while (*(p = skip(p, " \n\t,")) == '[') {
        if (t->seg_count >= TRACE_MAX_SEGS) {
            return false;
        }
        TraceSeg *s = &t->segs[t->seg_count++];
        int l, r, j;
        p = read_int(p + 1, &s->ticks);
        p = read_int(p, &l);
        p = read_int(p, &r);
        p = read_int(p, &j);
        s->left = l != 0;
        s->right = r != 0;
        s->jump = j != 0;
        p = strchr(p, ']');
        if (p == NULL) {
            return false;
        }
        p++;
    }
    return true;
}

bool trace_load(const char *path, Trace *t) {
    memset(t, 0, sizeof *t);
    char *json = read_file(path);
    if (json == NULL) {
        return false;
    }
    const char *events = array_after(json, "events");
    const char *inputs = array_after(json, "inputs");
    const char *seed = strstr(json, "\"seed\"");
    seed = seed != NULL ? strchr(seed, ':') : NULL;
    if (seed != NULL) {
        read_int(seed + 1, &t->seed);
    }
    bool ok = events != NULL && inputs != NULL && read_events(events, t) && read_segs(inputs, t);
    free(json);
    return ok && t->seg_count > 0 && t->event_count > 0;
}

void trace_input_at(const Trace *t, int step, bool *left, bool *right, bool *jump) {
    int start = 0;
    *left = *right = *jump = false;
    for (int i = 0; i < t->seg_count; i++) {
        if (step < start + t->segs[i].ticks) {
            *left = t->segs[i].left;
            *right = t->segs[i].right;
            *jump = t->segs[i].jump;
            return;
        }
        start += t->segs[i].ticks;
    }
}
