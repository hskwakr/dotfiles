# My GitHub activity summary
# - Fetch commits / PRs / issues for @me
# - No args: last 24 hours (UTC)
# - With arg: pass a gh date comparison expression as-is
#     ">=2026-05-01"  / "<2026-05-08"  / "2026-05-01..2026-05-08"
#
# Examples:
#   mygh-commits                          # last 24h
#   mygh-commits 2026-05-08               # that day only
#   mygh-commits 2026-05-01..2026-05-08   # range
#   mygh-day                              # commits + prs + issues at once

# Return an ISO timestamp for 24 hours ago (UTC); handle OS differences via uname
__mygh_24h_ago() {
  case "$(uname)" in
    Darwin*) date -u -v-24H +%Y-%m-%dT%H:%M:%SZ ;;
    *)       date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ ;;
  esac
}

# Return the given filter as-is, or ">=last 24h" when no argument is provided
__mygh_filter() {
  if [[ -n "${1:-}" ]]; then
    printf '%s' "$1"
  else
    printf '>=%s' "$(__mygh_24h_ago)"
  fi
}

# Fetch commits authored by me in the last 24h (or given range) and print a one-line summary
mygh-commits() {
  if ! command -v gh >/dev/null 2>&1; then
    printf 'mygh-commits: gh is not installed\n' >&2
    return 1
  fi
  local filter
  filter="$(__mygh_filter "${1:-}")"
  gh search commits --author=@me --author-date="$filter" --limit 100 \
    --json repository,sha,commit \
    --jq '.[] | "\(.repository.fullName) \(.sha[0:7]) \(.commit.message | split("\n")[0])"'
}

# Fetch PRs authored by me in the last 24h (or given range) and print a one-line summary
mygh-prs() {
  if ! command -v gh >/dev/null 2>&1; then
    printf 'mygh-prs: gh is not installed\n' >&2
    return 1
  fi
  local filter
  filter="$(__mygh_filter "${1:-}")"
  gh search prs --author=@me --updated="$filter" --limit 100 \
    --json repository,number,title,state \
    --jq '.[] | "\(.repository.fullName) #\(.number) [\(.state)] \(.title)"'
}

# Fetch issues authored by me in the last 24h (or given range) and print a one-line summary
mygh-issues() {
  if ! command -v gh >/dev/null 2>&1; then
    printf 'mygh-issues: gh is not installed\n' >&2
    return 1
  fi
  local filter
  filter="$(__mygh_filter "${1:-}")"
  gh search issues --author=@me --updated="$filter" --limit 100 \
    --json repository,number,title,state \
    --jq '.[] | "\(.repository.fullName) #\(.number) [\(.state)] \(.title)"'
}

# Print commits / PRs / issues all at once
mygh-day() {
  local filter
  filter="$(__mygh_filter "${1:-}")"
  printf '=== filter: %s ===\n\n' "$filter"
  printf '## Commits\n';       mygh-commits "$filter"
  printf '\n## Pull Requests\n'; mygh-prs     "$filter"
  printf '\n## Issues\n';        mygh-issues  "$filter"
}
