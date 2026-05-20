#!/usr/bin/env bats

setup() {
  TEST_DIR="$BATS_TMPDIR/tmux_snapshot_restore"
  rm -rf "$TEST_DIR"
  mkdir -p "$TEST_DIR/bin"

  export TMUX_CMD_LOG="$TEST_DIR/tmux_cmd.log"
  : > "$TMUX_CMD_LOG"
  export LIVE_SESSIONS_FILE="$TEST_DIR/live_sessions.txt"
  : > "$LIVE_SESSIONS_FILE"

  # Fake tmux that records every invocation and emits live sessions for list-sessions.
  cat > "$TEST_DIR/bin/tmux" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$TMUX_CMD_LOG"
if [ "$1" = "list-sessions" ]; then
  if [ -f "$LIVE_SESSIONS_FILE" ]; then
    cat "$LIVE_SESSIONS_FILE"
  fi
fi
exit 0
STUB
  chmod +x "$TEST_DIR/bin/tmux"

  PATH="$TEST_DIR/bin:$PATH"
  export PATH

  # Build a fixture snapshot file: 1 session "work", 2 windows, with panes.
  SNAPSHOT="$TEST_DIR/snapshot.json"
  cat > "$SNAPSHOT" <<'JSON'
{
  "version": 1,
  "saved_at": "2026-05-20T10:30:00Z",
  "sessions": [
    {
      "name": "work",
      "windows": [
        {
          "index": 0,
          "name": "main",
          "layout": "abc1,200x50,0,0[200x25,0,0,1,200x24,0,26,2]",
          "panes": [
            { "index": 0, "cwd": "/Users/akira/dev" },
            { "index": 1, "cwd": "/Users/akira/dev/foo" }
          ]
        },
        {
          "index": 1,
          "name": "logs",
          "layout": "def2,200x50,0,0,3",
          "panes": [
            { "index": 0, "cwd": "/var/log" }
          ]
        }
      ]
    }
  ]
}
JSON

  source "$BATS_TEST_DIRNAME/../../bin/tmux-snapshot.sh"
  log() { :; }
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "restore_snapshot fails when session already exists" {
  printf 'work\n' > "$LIVE_SESSIONS_FILE"

  run restore_snapshot "$SNAPSHOT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"work"* ]]
}

@test "restore_snapshot succeeds when no collision" {
  printf '' > "$LIVE_SESSIONS_FILE"

  run restore_snapshot "$SNAPSHOT"
  [ "$status" -eq 0 ]
}

@test "restore_snapshot creates new-session with first pane cwd" {
  printf '' > "$LIVE_SESSIONS_FILE"

  restore_snapshot "$SNAPSHOT"

  grep -q 'new-session -d -s work' "$TMUX_CMD_LOG"
  grep -q '/Users/akira/dev' "$TMUX_CMD_LOG"
}

@test "restore_snapshot creates additional windows for window_index > 0" {
  printf '' > "$LIVE_SESSIONS_FILE"

  restore_snapshot "$SNAPSHOT"

  grep -q 'new-window' "$TMUX_CMD_LOG"
  grep -q '/var/log' "$TMUX_CMD_LOG"
}

@test "restore_snapshot splits additional panes within a window" {
  printf '' > "$LIVE_SESSIONS_FILE"

  restore_snapshot "$SNAPSHOT"

  grep -q 'split-window' "$TMUX_CMD_LOG"
  grep -q '/Users/akira/dev/foo' "$TMUX_CMD_LOG"
}

@test "restore_snapshot applies saved layout via select-layout" {
  printf '' > "$LIVE_SESSIONS_FILE"

  restore_snapshot "$SNAPSHOT"

  grep -q 'select-layout' "$TMUX_CMD_LOG"
  grep -q 'abc1,200x50,0,0' "$TMUX_CMD_LOG"
  grep -q 'def2,200x50,0,0,3' "$TMUX_CMD_LOG"
}

@test "restore_snapshot does not invoke session-creating commands when collision detected" {
  printf 'work\n' > "$LIVE_SESSIONS_FILE"

  run restore_snapshot "$SNAPSHOT"
  [ "$status" -ne 0 ]

  ! grep -q 'new-session' "$TMUX_CMD_LOG"
  ! grep -q 'new-window' "$TMUX_CMD_LOG"
  ! grep -q 'split-window' "$TMUX_CMD_LOG"
}

@test "restore_snapshot detects collision when one of multiple sessions exists" {
  cat > "$TEST_DIR/multi.json" <<'JSON'
{
  "version": 1,
  "saved_at": "2026-05-20T10:30:00Z",
  "sessions": [
    { "name": "work",  "windows": [ { "index": 0, "name": "w0", "layout": "l1", "panes": [ { "index": 0, "cwd": "/a" } ] } ] },
    { "name": "study", "windows": [ { "index": 0, "name": "w0", "layout": "l2", "panes": [ { "index": 0, "cwd": "/b" } ] } ] }
  ]
}
JSON
  printf 'study\n' > "$LIVE_SESSIONS_FILE"

  run restore_snapshot "$TEST_DIR/multi.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"study"* ]]
}
