#!/usr/bin/env bash

ACTION=$1
DOTFILES_DIR=$HOME/dotfiles

case "$ACTION" in
    yes)
        echo "Setting up ZSH and plugins..."

        # Bootstrap ~/.zshrc
        touch "$HOME/.zshrc"

        if ! grep -q "DOTFILES_DIR=$DOTFILES_DIR" "$HOME/.zshrc"; then
            echo "DOTFILES_DIR=$DOTFILES_DIR" >> "$HOME/.zshrc"
        fi
        if ! grep -q "source \$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"; then
            echo "source \$DOTFILES_DIR/.zshrc" >> "$HOME/.zshrc"
        fi

        # Change shell
        if command -v zsh &>/dev/null; then
            CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
            if [[ "$CURRENT_SHELL" != "$(which zsh)" ]]; then
                echo "Changing default shell to zsh..."
                sudo chsh -s "$(which zsh)" "$(whoami)"
            fi
        fi

        # Antidote
        if [[ ! -d "$DOTFILES_DIR/.antidote" ]]; then
            git clone --depth=1 https://github.com/mattmc3/antidote.git "$DOTFILES_DIR/.antidote"
        fi

        # Bundle plugins
        if [[ -f "$DOTFILES_DIR/.antidote/antidote.zsh" ]]; then
            zsh -c "source \"$DOTFILES_DIR/.antidote/antidote.zsh\" && antidote bundle < \"$DOTFILES_DIR/modules/plugins.txt\" > \"$DOTFILES_DIR/modules/plugins.zsh\""
        fi

        if [[ ! -f "$DOTFILES_DIR/.env" && -f "$DOTFILES_DIR/.env.example" ]]; then
            cp "$DOTFILES_DIR/.env.example" "$DOTFILES_DIR/.env"
        fi

        # pnpm-shell-completion binary
        PNPM_COMPLETION_DIR="$HOME/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-g-plane-SLASH-pnpm-shell-completion"
        if [[ -d "$PNPM_COMPLETION_DIR" && ! -f "$PNPM_COMPLETION_DIR/pnpm-shell-completion" ]]; then
            echo "Downloading pnpm-shell-completion binary..."
            URL=$(curl -s -H "User-Agent: curl" https://api.github.com/repos/g-plane/pnpm-shell-completion/releases/latest | grep "browser_download_url.*x86_64-unknown-linux-gnu.tar.gz" | head -n 1 | cut -d '"' -f 4)
            if [[ -n "$URL" ]]; then
                curl -L "$URL" | tar -xz -C "$PNPM_COMPLETION_DIR/"
                chmod +x "$PNPM_COMPLETION_DIR/pnpm-shell-completion"
            else
                echo "Error: Could not find pnpm-shell-completion download URL."
            fi
        fi
        ;;
    no)
        echo "Removing ZSH setup..."
        if command -v bash &>/dev/null; then
            echo "Changing default shell back to bash..."
            sudo chsh -s "$(which bash)" "$(whoami)"
        fi
        rm -rf "$DOTFILES_DIR/.antidote"
        rm -f "$DOTFILES_DIR/modules/plugins.zsh"
        echo "Note: ~/.zshrc was not modified, you may want to clean it up manually."
        ;;
    skip)
        echo "Skipping ZSH setup."
        ;;
esac
