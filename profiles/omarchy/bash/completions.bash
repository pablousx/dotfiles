# Omarchy owns bash-completion and fzf initialization. Never replace its specs.
_dotfiles_package_scripts() {
    COMPREPLY=()
    command -v python3 >/dev/null 2>&1 || return 0
    local candidate cur="${COMP_WORDS[COMP_CWORD]}"
    # Offer scripts only in script positions, not package install arguments.
    case "${COMP_WORDS[0]#df-}:${COMP_WORDS[1]-}:$COMP_CWORD" in
        npm:run:2|npm:run-script:2|pnpm:run:2|yarn:run:2|pnpm:*:1|yarn:*:1) ;;
        *) return 0 ;;
    esac
    while IFS= read -r candidate; do
        [[ "$candidate" != "$cur"* ]] || COMPREPLY+=("$candidate")
    done < <(python3 "$DOTFILES_DIR/profiles/omarchy/tools.py" scripts)
}
for _dotfiles_tool in npm pnpm yarn; do
    if command -v "$_dotfiles_tool" >/dev/null 2>&1; then
        # Ask bash-completion to discover the installed command's own completion.
        if ! complete -p "$_dotfiles_tool" &>/dev/null && declare -F _completion_loader >/dev/null; then
            _completion_loader "$_dotfiles_tool" &>/dev/null || true
        fi
        if ! complete -p "$_dotfiles_tool" &>/dev/null; then
            complete -o bashdefault -o default -F _dotfiles_package_scripts "$_dotfiles_tool"
        fi
    fi
done
# An explicit script runner guarantees local script completion even when packaged
# completions do not handle scripts. Existing commands/completions still win.
if ! type -t df-run >/dev/null; then
    df-run() {
        local manager="${1:-}"; shift || return 2
        case "$manager" in npm|pnpm|yarn) ;; *) printf 'Usage: df-run npm|pnpm|yarn SCRIPT [ARGS...]\n' >&2; return 2 ;; esac
        command -v "$manager" >/dev/null 2>&1 || { printf 'Install %s with mise.\n' "$manager" >&2; return 127; }
        command "$manager" run "$@"
    }
    _dotfiles_run_complete() {
        COMPREPLY=()
        local candidate cur="${COMP_WORDS[COMP_CWORD]}"
        if [[ "$COMP_CWORD" == 1 ]]; then
            for candidate in npm pnpm yarn; do
                [[ "$candidate" != "$cur"* ]] || COMPREPLY+=("$candidate")
            done
        elif [[ "$COMP_CWORD" == 2 ]] && command -v python3 >/dev/null 2>&1; then
            while IFS= read -r candidate; do
                [[ "$candidate" != "$cur"* ]] || COMPREPLY+=("$candidate")
            done < <(python3 "$DOTFILES_DIR/profiles/omarchy/tools.py" scripts)
        fi
    }
    complete -o default -F _dotfiles_run_complete df-run
fi
unset _dotfiles_tool
