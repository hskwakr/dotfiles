#!/usr/bin/env bats

setup() {
  LOG_DIR="$BATS_TMPDIR/logs"
  mkdir -p "$LOG_DIR"
  LOG_FILE="$LOG_DIR/install.log"
  LOG_MAX_SIZE=10
  LOG_BACKUP_COUNT=2

  source "$BATS_TEST_DIRNAME/../../bin/install.sh"

  LOG_DIR="$BATS_TMPDIR/logs"
  LOG_FILE="$LOG_DIR/install.log"
  LOG_MAX_SIZE=10
  LOG_BACKUP_COUNT=2

  log() { :; }
}

teardown() {
  rm -rf "$LOG_DIR"
}

@test "rotates log when size exceeded" {
  printf '1234567890' > "$LOG_FILE"
  run manage_log_file "$LOG_FILE"
  [ "$status" -eq 0 ]
  [ -f "$LOG_FILE.1" ]
  grep -q '1234567890' "$LOG_FILE.1"
  grep -q 'Log rotated' "$LOG_FILE"
}

@test "keeps limited number of backups" {
  printf 'abc' > "$LOG_FILE"
  printf 'old1' > "$LOG_FILE.1"
  printf 'old2' > "$LOG_FILE.2"
  run manage_log_file "$LOG_FILE"
  [ "$status" -eq 0 ]
  [ -f "$LOG_FILE.1" ]
  [ -f "$LOG_FILE.2" ]
  [ ! -f "$LOG_FILE.3" ]
}

@test "shifts existing backups when rotated" {
  LOG_BACKUP_COUNT=3
  printf 'current_log' > "$LOG_FILE"
  printf 'first_backup' > "$LOG_FILE.1"
  printf 'second_backup' > "$LOG_FILE.2"
  run manage_log_file "$LOG_FILE"
  [ "$status" -eq 0 ]
  grep -q 'second_backup' "$LOG_FILE.3"
  grep -q 'first_backup' "$LOG_FILE.2"
  grep -q 'current_log' "$LOG_FILE.1"
  [ ! -f "$LOG_FILE.4" ]
  grep -q 'Log rotated' "$LOG_FILE"
}
