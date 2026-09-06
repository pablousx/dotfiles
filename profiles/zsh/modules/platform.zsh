# Platform-specific plugin loading for the shared Oh My Zsh checkout.

OMZ_DIR="${ANTIDOTE_HOME:-$HOME/.cache/antidote}/github.com/ohmyzsh/ohmyzsh"

case "$OSTYPE" in
  darwin*)
    [[ -r "$OMZ_DIR/plugins/macos/macos.plugin.zsh" ]] &&
      source "$OMZ_DIR/plugins/macos/macos.plugin.zsh"
    ;;
  linux*)
    linux_id=""
    linux_like=""
    if [[ -r /etc/os-release ]]; then
      linux_id="${${(M)${(f)"$(</etc/os-release)"}:#ID=*}#ID=}"
      linux_id="${linux_id//\"/}"
      linux_like="${${(M)${(f)"$(</etc/os-release)"}:#ID_LIKE=*}#ID_LIKE=}"
      linux_like="${linux_like//\"/}"
    fi

    if [[ "$linux_id" == (ubuntu|debian) || " $linux_like " == *" debian "* ]]; then
      [[ -r "$OMZ_DIR/plugins/ubuntu/ubuntu.plugin.zsh" ]] &&
        source "$OMZ_DIR/plugins/ubuntu/ubuntu.plugin.zsh"
      [[ -r "$OMZ_DIR/plugins/command-not-found/command-not-found.plugin.zsh" ]] &&
        source "$OMZ_DIR/plugins/command-not-found/command-not-found.plugin.zsh"
    fi
    unset linux_id linux_like
    ;;
esac

unset OMZ_DIR
