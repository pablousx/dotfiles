#!/usr/bin/env bash

ACTION=$1

case "$ACTION" in
    yes)
        echo "Installing xxh (portable shell)..."
        if ! command -v xxh &>/dev/null; then
            if command -v brew &>/dev/null; then
                brew install xxh
            else
                sudo apt install -y python3-pip
                # Use --break-system-packages if on newer debian/ubuntu, but we stick to standard
                pip3 install xxh-xxh || pip3 install --break-system-packages xxh-xxh
            fi
        fi
        export PATH="$HOME/.local/bin:$PATH"
        if command -v xxh &>/dev/null; then
            xxh +I xxh-shell-zsh
            xxh +I xxh-plugin-zsh-dotfiles+path+$HOME/dotfiles/modules/xxh-plugin
        else
            echo "Failed to install or find xxh executable."
        fi
        ;;
    no)
        echo "Removing xxh..."
        if command -v brew &>/dev/null; then
            brew uninstall xxh || true
        fi
        pip3 uninstall -y xxh-xxh || pip3 uninstall --break-system-packages -y xxh-xxh || true
        rm -rf "$HOME/.xxh"
        ;;
    skip)
        echo "Skipping xxh."
        ;;
esac
