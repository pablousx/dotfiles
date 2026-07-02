#!/usr/bin/env bash

ACTION=$1

case "$ACTION" in
    yes)
        echo "Installing core dependencies..."
        if [[ "$(uname)" == "Darwin" ]]; then
            if ! command -v brew &>/dev/null; then
                echo "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            brew install git curl nano unzip fzf
        else
            sudo apt update
            sudo apt install -y zsh git curl nano unzip fzf
        fi
        ;;
    no)
        echo "Removing core dependencies..."
        if [[ "$(uname)" == "Darwin" ]]; then
            if command -v brew &>/dev/null; then
                brew uninstall git curl nano unzip fzf
            fi
        else
            sudo apt remove -y zsh git curl nano unzip fzf
            sudo apt autoremove -y
        fi
        ;;
    skip)
        echo "Skipping core dependencies."
        ;;
esac

