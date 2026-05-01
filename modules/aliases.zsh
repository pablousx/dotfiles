# Core
alias dotfiles='/usr/bin/git --git-dir=$DOTFILES_DIR --work-tree=$DOTFILES_DIR'

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

# Zellij
alias zj="zellij"
alias za="zellij attach"
alias zl="zellij list-sessions"
alias zka="zellij kill-all-sessions"

# fzf-zellij: Open fzf in a Zellij floating pane when inside Zellij
fzf() {
   case "$1" in
      --bash|--zsh|--fish|--version|-h|--help|--man)
         command fzf "$@"
         ;;
      *)
         if [[ -n "$ZELLIJ" ]]; then
            fzf-zellij "$@"
         else
            command fzf "$@"
         fi
         ;;
   esac
}

# Auto-start Zellij
if [[ -z "$ZELLIJ" ]] && command -v zellij &> /dev/null; then
    if [[ "$(hostname)" != "PCP-PC" ]]; then
        # On VPS: use 'REMOTE' as session name for indicator
        zellij attach -c REMOTE 2>/dev/null || zellij --session REMOTE
    else
        # On Local: standard auto-start
        eval "$(zellij setup --generate-auto-start zsh)"
    fi
fi

alias reload="exec zsh"
alias bundle-plugins="antidote bundle < $DOTFILES_DIR/modules/plugins.txt > $DOTFILES_DIR/modules/plugins.zsh && reload"

alias zsh-config="$EDITOR $DOTFILES_DIR/.zshrc && reload"
alias zsh-aliases="$EDITOR $DOTFILES_DIR/modules/aliases.zsh && reload"
alias zsh-plugins="$EDITOR $DOTFILES_DIR/modules/plugins.txt && bundle-plugins"

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
upload-dotfiles(){
  local current_branch=$(dotfiles rev-parse --abbrev-ref HEAD)
  echo "Current branch: $current_branch"

  dotfiles status -s

  echo -n "Commit message (default: 'dotfiles updated $(date +%d-%m-%y)'): "
  read msg
  if [[ -z "$msg" ]]; then
    msg="dotfiles updated $(date +%d-%m-%y)"
  fi

  echo "Uploading dotfiles..."
  dotfiles add -u # Only add tracked files that have changed
  dotfiles commit -m "$msg"
  dotfiles push origin "$current_branch"
  echo "Done."
}

# xxh — portable shell for unmanaged remote hosts
function xxhh() {
  if [[ "$*" == *"+if"* ]]; then
    rm -rf ~/.xxh/.xxh/plugins/xxh-plugin-zsh-dotfiles* 2>/dev/null
  fi

  local dot_src="${DOTFILES_DIR:-$HOME/dotfiles}"
  XXH_DOTFILES_SRC="$dot_src" xxh "$1" +I xxh-plugin-zsh-dotfiles+path+"$dot_src/modules/xxh-plugin" +s zsh "${@:2}"
}
