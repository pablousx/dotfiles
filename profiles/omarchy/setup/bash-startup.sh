#!/usr/bin/env bash
# Manage bounded Omarchy blocks in Bash startup files; preserve user content, links, and modes.
set -Eeuo pipefail
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=setup/lib.sh
source "$SETUP_DIR/../../../setup/lib.sh"
action="${1:-}"
repo="${2:-}"
case "$action" in install|remove|skip) ;; *) die 'expected install, remove, or skip' ;; esac
[[ "$action" != skip ]] || exit 0
[[ "$action" != install || -r "$repo/profiles/omarchy/bash/rc.bash" ]] || die 'Bash profile not found'
[[ "$action" != install || -r "$repo/profiles/omarchy/bash/environment.bash" ]] || die 'Bash environment file not found'

bashrc="$HOME/.bashrc"
profile_start='# >>> dotfiles omarchy environment >>>'
profile_end='# <<< dotfiles omarchy environment <<<'

select_login_profile() {
    local candidate path
    # On removal, find a previously managed file even if login-file precedence
    # changed. Otherwise follow Bash's login-file precedence.
    if [[ "$action" == remove ]]; then
        for candidate in .bash_profile .bash_login .profile; do
            path="$HOME/$candidate"
            if [[ -f "$path" ]] && grep -Fqx "$profile_start" "$path"; then
                login_profile="$path"
                return
            fi
        done
    fi
    for candidate in .bash_profile .bash_login .profile; do
        path="$HOME/$candidate"
        if [[ -e "$path" || -L "$path" ]]; then
            login_profile="$path"
            return
        fi
    done
    login_profile="$HOME/.profile"
}

validate_target() {
    local startup="$1"
    [[ ! -L "$startup" || -e "$startup" ]] || die "refusing to replace dangling startup symlink: $startup"
    [[ -f "$startup" || ! -e "$startup" ]] || die "startup path is not a regular file: $startup"
}

render_block() {
    local startup="$1" start="$2" end="$3" kind="$4" generated="$5"
    local quoted_repo
    validate_target "$startup"
    if [[ -f "$startup" ]]; then
        awk -v start="$start" -v end="$end" '
            $0 == start { if (inside || count++) exit 1; inside=1; next }
            $0 == end { if (!inside) exit 1; inside=0; next }
            !inside { print }
            END { if (inside) exit 1 }
        ' "$startup" > "$generated" || die "invalid or duplicate dotfiles markers in $startup; file left unchanged"
    else
        : > "$generated"
    fi
    if [[ "$action" == install ]]; then
        printf -v quoted_repo '%q' "$repo"
        if [[ "$kind" == bashrc ]]; then
            {
                printf '%s\n' '# >>> dotfiles omarchy >>>'
                printf 'if [[ $- == *i* && -r %s/profiles/omarchy/bash/rc.bash ]]; then\n' "$quoted_repo"
                printf '    source %s/profiles/omarchy/bash/rc.bash\n' "$quoted_repo"
                printf '%s\n' 'fi' '# <<< dotfiles omarchy <<<'
            } >> "$generated"
        else
            {
                printf '%s\n' "$profile_start"
                printf 'if [ -r %s/profiles/omarchy/bash/environment.bash ]; then\n' "$quoted_repo"
                printf '    . %s/profiles/omarchy/bash/environment.bash\n' "$quoted_repo"
                printf '%s\n' 'fi' "$profile_end"
            } >> "$generated"
        fi
    fi
}

write_block() {
    local startup="$1" generated="$2" label="$3" backup
    if [[ ! -e "$startup" && ! -L "$startup" && "$action" == remove ]]; then
        return
    fi
    if [[ -f "$startup" ]] && cmp -s "$generated" "$startup"; then
        log "$label unchanged."
        return
    fi
    if [[ -f "$startup" ]]; then
        backup="$(mktemp "$startup.dotfiles-backup.XXXXXX")"
        cp -p "$startup" "$backup"
        log "Backup: $backup"
    else
        [[ "$action" != remove ]] || return
        (umask 077; : > "$startup")
    fi
    cat "$generated" > "$startup"
    log "$label: $action complete."
}

select_login_profile
bashrc_generated="$(mktemp)"
profile_generated="$(mktemp)"
trap 'rm -f "$bashrc_generated" "$profile_generated"' EXIT
# Validate and render both files before writing either, so damaged markers do
# not leave a partially installed startup configuration.
render_block "$bashrc" '# >>> dotfiles omarchy >>>' '# <<< dotfiles omarchy <<<' bashrc "$bashrc_generated"
render_block "$login_profile" "$profile_start" "$profile_end" environment "$profile_generated"
write_block "$bashrc" "$bashrc_generated" '.bashrc'
write_block "$login_profile" "$profile_generated" "${login_profile##*/}"
