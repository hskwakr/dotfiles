#!/usr/bin/env bash
# clean.sh - A script to clean up after dotfiles installation
# Usage:
#   ./clean.sh [-h] [-r] [-b] [-l] [-s]
#     -h: show this help message
#     -r: restore original environment
#     -b: clean old backups
#     -l: clean old logs
#     -s: clean broken symlinks
#   No options: execute all operations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/helpers.sh"

# Configuration Variables
# -----------------------
DOTFILES_DIR="$HOME/dotfiles"
BACKUP_DIR="$DOTFILES_DIR/backups"
ORIGINAL_BACKUP_DIR="$BACKUP_DIR/original"
LOG_DIR="$DOTFILES_DIR/logs"

print_usage() {
  echo "Description:"
  echo "  A script to clean up dotfiles and restore original environment"
  echo
  echo "Usage: $0 [-h] [-r] [-b] [-l] [-s]"
  echo "Options:"
  echo "  -h: show this help message"
  echo "  -r: restore original environment"
  echo "  -b: clean old backups (older than 30 days)"
  echo "  -l: clean old logs (older than 7 days)"
  echo "  -s: clean broken symlinks"
  echo
  echo "Examples:"
  echo "  $0          # Execute all operations"
  echo "  $0 -r       # Only restore original environment"
  echo "  $0 -bl      # Clean backups and logs"
  echo "  $0 -rbs     # Restore and clean backups and symlinks"
  exit 1
}

# -----------------------
# Cleaning Functions
# -----------------------
clean_backups() {
  if [ -d "$BACKUP_DIR" ]; then
    log INFO "Cleaning backup directory"
    # Original backup is not deleted
    find "$BACKUP_DIR" -type f -name "*.bak" -mtime +30 -exec rm {} \;
    log INFO "Removed backup files older than 30 days (excluding original backups)"
  fi
}

clean_logs() {
  if [ -d "$LOG_DIR" ]; then
    log INFO "Cleaning log directory"
    find "$LOG_DIR" -type f -mtime +7 -exec rm {} \;
    log INFO "Removed log files older than 7 days"
  fi
}

clean_broken_symlinks() {
  log INFO "Cleaning broken symbolic links in home directory"
  find "$HOME" -maxdepth 1 -type l ! -exec test -e {} \; -exec rm {} \;
  log INFO "Removed broken symbolic links"
}

restore_original_environment() {
  if [ ! -d "$ORIGINAL_BACKUP_DIR" ]; then
    log ERROR "Original backup directory does not exist: $ORIGINAL_BACKUP_DIR"
    return 1
  fi

  log INFO "Restoring original environment from $ORIGINAL_BACKUP_DIR"

  # Restore original environment from original backup directory
  find "$ORIGINAL_BACKUP_DIR" -type f | while read -r backup_file; do
    # Get relative path from original backup directory
    local rel_path=${backup_file#$ORIGINAL_BACKUP_DIR/}
    local target_path="$HOME/$rel_path"
    
    # Create target directory if it doesn't exist
    mkdir -p "$(dirname "$target_path")"
    
    # Remove symbolic link if it exists
    if [ -L "$target_path" ]; then
      rm "$target_path"
      log INFO "Removed symbolic link: $target_path"
    fi
    
    # Restore file
    cp "$backup_file" "$target_path"
    log INFO "Restored: $target_path"
  done
  
  log INFO "Original environment restoration completed"
}

# -----------------------
# Main Process
# -----------------------
main() {
  local do_restore=false
  local do_clean_backups=false
  local do_clean_logs=false
  local do_clean_symlinks=false
  local any_option=false
  
  # Parse command line arguments
  while getopts "hrbls" opt; do
    case $opt in
      h)
        print_usage
        ;;
      r)
        do_restore=true
        any_option=true
        ;;
      b)
        do_clean_backups=true
        any_option=true
        ;;
      l)
        do_clean_logs=true
        any_option=true
        ;;
      s)
        do_clean_symlinks=true
        any_option=true
        ;;
      \?)
        print_usage
        ;;
    esac
  done

  # If no options specified, execute all operations
  if [ "$any_option" = false ]; then
    do_restore=true
    do_clean_backups=true
    do_clean_logs=true
    do_clean_symlinks=true
  fi

  log INFO "Starting cleanup process"

  # Execute selected operations
  if [ "$do_restore" = true ]; then
    restore_original_environment
  fi

  if [ "$do_clean_backups" = true ]; then
    clean_backups
  fi

  if [ "$do_clean_logs" = true ]; then
    clean_logs
  fi

  if [ "$do_clean_symlinks" = true ]; then
    clean_broken_symlinks
  fi

  log INFO "Cleanup completed"
}

main "$@"

