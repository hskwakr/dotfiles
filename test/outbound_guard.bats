#!/usr/bin/env bats
# The guard's suite is a plain bash script living beside the script it tests,
# so `bats --recursive test` never saw it. It is the only thing that detects a
# contaminated stdout (spec.md 5-b), which is silent everywhere else.

@test "outbound-guard decision suite passes" {
  run bash "${BATS_TEST_DIRNAME}/../env/common/.claude/hooks/outbound-guard_test.sh"
  [ "$status" -eq 0 ]
  # A count, not just "0 failed": a suite that ran nothing also exits 0.
  [[ "$output" =~ ([0-9]+)' passed, 0 failed' ]]
  [ "${BASH_REMATCH[1]}" -ge 100 ]
}
