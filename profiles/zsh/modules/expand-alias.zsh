expand_alias_on_accept(){
  # If we're in the completion menu (fzf-tab or native), just accept the selection
  if [[ -n "$MENUSELECT" ]]; then
    zle accept-line
    return
  fi

  # Otherwise, expand the alias
  local word=${${(Az)LBUFFER}[-1]}
  zle _expand_alias
  zle expand-word
  zle accept-line
}

zle -N expand_alias_on_accept
bindkey "^M" expand_alias_on_accept
