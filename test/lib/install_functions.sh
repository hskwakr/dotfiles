#!/usr/bin/env bash
# Extracted functions from bin/install.sh for isolated testing

log() {
  local level=$1
  shift
  local message=$@
  local log_entry="$(date '+%Y-%m-%d %H:%M:%S') [$level] $message"
  echo "$log_entry"

  if [ -d "$LOG_DIR" ]; then
    if [ ! -f "$LOG_FILE" ]; then
      touch "$LOG_FILE"
    fi
    echo "$log_entry" >> "$LOG_FILE"
  fi
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
    local rel_path=${src#$HOME/}
    local original_backup="$ORIGINAL_BACKUP_DIR/$rel_path"
    if [ ! -e "$original_backup" ]; then
      mkdir -p "$(dirname "$original_backup")"
      cp "$src" "$original_backup"
      log INFO "Original backup created with directory structure: $original_backup"
    fi
    local backup_name="$BACKUP_DIR/$(basename "$src")_$(date '+%Y%m%d_%H%M%S').bak"
    cp "$src" "$backup_name"
    log INFO "Backup created: $backup_name"
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
