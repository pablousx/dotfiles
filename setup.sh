#!/usr/bin/env zsh

# Core dependencies
sudo apt update
sudo apt install zsh git curl nano unzip fzf -y

# fnm
NODE_VERSION=${NODE_VERSION:-24.12.0}
if ! command -v fnm &> /dev/null; then
  curl -fsSL https://fnm.vercel.app/install | bash
  # Make fnm available for the rest of this script without exporting PATH
  fnm() { "$HOME/.local/share/fnm/fnm" "$@" }
fi
fnm install $NODE_VERSION
fnm default $NODE_VERSION

# xxh — portable shell over SSH
if ! command -v xxh &>/dev/null; then
  echo "Installing xxh..."
  if command -v brew &>/dev/null; then
    brew install xxh
  else
    # Fallback to pip if brew is missing
    sudo apt install python3-pip -y
    pip3 install xxh-xxh
  fi
  xxh +I xxh-shell-zsh
  xxh +I xxh-plugin-zsh-dotfiles+path+$HOME/dotfiles/modules/xxh-plugin
fi

ZDOTDIR=$HOME/dotfiles

# Zellij Setup
if ! command -v zellij &> /dev/null; then
  echo "Installing zellij..."
  mkdir -p "$HOME/.local/bin"
  URL=$(curl -s -H "User-Agent: curl" https://api.github.com/repos/zellij-org/zellij/releases/latest | grep "browser_download_url.*x86_64-unknown-linux-musl.tar.gz" | head -n 1 | cut -d '"' -f 4)
  if [[ -n "$URL" ]]; then
    curl -L "$URL" | tar -xz -C "$HOME/.local/bin"
  else
    echo "Error: Could not find Zellij download URL. You might be rate-limited by GitHub API."
  fi
fi
mkdir -p "$HOME/.config"
if [[ ! -L "$HOME/.config/zellij" && ! -d "$HOME/.config/zellij" ]]; then
  ln -s "$ZDOTDIR/zellij" "$HOME/.config/zellij"
fi

# fzf-zellij Setup
if [[ ! -f "$HOME/.local/bin/fzf-zellij" ]]; then
  echo "Installing fzf-zellij..."
  curl -L https://raw.githubusercontent.com/k-kuroguro/fzf-zellij/refs/heads/main/bin/fzf-zellij -o "$HOME/.local/bin/fzf-zellij"
  chmod +x "$HOME/.local/bin/fzf-zellij"
fi

# room Setup
if [[ ! -f "$HOME/.config/zellij/plugins/room.wasm" ]]; then
  echo "Installing room..."
  mkdir -p "$HOME/.config/zellij/plugins"
  curl -L https://github.com/rvcas/room/releases/latest/download/room.wasm -o "$HOME/.config/zellij/plugins/room.wasm"
fi

# zellij-forgot Setup
if [[ ! -f "$HOME/.config/zellij/plugins/zellij_forgot.wasm" ]]; then
  echo "Installing zellij-forgot..."
  mkdir -p "$HOME/.config/zellij/plugins"
  curl -L https://github.com/karimould/zellij-forgot/releases/latest/download/zellij_forgot.wasm -o "$HOME/.config/zellij/plugins/zellij_forgot.wasm"
fi



# Bootstrap $HOME/.zshrc
touch $HOME/.zshrc
if ! grep -q "export ZDOTDIR=$ZDOTDIR" $HOME/.zshrc; then
  echo "export ZDOTDIR=$ZDOTDIR" >> $HOME/.zshrc
fi
if ! grep -q "source \$ZDOTDIR/.zshrc" $HOME/.zshrc; then
  echo "source \$ZDOTDIR/.zshrc" >> $HOME/.zshrc
fi

# Change shell
sudo chsh -s $(which zsh) $(whoami)

# Antidote
if [[ ! -d "$ZDOTDIR/.antidote" ]]; then
  git clone --depth=1 https://github.com/mattmc3/antidote.git "$ZDOTDIR/.antidote"
fi

# Bundle plugins (without relying on aliases)
source "$ZDOTDIR/.antidote/antidote.zsh"
antidote bundle < "$ZDOTDIR/modules/plugins.txt" > "$ZDOTDIR/modules/plugins.zsh"

if [[ ! -f "$ZDOTDIR/.env" ]]; then
  cp "$ZDOTDIR/.env.example" "$ZDOTDIR/.env"
fi

# Binary Plugins (Plugins that require a compiled binary)
PNPM_COMPLETION_DIR="$HOME/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-g-plane-SLASH-pnpm-shell-completion"
if [[ -d "$PNPM_COMPLETION_DIR" && ! -f "$PNPM_COMPLETION_DIR/pnpm-shell-completion" ]]; then
  echo "Downloading pnpm-shell-completion binary..."
  URL=$(curl -s -H "User-Agent: curl" https://api.github.com/repos/g-plane/pnpm-shell-completion/releases/latest | grep "browser_download_url.*x86_64-unknown-linux-gnu.tar.gz" | head -n 1 | cut -d '"' -f 4)
  if [[ -n "$URL" ]]; then
    curl -L "$URL" | tar -xz -C "$PNPM_COMPLETION_DIR/"
    chmod +x "$PNPM_COMPLETION_DIR/pnpm-shell-completion"
  else
    echo "Error: Could not find pnpm-shell-completion download URL."
  fi
fi

echo "Setup complete! Restart your terminal or run: exec zsh"
