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
  ignore_list=()

  log() { :; }
}

teardown() {
  rm -rf "$HOME_DIR" "$DOTFILES_DIR"
}

@test "links exact OS directory" {
  mkdir -p "$DOTFILES_DIR/env/wsl-ubuntu"
  echo "a" > "$DOTFILES_DIR/env/wsl-ubuntu/file1"

  run install_env_os "wsl-ubuntu"
  [ "$status" -eq 0 ]

  [ -L "$HOME/file1" ]
  [ "$(readlink "$HOME/file1")" = "$DOTFILES_DIR/env/wsl-ubuntu/file1" ]
}

@test "falls back to generic directory" {
  mkdir -p "$DOTFILES_DIR/env/wsl"
  echo "b" > "$DOTFILES_DIR/env/wsl/file1"

  run install_env_os "wsl-ubuntu"
  [ "$status" -eq 0 ]

  [ -L "$HOME/file1" ]
  [ "$(readlink "$HOME/file1")" = "$DOTFILES_DIR/env/wsl/file1" ]
}

@test "no links when directory missing" {
  run install_env_os "unknown-os"
  [ "$status" -eq 0 ]

  [ -z "$(ls -A "$HOME")" ]
}
