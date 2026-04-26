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

echo "Setup complete! Restart your terminal or run: exec zsh"
