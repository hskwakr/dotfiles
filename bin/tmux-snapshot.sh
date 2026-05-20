#!/usr/bin/env bash
# tmux-snapshot.sh - Save and restore tmux session/window/pane layout
# Usage:
#   ./tmux-snapshot.sh save                 Save current tmux state to backups/tmux/
#   ./tmux-snapshot.sh restore [--from F]   Restore from latest (or --from F)
#   ./tmux-snapshot.sh list                 List saved snapshots, newest first
#   ./tmux-snapshot.sh -h                   Show help
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/helpers.sh
source "$SCRIPT_DIR/lib/helpers.sh"

DOTFILES_DIR="$(detect_dotfiles_dir "${BASH_SOURCE[0]}")"
SNAPSHOT_DIR="$DOTFILES_DIR/backups/tmux"
SNAPSHOT_MAX_COUNT=10

# Build a JSON snapshot from the running tmux server and write it to the given path.
save_snapshot() {
  local output=$1
  local timestamp
  timestamp=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

  local windows_tsv panes_tsv
  windows_tsv=$(tmux list-windows -a -F '#{session_name}	#{window_index}	#{window_name}	#{window_layout}')
  panes_tsv=$(tmux list-panes -a -F '#{session_name}	#{window_index}	#{pane_index}	#{pane_current_path}')

  mkdir -p "$(dirname "$output")"

  jq -n \
    --arg saved_at "$timestamp" \
    --arg windows "$windows_tsv" \
    --arg panes "$panes_tsv" '
    def lines(s): s | split("\n") | map(select(length > 0));

    (lines($windows) | map(split("\t") | {
      session: .[0],
      index: (.[1] | tonumber),
      name: .[2],
      layout: .[3]
    })) as $wins |

    (lines($panes) | map(split("\t") | {
      session: .[0],
      window_index: (.[1] | tonumber),
      index: (.[2] | tonumber),
      cwd: .[3]
    })) as $panes |

    {
      version: 1,
      saved_at: $saved_at,
      sessions: (
        ($wins | map(.session) | unique) | map(. as $sname | {
          name: $sname,
          windows: (
            $wins | map(select(.session == $sname)) | map(. as $w | {
              index: $w.index,
              name: $w.name,
              layout: $w.layout,
              panes: (
                $panes
                | map(select(.session == $sname and .window_index == $w.index))
                | map({ index: .index, cwd: .cwd })
              )
            })
          )
        })
      )
    }
    ' > "$output"
}

# Read snapshot JSON and rebuild tmux sessions/windows/panes.
# Fails with non-zero exit if any session name in the snapshot already exists.
restore_snapshot() {
  local input=$1

  local snapshot_sessions live_sessions
  snapshot_sessions=$(jq -r '.sessions[].name' "$input")
  live_sessions=$(tmux list-sessions -F '#{session_name}' 2>/dev/null || true)

  # Collision detection: error out if any snapshot session name already exists.
  local name
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    if printf '%s\n' "$live_sessions" | grep -qxF "$name"; then
      echo "ERROR: session '$name' already exists. Aborting restore." >&2
      echo "Hint: kill the existing session or restore manually." >&2
      return 1
    fi
  done <<<"$snapshot_sessions"

  # Replay sessions, windows, and panes in array order. Targets are scoped to
  # the session name only (no `:N` index) so the most recently created or
  # split tmux entity is always the operand. Saved window/pane indices are
  # intentionally ignored at restore time because:
  #   - tmux assigns indices via `base-index` / `pane-base-index`, which may
  #     differ between the save and restore environments.
  #   - Saved indices can be non-contiguous (e.g. windows 3 and 5 after
  #     killing 0, 1, 2, 4 with `renumber-windows` off). Targeting those
  #     indices on a fresh session would address non-existent windows.
  local session_count s_pos
  session_count=$(jq -r '.sessions | length' "$input")
  for ((s_pos = 0; s_pos < session_count; s_pos++)); do
    local sname w0_name p0_cwd
    sname=$(jq -r ".sessions[$s_pos].name" "$input")
    w0_name=$(jq -r ".sessions[$s_pos].windows[0].name" "$input")
    p0_cwd=$(jq -r ".sessions[$s_pos].windows[0].panes[0].cwd" "$input")

    tmux new-session -d -s "$sname" -n "$w0_name" -c "$p0_cwd"

    local w_count w_pos
    w_count=$(jq -r ".sessions[$s_pos].windows | length" "$input")
    for ((w_pos = 0; w_pos < w_count; w_pos++)); do
      local w_name w_layout p_count p_pos
      w_name=$(jq -r ".sessions[$s_pos].windows[$w_pos].name" "$input")
      w_layout=$(jq -r ".sessions[$s_pos].windows[$w_pos].layout" "$input")
      p_count=$(jq -r ".sessions[$s_pos].windows[$w_pos].panes | length" "$input")

      if [ "$w_pos" -gt 0 ]; then
        local first_cwd
        first_cwd=$(jq -r ".sessions[$s_pos].windows[$w_pos].panes[0].cwd" "$input")
        tmux new-window -t "$sname" -n "$w_name" -c "$first_cwd"
      fi

      for ((p_pos = 1; p_pos < p_count; p_pos++)); do
        local p_cwd
        p_cwd=$(jq -r ".sessions[$s_pos].windows[$w_pos].panes[$p_pos].cwd" "$input")
        tmux split-window -t "$sname" -c "$p_cwd"
      done

      tmux select-layout -t "$sname" "$w_layout"
    done
  done
}

