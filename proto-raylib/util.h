#ifndef UTIL_H
#define UTIL_H

// Whole file as a NUL-terminated heap string; NULL when unreadable.
char *read_file(const char *path);

#endif
