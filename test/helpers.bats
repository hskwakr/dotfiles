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

