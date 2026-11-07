// Registry access (D14): prm.c owns the one live table; params.h keeps a
// static copy per translation unit, so PARAM() is redirected to prm.c.
#ifndef PRM_H
#define PRM_H

#include "params.h"

#undef PARAM
#define PARAM(k) (prm_table()[(k)].value)

Param *prm_table(void);
int prm_reload(const char *path); // entries updated, or -1 when unreadable
unsigned prm_hash(void);          // FNV-1a over all values, stored in saves

static inline void prm_local_copy_unused(void) {
    (void)PARAMS;
}

#endif
