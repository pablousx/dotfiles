# Sourced after Omarchy and user initialization, never from noninteractive Bash.
[[ $- == *i* ]] || return 0
[[ -z ${_DOTFILES_BASH_LOADED:-} ]] || return 0
_DOTFILES_BASH_LOADED=1
DOTFILES_DIR="$(builtin cd -- "$(command dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
export DOTFILES_DIR

_dotfiles_bash_settings() {
    local key value protected=':'
    local settings="$DOTFILES_DIR/.env.omarchy"
    for key in DISABLE_ALIASES DISABLE_PROMPT DISABLE_COMPLETIONS DISABLE_HISTORY_SYNC; do
        [[ ! -v $key ]] || protected="$protected$key:"
    done
    if [[ -r "$settings" ]]; then
        while IFS='=' read -r key value || [[ -n "$key" ]]; do
            value="${value%$'\r'}"
            case "$key" in
                DISABLE_ALIASES|DISABLE_PROMPT|DISABLE_COMPLETIONS|DISABLE_HISTORY_SYNC)
                    case "$value" in true|false) ;; *) continue ;; esac
                    [[ "$protected" == *":$key:"* ]] || printf -v "$key" '%s' "$value"
                    ;;
            esac
        done < "$settings"
    fi
    # Invalid environment values do not enable features accidentally.
    for key in DISABLE_ALIASES DISABLE_PROMPT DISABLE_COMPLETIONS DISABLE_HISTORY_SYNC; do
        value="${!key-false}"
        case "$value" in true|false) ;; *) value=true ;; esac
        printf -v "$key" '%s' "$value"
    done
}
_dotfiles_bash_settings
unset -f _dotfiles_bash_settings

if [[ "$DISABLE_PROMPT" == false && ! -v STARSHIP_CONFIG ]]; then
    [[ "$EUID" != 0 ]] || export DOTFILES_ROOT_CONTEXT=1
    export STARSHIP_CONFIG="$DOTFILES_DIR/profiles/omarchy/config/starship-omarchy.toml"
fi
if [[ "$DISABLE_ALIASES" == false ]]; then
    source "$DOTFILES_DIR/shared/repository.sh"
    source "$DOTFILES_DIR/profiles/omarchy/bash/helpers.bash"
fi
if [[ "$DISABLE_COMPLETIONS" == false ]]; then
    source "$DOTFILES_DIR/profiles/omarchy/bash/completions.bash"
fi
if [[ "$DISABLE_HISTORY_SYNC" == false ]]; then
    _dotfiles_history_sync() {
        local last_status=$?
        # Keep HISTFILE, history format, and all existing prompt hooks.
        if [[ -n ${HISTFILE:-} ]]; then
            builtin history -a
            builtin history -n
        fi
        return "$last_status"
    }
    if [[ $(declare -p PROMPT_COMMAND 2>/dev/null) == 'declare -a '* ]]; then
        PROMPT_COMMAND+=('_dotfiles_history_sync')
    else
        PROMPT_COMMAND=("${PROMPT_COMMAND[0]-}" '_dotfiles_history_sync')
    fi
fi
