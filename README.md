# Dotfiles

A comprehensive ZSH configuration with modular architecture, featuring Powerlevel10k prompt, extensive plugin management, and productivity aliases.

## Overview

This dotfiles repository manages a customized ZSH environment with the following components:

### Core Components

- **Shell**: ZSH with optimized completion system
- **Prompt**: [Powerlevel10k](https://github.com/romkatv/powerlevel10k) with Pure-style configuration
- **Plugin Manager**: [Antibody](https://getantibody.github.io/) for fast plugin loading
- **Node Version Manager**: [fnm](https://github.com/Schniz/fnm) with automatic version switching

### Module System

The configuration is split into modular components in `modules`:

- `modules/aliases.zsh` - Command shortcuts and custom functions
- `modules/bitwarden-ssh-agent.zsh` - SSH agent integration with Bitwarden
- `modules/expand-alias.zsh` - Automatic alias expansion in command line
- `modules/plugins.zsh` - Plugin loader (generated from `modules/plugins.txt`)
- `modules/plugins.txt` - Plugin definitions for Antibody
- `modules/print-alias-completion.zsh` - Alias suggestions during completion
- `modules/prompt.zsh` - Powerlevel10k initialization

### Configuration Files

- `.zshrc` - Main configuration entry point
- `.p10k.zsh` - Powerlevel10k prompt configuration
- `.env` - Module enable/disable flags (gitignored)
- `.env.example` - Environment configuration template
- `setup-bw-ssh-agent.sh` - Bitwarden SSH agent setup script

### Installation

The first step is to clone the dotfiles repository:
```sh
git clone --bare https://github.com/pablousx/dotfiles.git $HOME/dotfiles
```

Then, run the setup script:

```sh
sh setup.sh
```

Alternatively, you can manually execute the steps below:

```sh
# Install prerequisites
sudo apt update
sudo apt install zsh git curl nano unzip

# Install fnm (Node version manager)
curl -fsSL https://fnm.vercel.app/install | bash

# Configure dotfiles directory
touch $HOME/.zshrc
if ! grep -q "export ZDOTDIR=~/dotfiles" $HOME/.zshrc; then
  echo "export ZDOTDIR=~/dotfiles" >> $HOME/.zshrc
fi
if ! grep -q "source $ZDOTDIR/.zshrc" $HOME/.zshrc; then
  echo "source $ZDOTDIR/.zshrc" >> $HOME/.zshrc
fi

# Set ZSH as default shell
chsh -s $(which zsh)

# Install Antibody
curl -sfL git.io/antibody | sudo sh -s - -b /usr/local/bin

# Copy and configure environment
cp .env.example .env

# Bundle plugins
zsh-plugins

# Restart terminal
exec zsh
```

### Configuration

Edit `.env` to enable/disable modules.

### Key Aliases

```sh
# Dotfiles management
dotfiles <git command>      # Git operations for dotfiles

# DuckDuckGo search
duck <search terms>         # Search DuckDuckGo

# Google search
google <search terms>       # Search Google

# NPM/Pnpm/Yarn shortcuts
ni/pi/yi                   # npm/yarn/pnpm install
nd/pd/yd                   # npm/yarn/pnpm dev
nb/pb/yb                   # npm/yarn/pnpm build
ns/ps/ys                   # npm/yarn/pnpm start
# Navigation
c <path>                # Open in VS Code
dev                     # cd ~/dev
cx                      # cd ..

# Configuration
reload                  # Restart ZSH
zsh-config              # Edit .zshrc and reload
zsh-aliases             # Edit aliases and reload
zsh-plugins          # Rebuild plugin cache and reload
```

### Updating

```sh
# Sync dotfiles
upload-dotfiles         # Commits and pushes changes

# Update Powerlevel10k
p10k configure          # Reconfigure prompt
```

## Features

- **Fast startup**: Optimized completion caching and lazy loading
- **Git integration**: Enhanced git status in prompt with dirty state indicators
- **URL quoting**: Automatic URL escaping in paste operations
- **Command correction**: Auto-correction suggestions for mistyped commands
- **Smart completion**: Context-aware completions with fzf integration
