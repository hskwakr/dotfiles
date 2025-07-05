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
  ignore_list=("ignoreme")

  log() { :; }
}

teardown() {
  rm -rf "$HOME_DIR" "$DOTFILES_DIR"
}

@test "recursively links directory and respects ignore list" {
  mkdir -p "$DOTFILES_DIR/src/sub"
  echo "a" > "$DOTFILES_DIR/src/file1"
  echo "b" > "$DOTFILES_DIR/src/sub/file2"
  echo "c" > "$DOTFILES_DIR/src/ignoreme"

  run link_directory "$DOTFILES_DIR/src" "$HOME/dest"
  [ "$status" -eq 0 ]

  [ -L "$HOME/dest/file1" ]
  [ "$(readlink "$HOME/dest/file1")" = "$DOTFILES_DIR/src/file1" ]
  [ -L "$HOME/dest/sub/file2" ]
  [ "$(readlink "$HOME/dest/sub/file2")" = "$DOTFILES_DIR/src/sub/file2" ]
  [ ! -e "$HOME/dest/ignoreme" ]
}

@test "backs up existing destination file" {
  mkdir -p "$DOTFILES_DIR/src"
  echo "new" > "$DOTFILES_DIR/src/file1"
  mkdir -p "$HOME/dest"
  echo "old" > "$HOME/dest/file1"
  mkdir -p "$BACKUP_DIR" "$ORIGINAL_BACKUP_DIR"

  run link_directory "$DOTFILES_DIR/src" "$HOME/dest"
  [ "$status" -eq 0 ]

  [ -L "$HOME/dest/file1" ]
  [ "$(readlink "$HOME/dest/file1")" = "$DOTFILES_DIR/src/file1" ]
  shopt -s nullglob
  backups=("$BACKUP_DIR"/file1_*.bak)
  shopt -u nullglob
  [ "${#backups[@]}" -ge 1 ]
}
