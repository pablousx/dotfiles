#!/usr/bin/env bash
# Manage only the bounded block owned by this profile. Keep symlink targets and modes.
set -Eeuo pipefail
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=setup/lib.sh
source "$SETUP_DIR/../../../setup/lib.sh"
action="${1:-}"
repo="${2:-}"
case "$action" in install|remove|skip) ;; *) die 'expected install, remove, or skip' ;; esac
[[ "$action" != skip ]] || exit 0
[[ "$action" != install || -r "$repo/profiles/omarchy/bash/rc.bash" ]] || die 'Bash profile not found'
startup="$HOME/.bashrc"
[[ ! -L "$startup" || -e "$startup" ]] || die 'refusing to replace dangling .bashrc symlink'
[[ -f "$startup" || ! -e "$startup" ]] || die '.bashrc is not a regular file'
generated="$(mktemp)"
trap 'rm -f "$generated"' EXIT
if [[ -f "$startup" ]]; then
    # Reject damaged/duplicate markers instead of guessing what belongs to us.
    awk '
        $0 == "# >>> dotfiles omarchy >>>" { if (inside || count++) exit 1; inside=1; next }
        $0 == "# <<< dotfiles omarchy <<<" { if (!inside) exit 1; inside=0; next }
        !inside { print }
        END { if (inside) exit 1 }
    ' "$startup" > "$generated" || die 'invalid dotfiles markers in .bashrc; file left unchanged'
fi
if [[ "$action" == install ]]; then
    printf -v quoted_repo '%q' "$repo"
    {
        printf '%s\n' '# >>> dotfiles omarchy >>>'
        printf 'if [[ $- == *i* && -r %s/profiles/omarchy/bash/rc.bash ]]; then\n' "$quoted_repo"
        printf '    source %s/profiles/omarchy/bash/rc.bash\n' "$quoted_repo"
        printf '%s\n' 'fi' '# <<< dotfiles omarchy <<<'
    } >> "$generated"
fi
if [[ -f "$startup" ]] && cmp -s "$generated" "$startup"; then
    log 'Bash startup unchanged.'
    exit 0
fi
if [[ -f "$startup" ]]; then
    backup="$(mktemp "$startup.dotfiles-backup.XXXXXX")"
    cp -p "$startup" "$backup"
    log "Backup: $backup"
else
    [[ "$action" != remove ]] || exit 0
    (umask 077; touch "$startup")
fi
cat "$generated" > "$startup"
log "Bash startup: $action complete."
