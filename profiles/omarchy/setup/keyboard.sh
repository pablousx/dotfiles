#!/usr/bin/env bash
# Save or restore the user-owned Spanish AltGr layout; never edit packaged XKB files.
set -Eeuo pipefail
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=setup/lib.sh
source "$SETUP_DIR/../../../setup/lib.sh"
repo="$(cd "$SETUP_DIR/../../.." && pwd -P)"
action="${1:-}"
case "$action" in install|save|remove|skip) ;; *) die 'expected install, save, remove, or skip' ;; esac
[[ "$action" != skip ]] || exit 0
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
[[ "$config_home" == /* ]] || die 'XDG_CONFIG_HOME must be an absolute path'
symbols="$config_home/xkb/symbols/us-altgr-spanish"
saved_symbols="$repo/profiles/omarchy/config/xkb/symbols/us-altgr-spanish"
input="$config_home/hypr/input.lua"

replace_file() {
    local source_file="$1" target="$2" backup
    [[ ! -L "$target" || -e "$target" ]] || die "dangling symlink: $target"
    [[ ! -e "$target" || -f "$target" ]] || die "not a regular file: $target"
    if [[ -f "$target" ]]; then
        cmp -s "$source_file" "$target" && return 0
        backup="$(mktemp "$target.dotfiles-backup.XXXXXX")"
        cp -p "$target" "$backup"
        log "Backup: $backup"
    else
        mkdir -p "$(dirname "$target")"
        (umask 077; touch "$target")
    fi
    cat "$source_file" > "$target"
}

if [[ "$action" == save ]]; then
    [[ -r "$symbols" ]] || die "layout not found: $symbols"
    # Check syntax when the local XKB compiler is available, before saving.
    if command -v xkbcli >/dev/null 2>&1; then
        xkbcli compile-keymap --include "$config_home/xkb" --include-defaults \
            --layout us-altgr-spanish --variant basic --options '' --test >/dev/null
    fi
    replace_file "$symbols" "$saved_symbols"
    log 'Saved us-altgr-spanish in the repository. Review its Git diff before committing.'
    exit 0
fi

if [[ "$action" == install ]]; then
    [[ -r "$config_home/hypr/hyprland.lua" ]] ||
        die 'Omarchy Hyprland Lua configuration not found; keyboard setup needs hyprland.lua'
    [[ -r "$saved_symbols" && -r "$repo/profiles/omarchy/config/hypr/keyboard.lua" ]] || die 'saved keyboard preset is missing'
    if command -v xkbcli >/dev/null 2>&1; then
        xkbcli compile-keymap --include "$repo/profiles/omarchy/config/xkb" --include-defaults \
            --layout us-altgr-spanish --variant basic --options '' --test >/dev/null
    fi
fi
[[ "$action" != remove || -f "$input" ]] || exit 0
generated="$(mktemp)"
trap 'rm -f "$generated"' EXIT
if [[ -f "$input" ]]; then
    awk '
        $0 == "-- >>> dotfiles keyboard >>>" { if (inside || count++) exit 1; inside=1; next }
        $0 == "-- <<< dotfiles keyboard <<<" { if (!inside) exit 1; inside=0; next }
        !inside { print }
        END { if (inside) exit 1 }
    ' "$input" > "$generated" || die 'invalid keyboard markers; input.lua left unchanged'
fi
if [[ "$action" == install ]]; then
    {
        printf '%s\n' '-- >>> dotfiles keyboard >>>'
        cat "$repo/profiles/omarchy/config/hypr/keyboard.lua"
        printf '%s\n' '-- <<< dotfiles keyboard <<<'
    } >> "$generated"
    replace_file "$saved_symbols" "$symbols"
fi
replace_file "$generated" "$input"
# Only contact a live compositor when this user's Hyprland session is available.
# Test fixtures unset the signature and/or provide a mocked hyprctl.
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload
    errors="$(hyprctl configerrors)" || die 'could not read Hyprland configuration errors'
    [[ -z "$errors" ]] || die "Hyprland reported configuration errors: $errors"
else
    log 'No active Hyprland session. The keyboard preset will load at the next login.'
fi
log "Keyboard activation: $action complete. Layout files are retained on removal."
