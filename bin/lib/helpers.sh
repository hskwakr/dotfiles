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
