// Reader for the fixed shape of shared/replay/slice_trace.json.
#ifndef TRACE_H
#define TRACE_H

#include <stdbool.h>

#define TRACE_MAX_SEGS 128
#define TRACE_MAX_EVENTS 128
#define TRACE_NAME_LEN 24

typedef struct {
    int ticks;
    bool left, right, jump;
} TraceSeg;

typedef struct {
    int tick;
    char name[TRACE_NAME_LEN];
    int room;
} TraceEvent;

typedef struct {
    TraceSeg segs[TRACE_MAX_SEGS];
    int seg_count;
    TraceEvent events[TRACE_MAX_EVENTS];
    int event_count;
    int seed;
} Trace;

bool trace_load(const char *path, Trace *t);
void trace_input_at(const Trace *t, int step, bool *left, bool *right, bool *jump);

#endif
