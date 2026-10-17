# shellcheck shell=bash
# Shared by Bash and Zsh; no shell options or startup hooks.
_dotfiles_git() {
    command git -C "$DOTFILES_DIR" "$@"
}

_dotfiles_upload() {
    local current_branch msg
    current_branch="$(_dotfiles_git symbolic-ref --quiet --short HEAD)" || {
        printf '%s\n' 'Cannot upload dotfiles from a detached HEAD.' >&2
        return 1
    }
    _dotfiles_sync_ai || return
    _dotfiles_git status -s || return
    printf "Commit message (blank uses today's date): "
    IFS= read -r msg || return
    [[ -n "$msg" ]] || msg="dotfiles updated $(date +%d-%m-%y)"
    _dotfiles_git add -u || return
    # Include new rules and skills without staging unrelated untracked files.
    _dotfiles_git add -- ai || return
    if _dotfiles_git diff --cached --quiet; then
        printf '%s\n' 'No tracked changes to commit.'
    else
        _dotfiles_git commit -m "$msg" || return
    fi
    _dotfiles_git push origin "$current_branch"
}

_dotfiles_sync_ai() {
    # Successful setup records installed content here; preserve per-machine opt-in.
    if [[ -f "$HOME/.local/state/dotfiles-ai/.codex/AGENTS.md" ]]; then
        bash "$DOTFILES_DIR/scripts/sync-ai.sh"
    else
        printf '%s\n' 'AI sync skipped (not installed on this machine).'
    fi
}

_dotfiles_download() {
    _dotfiles_git pull --ff-only || return
    _dotfiles_sync_ai
}

# Reserve only these two subcommands; retain the system disk-usage command.
df() {
    case "${1:-}" in
        up|down)
            [[ "$#" == 1 ]] || { printf '%s\n' 'Usage: df up | df down' >&2; return 2; }
            case "$1" in
                up) _dotfiles_upload ;;
                down) _dotfiles_download ;;
            esac
            ;;
        *) command df "$@" ;;
    esac
}
