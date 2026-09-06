# Behavioral fixture based on /usr/share/omarchy/default/bash at 4.0.0.alpha.
# Models ownership/order without launching tools or requiring a desktop.
# Refresh deliberately when the upstream startup contract changes.
OMARCHY_FIXTURE_LOADS=$((${OMARCHY_FIXTURE_LOADS:-0} + 1))
shopt -s histappend
HISTCONTROL=ignoreboth
HISTSIZE=32768
HISTFILESIZE=32768
set +h
alias c='opencode --auto'
alias cx='claude --permission-mode auto'
alias h='herdr'
alias gcm='git commit -m'
open() { printf 'omarchy-open:%s\n' "$*"; }
zd() { builtin cd "$@"; }
alias cd=zd
_omarchy_fixture_complete() { COMPREPLY=(stock); }
complete -F _omarchy_fixture_complete omarchy
complete -F _omarchy_fixture_complete npm
# Stand-ins for mise and Starship, preserving a scalar prompt-command contract.
PROMPT_COMMAND=': mise; : starship'
# Stock Omarchy Readline completion cycling; fzf is loaded separately in PTY tests.
if [[ -t 0 ]]; then
    bind '"\C-i": menu-complete'
    bind '"\e[Z": menu-complete-backward'
fi
