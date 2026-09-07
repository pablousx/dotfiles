# Public commands are registered only when their names are free.
_dotfiles_edit() {
    local -a editor
    # EDITOR supports a command and whitespace-separated options, not shell code.
    read -r -a editor <<< "${EDITOR:-nano}"
    "${editor[@]}" "$1" && exec bash
}
_dotfiles_python() {
    python3 "$DOTFILES_DIR/profiles/omarchy/tools.py" "$@"
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
        clear) clear && printf '\033[%s;1H' "${LINES:-24}" ;;
        sql) "$HOME/sqlcl/bin/sql" "$@" ;;
        open) xdg-open "$@" ;;
        google|duck)
            local query base='https://www.google.com/search?q='
            [[ "$action" != duck ]] || base='https://duckduckgo.com/?q='
            query="$(_dotfiles_python urlencode "$*")" || return
            xdg-open "$base$query"
            ;;
        copyfile)
            [[ "$#" == 1 && -f "$1" ]] || { printf 'Usage: copyfile FILE\n' >&2; return 2; }
            wl-copy < "$1"
            ;;
        copypath) printf '%s' "$PWD" | wl-copy ;;
        extract)
            [[ "$#" == 1 && -f "$1" ]] || { printf 'Usage: x ARCHIVE\n' >&2; return 2; }
            local archive="$1"
            [[ "$archive" == /* ]] || archive="$PWD/$archive"
            case "$archive" in
                *.tar|*.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz|*.tar.zst) tar -xf "$archive" ;;
                *.zip) unzip "$archive" ;;
                *.7z) 7z x "$archive" ;;
                *.rar) unrar x "$archive" ;;
                *.gz) gzip -dk -- "$archive" ;;
                *.bz2) bzip2 -dk -- "$archive" ;;
                *.xz) xz -dk -- "$archive" ;;
                *.zst) zstd -dk -- "$archive" ;;
                *) printf 'Unsupported archive: %s\n' "$archive" >&2; return 2 ;;
            esac
            ;;
        gi)
            [[ "$#" -gt 0 ]] || { printf 'Usage: gi LANGUAGE[,LANGUAGE...]\n' >&2; return 2; }
            local query
            query="$(_dotfiles_python urlencode "$*")" || return
            curl --fail --silent --show-error --location "https://www.toptal.com/developers/gitignore/api/$query"
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
            for ((i = 0; i < 4; i++)); do /usr/bin/time bash -i -c exit; done
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
ni|npm install
nd|npm run dev
nb|npm run build
ns|npm run start
pni|pnpm install
pnd|pnpm run dev
pnb|pnpm run build
pns|pnpm run start
yi|yarn install
yd|yarn dev
yb|yarn build
ys|yarn start
c|code -r
cls|_dotfiles_helper clear
cx|_dotfiles_helper up
cz|_dotfiles_helper back
dev|_dotfiles_helper dev
lc|eza -la --group-directories-first
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
gst|git status
gco|git checkout
gcm|git checkout main
gp|git push
gl|git pull
glog|git log --oneline --decorate --graph
dco|docker compose
dcup|docker compose up
dcdown|docker compose down
dce|docker compose exec
ALIASES
unset name expansion
unset -f _dotfiles_register
