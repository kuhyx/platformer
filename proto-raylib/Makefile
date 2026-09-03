# Native build needs raylib installed (pkg-config raylib). Web build needs
# emsdk and a raylib checkout compiled with PLATFORM=PLATFORM_WEB.
CC ?= cc
CFLAGS ?= -std=c99 -Wall -Wextra -Wpedantic -Wshadow -Wconversion -Werror -O2
RAYLIB_WEB ?= $(HOME)/raylib
EMFLAGS = -Os -Wall -DPLATFORM_WEB -I$(RAYLIB_WEB)/src -L$(RAYLIB_WEB)/src -lraylib \
          -s USE_GLFW=3 -s ASYNCIFY --shell-file $(RAYLIB_WEB)/src/minshell.html

.PHONY: native web lint clean

native: bin/proto-raylib

bin/proto-raylib: main.c params.h
	mkdir -p bin
	$(CC) $(CFLAGS) main.c -o $@ $$(pkg-config --libs raylib) -lm

web: dist/index.html

dist/index.html: main.c params.h
	mkdir -p dist
	emcc main.c -o $@ $(EMFLAGS)
	python3 ../tools/size_budget.py dist 2000000

lint:
	clang-format --dry-run --Werror main.c

clean:
	rm -rf bin dist
