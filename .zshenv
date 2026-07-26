skip_global_compinit=1

# Resolve the repository when this file is sourced directly.
export DOTFILES_DIR="${DOTFILES_DIR:-${${(%):-%x}:A:h}}"

# Load known boolean settings without evaluating arbitrary shell text. Existing
# environment variables win, which makes one-off overrides predictable.
_dotfiles_load_env() {
  local env_file="$1" key value
  [[ -r "$env_file" ]] || return 0

  while IFS='=' read -r key value; do
    [[ -n "$key" && "$key" != \#* ]] || continue
    value="${value%$'\r'}"
    case "$key" in
      DISABLE_ALIASES|DISABLE_PROMPT|DISABLE_PLUGINS|DISABLE_PRINT_ALIAS_COMPLETION|DISABLE_EXPAND_ALIAS)
        [[ "$value" == true || "$value" == false ]] || {
          print -u2 "Ignoring invalid boolean in $env_file: $key=$value"
          continue
        }
        (( ${+parameters[$key]} )) || export "$key=$value"
        ;;
      *)
        print -u2 "Ignoring unknown setting in $env_file: $key"
        ;;
    esac
  done < "$env_file"
}
_dotfiles_load_env "$DOTFILES_DIR/.env"
unfunction _dotfiles_load_env
