# Bash implementations of helpers used by the pinned Git alias catalog.
# Adapted from Oh My Zsh (MIT); see ../licenses/oh-my-zsh.txt.
_dotfiles_git_current_branch() {
    local ref
    ref=$(command git symbolic-ref --quiet HEAD 2>/dev/null) || {
        command git rev-parse --short HEAD 2>/dev/null
        return
    }
    printf '%s\n' "${ref#refs/heads/}"
}
_dotfiles_git_main_branch() {
    command git rev-parse --git-dir &>/dev/null || return
    local prefix branch ref remote
    for prefix in refs/heads refs/remotes/origin refs/remotes/upstream; do
        for branch in main trunk mainline default stable master; do
            if command git show-ref -q --verify "$prefix/$branch"; then
                printf '%s\n' "$branch"
                return 0
            fi
        done
    done
    for remote in origin upstream; do
        ref=$(command git symbolic-ref --quiet "refs/remotes/$remote/HEAD" 2>/dev/null) || continue
        printf '%s\n' "${ref#refs/remotes/"$remote"/}"
        return 0
    done
    printf 'master\n'
    return 1
}
_dotfiles_git_develop_branch() {
    command git rev-parse --git-dir &>/dev/null || return
    local branch
    for branch in dev devel develop development; do
        if command git show-ref -q --verify "refs/heads/$branch"; then
            printf '%s\n' "$branch"
            return 0
        fi
    done
    printf 'develop\n'
    return 1
}
_dotfiles_git_pull_current() {
    if [[ $# == 0 ]]; then set -- "$(_dotfiles_git_current_branch)"; fi
    git pull origin "$@"
}
_dotfiles_git_push_current() {
    if [[ $# == 0 ]]; then set -- "$(_dotfiles_git_current_branch)"; fi
    git push origin "$@"
}
_dotfiles_git_pull_rebase() {
    if [[ $# == 0 ]]; then set -- "$(_dotfiles_git_current_branch)"; fi
    git pull --rebase origin "$@"
}
_dotfiles_git_push_force() {
    if [[ $# == 0 ]]; then set -- "$(_dotfiles_git_current_branch)"; fi
    git push --force origin "$@"
}
_dotfiles_git_push_lease() {
    if [[ $# == 0 ]]; then set -- "$(_dotfiles_git_current_branch)"; fi
    git push --force-with-lease origin "$@"
}
_dotfiles_git_pull_push() {
    _dotfiles_git_pull_current "$@" && _dotfiles_git_push_current "$@"
}
_dotfiles_git_rename() {
    [[ $# == 2 && -n $1 && -n $2 ]] || { printf 'Usage: grename OLD NEW\n' >&2; return 2; }
    git branch -m "$1" "$2" && git push origin ":$1" && git push --set-upstream origin "$2"
}
_dotfiles_git_wip() {
    # add --all already stages deleted paths, including names containing spaces.
    git add --all && git commit --no-verify --no-gpg-sign --message '--wip-- [skip ci]' "$@"
}
_dotfiles_git_unwip_all() {
    local commit head
    commit=$(git log --grep='--wip--' --invert-grep --max-count=1 --format=format:%H) || return
    head=$(git rev-parse HEAD) || return
    if [[ -n $commit && $commit != "$head" ]]; then git reset "$commit"; fi
}
_dotfiles_git_work_in_progress() {
    git -c log.showSignature=false log -n 1 2>/dev/null | grep -q -- '--wip--' && printf 'WIP!!\n'
}
_dotfiles_git_delete_merged() {
    local main develop current branch branches
    main=$(_dotfiles_git_main_branch) || main=${main:-master}
    develop=$(_dotfiles_git_develop_branch) || develop=${develop:-develop}
    current=$(_dotfiles_git_current_branch) || return
    branches=$(git for-each-ref --merged=HEAD --format='%(refname:short)' refs/heads/) || return
    while IFS= read -r branch; do
        [[ -n $branch && $branch != "$main" && $branch != "$develop" && $branch != "$current" ]] || continue
        git branch --delete -- "$branch" || return
    done <<< "$branches"
}
_dotfiles_git_delete_squashed() {
    local default current branch branches merge_base tree commit cherry
    default=$(_dotfiles_git_main_branch) || default=$(_dotfiles_git_develop_branch) || return
    current=$(_dotfiles_git_current_branch) || return
    branches=$(git for-each-ref refs/heads/ '--format=%(refname:short)') || return
    while IFS= read -r branch; do
        [[ -n $branch && $branch != "$default" && $branch != "$current" ]] || continue
        merge_base=$(git merge-base "$default" "$branch") || return
        tree=$(git rev-parse "$branch^{tree}") || return
        commit=$(git commit-tree "$tree" -p "$merge_base" -m _) || return
        cherry=$(git cherry "$default" "$commit") || return
        if [[ $cherry == -* ]]; then git branch -D -- "$branch" || return; fi
    done <<< "$branches"
}
_dotfiles_git_diff_view() { git diff -w "$@" | view -; }
_dotfiles_git_diff_no_lock() { git diff "$@" ':(exclude)package-lock.json' ':(exclude)*.lock'; }
_dotfiles_git_log_prettily() {
    [[ $# -gt 0 ]] || return 0
    local format=$1; shift
    git log "--pretty=$format" "$@"
}
_dotfiles_git_tag_list() { git tag --sort=-v:refname -n --list "${1:-}*"; }
_dotfiles_git_gui() {
    gitk --all --branches "$@" &
    disown "$!"
}
_dotfiles_git_gui_reflog() {
    local refs ref
    local -a commits=()
    refs=$(git log --walk-reflogs --pretty=%h) || return
    while IFS= read -r ref; do [[ -z $ref ]] || commits+=("$ref"); done <<< "$refs"
    gitk --all "${commits[@]}" "$@" &
    disown "$!"
}
_dotfiles_git_clone_cd() {
    local arg repo='' destination='' positional=false
    local -a arguments=("$@")
    while [[ $# -gt 0 ]]; do
        arg=$1; shift
        if [[ $positional == false ]]; then
            case "$arg" in
                --) positional=true; continue ;;
                -b|-o|-u|-c|-j|--branch|--origin|--upload-pack|--config|--jobs|--depth|--shallow-since|--shallow-exclude|--reference|--reference-if-able|--separate-git-dir|--template|--filter|--server-option|--bundle-uri|--revision)
                    [[ $# -gt 0 ]] || { printf 'Missing clone option argument: %s\n' "$arg" >&2; return 2; }
                    shift; continue ;;
                -*) continue ;;
            esac
        fi
        if [[ -z $repo ]]; then repo=$arg; else destination=$arg; fi
    done
    [[ -n $repo ]] || { printf 'Usage: gccd [CLONE_OPTIONS] REPOSITORY [DIRECTORY]\n' >&2; return 2; }
    if [[ -z $destination ]]; then
        destination=${repo%/}; destination=${destination##*/}; destination=${destination##*:}
        destination=${destination%.git}
    fi
    git clone --recurse-submodules "${arguments[@]}" || return
    cd -- "$destination" || return
}
