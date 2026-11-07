#define _POSIX_C_SOURCE 200809L
#include "save.h"
#include "prm.h"
#include "util.h"
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#if defined(PLATFORM_WEB)
#include <emscripten/emscripten.h>
#define SAVE_DIR "/save"
#else
#define APP_DIR "proto-raylib"
#endif

#define DIR_LEN 512
#define FILE_LEN 640 // room for a name after the dir
#define SAVE_NAME "save.json"

#if defined(PLATFORM_WEB)
EM_JS(void, web_mount, (void), {
    FS.mkdir('/save');
    FS.mount(IDBFS, {}, '/save');
    Module.saveLoaded = 0;
    FS.syncfs(true, function(err) { Module.saveLoaded = 1; });
})
EM_JS(int, web_loaded, (void), { return Module.saveLoaded ? 1 : 0; })
EM_JS(void, web_flush, (void), { FS.syncfs(false, function(err){}); })
#endif

static char dir_path[DIR_LEN];
static char file_path[FILE_LEN];

#if !defined(PLATFORM_WEB)
static void make_dir(const char *path) {
    if (mkdir(path, 0700) != 0 && errno != EEXIST) {
        dir_path[0] = '\0';
    }
}

static void resolve_dir(void) {
    const char *xdg = getenv("XDG_DATA_HOME");
    const char *home = getenv("HOME");
    char base[DIR_LEN - 16] = "";
    if (xdg != NULL && xdg[0] != '\0') {
        snprintf(base, sizeof base, "%s", xdg);
    } else if (home != NULL) {
        snprintf(base, sizeof base, "%s/.local/share", home);
    }
    if (base[0] == '\0') {
        return;
    }
    make_dir(base);
    snprintf(dir_path, sizeof dir_path, "%s/%s", base, APP_DIR);
    make_dir(dir_path);
}
#endif

void save_init(void) {
#if defined(PLATFORM_WEB)
    snprintf(dir_path, sizeof dir_path, "%s", SAVE_DIR);
    web_mount();
#else
    resolve_dir();
#endif
    snprintf(file_path, sizeof file_path, "%s/%s", dir_path, SAVE_NAME);
}

bool save_ready(void) {
#if defined(PLATFORM_WEB)
    return web_loaded() != 0;
#else
    return true;
#endif
}

const char *save_path(const char *name) {
    static char out[FILE_LEN];
    if (dir_path[0] == '\0') {
        return NULL;
    }
    snprintf(out, sizeof out, "%s/%s", dir_path, name);
    return out;
}

void save_write(int room_id) {
    if (dir_path[0] == '\0') {
        return;
    }
    char tmp[FILE_LEN + 8];
    snprintf(tmp, sizeof tmp, "%s.tmp", file_path);
    FILE *f = fopen(tmp, "w");
    if (f == NULL) {
        return;
    }
    fprintf(f, "{\"room_id\": %d, \"params_hash\": \"%08x\"}\n", room_id, prm_hash());
    bool ok = fflush(f) == 0;
    ok = (fclose(f) == 0) && ok;
    if (!ok || rename(tmp, file_path) != 0) {
        remove(tmp);
        return;
    }
#if defined(PLATFORM_WEB)
    web_flush();
#endif
}

int save_read_room(int room_count) {
    char *text = dir_path[0] != '\0' ? read_file(file_path) : NULL;
    if (text == NULL) {
        return 0;
    }
    const char *key = strstr(text, "\"room_id\"");
    const char *colon = key != NULL ? strchr(key, ':') : NULL;
    char *end = NULL;
    long id = colon != NULL ? strtol(colon + 1, &end, 10) : -1;
    bool valid = colon != NULL && end != colon + 1 && id >= 0 && id < room_count;
    free(text);
    return valid ? (int)id : 0;
}
