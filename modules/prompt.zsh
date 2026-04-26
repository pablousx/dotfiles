#Enable Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

[[ ! -f $ZDOTDIR/.p10k.zsh ]] || source $ZDOTDIR/.p10k.zsh

# Vs code & Windows Terminal integration
if [[ "$TERM_PROGRAM" == "vscode" || "$WT_SESSION" != "" ]]; then
  POWERLEVEL9K_TERM_SHELL_INTEGRATION=true
fi

# Update automatically
DISABLE_UPDATE_PROMPT=false
