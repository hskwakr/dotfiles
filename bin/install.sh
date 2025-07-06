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
  "env"
  "test"
)

# URL of the git repository containing the dotfiles.
GIT_REPO_URL="https://github.com/hskwakr/dotfiles.git"

# Base directories for dotfiles management.
DOTFILES_DIR="$HOME/dotfiles"
SHELL_PATH="$SHELL"

# Directories derived from DOTFILES_DIR. These values are updated after
# option parsing to reflect any custom location.
BACKUP_DIR=""
ORIGINAL_BACKUP_DIR=""
LOG_DIR=""

# Maximum log file size (in bytes) and number of rotated logs to retain.
LOG_MAX_SIZE=1048576 # 1MB
LOG_BACKUP_COUNT=5

# Maximum number of backups for individual files.
BACKUP_MAX_COUNT=10

# Log file path (computed after option parsing)
LOG_FILE=""

# -----------------------
# Utility Functions
# -----------------------

# Print a timestamped log message and append it to the log file if available
log() {
  local level=$1
  shift
  local message=$@
  local log_entry="$(date '+%Y-%m-%d %H:%M:%S') [$level] $message"
  echo "$log_entry"
  
  # Log directory exists only if it is created
  if [ -d "$LOG_DIR" ]; then
    # Create log file if it doesn't exist
    if [ ! -f "$LOG_FILE" ]; then
      touch "$LOG_FILE"
    fi
    echo "$log_entry" >> "$LOG_FILE"
  fi
}

# Rotate the log file when it exceeds the size limit
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

# Return 0 if the given path matches an ignored name
is_ignored() {
  local item_name=$1
  for ignored in "${ignore_list[@]}"; do
    [ "$item_name" == "$ignored" ] && return 0
  done
  return 1
}

