# Core
source "$DOTFILES_DIR/shared/repository.sh"
dotfiles() {
  _dotfiles_git "$@"
}

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

# WSL / Windows / macOS specific
if [[ "$(uname)" == "Darwin" ]]; then
  # macOS has its own native 'open' command; do nothing/keep it native
  :
elif grep -qi microsoft /proc/version 2>/dev/null; then
  alias open="powershell.exe -Command Start"
else
  alias open="xdg-open 2>/dev/null"
fi

alias reload="exec zsh"
bundle-plugins() {
  local generated="$DOTFILES_DIR/profiles/zsh/modules/plugins.zsh.tmp"
  if antidote bundle < "$DOTFILES_DIR/profiles/zsh/modules/plugins.txt" > "$generated"; then
    command mv "$generated" "$DOTFILES_DIR/profiles/zsh/modules/plugins.zsh"
    exec zsh
  else
    command rm -f "$generated"
    return 1
  fi
}

alias zsh-config="$EDITOR $DOTFILES_DIR/.zshrc && reload"
alias zsh-aliases="$EDITOR $DOTFILES_DIR/profiles/zsh/modules/aliases.zsh && reload"
alias zsh-plugins="$EDITOR $DOTFILES_DIR/profiles/zsh/modules/plugins.txt && bundle-plugins"

# Move the prompt to the bottom of the screen
move_to_bottom() {
  print ${(pl:$LINES-3::\n:):-}
}

# Web search
google(){
  open "https://google.com/search?q=${(j:+:)@}"
}

duck(){
  open "https://duckduckgo.com/?q=${(j:+:)@}"
}

# Meassure zsh exec time
timezsh(){
  shell=${1-$SHELL}
  for i in $(seq 1 4); do /usr/bin/time $shell -i -c exit; done
}

# Upload dotfiles to cloud
upload-dotfiles() {
  _dotfiles_upload "$@"
}
