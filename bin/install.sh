#!/bin/bash
set -e

# Ignore list
# Files and directories listed here will be ignored during processing.
# Update this list as needed to exclude additional items.
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

# Git Repository URL
GIT_REPO_URL="https://github.com/hskwakr/dotfiles.git"

# Base directory for dotfiles
DOTFILES_DIR="$HOME/dotfiles"
BACKUP_DIR="$DOTFILES_DIR/backups"
LOG_DIR="$DOTFILES_DIR/logs"

# Create necessary directories
mkdir -p "$BACKUP_DIR"
mkdir -p "$LOG_DIR"

# Log file settings
LOG_FILE="$LOG_DIR/install.log"

# Maximum log file size (bytes)
LOG_MAX_SIZE=1048576 # 1MB
LOG_BACKUP_COUNT=5    # Number of backups to keep

# Log output function
log() {
  local level=$1
  shift
  local message=$@
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" | tee -a "$LOG_FILE"
}

# Log rotation function
# This function rotates the log file if it exceeds a specified size.
# Ensure that the rotation policy aligns with the system’s logging practices,
# especially in cases where logs may grow rapidly.
manage_log_file() {
  local log_file=$1

  if [ -f "$log_file" ] && [ "$(stat --format=%s "$log_file")" -ge "$LOG_MAX_SIZE" ]; then
    for ((i=LOG_BACKUP_COUNT-1; i>=1; i--)); do
      if [ -f "$log_file.$i" ]; then
        mv "$log_file.$i" "$log_file.$((i+1))"
      fi
    done
    mv "$log_file" "$log_file.1"
    echo "Log rotated: $log_file" > "$log_file"
  fi
}

# Check if the item is in the ignore list
is_ignored() {
  local item_name=$1

  for ignored in "${ignore_list[@]}"; do
    if [[ "$item_name" == "$ignored" ]]; then
      return 0
    fi
  done
  return 1
}

# Backup file
backup_file() {
  local src=$1

  if [ -e "$src" ]; then
    local backup_name="$BACKUP_DIR/$(basename "$src")_$(date '+%Y%m%d_%H%M%S').bak"
    cp "$src" "$backup_name"
    log INFO "Backup created: $backup_name"
  fi
}

# Backup and create symbolic link
backup_and_link() {
  local src=$1
  local dest=$2

  if [ -e "$dest" ];then
    if [ -L "$dest" ] && [ "$(readlink "$dest")" != "$src" ];then
      log WARNING "Symbolic link $dest exists but points to $(readlink "$dest"), not $src. Re-linking."
      rm "$dest"
    elif [ ! -L "$dest" ];then
      backup_file "$dest"
      rm -f "$dest"
    fi
  fi
  ln -s "$src" "$dest"
  log INFO "Linked $src to $dest"
}

# Recursively link directory
link_directory() {
  local src_dir=$1
  local dest_dir=$2

  mkdir -p "$dest_dir"

  for item in "$src_dir"/*;do
    local item_name=$(basename "$item")
    local dest_item="$dest_dir/$item_name"

    if is_ignored "$item_name";then
      log INFO "Ignored $item_name"
      continue
    fi

    if [ -d "$item" ];then
      log INFO "Processing directory: $item"
      link_directory "$item" "$dest_item"
    else
      log INFO "Processing file: $item"
      backup_and_link "$item" "$dest_item"
    fi
  done
}

# Check if the command exists
check_command() {
  if ! command -v "$1" &> /dev/null;then
    log ERROR "Error: $1 is not installed. Please install it before running this script."
    exit 1
  fi
}

# Install dotfiles
install_dotfiles() {
  if [ ! -d "$DOTFILES_DIR" ];then
    git clone "$GIT_REPO_URL" "$DOTFILES_DIR"
    log INFO "Cloned dotfiles repository"
  else
    log INFO "Pulling latest changes in dotfiles repository"
    git -C "$DOTFILES_DIR" pull origin main
  fi

  for item in "$DOTFILES_DIR"/*;do
    local item_name=$(basename "$item")
    local dest_item="$HOME/$item_name"

    if is_ignored "$item_name";then
      log INFO "Ignored $item_name"
      continue
    fi

    if [ -d "$item" ];then
      log INFO "Processing directory: $item"
      link_directory "$item" "$dest_item"
    else
      log INFO "Processing file: $item"
      backup_and_link "$item" "$dest_item"
    fi
  done
}

# Set default shell
setup_shell() {
  local shell_path=${1:-$SHELL} # Default to current shell if no argument is provided

  if [ "$shell_path" == "$SHELL" ];then
    log INFO "The current shell is already set to $shell_path. No changes made."
    return
  fi

  if [ ! -x "$shell_path" ];then
    log ERROR "The specified shell $shell_path is not valid or executable."
    exit 1
  fi

  if [ ! -w /etc/passwd ];then
    log ERROR "Insufficient permissions to change the default shell. Please run the script with the necessary privileges."
    exit 1
  fi

  chsh -s "$shell_path"
  log INFO "Default shell changed to $shell_path"
}

# Main process
main() {
  manage_log_file "$LOG_FILE"

  log INFO "Starting installation"
  check_command "git"
  check_command "zsh"
  install_dotfiles

  # Allow shell override
  local shell_to_set=${1:-$SHELL}
  setup_shell "$shell_to_set"

  log INFO "Installation completed"
}

main "$@"
