#!/usr/bin/env bash

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=setup/lib.sh
source "$REPO_ROOT/setup/lib.sh"

usage() {
    cat <<'EOF'
Usage: ./uninstall.sh [--mise] [--plugins] [--omarchy] [--keyboard] [--brightness-knob]

With no arguments, the uninstaller prompts for each removable component.

Only installations marked as created by this repository are removed. System
packages, shell startup files, and Node projects are never removed
automatically. --omarchy removes only the marked dotfiles block from .bashrc
(after backup); profile settings and other startup content are retained.
--keyboard removes only the marked keyboard activation block from input.lua;
the saved and installed XKB symbol files are retained.
--brightness-knob removes its marked bindings block and the unmodified helper.
--mise removes only the unchanged, marked binary; runtimes and config are retained.
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

REMOVE_MISE=false
REMOVE_PLUGINS=false
REMOVE_OMARCHY=false
REMOVE_KEYBOARD=false
REMOVE_BRIGHTNESS_KNOB=false

if [[ "$#" -eq 0 ]]; then
    printf '%s\n' "========================================"
    printf '%s\n' "  Dotfiles Interactive Uninstall"
    printf '%s\n\n' "========================================"
    REMOVE_MISE="$(prompt_removal "Remove mise installed by these dotfiles?")"
    REMOVE_PLUGINS="$(prompt_removal "Remove the local Antidote checkout?")"
    if [[ -f "$HOME/.bashrc" ]] && grep -Fxq '# >>> dotfiles omarchy >>>' "$HOME/.bashrc"; then
        REMOVE_OMARCHY="$(prompt_removal "Remove the marked Omarchy Bash startup block?")"
    fi
    if [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/input.lua" ]] &&
        grep -Fxq -- '-- >>> dotfiles keyboard >>>' "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/input.lua"; then
        REMOVE_KEYBOARD="$(prompt_removal "Remove the marked keyboard activation block?")"
    fi
    if { [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/bindings.lua" ]] &&
        grep -Fxq -- '-- >>> dotfiles brightness knob >>>' "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/bindings.lua"; } ||
        [[ -f "$HOME/.local/bin/omarchy-brightness-all" ]]; then
        REMOVE_BRIGHTNESS_KNOB="$(prompt_removal "Remove the all-monitor brightness knob setup?")"
    fi
else
    for option in "$@"; do
        case "$option" in
            --mise) REMOVE_MISE=true ;;
            --plugins) REMOVE_PLUGINS=true ;;
            --omarchy) REMOVE_OMARCHY=true ;;
            --keyboard) REMOVE_KEYBOARD=true ;;
            --brightness-knob) REMOVE_BRIGHTNESS_KNOB=true ;;
            --help|-h) usage; exit 0 ;;
            *) die "unknown option: $option" ;;
        esac
    done
fi

if [[ "$REMOVE_MISE" == false && "$REMOVE_PLUGINS" == false &&
    "$REMOVE_OMARCHY" == false && "$REMOVE_KEYBOARD" == false &&
    "$REMOVE_BRIGHTNESS_KNOB" == false ]]; then
    log "No components selected; nothing was removed."
    exit 0
fi

printf '%s\n' "Requested removals:"
[[ "$REMOVE_MISE" == true ]] && printf '%s\n' "  - mise installed by dotfiles"
[[ "$REMOVE_PLUGINS" == true ]] && printf '%s\n' "  - repository-local Antidote checkout"
[[ "$REMOVE_OMARCHY" == true ]] && printf '%s\n' "  - marked Omarchy profile block in .bashrc (settings retained)"
[[ "$REMOVE_KEYBOARD" == true ]] && printf '%s\n' "  - marked keyboard activation block in input.lua (layout files retained)"
[[ "$REMOVE_BRIGHTNESS_KNOB" == true ]] &&
    printf '%s\n' "  - all-monitor brightness bindings and unmodified helper"
read -r -p "Type 'uninstall' to continue: " confirmation
[[ "$confirmation" == "uninstall" ]] || die "uninstall aborted."

if [[ "$REMOVE_MISE" == true ]]; then
    mise_bin="$HOME/.local/bin/mise"
    marker="$HOME/.local/bin/.mise-installed-by-dotfiles"
    if [[ -f "$marker" && -f "$mise_bin" && ! -L "$mise_bin" ]] &&
        [[ "$(cat "$marker")" == "$(sha256_file "$mise_bin")" ]]; then
        rm -f "$mise_bin" "$marker"
    else
        log "Skipping mise: binary is unmarked or has changed since installation."
    fi
fi

if [[ "$REMOVE_PLUGINS" == true ]]; then
    rm -rf "$REPO_ROOT/.antidote"
fi

if [[ "$REMOVE_OMARCHY" == true ]]; then
    bash "$REPO_ROOT/setup/bash-startup.sh" remove "$REPO_ROOT"
fi
if [[ "$REMOVE_KEYBOARD" == true ]]; then
    bash "$REPO_ROOT/setup/keyboard.sh" remove
fi
if [[ "$REMOVE_BRIGHTNESS_KNOB" == true ]]; then
    bash "$REPO_ROOT/setup/brightness-knob.sh" remove "$REPO_ROOT"
fi
log "Uninstall flow complete. Unselected components and user settings were retained."
