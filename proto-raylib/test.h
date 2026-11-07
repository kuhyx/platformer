#ifndef TEST_H
#define TEST_H

#include "sim.h"

#define SECONDS SIM_TICK_HZ
#define TEST_SEED 7

extern int failures;

void expect(bool cond, const char *what);
void run_replay_checks(const char *trace_path);
void run_save_checks(void);

#endif
