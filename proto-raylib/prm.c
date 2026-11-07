// The single live registry table plus the native F5 reader.
#include "prm.h"
#include "util.h"
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define FNV_OFFSET 2166136261u
#define FNV_PRIME 16777619u
#define KEY_BUF 64

Param *prm_table(void) {
    return PARAMS;
}

unsigned prm_hash(void) {
    unsigned h = FNV_OFFSET;
    for (int i = 0; i < P_COUNT; i++) {
        unsigned char bytes[sizeof(float)];
        memcpy(bytes, &PARAMS[i].value, sizeof bytes);
        for (size_t b = 0; b < sizeof bytes; b++) {
            h = (h ^ bytes[b]) * FNV_PRIME;
        }
    }
    return h;
}

// Finds `"key"` then its entry's `"value":` number; false when absent.
static bool read_value(const char *json, const char *key, float *out) {
    char quoted[KEY_BUF];
    snprintf(quoted, sizeof quoted, "\"%s\"", key);
    const char *entry = strstr(json, quoted);
    if (entry == NULL) {
        return false;
    }
    const char *value = strstr(entry, "\"value\"");
    if (value == NULL) {
        return false;
    }
    value = strchr(value + 7, ':');
    char *end = NULL;
    double v = value != NULL ? strtod(value + 1, &end) : 0.0;
    if (end == NULL || end == value + 1) {
        return false;
    }
    *out = (float)v;
    return true;
}

int prm_reload(const char *path) {
    char *json = read_file(path);
    if (json == NULL) {
        return -1;
    }
    int updated = 0;
    for (int i = 0; i < P_COUNT; i++) {
        float v;
        if (read_value(json, PARAMS[i].key, &v)) {
            PARAMS[i].value = v;
            updated++;
        }
    }
    free(json);
    return updated;
}