# Create a timestamped backup of the file and limit the number kept
backup_file() {
  local src=$1
  if [ -e "$src" ]; then
    # Get relative path from HOME
    local rel_path=${src#$HOME/}
    
    # Check if original backup exists
    local original_backup="$ORIGINAL_BACKUP_DIR/$rel_path"
    if [ ! -e "$original_backup" ]; then
      # Create original backup with directory structure
      mkdir -p "$(dirname "$original_backup")"
      cp "$src" "$original_backup"
      log INFO "Original backup created with directory structure: $original_backup"
    fi

    # Create regular backup
    local backup_name="$BACKUP_DIR/$(basename "$src")_$(date '+%Y%m%d_%H%M%S').bak"
    cp "$src" "$backup_name"
    log INFO "Backup created: $backup_name"

    # Expand the backup glob to an array of existing files
    shopt -s nullglob
    local backups=("$BACKUP_DIR"/$(basename "$src")_*.bak)
    shopt -u nullglob

    if [ "${#backups[@]}" -gt "$BACKUP_MAX_COUNT" ]; then
      local excess_count=$((${#backups[@]} - BACKUP_MAX_COUNT))
      for old_backup in $(ls -t "${backups[@]}" | tail -n $excess_count); do
        rm "$old_backup"
        log INFO "Removed old backup: $old_backup"
      done
    fi
  fi
}

# Backup the destination then link the source file
backup_and_link() {
  local src=$1 dest=$2
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ -L "$dest" ]; then
      if [ "$(readlink "$dest")" = "$src" ]; then
        log INFO "Symbolic link already exists and points to the correct location: $dest"
        return
      else
        log WARNING "Re-linking symbolic link: $dest"
        rm "$dest"
      fi
    else
      backup_file "$dest"
      rm -f "$dest"
    fi
  fi
  ln -s "$src" "$dest"
  log INFO "Linked $src to $dest"
}

# Recursively link all items from the source directory into the destination
link_directory() {
  local src_dir=$1 dest_dir=$2
  mkdir -p "$dest_dir"
  for item in "$src_dir"/.* "$src_dir"/*; do
    local item_name
    item_name=$(basename "$item")

    # Skip current and parent directory entries
    if [[ "$item_name" == "." || "$item_name" == ".." ]]; then
      continue
    fi

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

# Exit if the specified command is not available in PATH
check_command() {
  if ! command -v "$1" &> /dev/null; then
    log ERROR "$1 is required but not installed."
    exit 1
  fi
}

# Detect the operating system and distinguish WSL environments
# Outputs a lowercase identifier such as "fedora" or "wsl-ubuntu"
detect_os() {
  local uname_out
  uname_out="$(uname -s)"

  case "$uname_out" in
    Darwin*)
      echo "macOS"
      return
      ;;
    CYGWIN*|MINGW*|MSYS*)
      echo "Windows"
      return
      ;;
    Linux*)
      local is_wsl="false"
      if grep -qi microsoft /proc/version 2>/dev/null || grep -qi wsl /proc/sys/kernel/osrelease 2>/dev/null; then
        is_wsl="true"
      fi

      if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
          ubuntu)
            if [ "$is_wsl" = "true" ]; then
              echo "wsl-ubuntu"
            else
              echo "ubuntu"
            fi
            ;;
          fedora)
            if [ "$is_wsl" = "true" ]; then
              echo "wsl-fedora"
            else
              echo "fedora"
            fi
            ;;
          *)
            if [ "$is_wsl" = "true" ]; then
              echo "wsl-$ID"
            else
              echo "$ID"
            fi
            ;;
        esac
      else
        if [ "$is_wsl" = "true" ]; then
          echo "wsl-linux"
        else
          echo "linux"
        fi
      fi
      return
      ;;
  esac

  echo "$uname_out"
}

# -----------------------
# Core Functions
# -----------------------
# Clone the repository if needed and create backup/log directories
prepare_repo() {
  local repo_dir=$1

  # Git clone dotfiles repository if it doesn't exist
  if [ ! -d "$repo_dir" ]; then
    git clone "$GIT_REPO_URL" "$repo_dir"
    log INFO "Cloned dotfiles repository"
  else
    # Pull latest changes from dotfiles repository if it exists
    if [ -d "$repo_dir/.git" ]; then
      log INFO "Pulling latest changes from dotfiles repository"
      git -C "$repo_dir" pull origin main
    else
      # If it's not a valid git repository, re-clone the repository
      log WARNING "$repo_dir is not a valid git repository. Re-cloning the repository."
      rm -rf "$repo_dir"
      git clone "$GIT_REPO_URL" "$repo_dir"
      log INFO "Re-cloned dotfiles repository"
    fi
  fi

  # Create backup and log directories if they don't exist
  if [ -d "$repo_dir" ]; then
    log INFO "Creating backup and log directories"
    mkdir -p "$BACKUP_DIR" "$LOG_DIR"
  fi
}

# Link dotfiles from the repository root into the home directory
install_root_dotfiles() {
  # Process each item in the dotfiles directory
  for item in "$DOTFILES_DIR"/.* "$DOTFILES_DIR"/*; do
    # Skip . and .. directories
    [ "$item" = "$DOTFILES_DIR/." ] || [ "$item" = "$DOTFILES_DIR/.." ] && continue

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

# Wrapper to prepare the repository and link dotfiles
install_dotfiles() {
  local repo_dir=$1
  prepare_repo "$repo_dir"
  install_root_dotfiles
}

# Link files located under env/common into the user's home
install_env_common() {
  local common_dir="$DOTFILES_DIR/env/common"
  if [ -d "$common_dir" ]; then
    log INFO "Linking common environment configs from $common_dir"
    link_directory "$common_dir" "$HOME"
  else
    log WARNING "Common environment directory not found: $common_dir"
  fi
}

# Link OS-specific config directory to the user's home with one-level fallback
install_env_os() {
  local os_id=$1
  local os_dir="$DOTFILES_DIR/env/$os_id"
  if [ -d "$os_dir" ]; then
    log INFO "Linking OS-specific configs from $os_dir"
    link_directory "$os_dir" "$HOME"
    return
  fi

  if [[ "$os_id" == *-* ]]; then
    local generic="${os_id%-*}"
    os_dir="$DOTFILES_DIR/env/$generic"
    if [ -d "$os_dir" ]; then
      log INFO "Linking OS fallback configs from $os_dir"
      link_directory "$os_dir" "$HOME"
      return
    fi
  fi

  log INFO "No OS-specific directory found for $os_id"
}

# Change the default shell if the given path is valid and different
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
# Execute all installation steps with logging
main() {
  local repo_dir=$1
  local shell_path=$2

  manage_log_file "$LOG_FILE"

  log INFO "Starting installation"
  local os_name
  os_name=$(detect_os)
  log INFO "Detected OS: $os_name"
  check_command "git"
  prepare_repo "$repo_dir"
  install_env_common
  install_env_os "$os_name"
  setup_shell "$shell_path"
  log INFO "Installation completed"
}

# Parse command line options
while getopts "d:s:h" opt; do
  case "$opt" in
    d)
      DOTFILES_DIR="$OPTARG"
      ;;
    s)
      SHELL_PATH="$OPTARG"
      ;;
    h)
      echo "Usage: $0 [-d dotfiles_directory] [-s shell_path]"
      exit 0
      ;;
    \?)
      echo "Usage: $0 [-d dotfiles_directory] [-s shell_path]" >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))

# Update paths based on chosen dotfiles directory
BACKUP_DIR="$DOTFILES_DIR/backups"
ORIGINAL_BACKUP_DIR="$BACKUP_DIR/original"
LOG_DIR="$DOTFILES_DIR/logs"
LOG_FILE="$LOG_DIR/install.log"

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$DOTFILES_DIR" "$SHELL_PATH"
fi
