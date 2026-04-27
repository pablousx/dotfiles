# xxh-plugin-zsh-dotfiles
CURR_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"

# Initialize P10k config
[[ -f "$CURR_DIR/p10k.zsh" ]] && source "$CURR_DIR/p10k.zsh"

# Initialize P10k theme
[[ -f "$CURR_DIR/powerlevel10k/powerlevel10k.zsh-theme" ]] && source "$CURR_DIR/powerlevel10k/powerlevel10k.zsh-theme"

# Force reload if already initialized
(( ! $+functions[p10k] )) || p10k reload

# Load Bundled Plugins
[[ -f "$CURR_DIR/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$CURR_DIR/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
[[ -f "$CURR_DIR/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "$CURR_DIR/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
