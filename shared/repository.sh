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
    _dotfiles_git status -s || return
    printf "Commit message (blank uses today's date): "
    IFS= read -r msg || return
    [[ -n "$msg" ]] || msg="dotfiles updated $(date +%d-%m-%y)"
    _dotfiles_git add -u || return
    if _dotfiles_git diff --cached --quiet; then
        printf '%s\n' 'No tracked changes to commit.'
    else
        _dotfiles_git commit -m "$msg" || return
    fi
    _dotfiles_git push origin "$current_branch"
}
