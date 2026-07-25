# xxh-plugin-zsh-dotfiles
CURR_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"

# Initialize P10k theme
[[ -f "$CURR_DIR/powerlevel10k/powerlevel10k.zsh-theme" ]] && source "$CURR_DIR/powerlevel10k/powerlevel10k.zsh-theme"

# Initialize P10k config after the theme is available.
[[ -f "$CURR_DIR/p10k.zsh" ]] && source "$CURR_DIR/p10k.zsh"

# Load Bundled Plugins
[[ -f "$CURR_DIR/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$CURR_DIR/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
[[ -f "$CURR_DIR/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "$CURR_DIR/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
