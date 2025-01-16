#!/bin/bash
# install.sh - A script to manage dotfiles installation
# Usage:
#   ./install.sh [-d dotfiles_directory] [-s shell_path]
# Requirements:
#   - git
#   - bash 4.0+
# Description:
#   This script links dotfiles to the home directory and optionally changes the default shell.

set -e

# Configuration Variables
# -----------------------
# Update the following variables as per your environment and requirements.

# Files and directories to ignore during processing.
ignore_list=(
  ".git"
  ".github"
  ".gitignore"
  ".gitmodules"
  ".gitattributes"
  ".vscode"
  ".DS_Store"
  "LICENSE"
  "README.md"
  "backups"
  "logs"
  "bin"
)

# URL of the git repository containing the dotfiles.
GIT_REPO_URL="https://github.com/hskwakr/dotfiles.git"

# Base directories for dotfiles management.
DOTFILES_DIR="$HOME/dotfiles"
BACKUP_DIR="$DOTFILES_DIR/backups"
LOG_DIR="$DOTFILES_DIR/logs"

# Maximum log file size (in bytes) and number of rotated logs to retain.
LOG_MAX_SIZE=1048576 # 1MB
LOG_BACKUP_COUNT=5

# Maximum number of backups for individual files.
BACKUP_MAX_COUNT=10

# -----------------------
# Initialization
# -----------------------
mkdir -p "$BACKUP_DIR" "$LOG_DIR"
LOG_FILE="$LOG_DIR/install.log"

# -----------------------
# Utility Functions
# -----------------------
log() {
  local level=$1
  shift
  local message=$@
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" | tee -a "$LOG_FILE"
}

manage_log_file() {
  local log_file=$1
  if [ -f "$log_file" ] && [ "$(stat --format=%s "$log_file")" -ge "$LOG_MAX_SIZE" ]; then
    for ((i=LOG_BACKUP_COUNT-1; i>=1; i--)); do
      [ -f "$log_file.$i" ] && mv "$log_file.$i" "$log_file.$((i+1))"
    done
    mv "$log_file" "$log_file.1"
    echo "Log rotated: $log_file" > "$log_file"
  fi
}

is_ignored() {
  local item_name=$1
  for ignored in "${ignore_list[@]}"; do
    [ "$item_name" == "$ignored" ] && return 0
  done
  return 1
}

backup_file() {
  local src=$1
  if [ -e "$src" ]; then
    local backup_name="$BACKUP_DIR/$(basename "$src")_$(date '+%Y%m%d_%H%M%S').bak"
    cp "$src" "$backup_name"
    log INFO "Backup created: $backup_name"

    local backups=("$BACKUP_DIR/$(basename "$src")_*.bak")
    if [ "${#backups[@]}" -gt "$BACKUP_MAX_COUNT" ]; then
      local excess_count=$((${#backups[@]} - BACKUP_MAX_COUNT))
      for old_backup in $(ls -t "${backups[@]}" | tail -n $excess_count); do
        rm "$old_backup"
        log INFO "Removed old backup: $old_backup"
      done
    fi
  fi
}

backup_and_link() {
  local src=$1 dest=$2
  if [ -e "$dest" ]; then
    if [ -L "$dest" ] && [ "$(readlink "$dest")" != "$src" ]; then
      log WARNING "Re-linking symbolic link: $dest"
      rm "$dest"
    elif [ ! -L "$dest" ]; then
      backup_file "$dest"
      rm -f "$dest"
    fi
  fi
  ln -s "$src" "$dest"
  log INFO "Linked $src to $dest"
}

link_directory() {
  local src_dir=$1 dest_dir=$2
  mkdir -p "$dest_dir"
  for item in "$src_dir"/*; do
    local item_name=$(basename "$item")
    local dest_item="$dest_dir/$item_name"
    if is_ignored "$item_name"; then
      log INFO "Ignored $item_name"
      continue
    fi
    if [ -d "$item" ]; then
      log INFO "Processing directory: $item"
      link_directory "$item" "$dest_item"
    elif [ -f "$item" ] || [ -L "$item" ]; then
      log INFO "Processing file: $item"
      backup_and_link "$item" "$dest_item"
    else
      log WARNING "Skipped unusual item: $item"
    fi
  done
}

check_command() {
  if ! command -v "$1" &> /dev/null; then
    log ERROR "$1 is required but not installed."
    exit 1
  fi
}

# -----------------------
# Core Functions
# -----------------------
install_dotfiles() {
  if [ ! -d "$DOTFILES_DIR" ]; then
    git clone "$GIT_REPO_URL" "$DOTFILES_DIR"
    log INFO "Cloned dotfiles repository"
  else
    if [ -d "$DOTFILES_DIR/.git" ]; then
      log INFO "Pulling latest changes from dotfiles repository"
      git -C "$DOTFILES_DIR" pull origin main
    else
      log WARNING "$DOTFILES_DIR is not a valid git repository. Re-cloning the repository."
      rm -rf "$DOTFILES_DIR"
      git clone "$GIT_REPO_URL" "$DOTFILES_DIR"
      log INFO "Re-cloned dotfiles repository"
    fi
  fi
  for item in "$DOTFILES_DIR"/*; do
    local item_name=$(basename "$item")
    local dest_item="$HOME/$item_name"
    if is_ignored "$item_name"; then
      log INFO "Ignored $item_name"
      continue
    fi
    if [ -d "$item" ]; then
      log INFO "Processing directory: $item"
      link_directory "$item" "$dest_item"
    elif [ -f "$item" ] || [ -L "$item" ]; then
      log INFO "Processing file: $item"
      backup_and_link "$item" "$dest_item"
    else
      log WARNING "Skipped unusual item: $item"
    fi
  done
}

setup_shell() {
  local shell_path=${1:-$SHELL}
  if [ "$shell_path" == "$SHELL" ]; then
    log INFO "Current shell is already set to $shell_path."
    return
  fi
  if [ ! -x "$shell_path" ]; then
    log ERROR "Invalid shell: $shell_path"
    exit 1
  fi
  if ! grep -q "$USER" /etc/passwd; then
    log ERROR "User $USER not found in /etc/passwd."
    exit 1
  fi
  chsh -s "$shell_path"
  log INFO "Default shell changed to $shell_path"
}

# -----------------------
# Main Process
# -----------------------
main() {
  manage_log_file "$LOG_FILE"

  log INFO "Starting installation"
  check_command "git"
  install_dotfiles
  setup_shell "${1:-$SHELL}"
  log INFO "Installation completed"
}

main "$@"
