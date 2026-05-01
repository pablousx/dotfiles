#!/usr/bin/env bash

ACTION=$1
DOTFILES_DIR=$HOME/dotfiles

case "$ACTION" in
    yes)
        echo "Installing Zellij and plugins..."
        mkdir -p "$HOME/.local/bin"
        mkdir -p "$HOME/.config/zellij/plugins"

        # Zellij
        if ! command -v zellij &> /dev/null && [[ ! -f "$HOME/.local/bin/zellij" ]]; then
            echo "Downloading zellij..."
            URL=$(curl -s -H "User-Agent: curl" https://api.github.com/repos/zellij-org/zellij/releases/latest | grep "browser_download_url.*x86_64-unknown-linux-musl.tar.gz" | head -n 1 | cut -d '"' -f 4)
            if [[ -n "$URL" ]]; then
                curl -L "$URL" | tar -xz -C "$HOME/.local/bin"
            else
                echo "Error: Could not find Zellij download URL. You might be rate-limited by GitHub API."
            fi
        fi

        # Link config
        if [[ ! -L "$HOME/.config/zellij" && ! -d "$HOME/.config/zellij" && -d "$DOTFILES_DIR/zellij" ]]; then
            ln -s "$DOTFILES_DIR/zellij" "$HOME/.config/zellij"
        fi

        # fzf-zellij
        if [[ ! -f "$HOME/.local/bin/fzf-zellij" ]]; then
            echo "Installing fzf-zellij..."
            curl -L https://raw.githubusercontent.com/k-kuroguro/fzf-zellij/refs/heads/main/bin/fzf-zellij -o "$HOME/.local/bin/fzf-zellij"
            chmod +x "$HOME/.local/bin/fzf-zellij"
        fi

        # room plugin
        if [[ ! -f "$HOME/.config/zellij/plugins/room.wasm" ]]; then
            echo "Installing room plugin..."
            curl -L https://github.com/rvcas/room/releases/latest/download/room.wasm -o "$HOME/.config/zellij/plugins/room.wasm"
        fi

        # zellij-forgot plugin
        if [[ ! -f "$HOME/.config/zellij/plugins/zellij_forgot.wasm" ]]; then
            echo "Installing zellij-forgot plugin..."
            curl -L https://github.com/karimould/zellij-forgot/releases/latest/download/zellij_forgot.wasm -o "$HOME/.config/zellij/plugins/zellij_forgot.wasm"
        fi
        ;;
    no)
        echo "Removing Zellij and plugins..."
        rm -f "$HOME/.local/bin/zellij"
        rm -f "$HOME/.local/bin/fzf-zellij"
        if [[ -L "$HOME/.config/zellij" ]]; then
            rm -f "$HOME/.config/zellij"
        else
            rm -rf "$HOME/.config/zellij"
        fi
        ;;
    skip)
        echo "Skipping Zellij."
        ;;
esac
