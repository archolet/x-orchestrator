#!/bin/bash
# X-Orchestrator v3.1 - Rollback Engine
# Handles file restoration from rollback points

set -e

ACTION="$1"
ROLLBACK_ID="$2"

X_DIR="$HOME/.claude/x-orchestrator"
X_STATE_DIR="$PWD/.claude/x-state"
CHECKPOINT_DIR="$X_STATE_DIR/rollback-points"
SESSION_FILE="$X_STATE_DIR/current-session.json"

list_rollback_points() {
    if [ -d "$CHECKPOINT_DIR" ]; then
        echo "["
        FIRST=true
        for rp_file in "$CHECKPOINT_DIR"/*.json; do
            if [ -f "$rp_file" ]; then
                $FIRST || echo ","
                FIRST=false
                jq '{rollback_id, created_at, file_path, operation}' "$rp_file"
            fi
        done
        echo "]"
    else
        echo "[]"
    fi
}

restore_rollback_point() {
    local rp_id=$1
    local rp_file="$CHECKPOINT_DIR/$rp_id.json"

    if [ ! -f "$rp_file" ]; then
        echo "{\"error\": \"Rollback point not found: $rp_id\"}"
        exit 1
    fi

    # Get file info
    FILE_PATH=$(jq -r '.file_path' "$rp_file")
    ORIGINAL_CONTENT=$(jq -r '.original_content_base64' "$rp_file")

    # Backup current state before rollback
    if [ -f "$FILE_PATH" ]; then
        BACKUP_ID="backup-$(date +%Y%m%d%H%M%S)"
        BACKUP_FILE="$CHECKPOINT_DIR/$BACKUP_ID.json"
        CURRENT_CONTENT=$(cat "$FILE_PATH" | base64)

        cat > "$BACKUP_FILE" << EOF
{
  "rollback_id": "$BACKUP_ID",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "file_path": "$FILE_PATH",
  "operation": "pre_rollback_backup",
  "original_content_base64": "$CURRENT_CONTENT",
  "note": "Backup before rollback to $rp_id"
}
EOF
    fi

    # Restore original content
    echo "$ORIGINAL_CONTENT" | base64 -d > "$FILE_PATH"

    # Record telemetry
    if [ -f "$X_DIR/hooks/telemetry-collector.sh" ]; then
        "$X_DIR/hooks/telemetry-collector.sh" "rollback_triggered" "{
            \"rollback_id\": \"$rp_id\",
            \"file\": \"$FILE_PATH\",
            \"backup_id\": \"$BACKUP_ID\"
        }" 2>/dev/null || true
    fi

    echo "{\"status\": \"restored\", \"rollback_id\": \"$rp_id\", \"file\": \"$FILE_PATH\", \"backup_id\": \"$BACKUP_ID\"}"
}

get_rollback_point() {
    local rp_id=$1
    local rp_file="$CHECKPOINT_DIR/$rp_id.json"

    if [ -f "$rp_file" ]; then
        cat "$rp_file"
    else
        echo "{\"error\": \"Rollback point not found: $rp_id\"}"
        exit 1
    fi
}

delete_rollback_point() {
    local rp_id=$1
    local rp_file="$CHECKPOINT_DIR/$rp_id.json"

    if [ -f "$rp_file" ]; then
        rm "$rp_file"
        echo "{\"status\": \"deleted\", \"rollback_id\": \"$rp_id\"}"
    else
        echo "{\"error\": \"Rollback point not found: $rp_id\"}"
        exit 1
    fi
}

case "$ACTION" in
    "list")
        list_rollback_points
        ;;
    "restore")
        if [ -z "$ROLLBACK_ID" ]; then
            echo "{\"error\": \"Rollback ID required\"}"
            exit 1
        fi
        restore_rollback_point "$ROLLBACK_ID"
        ;;
    "get")
        if [ -z "$ROLLBACK_ID" ]; then
            echo "{\"error\": \"Rollback ID required\"}"
            exit 1
        fi
        get_rollback_point "$ROLLBACK_ID"
        ;;
    "delete")
        if [ -z "$ROLLBACK_ID" ]; then
            echo "{\"error\": \"Rollback ID required\"}"
            exit 1
        fi
        delete_rollback_point "$ROLLBACK_ID"
        ;;
    "latest")
        # Get the most recent rollback point
        LATEST=$(ls -t "$CHECKPOINT_DIR"/*.json 2>/dev/null | head -1)
        if [ -n "$LATEST" ]; then
            cat "$LATEST"
        else
            echo "{\"error\": \"No rollback points found\"}"
        fi
        ;;
    *)
        echo "{\"error\": \"Unknown action. Use: list, restore, get, delete, latest\"}"
        exit 1
        ;;
esac
