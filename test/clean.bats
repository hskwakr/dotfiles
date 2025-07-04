#!/usr/bin/env bats

setup() {
  HOME_DIR="$BATS_TMPDIR/home"
  mkdir -p "$HOME_DIR"
  export HOME="$HOME_DIR"

  REPO="$HOME/dotfiles"
  mkdir -p "$REPO/env/common"
  echo "repo bashrc" > "$REPO/.bashrc"
  echo "common rc" > "$REPO/env/common/commonrc"
  git -C "$REPO" init -q
  git -C "$REPO" config user.email "test@example.com"
  git -C "$REPO" config user.name "Test"
  git -C "$REPO" commit --allow-empty -m init >/dev/null
  git -C "$REPO" branch -M main
  git -C "$REPO" remote add origin "$REPO"

  echo "original config" > "$HOME/commonrc"

  bash "$BATS_TEST_DIRNAME/../bin/install.sh" -d "$REPO" >/dev/null

  # create old backup
  touch -d "40 days ago" "$REPO/backups/old.bak"
  # create old log
  mkdir -p "$REPO/logs"
  touch -d "10 days ago" "$REPO/logs/old.log"
  # create broken symlink
  ln -s /nonexistent "$HOME/broken.link"
}

teardown() {
  rm -rf "$REPO" "$HOME_DIR"
}

@test "clean.sh restores and cleans" {
  run bash "$BATS_TEST_DIRNAME/../bin/clean.sh"
  [ "$status" -eq 0 ]

  [ -f "$HOME/commonrc" ]
  [ ! -L "$HOME/commonrc" ]
  grep -q "original config" "$HOME/commonrc"

  [ ! -e "$HOME/broken.link" ]
  [ ! -e "$REPO/backups/old.bak" ]
  [ ! -e "$REPO/logs/old.log" ]
}
