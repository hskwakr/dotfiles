#!/bin/bash
# Claude Code 通知フック
# Usage: echo '<json>' | claude-notify.sh <event_type>
#   event_type: stop | stop_failure | notification

set -euo pipefail

# terminal-notifier の存在チェック
if ! command -v terminal-notifier &>/dev/null; then
    echo "terminal-notifier not found. Install with: brew install terminal-notifier" >&2
    exit 2
fi

EVENT_TYPE="${1:-unknown}"
INPUT=$(cat)
PROJECT_NAME=$(basename "${CLAUDE_PROJECT_DIR:-$PWD}")

# Stop hookの無限ループ防止
if [ "$EVENT_TYPE" = "stop" ]; then
    STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
    if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
        exit 0
    fi
fi

# 共通フィールドを1回のjqで取得
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
GROUP="claude-code-${SESSION_ID:0:8}"

case "$EVENT_TYPE" in
    stop)
        TITLE="Claude Code - 完了"
        MESSAGE="処理が完了しました"
        SOUND="default"
        ;;
    stop_failure)
        # エラー情報を1回のjqで取得
        read -r ERROR ERROR_DETAILS < <(echo "$INPUT" | jq -r '[.error // "unknown", .error_details // ""] | @tsv')
        TITLE="Claude Code - エラー"
        MESSAGE="APIエラー: ${ERROR}"
        if [ -n "$ERROR_DETAILS" ] && [ "$ERROR_DETAILS" != "null" ]; then
            MESSAGE="${MESSAGE} (${ERROR_DETAILS})"
        fi
        SOUND="Basso"
        ;;
    notification)
        MESSAGE=$(echo "$INPUT" | jq -r '.message // "入力を待っています"')
        TITLE="Claude Code - 入力待ち"
        SOUND="Purr"
        ;;
    *)
        exit 0
        ;;
esac

terminal-notifier \
    -title "$TITLE" \
    -subtitle "Project: $PROJECT_NAME" \
    -message "$MESSAGE" \
    -sound "$SOUND" \
    -group "$GROUP"
