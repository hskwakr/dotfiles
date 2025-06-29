# Homebrew environment setup
brew_path="/home/linuxbrew/.linuxbrew/bin/brew"
if [ -x "$brew_path" ]; then
    eval "$($brew_path shellenv)"
fi
unset brew_path
