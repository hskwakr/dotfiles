# Set up Homebrew shell environment
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Set up rbenv for Ruby version management
if command -v rbenv > /dev/null 2>&1; then
  eval "$(rbenv init - --no-rehash zsh)"
fi
