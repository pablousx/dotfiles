# Public commands are registered only when their names are free.
_dotfiles_run() {
    command -v "$1" >/dev/null 2>&1 || {
        printf 'dotfiles: %s is required; install it using Omarchy or mise.\n' "$1" >&2
        return 127
    }
    command "$@"
}
_dotfiles_edit() {
    local -a editor
    # EDITOR supports a command and whitespace-separated options, not shell code.
    read -r -a editor <<< "${EDITOR:-nano}"
    _dotfiles_run "${editor[@]}" "$1" && exec bash
}
_dotfiles_python() {
    _dotfiles_run python3 "$DOTFILES_DIR/profiles/omarchy/tools.py" "$@"
}
_dotfiles_helper() {
    local action="$1"; shift
    case "$action" in
        repo) _dotfiles_git "$@" ;;
        upload) _dotfiles_upload "$@" ;;
        reload) exec bash ;;
        config) _dotfiles_edit "$DOTFILES_DIR/profiles/omarchy/bash/rc.bash" ;;
        aliases) _dotfiles_edit "$DOTFILES_DIR/profiles/omarchy/bash/helpers.bash" ;;
        settings) _dotfiles_edit "$DOTFILES_DIR/.env.omarchy" ;;
        prompt) _dotfiles_edit "$DOTFILES_DIR/profiles/omarchy/config/starship-omarchy.toml" ;;
        up) cd .. ;;
        back) cd - || return ;;
        dev) cd "$HOME/dev" || return ;;
        bottom) printf '\033[%s;1H' "${LINES:-24}" ;;
        clear) _dotfiles_run clear && printf '\033[%s;1H' "${LINES:-24}" ;;
        sql) _dotfiles_run "$HOME/sqlcl/bin/sql" "$@" ;;
        open) _dotfiles_run xdg-open "$@" ;;
        google|duck)
            local query base='https://www.google.com/search?q='
            [[ "$action" != duck ]] || base='https://duckduckgo.com/?q='
            query="$(_dotfiles_python urlencode "$*")" || return
            _dotfiles_run xdg-open "$base$query"
            ;;
        copyfile)
            [[ "$#" == 1 && -f "$1" ]] || { printf 'Usage: copyfile FILE\n' >&2; return 2; }
            _dotfiles_run wl-copy < "$1"
            ;;
        copypath) printf '%s' "$PWD" | _dotfiles_run wl-copy ;;
        extract)
            [[ "$#" == 1 && -f "$1" ]] || { printf 'Usage: x ARCHIVE\n' >&2; return 2; }
            local archive="$1"
            [[ "$archive" == /* ]] || archive="$PWD/$archive"
            case "$archive" in
                *.tar|*.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz|*.tar.zst) _dotfiles_run tar -xf "$archive" ;;
                *.zip) _dotfiles_run unzip "$archive" ;;
                *.7z) _dotfiles_run 7z x "$archive" ;;
                *.rar) _dotfiles_run unrar x "$archive" ;;
                *.gz) _dotfiles_run gzip -dk -- "$archive" ;;
                *.bz2) _dotfiles_run bzip2 -dk -- "$archive" ;;
                *.xz) _dotfiles_run xz -dk -- "$archive" ;;
                *.zst) _dotfiles_run zstd -dk -- "$archive" ;;
                *) printf 'Unsupported archive: %s\n' "$archive" >&2; return 2 ;;
            esac
            ;;
        gi)
            [[ "$#" -gt 0 ]] || { printf 'Usage: gi LANGUAGE[,LANGUAGE...]\n' >&2; return 2; }
            local query
            query="$(_dotfiles_python urlencode "$*")" || return
            _dotfiles_run curl --fail --silent --show-error --location "https://www.toptal.com/developers/gitignore/api/$query"
            ;;
        als) alias | command grep -F -- "${1:-}" ;;
        inspect)
            [[ "$#" == 1 ]] || { printf 'Usage: alias-show NAME\n' >&2; return 2; }
            builtin type -- "$1"
            ;;
        history) builtin history ;;
        hs) builtin history | command grep -F -- "${1:-}" ;;
        hsi) builtin history | command grep -Fi -- "${1:-}" ;;
        timing)
            local i
            for ((i = 0; i < 4; i++)); do _dotfiles_run /usr/bin/time bash -i -c exit; done
            ;;
        *) _dotfiles_python "$action" "$@" ;;
    esac
}
_dotfiles_register() {
    local name="$1" expansion="$2"
    # Always provide a deterministic prefixed name, unless the user owns it too.
    if ! type -t "df-$name" >/dev/null; then
        # Registry entries are literal commands, deliberately expanded at registration.
        # shellcheck disable=SC2139
        alias "df-$name=$expansion"
    fi
    if ! type -t "$name" >/dev/null; then
        # shellcheck disable=SC2139
        alias "$name=$expansion"
    fi
}
_dotfiles_register dotfiles '_dotfiles_helper repo'
_dotfiles_register upload-dotfiles '_dotfiles_helper upload'
while IFS='|' read -r name expansion; do
    _dotfiles_register "$name" "$expansion"
done <<'ALIASES'
ni|_dotfiles_run npm install
nd|_dotfiles_run npm run dev
nb|_dotfiles_run npm run build
ns|_dotfiles_run npm run start
pni|_dotfiles_run pnpm install
pnd|_dotfiles_run pnpm run dev
pnb|_dotfiles_run pnpm run build
pns|_dotfiles_run pnpm run start
yi|_dotfiles_run yarn install
yd|_dotfiles_run yarn dev
yb|_dotfiles_run yarn build
ys|_dotfiles_run yarn start
c|_dotfiles_run code -r
cls|_dotfiles_helper clear
cx|_dotfiles_helper up
cz|_dotfiles_helper back
dev|_dotfiles_helper dev
lc|_dotfiles_run eza -la --group-directories-first
sql|_dotfiles_helper sql
open|_dotfiles_helper open
reload|_dotfiles_helper reload
bash-config|_dotfiles_helper config
bash-aliases|_dotfiles_helper aliases
bash-settings|_dotfiles_helper settings
bash-prompt|_dotfiles_helper prompt
move_to_bottom|_dotfiles_helper bottom
google|_dotfiles_helper google
duck|_dotfiles_helper duck
timebash|_dotfiles_helper timing
copyfile|_dotfiles_helper copyfile
copypath|_dotfiles_helper copypath
x|_dotfiles_helper extract
e64|_dotfiles_helper e64
d64|_dotfiles_helper d64
pp_json|_dotfiles_helper pp_json
is_json|_dotfiles_helper is_json
urlencode_json|_dotfiles_helper urlencode_json
urldecode_json|_dotfiles_helper urldecode_json
urlencode|_dotfiles_helper urlencode
urldecode|_dotfiles_helper urldecode
h|_dotfiles_helper history
hs|_dotfiles_helper hs
hsi|_dotfiles_helper hsi
als|_dotfiles_helper als
alias-show|_dotfiles_helper inspect
gi|_dotfiles_helper gi
gst|_dotfiles_run git status
gco|_dotfiles_run git checkout
gcm|_dotfiles_run git checkout main
gp|_dotfiles_run git push
gl|_dotfiles_run git pull
glog|_dotfiles_run git log --oneline --decorate --graph
dco|_dotfiles_run docker compose
dcup|_dotfiles_run docker compose up
dcdown|_dotfiles_run docker compose down
dce|_dotfiles_run docker compose exec
ALIASES
unset name expansion
unset -f _dotfiles_register
