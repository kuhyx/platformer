#include "util.h"
#include <stdio.h>
#include <stdlib.h>

char *read_file(const char *path) {
    FILE *f = fopen(path, "rb");
    if (f == NULL) {
        return NULL;
    }
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    rewind(f);
    char *buf = size < 0 ? NULL : malloc((size_t)size + 1);
    if (buf != NULL) {
        buf[fread(buf, 1, (size_t)size, f)] = '\0';
    }
    fclose(f);
    return buf;
}
