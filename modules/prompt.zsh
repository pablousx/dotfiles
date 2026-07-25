# Powerlevel10k is loaded by the plugin bundle before this configuration.
[[ ! -f "$DOTFILES_DIR/.p10k.zsh" ]] || source "$DOTFILES_DIR/.p10k.zsh"

# Vs code & Windows Terminal integration
if [[ "$TERM_PROGRAM" == "vscode" || "$WT_SESSION" != "" ]]; then
  POWERLEVEL9K_TERM_SHELL_INTEGRATION=true
fi
