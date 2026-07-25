#!/usr/bin/env bash

set -Eeuo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=setup/lib.sh
source "$SETUP_DIR/lib.sh"

ACTION="${1:-}"
DOTFILES_DIR="${2:-}"
XXH_VERSION="${XXH_VERSION:-0.8.14}"
XXH_VENV="${XXH_VENV:-$HOME/.local/share/xxh-dotfiles}"
LOCAL_BIN="${LOCAL_BIN:-$HOME/.local/bin}"

require_action "$ACTION"
[[ -n "$DOTFILES_DIR" ]] || die "repository path was not supplied to XXH setup."

if [[ "$ACTION" == "skip" ]]; then
    log "Skipping XXH."
    exit 0
fi

command -v python3 >/dev/null 2>&1 || die "python3 is required to install XXH."

if [[ ! -x "$XXH_VENV/bin/xxh" ]] ||
    ! "$XXH_VENV/bin/python" -c \
        "import importlib.metadata; raise SystemExit(importlib.metadata.version('xxh-xxh') != '$XXH_VERSION')" \
        >/dev/null 2>&1; then
    log "Installing XXH $XXH_VERSION in an isolated virtual environment..."
    python3 -m venv "$XXH_VENV"
    "$XXH_VENV/bin/python" -m pip install --disable-pip-version-check --upgrade pip
    "$XXH_VENV/bin/python" -m pip install --disable-pip-version-check "xxh-xxh==$XXH_VERSION"
    printf '%s\n' "$XXH_VERSION" > "$XXH_VENV/.installed-by-dotfiles"
fi

mkdir -p "$LOCAL_BIN"
ln -sfn "$XXH_VENV/bin/xxh" "$LOCAL_BIN/xxh"
export PATH="$LOCAL_BIN:$PATH"

xxh +I xxh-shell-zsh
xxh +I "xxh-plugin-zsh-dotfiles+path+$DOTFILES_DIR/modules/xxh-plugin"