# Match only basenames of the form snapshot_YYYYMMDD_HHMMSS.json.
# Guards list/restore/rotate against unrelated files like snapshot_draft.json
# that share the snapshot_*.json prefix but are not produced by `save`.
is_timestamped_snapshot() {
  local base
  base=$(basename "$1")
  [[ $base =~ ^snapshot_[0-9]{8}_[0-9]{6}\.json$ ]]
}

# Print snapshot files in the given directory, newest first.
# Only files matching snapshot_YYYYMMDD_HHMMSS.json are considered.
list_snapshots() {
  local dir=$1
  [ -d "$dir" ] || return 0
  shopt -s nullglob
  local candidates=("$dir"/snapshot_*.json)
  shopt -u nullglob
  local files=()
  if [ "${#candidates[@]}" -gt 0 ]; then
    local f
    for f in "${candidates[@]}"; do
      if is_timestamped_snapshot "$f"; then
        files+=("$f")
      fi
    done
  fi
  [ "${#files[@]}" -eq 0 ] && return 0
  # ls -t prints newest first by mtime.
  ls -t "${files[@]}"
}

# Delete oldest snapshot files beyond <max_count>. Keeps newest <max_count>.
rotate_snapshots() {
  local dir=$1
  local max_count=$2
  [ -d "$dir" ] || return 0
  shopt -s nullglob
  local candidates=("$dir"/snapshot_*.json)
  shopt -u nullglob
  local files=()
  if [ "${#candidates[@]}" -gt 0 ]; then
    local f
    for f in "${candidates[@]}"; do
      if is_timestamped_snapshot "$f"; then
        files+=("$f")
      fi
    done
  fi
  if [ "${#files[@]}" -le "$max_count" ]; then
    return 0
  fi
  local excess=$((${#files[@]} - max_count))
  local old
  while IFS= read -r old; do
    [ -n "$old" ] || continue
    rm -f "$old"
    log INFO "Removed old snapshot: $old"
  done < <(ls -t "${files[@]}" | tail -n "$excess")
}

usage() {
  cat <<EOF
Usage:
  $0 save                   Save tmux state to $SNAPSHOT_DIR/snapshot_YYYYMMDD_HHMMSS.json
  $0 restore [--from FILE]  Restore from latest snapshot, or from FILE if given
  $0 list                   List saved snapshots, newest first
  $0 -h                     Show this help
EOF
}

# Verify required external commands are available; exits non-zero on missing.
require_commands() {
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "ERROR: required command '$cmd' not found in PATH" >&2
      exit 1
    fi
  done
}

main() {
  if [ $# -eq 0 ]; then
    usage >&2
    exit 1
  fi

  local subcommand=$1
  shift

  case "$subcommand" in
    save)
      require_commands tmux jq
      local stamp output
      stamp=$(date '+%Y%m%d_%H%M%S')
      output="$SNAPSHOT_DIR/snapshot_${stamp}.json"
      save_snapshot "$output"
      log INFO "Snapshot saved: $output"
      rotate_snapshots "$SNAPSHOT_DIR" "$SNAPSHOT_MAX_COUNT"
      ;;
    restore)
      require_commands tmux jq
      local from=""
      while [ $# -gt 0 ]; do
        case "$1" in
          --from)
            from=${2:-}
            shift 2
            ;;
          -h|--help)
            usage
            return 0
            ;;
          *)
            echo "Unknown option for restore: $1" >&2
            usage >&2
            exit 1
            ;;
        esac
      done
      if [ -z "$from" ]; then
        from=$(list_snapshots "$SNAPSHOT_DIR" | head -n 1)
      fi
      if [ -z "$from" ] || [ ! -f "$from" ]; then
        echo "ERROR: no snapshot found to restore (looked in $SNAPSHOT_DIR)" >&2
        exit 1
      fi
      log INFO "Restoring from: $from"
      restore_snapshot "$from"
      log INFO "Restore complete"
      ;;
    list)
      list_snapshots "$SNAPSHOT_DIR"
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      echo "Unknown subcommand: $subcommand" >&2
      usage >&2
      exit 1
      ;;
  esac
}

# Run main only when executed directly, not when sourced (e.g. from BATS tests).
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
