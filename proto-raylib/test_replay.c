// Cross-engine replay fixture and save checks for the headless test binary.
#define _POSIX_C_SOURCE 200809L
#include "save.h"
#include "test.h"
#include "trace.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define TICK_TOLERANCE 1 // float width differs per engine
#define MAX_SEEN 256

typedef struct {
    int tick;
    EventKind kind;
    int room;
} Seen;

static void record(const Sim *s, Seen *out, int *n) {
    for (int e = 0; e < s->event_count && *n < MAX_SEEN; e++) {
        out[*n] = (Seen){s->tick_count, s->events[e].kind, s->events[e].room};
        (*n)++;
    }
}

static int max_deviation;

static bool matches(const Trace *t, const Seen *got, int n) {
    if (n != t->event_count) {
        return false;
    }
    for (int i = 0; i < n; i++) {
        const TraceEvent *want = &t->events[i];
        bool same = strcmp(EVENT_NAMES[got[i].kind], want->name) == 0 && got[i].room == want->room;
        int dev = abs(got[i].tick - want->tick);
        max_deviation = dev > max_deviation ? dev : max_deviation;
        if (!same || dev > TICK_TOLERANCE) {
            printf("  event %d: got tick %d %s room %d, want tick %d %s room %d\n", i, got[i].tick,
                   EVENT_NAMES[got[i].kind], got[i].room, want->tick, want->name, want->room);
            return false;
        }
    }
    return true;
}

static int replay(const Trace *t, Seen *out) {
    Sim s;
    sim_init(&s, (uint64_t)t->seed);
    sim_enter_room(&s, 0, false);
    int n = 0;
    record(&s, out, &n);
    int total = 0;
    for (int i = 0; i < t->seg_count; i++) {
        total += t->segs[i].ticks;
    }
    for (int step = 0; step < total; step++) {
        SimInput in;
        trace_input_at(t, step, &in.left, &in.right, &in.jump);
        sim_tick(&s, in);
        record(&s, out, &n);
    }
    return n;
}

void run_replay_checks(const char *trace_path) {
    static Trace t;
    static Seen got[MAX_SEEN];
    if (!trace_load(trace_path, &t)) {
        expect(false, "replay fixture loads");
        return;
    }
    int n = replay(&t, got);
    char label[96];
    bool ok = matches(&t, got, n);
    snprintf(label, sizeof label, "replay: %d events match slice_trace.json (max drift %d tick)", n,
             max_deviation);
    expect(ok, label);
}

static void write_text(const char *path, const char *text) {
    FILE *f = fopen(path, "w");
    if (f != NULL) {
        fputs(text, f);
        fclose(f);
    }
}

void run_save_checks(void) {
    char dir[] = "/tmp/proto-raylib-test-XXXXXX";
    if (mkdtemp(dir) == NULL) {
        expect(false, "temp dir for save checks");
        return;
    }
    setenv("XDG_DATA_HOME", dir, 1);
    save_init();
    expect(save_read_room(ROOM_COUNT) == 0, "missing save starts in room 0");
    save_write(1);
    expect(save_read_room(ROOM_COUNT) == 1, "saved room 1 is read back");
    const char *path = save_path("save.json");
    write_text(path, "{\"room_id\": 99}");
    expect(save_read_room(ROOM_COUNT) == 0, "out-of-range room id starts in room 0");
    write_text(path, "\x01garbage{{{");
    expect(save_read_room(ROOM_COUNT) == 0, "corrupt save starts silently in room 0");
    save_write(1);
    char tmp[700];
    snprintf(tmp, sizeof tmp, "%s.tmp", path);
    expect(fopen(tmp, "r") == NULL, "atomic write leaves no temp file behind");
    remove(path);
    rmdir(save_path(""));
    rmdir(dir);
}
