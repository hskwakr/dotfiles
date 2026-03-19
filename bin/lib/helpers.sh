#!/usr/bin/env bash
# Common helper functions for dotfiles scripts

# Set default ignore list if not already defined by the sourcing script
if [ -z "${IGNORE_LIST+x}" ]; then
  IGNORE_LIST=(
    ".git" ".github" ".gitignore" ".gitmodules" ".gitattributes" \
    ".vscode" ".DS_Store" "LICENSE" "README.md" "backups" "logs" \
    "bin" "env" "test"
  )
fi

# Detect the dotfiles repository root from the calling script location.
# Falls back to $HOME/dotfiles when the script path cannot be resolved
# (e.g. when executed via curl).
detect_dotfiles_dir() {
  local script_path="${1:-}"
  if [ -n "$script_path" ] && [ -f "$script_path" ]; then
    local script_dir
    script_dir="$(cd "$(dirname "$script_path")" && pwd)"
    # The parent of bin/ is the repository root
    echo "$(cd "$script_dir/.." && pwd)"
  else
    echo "$HOME/dotfiles"
  fi
}

# Output log messages with timestamp and level
log() {
  local level=$1
  shift
  local message="$*"
  local entry="$(date '+%Y-%m-%d %H:%M:%S') [$level] $message"
  echo "$entry"
}

# Return 0 if the given name is listed in IGNORE_LIST
is_ignored() {
  local name=$1
  for ignored in "${IGNORE_LIST[@]}"; do
    [[ "$name" == "$ignored" ]] && return 0
  done
  return 1
}
