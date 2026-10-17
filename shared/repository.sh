# shellcheck shell=bash
# Shared by Bash and Zsh; no shell options or startup hooks.
_dotfiles_repository() {
    command python3 "$DOTFILES_DIR/omasync/sync.py" --repo "$DOTFILES_DIR" "$@"
}
_dotfiles_upload() { _dotfiles_repository up; }
_dotfiles_download() { _dotfiles_repository down; }

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
