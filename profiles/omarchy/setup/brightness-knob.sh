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
restore_helper="$HOME/.local/bin/omarchy-brightness-restore"
saved_restore_helper="$repo/profiles/omarchy/config/omarchy/bin/omarchy-brightness-restore"
service="$config_home/systemd/user/omarchy-brightness-restore.service"
saved_service="$repo/profiles/omarchy/config/systemd/user/omarchy-brightness-restore.service"

[[ ! -L "$bindings" || -e "$bindings" ]] || die "dangling symlink: $bindings"
[[ ! -e "$bindings" || -f "$bindings" ]] || die "not a regular file: $bindings"
[[ ! -L "$helper" || -e "$helper" ]] || die "dangling symlink: $helper"
[[ ! -e "$helper" || -f "$helper" ]] || die "not a regular file: $helper"
[[ ! -L "$restore_helper" || -e "$restore_helper" ]] || die "dangling symlink: $restore_helper"
[[ ! -e "$restore_helper" || -f "$restore_helper" ]] || die "not a regular file: $restore_helper"
[[ ! -L "$service" || -e "$service" ]] || die "dangling symlink: $service"
[[ ! -e "$service" || -f "$service" ]] || die "not a regular file: $service"

if [[ "$action" == install ]]; then
    [[ -r "$config_home/hypr/hyprland.lua" ]] ||
        die 'Omarchy Hyprland Lua configuration not found; brightness setup needs hyprland.lua'
    [[ -r "$saved_bindings" && -r "$saved_helper" && -r "$saved_restore_helper" &&
        -r "$saved_service" ]] ||
        die 'saved brightness-knob preset is missing'
    command -v systemctl >/dev/null 2>&1 || die 'systemctl is required for brightness restoration'
fi

install_managed_file() {
    local source="$1" destination="$2" mode="$3" backup=""

    mkdir -p "$(dirname "$destination")"
    if [[ ! -f "$destination" ]] || ! cmp -s "$source" "$destination"; then
        if [[ -e "$destination" ]]; then
            [[ -f "$destination" ]] || die "not a regular file: $destination"
            backup="$(mktemp "$destination.dotfiles-backup.XXXXXX")"
            cp -p "$destination" "$backup"
            log "Backup: $backup"
        fi
        cat "$source" > "$destination"
    fi
    chmod "$mode" "$destination"
}

remove_managed_file() {
    local source="$1" destination="$2"

    [[ -f "$destination" ]] || return 0
    if cmp -s "$source" "$destination"; then
        rm "$destination"
    else
        log "Keeping modified file: $destination"
    fi
}

generated="$(mktemp)"
managed="$(mktemp)"
trap 'rm -f "$generated" "$managed"' EXIT
if [[ "$action" == install ]]; then
    {
        printf '%s\n' '-- >>> dotfiles brightness knob >>>'
        cat "$saved_bindings"
        printf '%s\n' '-- <<< dotfiles brightness knob <<<'
    } > "$managed"
fi

had_managed_block=false
if [[ -f "$bindings" ]] && grep -Fxq -- '-- >>> dotfiles brightness knob >>>' "$bindings"; then
    had_managed_block=true
fi
if [[ -f "$bindings" ]]; then
    awk -v action="$action" -v replacement="$managed" '
        $0 == "-- >>> dotfiles brightness knob >>>" {
            if (inside || count++) exit 1
            inside=1
            if (action == "install") {
                while ((getline replacement_line < replacement) > 0) print replacement_line
                close(replacement)
            }
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
if [[ "$action" == install && "$had_managed_block" == false ]]; then
    cat "$managed" >> "$generated"
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
    install_managed_file "$saved_helper" "$helper" 0755
    install_managed_file "$saved_restore_helper" "$restore_helper" 0755
    install_managed_file "$saved_service" "$service" 0644
    systemctl --user daemon-reload
    systemctl --user enable --now omarchy-brightness-restore.service
else
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user disable --now omarchy-brightness-restore.service || true
    fi
    remove_managed_file "$saved_helper" "$helper"
    remove_managed_file "$saved_restore_helper" "$restore_helper"
    remove_managed_file "$saved_service" "$service"
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload
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
