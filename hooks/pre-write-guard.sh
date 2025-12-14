#!/bin/bash
# X-Orchestrator v3.1 - Pre-Write Guard
# Creates automatic checkpoints before file modifications

set -e

FILE_PATH="$1"
OPERATION="$2"  # write or edit

X_DIR="$HOME/.claude/x-orchestrator"
X_STATE_DIR="$PWD/.claude/x-state"
CHECKPOINT_DIR="$X_STATE_DIR/rollback-points"
SESSION_FILE="$X_STATE_DIR/current-session.json"

mkdir -p "$CHECKPOINT_DIR"

# Check if checkpoint is needed (configurable)
should_checkpoint() {
    # Always checkpoint for important files
    case "$FILE_PATH" in
        *.ts|*.tsx|*.js|*.jsx|*.py|*.java|*.cs|*.go|*.rs)
            return 0
            ;;
        *test*|*spec*)
            return 1  # Don't checkpoint test files
            ;;
        *)
            return 0
            ;;
    esac
}

if should_checkpoint && [ -f "$FILE_PATH" ]; then
    # Create rollback point
    ROLLBACK_ID="rp-$(date +%Y%m%d%H%M%S)-$(openssl rand -hex 4)"
    ROLLBACK_FILE="$CHECKPOINT_DIR/$ROLLBACK_ID.json"

    # Read original content
    ORIGINAL_CONTENT=$(cat "$FILE_PATH" | base64)

    cat > "$ROLLBACK_FILE" << EOF
{
  "rollback_id": "$ROLLBACK_ID",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "file_path": "$FILE_PATH",
  "operation": "$OPERATION",
  "original_content_base64": "$ORIGINAL_CONTENT",
  "file_hash": "$(md5 -q "$FILE_PATH" 2>/dev/null || echo 'unknown')"
}
EOF

    # Update session with rollback point
    if [ -f "$SESSION_FILE" ]; then
        jq --arg rp "$ROLLBACK_ID" \
           '.rollback_points += [$rp]' \
           "$SESSION_FILE" > "${SESSION_FILE}.tmp" 2>/dev/null && \
        mv "${SESSION_FILE}.tmp" "$SESSION_FILE" || true
    fi

    # Record telemetry
    if [ -f "$X_DIR/hooks/telemetry-collector.sh" ]; then
        "$X_DIR/hooks/telemetry-collector.sh" "checkpoint_created" "{
            \"checkpoint_id\": \"$ROLLBACK_ID\",
            \"file\": \"$FILE_PATH\",
            \"operation\": \"$OPERATION\"
        }" 2>/dev/null || true
    fi

    echo "{\"status\": \"checkpoint_created\", \"rollback_id\": \"$ROLLBACK_ID\", \"file\": \"$FILE_PATH\"}"
else
    echo "{\"status\": \"skipped\", \"reason\": \"file_not_exists_or_excluded\"}"
fi
