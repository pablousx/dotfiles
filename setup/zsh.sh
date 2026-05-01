#!/usr/bin/env bash

ACTION=$1
ZDOTDIR=$HOME/dotfiles

case "$ACTION" in
    yes)
        echo "Setting up ZSH and plugins..."
        
        # Bootstrap ~/.zshrc
        touch "$HOME/.zshrc"
        if ! grep -q "export ZDOTDIR=$ZDOTDIR" "$HOME/.zshrc"; then
            echo "export ZDOTDIR=$ZDOTDIR" >> "$HOME/.zshrc"
        fi
        if ! grep -q "source \$ZDOTDIR/.zshrc" "$HOME/.zshrc"; then
            echo "source \$ZDOTDIR/.zshrc" >> "$HOME/.zshrc"
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
        if [[ ! -d "$ZDOTDIR/.antidote" ]]; then
            git clone --depth=1 https://github.com/mattmc3/antidote.git "$ZDOTDIR/.antidote"
        fi

        # Bundle plugins
        if [[ -f "$ZDOTDIR/.antidote/antidote.zsh" ]]; then
            # Zsh syntax is sometimes needed for antidote if it's purely zsh, 
            # but we can try running it in zsh explicitly
            zsh -c "source \"$ZDOTDIR/.antidote/antidote.zsh\" && antidote bundle < \"$ZDOTDIR/modules/plugins.txt\" > \"$ZDOTDIR/modules/plugins.zsh\""
        fi

        if [[ ! -f "$ZDOTDIR/.env" && -f "$ZDOTDIR/.env.example" ]]; then
            cp "$ZDOTDIR/.env.example" "$ZDOTDIR/.env"
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
        rm -rf "$ZDOTDIR/.antidote"
        rm -f "$ZDOTDIR/modules/plugins.zsh"
        # We leave ~/.zshrc but note it
        echo "Note: ~/.zshrc was not modified, you may want to clean it up manually."
        ;;
    skip)
        echo "Skipping ZSH setup."
        ;;
esac
