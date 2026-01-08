local cmd_alias=""

alias_for() {
  [[ $1 =~ '[[:punct:]]' ]] && return
  local search=${1}
  local found="$( alias $search )"
  if [[ -n $found ]]; then
    found=${found//\\//}
    found=${found%\'}
    found=${found#"$search="}
    found=${found#"'"}
    echo "${found} ${2}" | xargs
  else
    echo ""
  fi
}

expand_command_line() {
  first=$(echo "$1" | awk '{print $1;}')
  rest=$(echo ${${1}/"${first}"/})

  if [[ -n "${first//-//}" ]]; then
    cmd_alias="$(alias_for "${first}" "${rest:1}")"
    if [[ -n $cmd_alias ]] && [[ "${cmd_alias:0:1}" != "." ]]; then
      echo "\e[1;34m❯ ${cmd_alias}\e[0m"
    fi
  fi
}

pre_validation() {
  [[ $# -eq 0 ]] && return
  expand_command_line "$@"
}

autoload -U add-zsh-hook
add-zsh-hook preexec pre_validation
