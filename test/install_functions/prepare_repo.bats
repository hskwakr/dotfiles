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
  rm -rf "$HOME_DIR" "$DOTFILES_DIR" "$BATS_TMPDIR/repo2" "$BATS_TMPDIR/repo-main"
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

@test "prepare_repo keeps a git worktree (where .git is a file) intact" {
  local main_repo="$BATS_TMPDIR/repo-main"
  git init -q "$main_repo"
  git -C "$main_repo" -c user.name=test -c user.email=test@example.com \
    commit -q --allow-empty -m init
  git -C "$main_repo" worktree add -q --detach "$DOTFILES_DIR"
  echo "work in progress" > "$DOTFILES_DIR/uncommitted.txt"
  [ -f "$DOTFILES_DIR/.git" ]

  # Fail instead of hitting the network if prepare_repo tries to re-clone
  git() {
    if [ "${1:-}" = "clone" ]; then
      echo "unexpected git clone" >&2
      return 1
    fi
    command git "$@"
  }

  run prepare_repo "$DOTFILES_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already inside dotfiles repository"* ]] || false
  [ -f "$DOTFILES_DIR/uncommitted.txt" ]
  [ -f "$DOTFILES_DIR/.git" ]
}
