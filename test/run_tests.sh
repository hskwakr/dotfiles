#!/usr/bin/env bash
# Build container and run BATS with given arguments.

set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required to run tests" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Running tests from repository root: $REPO_ROOT"

docker build -f "$SCRIPT_DIR/Dockerfile" -t dotfiles-bats "$REPO_ROOT"

# Ensure BATS receives paths relative to the repository root
ARGS=()
for path in "$@"; do
  if [[ "$path" == test/* ]]; then
    ARGS+=("$path")
  else
    ARGS+=("test/$path")
  fi
done

docker run --rm dotfiles-bats "${ARGS[@]}"
