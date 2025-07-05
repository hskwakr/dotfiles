#!/usr/bin/env bats

setup() {
  export SHELL="/bin/sh"
  CHSH_LOG="$BATS_TEST_TMPDIR/chsh.log"
  chsh() { echo "chsh $@" >> "$CHSH_LOG"; }
  export -f chsh

  source "$BATS_TEST_DIRNAME/../../bin/install.sh"

  log() { :; }
}

@test "no change when shell already set" {
  run setup_shell "/bin/sh"
  [ "$status" -eq 0 ]
  [ ! -s "$CHSH_LOG" ]
}

@test "fails on invalid shell path" {
  run setup_shell "/no/shell"
  [ "$status" -ne 0 ]
}

@test "fails when user not found" {
  USER="nonexistentuser"
  run setup_shell "/bin/bash"
  [ "$status" -ne 0 ]
}

@test "changes shell when valid" {
  USER="root"
  run setup_shell "/bin/bash"
  [ "$status" -eq 0 ]
  grep -q "/bin/bash" "$CHSH_LOG"
}
