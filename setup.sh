#!/usr/bin/env zsh

# Core dependencies
sudo apt update
sudo apt install zsh git curl nano unzip -y

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
  URL=$(curl -s https://api.github.com/repos/g-plane/pnpm-shell-completion/releases/latest | grep "browser_download_url.*x86_64-unknown-linux-gnu.tar.gz" | cut -d '"' -f 4)
  curl -L "$URL" | tar -xz -C "$PNPM_COMPLETION_DIR/"
  chmod +x "$PNPM_COMPLETION_DIR/pnpm-shell-completion"
fi

echo "Setup complete! Restart your terminal or run: exec zsh"
