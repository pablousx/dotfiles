#!/usr/bin/env bash

ACTION=$1
NODE_VERSION=${NODE_VERSION:-24.12.0}

case "$ACTION" in
    yes)
        echo "Installing fnm and Node.js ($NODE_VERSION)..."
        if ! command -v fnm &> /dev/null; then
            curl -fsSL https://fnm.vercel.app/install | bash
        fi
        
        # Source fnm manually to make it available in this sub-shell
        export PATH="$HOME/.local/share/fnm:$PATH"
        eval "$(fnm env)"
        
        fnm install "$NODE_VERSION"
        fnm default "$NODE_VERSION"
        ;;
    no)
        echo "Removing fnm and Node.js..."
        rm -rf "$HOME/.local/share/fnm"
        rm -rf "$HOME/.fnm"
        ;;
    skip)
        echo "Skipping fnm and Node.js."
        ;;
esac
