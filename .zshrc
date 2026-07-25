# Powerlevel10k instant prompt must stay close to the top of this file.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Resolve the repository when this file is sourced directly.
export DOTFILES_DIR="${DOTFILES_DIR:-${${(%):-%x}:A:h}}"
export ZSH_CACHE_DIR="$DOTFILES_DIR/.cache/zsh"
mkdir -p "$ZSH_CACHE_DIR/completions"

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

# Paths
typeset -U path PATH
path=(
  "$HOME/.local/bin"
  "$HOME/.opencode/bin"
  "$HOME/.local/share/pnpm"
  $path
)
export PNPM_HOME="$HOME/.local/share/pnpm"

FNM_PATH="$HOME/.local/share/fnm"
[[ -d "$FNM_PATH" ]] && path=("$FNM_PATH" $path)

fpath=("$DOTFILES_DIR/completions" $fpath)
if [[ -d "$DOTFILES_DIR/.antidote/functions" ]]; then
  fpath=("$DOTFILES_DIR/.antidote/functions" $fpath)
fi

# zsh-completions must be visible before compinit scans fpath.
ANTIDOTE_HOME="${ANTIDOTE_HOME:-$HOME/.cache/antidote}"
zsh_completions_dir="$ANTIDOTE_HOME/github.com/zsh-users/zsh-completions/src"
[[ -d "$zsh_completions_dir" ]] && fpath=("$zsh_completions_dir" $fpath)
unset zsh_completions_dir

