#!/usr/bin/env bats

setup() {
  HOME_DIR="$BATS_TMPDIR/home"
  DOTFILES_DIR="$BATS_TMPDIR/repo"
  mkdir -p "$HOME_DIR" "$DOTFILES_DIR"
  export HOME="$HOME_DIR"

  source "$BATS_TEST_DIRNAME/../../bin/install.sh"

  DOTFILES_DIR="$BATS_TMPDIR/repo"

  BACKUP_DIR="$DOTFILES_DIR/backups"
  ORIGINAL_BACKUP_DIR="$BACKUP_DIR/original"
  LOG_DIR="$DOTFILES_DIR/logs"
  LOG_FILE="$LOG_DIR/install.log"
  LOG_MAX_SIZE=1024
  LOG_BACKUP_COUNT=3
  BACKUP_MAX_COUNT=5
  ignore_list=()

  log() { :; }
}

teardown() {
  rm -rf "$HOME_DIR" "$DOTFILES_DIR"
}

@test "creates link when destination absent" {
  mkdir -p "$DOTFILES_DIR"
  echo "data" > "$DOTFILES_DIR/srcfile"
  run backup_and_link "$DOTFILES_DIR/srcfile" "$HOME/file"
  [ "$status" -eq 0 ]
  [ -L "$HOME/file" ]
  [ "$(readlink "$HOME/file")" = "$DOTFILES_DIR/srcfile" ]
}

@test "backs up existing file and links" {
  mkdir -p "$BACKUP_DIR" "$ORIGINAL_BACKUP_DIR"
  echo "src" > "$DOTFILES_DIR/srcfile"
  echo "old" > "$HOME/file"
  run backup_and_link "$DOTFILES_DIR/srcfile" "$HOME/file"
  [ "$status" -eq 0 ]
  [ -L "$HOME/file" ]
  [ "$(readlink "$HOME/file")" = "$DOTFILES_DIR/srcfile" ]
  shopt -s nullglob
  backups=("$BACKUP_DIR"/file_*.bak)
  shopt -u nullglob
  [ "${#backups[@]}" -ge 1 ]
}

@test "relinks existing symlink" {
  echo "src" > "$DOTFILES_DIR/srcfile"
  echo "other" > "$DOTFILES_DIR/other"
  ln -s "$DOTFILES_DIR/other" "$HOME/file"
  run backup_and_link "$DOTFILES_DIR/srcfile" "$HOME/file"
  [ "$status" -eq 0 ]
  [ -L "$HOME/file" ]
  [ "$(readlink "$HOME/file")" = "$DOTFILES_DIR/srcfile" ]
}

@test "no backup when symlink already correct" {
  echo "src" > "$DOTFILES_DIR/srcfile"
  ln -s "$DOTFILES_DIR/srcfile" "$HOME/file"
  run backup_and_link "$DOTFILES_DIR/srcfile" "$HOME/file"
  [ "$status" -eq 0 ]
  shopt -s nullglob
  backups=("$BACKUP_DIR"/file_*.bak)
  shopt -u nullglob
  [ "${#backups[@]}" -eq 0 ]
}
