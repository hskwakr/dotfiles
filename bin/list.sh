#!/usr/bin/env bash
# list.sh - List available dotfiles in the repository
# Usage:
#   ./list.sh [-d dotfiles_directory] [-h]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/helpers.sh"

DOT_DIR="$(detect_dotfiles_dir "${BASH_SOURCE[0]}")"

# Parse command line options
while getopts "d:h" opt; do
  case "$opt" in
    d)
      DOT_DIR="$OPTARG"
      ;;
    h)
      echo "Usage: $0 [-d dotfiles_directory] [-h]"
      exit 0
      ;;
    \?)
      echo "Usage: $0 [-d dotfiles_directory] [-h]" >&2
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))

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
