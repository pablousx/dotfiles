expand_alias_on_accept(){
 local word=${${(Az)LBUFFER}[-1]}
 zle _expand_alias
 zle expand-word
 zle accept-line
}

zle -N expand_alias_on_accept
bindkey "^M" expand_alias_on_accept
