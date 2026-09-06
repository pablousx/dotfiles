#!/usr/bin/env bash
# Manage the Omarchy all-monitor brightness knob without owning other bindings.
set -Eeuo pipefail

SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=setup/lib.sh
source "$SETUP_DIR/../../../setup/lib.sh"

action="${1:-}"
repo="${2:-$(cd "$SETUP_DIR/../../.." && pwd -P)}"
case "$action" in install|remove|skip) ;; *) die 'expected install, remove, or skip' ;; esac
[[ "$action" != skip ]] || exit 0

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
[[ "$config_home" == /* ]] || die 'XDG_CONFIG_HOME must be an absolute path'
bindings="$config_home/hypr/bindings.lua"
saved_bindings="$repo/profiles/omarchy/config/hypr/brightness-knob.lua"
helper="$HOME/.local/bin/omarchy-brightness-all"
saved_helper="$repo/profiles/omarchy/config/omarchy/bin/omarchy-brightness-all"

[[ ! -L "$bindings" || -e "$bindings" ]] || die "dangling symlink: $bindings"
[[ ! -e "$bindings" || -f "$bindings" ]] || die "not a regular file: $bindings"
[[ ! -L "$helper" || -e "$helper" ]] || die "dangling symlink: $helper"
[[ ! -e "$helper" || -f "$helper" ]] || die "not a regular file: $helper"

if [[ "$action" == install ]]; then
    [[ -r "$config_home/hypr/hyprland.lua" ]] ||
        die 'Omarchy Hyprland Lua configuration not found; brightness setup needs hyprland.lua'
    [[ -r "$saved_bindings" && -r "$saved_helper" ]] ||
        die 'saved brightness-knob preset is missing'
fi

generated="$(mktemp)"
trap 'rm -f "$generated"' EXIT
if [[ -f "$bindings" ]]; then
    awk '
        $0 == "-- >>> dotfiles brightness knob >>>" {
            if (inside || count++) exit 1
            inside=1
            next
        }
        $0 == "-- <<< dotfiles brightness knob <<<" {
            if (!inside) exit 1
            inside=0
            next
        }
        !inside { print }
        END { if (inside) exit 1 }
    ' "$bindings" > "$generated" ||
        die 'invalid brightness-knob markers in bindings.lua; file left unchanged'
fi
if [[ "$action" == install ]]; then
    {
        printf '%s\n' '-- >>> dotfiles brightness knob >>>'
        cat "$saved_bindings"
        printf '%s\n' '-- <<< dotfiles brightness knob <<<'
    } >> "$generated"
fi

if [[ ! -f "$bindings" ]] || ! cmp -s "$generated" "$bindings"; then
    if [[ -f "$bindings" ]]; then
        backup="$(mktemp "$bindings.dotfiles-backup.XXXXXX")"
        cp -p "$bindings" "$backup"
        log "Backup: $backup"
        cat "$generated" > "$bindings"
    elif [[ "$action" == install ]]; then
        mkdir -p "$(dirname "$bindings")"
        (umask 077; touch "$bindings")
        cat "$generated" > "$bindings"
    fi
fi

if [[ "$action" == install ]]; then
    mkdir -p "$(dirname "$helper")"
    if [[ ! -f "$helper" ]] || ! cmp -s "$saved_helper" "$helper"; then
        if [[ -e "$helper" ]]; then
            [[ -f "$helper" ]] || die "not a regular file: $helper"
            helper_backup="$(mktemp "$helper.dotfiles-backup.XXXXXX")"
            cp -p "$helper" "$helper_backup"
            log "Backup: $helper_backup"
        fi
        cat "$saved_helper" > "$helper"
    fi
    chmod 0755 "$helper"
elif [[ -f "$helper" ]]; then
    if cmp -s "$saved_helper" "$helper"; then
        rm "$helper"
    else
        log "Keeping modified helper: $helper"
    fi
fi

if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload
    errors="$(hyprctl configerrors)" || die 'could not read Hyprland configuration errors'
    [[ -z "$errors" ]] || die "Hyprland reported configuration errors: $errors"
else
    log 'No active Hyprland session. Brightness bindings will load at the next login.'
fi
log "Brightness knob activation: $action complete."
