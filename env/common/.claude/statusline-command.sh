#!/usr/bin/env bash
# Statusline: model name + context % with progress bar
input=$(cat)

model=$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"')

# Use Claude Code's pre-calculated context usage (falls back to 0 before first API response)
used_pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // 0 | floor')
[ -z "$used_pct" ] && used_pct=0
[ "$used_pct" -gt 100 ] && used_pct=100

bar_width=20
filled=$(( used_pct * bar_width / 100 ))
empty=$(( bar_width - filled ))

bar=""
i=0
while [ $i -lt $filled ]; do bar="${bar}█"; i=$((i+1)); done
i=0
while [ $i -lt $empty ]; do bar="${bar}░"; i=$((i+1)); done

# Color thresholds for the percentage
if [ "$used_pct" -ge 80 ]; then
  pct_color="\033[0;31m"  # red
elif [ "$used_pct" -ge 50 ]; then
  pct_color="\033[0;33m"  # yellow
else
  pct_color="\033[0;32m"  # green
fi

printf "\033[0;36m%s\033[0m  \033[0;90m[%s]\033[0m ${pct_color}%d%%\033[0m" \
  "$model" "$bar" "$used_pct"
