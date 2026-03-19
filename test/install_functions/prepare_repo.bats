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
  GIT_REPO_URL="https://github.com/hskwakr/dotfiles.git"

  log() { echo "$@"; }
}

teardown() {
  rm -rf "$HOME_DIR" "$DOTFILES_DIR" "$BATS_TMPDIR/repo2"
}

@test "prepare_repo skips clone/pull when .git exists" {
  git -C "$DOTFILES_DIR" init -q
  run prepare_repo "$DOTFILES_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already inside dotfiles repository"* ]]
  [ -d "$BACKUP_DIR" ]
  [ -d "$LOG_DIR" ]
}

@test "prepare_repo creates backup and log dirs" {
  git -C "$DOTFILES_DIR" init -q
  run prepare_repo "$DOTFILES_DIR"
  [ "$status" -eq 0 ]
  [ -d "$BACKUP_DIR" ]
  [ -d "$LOG_DIR" ]
}
