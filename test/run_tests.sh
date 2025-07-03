#!/usr/bin/env bash
# Build container and run BATS with given arguments.

set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required to run tests" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

docker build -f "$SCRIPT_DIR/Dockerfile" -t dotfiles-bats "$REPO_ROOT"
docker run --rm dotfiles-bats "$@"
