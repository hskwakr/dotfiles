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
}

teardown() {
  rm -rf "$REPO" "$HOME_DIR"
}

@test "install.sh links files and creates backups" {
  run bash "$BATS_TEST_DIRNAME/../bin/install.sh" -d "$REPO"
  [ "$status" -eq 0 ]

  [ -L "$HOME/commonrc" ]
  [ "$(readlink "$HOME/commonrc")" = "$REPO/env/common/commonrc" ]

  [ -f "$REPO/backups/original/commonrc" ]

  shopt -s nullglob
  backups=("$REPO"/backups/commonrc_*.bak)
  shopt -u nullglob
  [ "${#backups[@]}" -ge 1 ]
}

@test "install.sh links dotfiles in env/common" {
  echo "hidden" > "$REPO/env/common/.hiddenrc"

  run bash "$BATS_TEST_DIRNAME/../bin/install.sh" -d "$REPO"
  [ "$status" -eq 0 ]

  [ -L "$HOME/.hiddenrc" ]
  [ "$(readlink "$HOME/.hiddenrc")" = "$REPO/env/common/.hiddenrc" ]
}

@test "install.sh does not link root-level dotfiles" {
  echo "keep" > "$HOME/.bashrc"

  run bash "$BATS_TEST_DIRNAME/../bin/install.sh" -d "$REPO"
  [ "$status" -eq 0 ]

  [ ! -L "$HOME/.bashrc" ]
  grep -q "keep" "$HOME/.bashrc"
  [ ! -e "$REPO/backups/original/.bashrc" ]
}
