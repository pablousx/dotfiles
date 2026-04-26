# Core
alias dotfiles='/usr/bin/git --git-dir=$ZDOTDIR --work-tree=$ZDOTDIR'

# Npm
alias ni="npm install"
alias nd="npm run dev"
alias nb="npm run build"
alias ns="npm run start"

# Pnpm
alias pni="pnpm install"
alias pnd="pnpm run dev"
alias pnb="pnpm run build"
alias pns="pnpm run start"

# Yarn
alias yi="yarn install"
alias yd="yarn dev"
alias yb="yarn build"
alias ys="yarn start"

# Global
alias -g G='| grep'
alias -g H='| head'
alias -g L='| less'
alias -g M='| more'
alias -g S='| sort'
alias -g T='| tail'
alias -g X='| xargs'

# Other
alias c="code -r"
alias cls="clear && move_to_bottom"
alias cx="cd .."
alias cz="cd -"
alias dev="cd ~/dev"
alias lc="colorls --sd -A"
alias sql="$HOME/sqlcl/bin/sql"

# WSL / Windows specific
if grep -qi microsoft /proc/version 2>/dev/null; then
  alias open="powershell.exe -Command Start"
else
  alias open="xdg-open 2>/dev/null"
fi

alias reload="exec zsh"
alias bundle-plugins="antidote bundle < $ZDOTDIR/modules/plugins.txt > $ZDOTDIR/modules/plugins.zsh && reload"

alias zsh-config="nano $ZDOTDIR/.zshrc && reload"
alias zsh-aliases="nano $ZDOTDIR/modules/aliases.zsh && reload"
alias zsh-plugins="nano $ZDOTDIR/modules/plugins.txt && bundle-plugins"

# Move the prompt to the bottom of the screen
move_to_bottom() {
  print ${(pl:$LINES-3::\n:):-}
}

# Google command
google(){
  open "https://google.com/search?q=$1"
}

duck(){
  open "https://duckduckgo.com/?q=$1"
}

# Meassure zsh exec time
timezsh(){
  shell=${1-$SHELL}
  for i in $(seq 1 4); do /usr/bin/time $shell -i -c exit; done
}

# Upload dotfiles to cloud
upload-dotfiles(){
  echo "Uploading dotfiles..."
  dotfiles add .
  dotfiles commit -m "dotfiles updated $(date +%d-%m-%y)"
  dotfiles push
  echo "Done."
}