# Completion initialization: run the security audit once per day and reuse the
# explicit cache between audits.
_dotfiles_compinit() {
  autoload -Uz compinit
  local dump_file="$ZSH_CACHE_DIR/zcompdump-$ZSH_VERSION"
  local -a stale_dump
  stale_dump=("$dump_file"(N.mh+24))

  if [[ ! -s "$dump_file" || ${#stale_dump} -gt 0 ]]; then
    compinit -d "$dump_file"
    zcompile -R -- "$dump_file.zwc" "$dump_file" 2>/dev/null || true
  else
    compinit -C -d "$dump_file"
  fi
}
_dotfiles_compinit
unfunction _dotfiles_compinit

# Completion presentation
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{blue}-- %d --%f'
zstyle ':completion:*:corrections' format '%F{yellow}!- %d (errors: %e) -!%f'
zstyle ':completion:*:messages' format '%F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format '%F{red}No matches for:%f %d'
zstyle ':completion:*' matcher-list \
  'm:{a-zA-Z}={A-Za-z}' \
  'r:|[._-]=* r:|=*' \
  'l:|=* r:|=*'
zstyle ':completion:*' menu no

# Shell options
setopt GLOB_DOTS
setopt NUMERIC_GLOB_SORT
setopt NO_BEEP
setopt INTERACTIVE_COMMENTS
setopt MAGIC_EQUAL_SUBST
setopt NOTIFY
setopt AUTO_RESUME
setopt LONG_LIST_JOBS
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# History lives outside the repository. Preserve the old history on first use.
ZSH_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/zsh"
mkdir -p "$ZSH_STATE_DIR"
HISTFILE="$ZSH_STATE_DIR/history"
if [[ ! -e "$HISTFILE" && -f "$DOTFILES_DIR/.zsh_history" ]]; then
  command cp -p "$DOTFILES_DIR/.zsh_history" "$HISTFILE"
fi
touch "$HISTFILE"
chmod 0600 "$HISTFILE"
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_VERIFY
setopt SHARE_HISTORY

# Machine-specific SSH agent synchronization.
if [[ -r "$HOME/.ssh/sync-ssh-env.sh" ]]; then
  source "$HOME/.ssh/sync-ssh-env.sh"
fi

: "${EDITOR:=nano}"
export EDITOR
ENABLE_CORRECTION=true

# Plugins load after compinit; completion-only paths were added above.
if [[ "${DISABLE_PLUGINS:-false}" != true ]]; then
  if [[ -r "$DOTFILES_DIR/modules/plugins.zsh" ]]; then
    source "$DOTFILES_DIR/modules/plugins.zsh"
  else
    print -u2 "Plugin bundle missing. Run: bash $DOTFILES_DIR/setup/zsh.sh install $DOTFILES_DIR"
  fi
  [[ -r "$DOTFILES_DIR/modules/platform.zsh" ]] && source "$DOTFILES_DIR/modules/platform.zsh"
fi

# User modules load after third-party plugins so local definitions win.
if [[ "${DISABLE_ALIASES:-false}" != true ]]; then
  source "$DOTFILES_DIR/modules/aliases.zsh"
fi
if [[ "${DISABLE_PRINT_ALIAS_COMPLETION:-false}" != true ]]; then
  source "$DOTFILES_DIR/modules/print-alias-completion.zsh"
fi
if [[ "${DISABLE_EXPAND_ALIAS:-false}" != true ]]; then
  source "$DOTFILES_DIR/modules/expand-alias.zsh"
fi
if [[ "${DISABLE_PROMPT:-false}" != true ]]; then
  source "$DOTFILES_DIR/modules/prompt.zsh"
fi

# fzf-tab styles
zstyle ':fzf-tab:*' fzf-preview-window 'right:60%'
zstyle ':fzf-tab:*' fzf-flags --color=fg:1,fg+:2 --bind=tab:accept
zstyle ':fzf-tab:*' switch-group '<' '>'

if [[ "$(uname -s)" == "Darwin" ]]; then
  if command -v gls >/dev/null 2>&1; then
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'gls --color=always $realpath'
    zstyle ':fzf-tab:complete:ls:*' fzf-preview 'gls --color=always $realpath'
  else
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -G $realpath'
    zstyle ':fzf-tab:complete:ls:*' fzf-preview 'ls -G $realpath'
  fi
else
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color=always $realpath'
  zstyle ':fzf-tab:complete:ls:*' fzf-preview 'ls --color=always $realpath'
fi

zstyle ':fzf-tab:complete:(cat|nano|open|vi|vim):*' fzf-preview \
  '[[ -f $realpath ]] && head -n 20 -- $realpath'
zstyle ':fzf-tab:complete:(-command-|-parameter-|-brace-parameter-|export|unset|expand):*' \
  fzf-preview 'echo ${(P)word}'
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-preview \
  '[[ $group == "[process ID]" ]] && ps -p $word -o comm,stat,pcpu,pmem'
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-flags --preview-window=down:3:wrap
zstyle ':fzf-tab:complete:git-(add|diff|restore):*' fzf-preview \
  'git diff -- $word | head -n 20'
zstyle ':fzf-tab:complete:git-log:*' fzf-preview 'git log -n 1 -- $word'
zstyle ':fzf-tab:complete:git-show:*' fzf-preview \
  'git show --color=always -- $word | head -n 20'
zstyle ':fzf-tab:complete:git-checkout:*' fzf-preview \
  '[[ -f $realpath ]] && git diff -- $word || git log -n 5 --graph --color=always -- $word'

if command -v systemctl >/dev/null 2>&1; then
  zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'systemctl status -- $word'
fi

# Quote pasted URLs while avoiding expensive highlighting during bracketed paste.
autoload -Uz url-quote-magic
zle -N self-insert url-quote-magic

pasteinit() {
  OLD_SELF_INSERT=${${(s.:.)widgets[self-insert]}[2,3]}
  zle -N self-insert url-quote-magic
}

pastefinish() {
  zle -N self-insert "$OLD_SELF_INSERT"
}

zstyle :bracketed-paste-magic paste-init pasteinit
zstyle :bracketed-paste-magic paste-finish pastefinish

if [[ -x "$FNM_PATH/fnm" ]]; then
  eval "$("$FNM_PATH/fnm" env --use-on-cd --version-file-strategy=recursive --shell zsh)"
elif command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --version-file-strategy=recursive --shell zsh)"
fi
