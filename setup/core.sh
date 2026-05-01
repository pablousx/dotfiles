#!/usr/bin/env bash

ACTION=$1

case "$ACTION" in
    yes)
        echo "Installing core dependencies..."
        sudo apt update
        sudo apt install -y zsh git curl nano unzip fzf
        ;;
    no)
        echo "Removing core dependencies..."
        sudo apt remove -y zsh git curl nano unzip fzf
        sudo apt autoremove -y
        ;;
    skip)
        echo "Skipping core dependencies."
        ;;
esac
