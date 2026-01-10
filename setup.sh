sudo apt update
sudo apt install zsh git curl nano unzip -y

NODE_VERSION=${NODE_VERSION:-24.12.0}
curl -fsSL https://fnm.vercel.app/install | bash
fnm install $NODE_VERSION
fnm default $NODE_VERSION

export ZDOTDIR=$HOME/dotfiles

touch $HOME/.zshrc
if ! grep -q "export ZDOTDIR=$ZDOTDIR" $HOME/.zshrc; then
  echo "export ZDOTDIR=$ZDOTDIR" >> $HOME/.zshrc
fi
if ! grep -q "source \$ZDOTDIR/.zshrc" $HOME/.zshrc; then
  echo "source \$ZDOTDIR/.zshrc" >> $HOME/.zshrc
fi

chsh -s $(which zsh)

curl -sfL git.io/antibody | sudo sh -s - -b /usr/local/bin
antibody bundle < $ZDOTDIR/modules/plugins.txt > $ZDOTDIR/modules/plugins.zsh && reload

cp .env.example .env

zsh-plugins

exec zsh
