sudo apt update
sudo apt install zsh git curl nano

curl -fsSL https://fnm.vercel.app/install | bash

touch $HOME/.zshrc
if ! grep -q "export ZDOTDIR=~/dotfiles" $HOME/.zshrc; then
  echo "export ZDOTDIR=~/dotfiles" >> $HOME/.zshrc
fi
if ! grep -q "source $ZDOTDIR/.zshrc" $HOME/.zshrc; then
  echo "source $ZDOTDIR/.zshrc" >> $HOME/.zshrc
fi

chsh -s $(which zsh)

curl -sfL git.io/antibody | sh -s - -b /usr/local/bin

cp .env.example .env

zsh-plugins

exec zsh
