# Native build needs raylib installed (pkg-config raylib). Web build needs
# emsdk and a raylib checkout compiled with PLATFORM=PLATFORM_WEB
# (install_web_toolchain.sh does both from scratch).
CC ?= cc
CFLAGS ?= -std=c99 -Wall -Wextra -Wpedantic -Wshadow -Wconversion -Werror -O2
RAYLIB_WEB ?= $(HOME)/raylib
EMFLAGS = -Os -DPLATFORM_WEB -I$(RAYLIB_WEB)/src $(RAYLIB_WEB)/src/libraylib.web.a \
          -s USE_GLFW=3 -s FORCE_FILESYSTEM=1 -s ALLOW_MEMORY_GROWTH=1 -lidbfs.js \
          --shell-file shell.html

LIB_SRC = sim.c rng.c winnable.c fx.c prm.c save.c trace.c util.c
APP_SRC = main.c render.c input.c overlay.c debug.c $(LIB_SRC)
TEST_SRC = test_sim.c test_replay.c $(LIB_SRC)
GENERATED = params.h rooms.h
HEADERS = $(wildcard *.h)
FORMAT_FILES = $(filter-out $(GENERATED),$(wildcard *.c *.h))

.PHONY: native test web lint clean

native: bin/proto-raylib

bin/proto-raylib: $(APP_SRC) $(HEADERS)
	mkdir -p bin
	$(CC) $(CFLAGS) $(APP_SRC) -o $@ $$(pkg-config --cflags --libs raylib) -lm

test: bin/test_sim
	bin/test_sim ../shared/replay/slice_trace.json

bin/test_sim: $(TEST_SRC) $(HEADERS)
	mkdir -p bin
	$(CC) $(CFLAGS) $(TEST_SRC) -o $@ -lm

web: dist/index.html

dist/index.html: $(APP_SRC) $(HEADERS) shell.html
	mkdir -p dist
	emcc $(CFLAGS) $(APP_SRC) -o $@ $(EMFLAGS)
	python3 ../tools/size_budget.py dist 2000000

lint:
	clang-format --dry-run --Werror $(FORMAT_FILES)

clean:
	rm -rf bin dist
