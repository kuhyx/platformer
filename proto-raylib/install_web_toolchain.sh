#!/bin/bash
# Builds the raylib web library that `make web` links (emscripten from the
# distro, raylib at a release tag, PLATFORM_WEB). Idempotent.
set -euo pipefail

readonly RAYLIB_WEB="${RAYLIB_WEB:-$HOME/raylib}"
readonly RAYLIB_TAG="${RAYLIB_TAG:-6.2}"
readonly EMSCRIPTEN_DIR="${EMSCRIPTEN_DIR:-/usr/lib/emscripten}"
readonly LIB="$RAYLIB_WEB/src/libraylib.web.a"

[[ -d "$EMSCRIPTEN_DIR" ]] || {
    echo "emscripten missing: sudo pacman -S emscripten (or install emsdk)" >&2
    exit 1
}
export PATH="$PATH:$EMSCRIPTEN_DIR"
command -v emcc >/dev/null || { echo "emcc not on PATH" >&2; exit 1; }

if [[ ! -d "$RAYLIB_WEB/.git" ]]; then
    git clone --depth 1 --branch "$RAYLIB_TAG" https://github.com/raysan5/raylib.git "$RAYLIB_WEB"
fi
if [[ ! -f "$LIB" ]]; then
    make -C "$RAYLIB_WEB/src" PLATFORM=PLATFORM_WEB -j"$(nproc)"
fi
echo "raylib web library: $LIB ($(git -C "$RAYLIB_WEB" describe --tags))"
