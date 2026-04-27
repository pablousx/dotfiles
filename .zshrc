# Add deno completions to search path
if [[ ":$FPATH:" != *":$ZDOTDIR/completions:"* ]]; then export FPATH="$ZDOTDIR/completions:$FPATH"; fi
export HOME_ZSHRC="$HOME/.zshrc"
export ZSHRC="$ZDOTDIR/.zshrc"

# SSH Environment Configuration
source $HOME/.ssh/sync-ssh-env.sh

# ================= MODULES =================

# Enable or disable modules creating a ./.env file (copy ./.env.example to ./.env)
if [[ -f $ZDOTDIR/.env ]]; then
  export $(grep -v '^#' $ZDOTDIR/.env | xargs)
fi

# Optimizing auto-completion
autoload -Uz compinit
if [[ -n $ZDOTDIR/.zcompdump(N.mh+24) ]]; then
  compinit
else
  compinit -C
fi

# ================= COMPLETION ENGINE SETTINGS =================
# Use LS_COLORS for completions
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Group completions by type
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{blue}-- %d --%f'
zstyle ':completion:*:corrections' format '%F{yellow}!- %d (errors: %e) -!%f'
zstyle ':completion:*:messages' format '%F{purple} -- %d --%f'
zstyle ':completion:*:warnings' format '%F{red}No matches for:%f %d'

# Smart matching (Case-insensitive, partial-word, and substring)
# 0: exact match, 1: case-insensitive, 2: partial-word, 3: substring
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# Automatically select the first element of fzf-tab
zstyle ':fzf-tab:*' fzf-preview-window 'right:60%'

# ================= ZSH OPTIONS =================
setopt GLOB_DOTS              # Match hidden files with globs
setopt NUMERIC_GLOB_SORT      # Sort filenames numerically (1, 2, 10 instead of 1, 10, 2)
setopt NO_BEEP                # Shut up
setopt INTERACTIVE_COMMENTS   # Allow comments in interactive shell
setopt MAGIC_EQUAL_SUBST      # Expansion after = (e.g. --prefix=~/bin)
setopt NOTIFY                 # Report status of background jobs immediately
setopt AUTO_RESUME            # Resume existing job if typing its name
setopt LONG_LIST_JOBS         # List jobs in the long format by default

# Automatically quote URLs when pasted
autoload -Uz url-quote-magic
zle -N self-insert url-quote-magic

# ALIASES - Source aliases definition
if [[ $DISABLE_ALIASES != true ]]; then
  source $ZDOTDIR/modules/aliases.zsh
fi

# PROMPT - Powerlevel10k
if [[ $DISABLE_PROMPT != true ]]; then
  source $ZDOTDIR/modules/prompt.zsh
fi

# Loading fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# fzf-tab styles
zstyle ':completion:*' menu no
zstyle ':fzf-tab:*' fzf-flags --color=fg:1,fg+:2 --bind=tab:accept
zstyle ':fzf-tab:*' switch-group '<' '>'

# fzf-tab previews
# Directory previews (ls)
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color=always $realpath'
zstyle ':fzf-tab:complete:ls:*' fzf-preview 'ls --color=always $realpath'

# File previews (cat/head)
zstyle ':fzf-tab:complete:(cat|nano|open|vi|vim):*' fzf-preview '[[ -f $realpath ]] && head -n 20 $realpath'

# Command help previews (tldr/man)
zstyle ':fzf-tab:complete:(-command-|-parameter-|-brace-parameter-|export|unset|expand):*' fzf-preview 'echo ${(P)word}'

# Process previews (kill)
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-preview \
  '[[ $group == "[process ID]" ]] && ps -p $word -o comm,stat,pcpu,pmem'
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-flags --preview-window=down:3:wrap

# Git previews
zstyle ':fzf-tab:complete:git-(add|diff|restore):*' fzf-preview 'git diff $word | head -n 20'
zstyle ':fzf-tab:complete:git-log:*' fzf-preview 'git log -n 1 $word'
zstyle ':fzf-tab:complete:git-show:*' fzf-preview 'git show --color=always $word | head -n 20'
zstyle ':fzf-tab:complete:git-checkout:*' fzf-preview '[ -f "$realpath" ] && git diff "$word" || git log -n 5 --graph --color=always "$word"'

# Systemd previews
zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'systemctl status $word'

# PLUGINS - Antidote
if [[ $DISABLE_PLUGINS != true ]]; then
  fpath=($ZDOTDIR/.antidote/functions $fpath)
  autoload -Uz antidote
  source $ZDOTDIR/modules/plugins.zsh
fi

# PRINT ALIAS COMPLETION
if [[ $DISABLE_PRINT_ALIAS_COMPLETION != true ]]; then
  source $ZDOTDIR/modules/print-alias-completion.zsh
fi

# EXPAND ALIAS
if [[ $DISABLE_EXPAND_ALIAS != true ]]; then
  source $ZDOTDIR/modules/expand-alias.zsh
fi

# ================= CONFIGURATION =================
# Default Editor
export EDITOR="nano"

# Enable command auto-correction
ENABLE_CORRECTION="true"

# ================= HISTORY =================
HISTFILE="$ZDOTDIR/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY        # save timestamp and duration
setopt HIST_EXPIRE_DUPS_FIRST  # expire duplicates first when trimming
setopt HIST_IGNORE_DUPS        # don't record duplicate of previous command
setopt HIST_IGNORE_SPACE       # skip commands starting with a space
setopt HIST_VERIFY             # show expanded history before running
setopt SHARE_HISTORY           # share history across all sessions

# ================= DIRECTORIES =================
setopt AUTO_CD                 # type a directory name to cd into it
setopt AUTO_PUSHD              # cd pushes to directory stack
setopt PUSHD_IGNORE_DUPS       # no duplicate entries in stack
setopt PUSHD_SILENT            # don't print stack on pushd/popd

# ================= TWEAKS =================

#Fix slowness of pastes with zsh-syntax-highlighting.zsh
pasteinit() {
  OLD_SELF_INSERT=${${(s.:.)widgets[self-insert]}[2,3]}
  zle -N self-insert url-quote-magic
}

pastefinish() {
  zle -N self-insert $OLD_SELF_INSERT
}

zstyle :bracketed-paste-magic paste-init pasteinit
zstyle :bracketed-paste-magic paste-finish pastefinish

# fnm
FNM_PATH="$HOME/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --use-on-cd --version-file-strategy=recursive)"
fi

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"

# opencode
export PATH="$HOME/.opencode/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
. "/home/pablousx/.deno/env"
