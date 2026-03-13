# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

# Homebrew
if ! [[ "$PATH" =~ "$HOMEBREW_PREFIX/bin:" ]]; then
    PATH="$HOMEBREW_PREFIX/bin:$PATH"
fi
export PATH

# Common shell configuration (shared with bash)
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc

# macOS specific zsh configuration
if [ -d ~/.zshrc.d ]; then
    for rc in ~/.zshrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc

# Set up fzf key bindings and fuzzy completion
source <(fzf --zsh)

# Set up rbenv
eval "$(rbenv init - zsh)"

# Set up starship prompt
eval "$(starship init zsh)"
