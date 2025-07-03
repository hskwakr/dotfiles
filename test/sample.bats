#!/usr/bin/env bats

@test "sample runs" {
  run echo "hello"
  [ "$status" -eq 0 ]
  [ "$output" = "hello" ]
}
