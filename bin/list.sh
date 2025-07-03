#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/helpers.sh"

DOT_DIR="${HOME}/dotfiles"

if [ -d "${DOT_DIR}" ]; then
  cd "${DOT_DIR}" || exit 1
  log INFO "Show list of available dotfiles in dotfiles repository..."
  for f in .??*; do
    if is_ignored "$f"; then
      continue
    fi
    echo "${HOME}/$f"
  done
else
  log ERROR "dotfiles does not exist"
  exit 1
fi
