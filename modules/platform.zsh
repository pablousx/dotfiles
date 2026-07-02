# Platform-specific plugin loading for oh-my-zsh plugins cloned via antidote

OMZ_DIR="$HOME/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-ohmyzsh-SLASH-ohmyzsh"

if [[ "$(uname)" == "Darwin" ]]; then
  # macOS-specific plugins
  if [[ -d "$OMZ_DIR/plugins/macos" ]]; then
    fpath+=("$OMZ_DIR/plugins/macos")
    if [[ -f "$OMZ_DIR/plugins/macos/macos.plugin.zsh" ]]; then
      source "$OMZ_DIR/plugins/macos/macos.plugin.zsh"
    fi
  fi
else
  # Linux-specific plugins (Ubuntu)
  if [[ -d "$OMZ_DIR/plugins/ubuntu" ]]; then
    fpath+=("$OMZ_DIR/plugins/ubuntu")
    if [[ -f "$OMZ_DIR/plugins/ubuntu/ubuntu.plugin.zsh" ]]; then
      source "$OMZ_DIR/plugins/ubuntu/ubuntu.plugin.zsh"
    fi
  fi
  
  # Command Not Found helper
  if [[ -d "$OMZ_DIR/plugins/command-not-found" ]]; then
    fpath+=("$OMZ_DIR/plugins/command-not-found")
    if [[ -f "$OMZ_DIR/plugins/command-not-found/command-not-found.plugin.zsh" ]]; then
      source "$OMZ_DIR/plugins/command-not-found/command-not-found.plugin.zsh"
    fi
  fi
fi
