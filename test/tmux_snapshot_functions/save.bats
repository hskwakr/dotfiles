#!/usr/bin/env bats

setup() {
  TEST_DIR="$BATS_TMPDIR/tmux_snapshot_save"
  rm -rf "$TEST_DIR"
  mkdir -p "$TEST_DIR/bin"

  # Fake tmux that emits fixture output based on the first argument.
  cat > "$TEST_DIR/bin/tmux" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  list-sessions)
    printf 'work\nstudy\n'
    ;;
  list-windows)
    printf 'work\t0\tmain\tabc1,layout1\n'
    printf 'work\t1\tlogs\tdef2,layout2\n'
    printf 'study\t0\tnotes\tghi3,layout3\n'
    ;;
  list-panes)
    printf 'work\t0\t0\t/Users/akira/dev\n'
    printf 'work\t0\t1\t/Users/akira/dev/foo\n'
    printf 'work\t1\t0\t/var/log\n'
    printf 'study\t0\t0\t/Users/akira\n'
    ;;
  *)
    echo "fake tmux: unsupported subcommand $1" >&2
    exit 1
    ;;
esac
STUB
  chmod +x "$TEST_DIR/bin/tmux"

  PATH="$TEST_DIR/bin:$PATH"
  export PATH

  source "$BATS_TEST_DIRNAME/../../bin/tmux-snapshot.sh"

  log() { :; }
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "save_snapshot writes JSON to given path" {
  target="$TEST_DIR/snapshot.json"
  run save_snapshot "$target"
  [ "$status" -eq 0 ]
  [ -f "$target" ]
}

@test "save_snapshot produces valid JSON" {
  target="$TEST_DIR/snapshot.json"
  save_snapshot "$target"
  run jq -e . "$target"
  [ "$status" -eq 0 ]
}

@test "save_snapshot captures all session names" {
  target="$TEST_DIR/snapshot.json"
  save_snapshot "$target"
  names=$(jq -r '.sessions[].name' "$target" | sort | tr '\n' ',')
  [ "$names" = "study,work," ]
}

@test "save_snapshot captures window layout per session" {
  target="$TEST_DIR/snapshot.json"
  save_snapshot "$target"
  layout=$(jq -r '.sessions[] | select(.name == "work") | .windows[] | select(.index == 0) | .layout' "$target")
  [ "$layout" = "abc1,layout1" ]
}

@test "save_snapshot captures pane cwd per window" {
  target="$TEST_DIR/snapshot.json"
  save_snapshot "$target"
  cwd=$(jq -r '.sessions[] | select(.name == "work") | .windows[] | select(.index == 0) | .panes[] | select(.index == 1) | .cwd' "$target")
  [ "$cwd" = "/Users/akira/dev/foo" ]
}

@test "save_snapshot records saved_at timestamp" {
  target="$TEST_DIR/snapshot.json"
  save_snapshot "$target"
  saved_at=$(jq -r '.saved_at' "$target")
  [ -n "$saved_at" ]
  [ "$saved_at" != "null" ]
}

@test "save_snapshot includes version field" {
  target="$TEST_DIR/snapshot.json"
  save_snapshot "$target"
  version=$(jq -r '.version' "$target")
  [ "$version" = "1" ]
}
