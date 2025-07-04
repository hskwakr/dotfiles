#!/usr/bin/env bats

setup() {
  HOME_DIR="$BATS_TMPDIR/home"
  mkdir -p "$HOME_DIR"
  export HOME="$HOME_DIR"

  REPO="$HOME/dotfiles"
  mkdir -p "$REPO"
  echo "bashrc" > "$REPO/.bashrc"
  echo "vimrc" > "$REPO/.vimrc"
  git -C "$REPO" init -q
  git -C "$REPO" config user.email "test@example.com"
  git -C "$REPO" config user.name "Test"
  git -C "$REPO" commit --allow-empty -m init >/dev/null
  git -C "$REPO" branch -M main
  git -C "$REPO" remote add origin "$REPO"
}

teardown() {
  rm -rf "$REPO" "$HOME_DIR"
}

@test "list.sh outputs only non-ignored dotfiles" {
  run bash "$BATS_TEST_DIRNAME/../bin/list.sh"
  [ "$status" -eq 0 ]

  [[ "$output" == *"$HOME/.bashrc"* ]]
  [[ "$output" == *"$HOME/.vimrc"* ]]
  [[ "$output" != *"$HOME/.git"* ]]
}
