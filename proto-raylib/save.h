// Invisible autosave (D03): room id + registry hash, written atomically
// (temp file + rename). Native: the user-data dir. Web: IndexedDB through an
// IDBFS mount. Missing or corrupt means room 0, silently (D19).
#ifndef SAVE_H
#define SAVE_H

#include <stdbool.h>

// Starts the (web) storage mount. Native is ready immediately.
void save_init(void);
bool save_ready(void);

void save_write(int room_id);

// The saved room id when it is a valid index, else 0.
int save_read_room(int room_count);

// Full path of `name` in the save dir; NULL when unavailable (used by F6).
const char *save_path(const char *name);

#endif
