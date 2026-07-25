#!/usr/bin/env bash

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=setup/lib.sh
source "$REPO_ROOT/setup/lib.sh"

usage() {
    cat <<'EOF'
Usage: ./uninstall.sh [--fnm] [--xxh] [--plugins]

With no arguments, the uninstaller prompts for each removable component.

Only installations marked as created by this repository are removed. System
packages, shell startup files, Node projects, and XXH connection state are
never removed automatically.
EOF
}

prompt_removal() {
    local prompt_text="$1"
    local answer

    while true; do
        read -r -p "$prompt_text (yes [y], no [n]) [no]: " answer
        answer="$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')"
        [[ -n "$answer" ]] || answer="no"

        case "$answer" in
            y|yes) printf '%s\n' "true"; return 0 ;;
            n|no) printf '%s\n' "false"; return 0 ;;
            *) printf '%s\n' "Invalid option. Please use 'y' or 'n'." >&2 ;;
        esac
    done
}

REMOVE_FNM=false
REMOVE_XXH=false
REMOVE_PLUGINS=false

if [[ "$#" -eq 0 ]]; then
    printf '%s\n' "========================================"
    printf '%s\n' "  Dotfiles Interactive Uninstall"
    printf '%s\n\n' "========================================"
    REMOVE_FNM="$(prompt_removal "Remove FNM installed by these dotfiles?")"
    REMOVE_XXH="$(prompt_removal "Remove the isolated XXH installation?")"
    REMOVE_PLUGINS="$(prompt_removal "Remove the local Antidote checkout?")"
else
    for option in "$@"; do
        case "$option" in
            --fnm) REMOVE_FNM=true ;;
            --xxh) REMOVE_XXH=true ;;
            --plugins) REMOVE_PLUGINS=true ;;
            --help|-h) usage; exit 0 ;;
            *) die "unknown option: $option" ;;
        esac
    done
fi

if [[ "$REMOVE_FNM" == false && "$REMOVE_XXH" == false && "$REMOVE_PLUGINS" == false ]]; then
    log "No components selected; nothing was removed."
    exit 0
fi

printf '%s\n' "Requested removals:"
[[ "$REMOVE_FNM" == true ]] && printf '%s\n' "  - FNM installed by dotfiles"
[[ "$REMOVE_XXH" == true ]] && printf '%s\n' "  - isolated XXH virtual environment and launcher"
[[ "$REMOVE_PLUGINS" == true ]] && printf '%s\n' "  - repository-local Antidote checkout"
read -r -p "Type 'uninstall' to continue: " confirmation
[[ "$confirmation" == "uninstall" ]] || die "uninstall aborted."

if [[ "$REMOVE_FNM" == true ]]; then
    fnm_dir="$HOME/.local/share/fnm"
    if [[ -f "$fnm_dir/.installed-by-dotfiles" ]]; then
        rm -rf "$fnm_dir"
    else
        log "Skipping FNM: $fnm_dir is not marked as installed by this repository."
    fi
fi

if [[ "$REMOVE_XXH" == true ]]; then
    xxh_venv="$HOME/.local/share/xxh-dotfiles"
    if [[ -f "$xxh_venv/.installed-by-dotfiles" ]]; then
        rm -rf "$xxh_venv"
        if [[ -L "$HOME/.local/bin/xxh" ]]; then
            rm "$HOME/.local/bin/xxh"
        fi
    else
        log "Skipping XXH: $xxh_venv is not marked as installed by this repository."
    fi
fi

if [[ "$REMOVE_PLUGINS" == true ]]; then
    rm -rf "$REPO_ROOT/.antidote"
fi

log "Uninstall flow complete. Shell startup files were left unchanged."
