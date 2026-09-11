#!/bin/bash

# ============================================================================
# run.sh — install one prototype's dependencies and run it natively.
#
#   ./run.sh <godot|phaser|love|raylib|bevy>
#   ./run.sh --install-only <proto>     deps only, no launch (vmbox / CI)
#
# Arch-only: system tools come from pacman. Each prototype lists
# "probe|package" pairs; a probe is a command name or "pkg:<pkg-config name>".
# Only what the probe cannot find gets installed, so a machine whose cargo
# comes from rustup or whose node comes from nvm is left alone.
# Web toolchains (emsdk, wasm-bindgen, love.js) are out of scope: see
# TODO-handoff.md.
# ============================================================================

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
readonly PROTOS="godot phaser love raylib bevy"
readonly NODE_MAJOR_EXPECTED=24

INSTALL_ONLY=0
PROTO=""

usage() {
    echo "Usage: $SCRIPT_NAME [--install-only] <proto>"
    echo "  proto: $PROTOS"
    echo "  --install-only   install dependencies, do not launch"
    echo "  -h, --help       show this help"
}

die() {
    echo "Error: $*" >&2
    exit 1
}

validate_requirements() {
    [[ -r /etc/arch-release ]] || die "Arch Linux only (installs via pacman)"
    command -v pacman >/dev/null || die "pacman not found"
    [[ " $PROTOS " == *" $PROTO "* ]] || die "unknown prototype '$PROTO'"
    [[ -d "$PROTO_DIR" ]] || die "missing directory $PROTO_DIR"
}

# ----------------------------------------------------------------------------
# Dependency probing / installation
# ----------------------------------------------------------------------------

# probe "cc" -> command exists; probe "pkg:raylib" -> pkg-config finds it.
probe() {
    local what="$1"
    if [[ "$what" == pkg:* ]]; then
        command -v pkg-config >/dev/null && pkg-config --exists "${what#pkg:}"
    else
        command -v "$what" >/dev/null
    fi
}

# Single pacman transaction for every missing package. --noconfirm only when
# nobody is at the keyboard (vmbox / CI); interactive runs see the transaction.
install_pkgs() {
    local -a pkgs=("$@")
    [[ ${#pkgs[@]} -gt 0 ]] || return 0
    echo "Installing: ${pkgs[*]}"
    local -a flags=(-S --needed)
    if [[ ! -t 0 ]]; then
        flags+=(--noconfirm)
        if ! sudo -n true 2>/dev/null; then
            echo "sudo needs a password and stdin is not a terminal. Run:" >&2
            echo "  sudo pacman -S --needed ${pkgs[*]}" >&2
            exit 1
        fi
    fi
    sudo pacman "${flags[@]}" "${pkgs[@]}"
}

# ensure_deps "probe|package" ... — install every package whose probe fails.
ensure_deps() {
    local -a missing=()
    local pair
    for pair in "$@"; do
        probe "${pair%%|*}" || missing+=("${pair##*|}")
    done
    install_pkgs "${missing[@]}"
}

# ----------------------------------------------------------------------------
# Per-prototype install + run
# ----------------------------------------------------------------------------

install_godot() {
    ensure_deps "godot|godot"
    # First import builds .godot/ (gitignored) and registers the Params class.
    if [[ ! -d "$PROTO_DIR/.godot" ]]; then
        godot --headless --path "$PROTO_DIR" --import
    fi
}
run_godot() { godot --path "$PROTO_DIR"; }

install_phaser() {
    # Prefer the newest nvm-installed node over a pacman one that would
    # shadow it (nvm.sh is not sourced; a login shell already did that).
    local nvm_root="$HOME/.nvm/versions/node"
    if ! command -v node >/dev/null && [[ -d "$nvm_root" ]]; then
        local nvm_bin
        nvm_bin="$(find "$nvm_root" -maxdepth 1 -name 'v*' | sort -V | tail -n 1)"
        [[ -n "$nvm_bin" ]] && PATH="$nvm_bin/bin:$PATH"
    fi
    ensure_deps "node|nodejs" "npm|npm"
    local major
    major="$(node --version)"
    major="${major#v}"
    major="${major%%.*}"
    if [[ "$major" != "$NODE_MAJOR_EXPECTED" ]]; then
        echo "Warning: node $major found, README expects $NODE_MAJOR_EXPECTED" >&2
    fi
    # npm ci wipes node_modules; only pay for it when the lockfile is newer.
    if [[ ! -d "$PROTO_DIR/node_modules" ||
          "$PROTO_DIR/package-lock.json" -nt "$PROTO_DIR/node_modules" ]]; then
        npm ci --prefix "$PROTO_DIR"
    fi
}
# Vite serves until interrupted; Ctrl-C (130) is the normal way to close it.
run_phaser() {
    local rc=0
    npm run dev --prefix "$PROTO_DIR" -- --open || rc=$?
    [[ $rc -eq 130 ]] && rc=0
    return "$rc"
}

install_love() { ensure_deps "love|love"; }
run_love() { love "$PROTO_DIR"; }

install_raylib() {
    ensure_deps "pkg-config|pkgconf" "pkg:raylib|raylib" "cc|gcc" "make|make"
    make -C "$PROTO_DIR" native
}
run_raylib() { "$PROTO_DIR/bin/proto-raylib"; }

install_bevy() {
    ensure_deps "rustup|rustup" "pkg:alsa|alsa-lib" "pkg:libudev|systemd-libs"
    # Arch's rustup package ships no toolchain; Bevy needs stable >= 1.95.
    if ! rustup show active-toolchain >/dev/null 2>&1; then
        rustup toolchain install stable
    fi
    cargo build --manifest-path "$PROTO_DIR/Cargo.toml"
}
run_bevy() { cargo run --manifest-path "$PROTO_DIR/Cargo.toml"; }

# ----------------------------------------------------------------------------

main() {
    validate_requirements
    echo "== $PROTO: installing dependencies"
    "install_$PROTO"
    if [[ $INSTALL_ONLY -eq 1 ]]; then
        echo "== $PROTO: dependencies ready"
        return 0
    fi
    echo "== $PROTO: running"
    "run_$PROTO"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --install-only) INSTALL_ONLY=1; shift ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
        *)
            [[ -z "$PROTO" ]] || die "only one prototype at a time"
            PROTO="$1"; shift ;;
    esac
done
[[ -n "$PROTO" ]] || { usage >&2; exit 1; }

# The script is cwd-independent; prototypes are addressed relative to it.
cd "$(dirname "$0")"
readonly PROTO_DIR="proto-$PROTO"

main
