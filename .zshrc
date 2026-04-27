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
