#!/usr/bin/env bats

setup() {
  TEST_DIR="$BATS_TMPDIR/tmux_snapshot_list"
  rm -rf "$TEST_DIR"
  mkdir -p "$TEST_DIR"

  source "$BATS_TEST_DIRNAME/../../bin/tmux-snapshot.sh"

  log() { :; }
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "list_snapshots returns empty when directory is empty" {
  run list_snapshots "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "list_snapshots returns empty when directory does not exist" {
  run list_snapshots "$TEST_DIR/missing"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "list_snapshots prints files newest first" {
  touch -t 202605181800 "$TEST_DIR/snapshot_20260518_180000.json"
  touch -t 202605200900 "$TEST_DIR/snapshot_20260520_090000.json"
  touch -t 202605191000 "$TEST_DIR/snapshot_20260519_100000.json"

  run list_snapshots "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$TEST_DIR/snapshot_20260520_090000.json" ]
  [ "${lines[1]}" = "$TEST_DIR/snapshot_20260519_100000.json" ]
  [ "${lines[2]}" = "$TEST_DIR/snapshot_20260518_180000.json" ]
}

@test "list_snapshots ignores non-snapshot files" {
  touch "$TEST_DIR/snapshot_20260520_090000.json"
  touch "$TEST_DIR/readme.txt"
  touch "$TEST_DIR/other.json"

  run list_snapshots "$TEST_DIR"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [ "${lines[0]}" = "$TEST_DIR/snapshot_20260520_090000.json" ]
}

@test "rotate_snapshots keeps newest N and deletes older" {
  touch -t 202605150900 "$TEST_DIR/snapshot_20260515_090000.json"
  touch -t 202605160900 "$TEST_DIR/snapshot_20260516_090000.json"
  touch -t 202605170900 "$TEST_DIR/snapshot_20260517_090000.json"
  touch -t 202605180900 "$TEST_DIR/snapshot_20260518_090000.json"
  touch -t 202605190900 "$TEST_DIR/snapshot_20260519_090000.json"

  run rotate_snapshots "$TEST_DIR" 3
  [ "$status" -eq 0 ]

  [ -f "$TEST_DIR/snapshot_20260519_090000.json" ]
  [ -f "$TEST_DIR/snapshot_20260518_090000.json" ]
  [ -f "$TEST_DIR/snapshot_20260517_090000.json" ]
  [ ! -f "$TEST_DIR/snapshot_20260516_090000.json" ]
  [ ! -f "$TEST_DIR/snapshot_20260515_090000.json" ]
}

@test "rotate_snapshots does nothing when count under limit" {
  touch -t 202605180900 "$TEST_DIR/snapshot_20260518_090000.json"
  touch -t 202605190900 "$TEST_DIR/snapshot_20260519_090000.json"

  run rotate_snapshots "$TEST_DIR" 5
  [ "$status" -eq 0 ]

  [ -f "$TEST_DIR/snapshot_20260518_090000.json" ]
  [ -f "$TEST_DIR/snapshot_20260519_090000.json" ]
}

@test "rotate_snapshots tolerates empty or missing directory" {
  run rotate_snapshots "$TEST_DIR" 3
  [ "$status" -eq 0 ]

  run rotate_snapshots "$TEST_DIR/missing" 3
  [ "$status" -eq 0 ]
}
