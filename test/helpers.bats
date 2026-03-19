#!/usr/bin/env bats

setup() {
  LIB_DIR="${BATS_TEST_DIRNAME}/../bin/lib"
  source "${LIB_DIR}/helpers.sh"
}

@test "is_ignored returns 0 when item is in list" {
  IGNORE_LIST=("foo" "bar")
  run is_ignored "foo"
  [ "$status" -eq 0 ]
}

@test "is_ignored returns 1 when item is not in list" {
  IGNORE_LIST=("foo" "bar")
  run is_ignored "baz"
  [ "$status" -eq 1 ]
}

@test "log outputs level and message" {
  run log INFO "hello"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[INFO]"* ]]
  [[ "$output" == *"hello"* ]]
}

@test "detect_dotfiles_dir returns repo root when given a script in bin/" {
  local script_path="${BATS_TEST_DIRNAME}/../bin/clean.sh"
  run detect_dotfiles_dir "$script_path"
  [ "$status" -eq 0 ]
  # clean.sh is in bin/, so parent of bin/ is repo root
  local expected
  expected="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  [ "$output" = "$expected" ]
}

@test "detect_dotfiles_dir falls back to HOME/dotfiles when path is empty" {
  run detect_dotfiles_dir ""
  [ "$status" -eq 0 ]
  [ "$output" = "$HOME/dotfiles" ]
}

@test "detect_dotfiles_dir falls back to HOME/dotfiles when file does not exist" {
  run detect_dotfiles_dir "/nonexistent/path/script.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "$HOME/dotfiles" ]
}

