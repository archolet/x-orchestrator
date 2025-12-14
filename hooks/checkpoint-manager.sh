#!/bin/bash
# X-Orchestrator v3.1 - Checkpoint Manager
# Handles named checkpoint operations

set -e

ACTION="$1"
NAME="$2"

X_STATE_DIR="$PWD/.claude/x-state"
CHECKPOINT_DIR="$X_STATE_DIR/checkpoints"
SESSION_FILE="$X_STATE_DIR/current-session.json"

mkdir -p "$CHECKPOINT_DIR"

create_checkpoint() {
    local name=$1
    local checkpoint_id="cp-$(date +%Y%m%d%H%M%S)-$(openssl rand -hex 4)"
    local checkpoint_file="$CHECKPOINT_DIR/$checkpoint_id.json"
    
    # Get current session state
    local session_state="{}"
    if [ -f "$SESSION_FILE" ]; then
        session_state=$(cat "$SESSION_FILE")
    fi
    
    cat > "$checkpoint_file" << EOF
{
  "checkpoint_id": "$checkpoint_id",
  "name": "$name",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "session_state": $session_state,
  "project_path": "$PWD"
}
EOF

    # Update session with checkpoint
    if [ -f "$SESSION_FILE" ]; then
        jq --arg cp "$checkpoint_id" --arg name "$name" \
           '.checkpoints += [{id: $cp, name: $name, created_at: now | todate}]' \
           "$SESSION_FILE" > "${SESSION_FILE}.tmp" 2>/dev/null && \
        mv "${SESSION_FILE}.tmp" "$SESSION_FILE" || true
    fi
    
    echo "{\"status\": \"created\", \"checkpoint_id\": \"$checkpoint_id\", \"name\": \"$name\"}"
}

list_checkpoints() {
    if [ -d "$CHECKPOINT_DIR" ]; then
        echo "["
        FIRST=true
        for cp_file in "$CHECKPOINT_DIR"/*.json; do
            if [ -f "$cp_file" ]; then
                $FIRST || echo ","
                FIRST=false
                jq '{checkpoint_id, name, created_at}' "$cp_file"
            fi
        done
        echo "]"
    else
        echo "[]"
    fi
}

get_checkpoint() {
    local id_or_name=$1
    
    # First try by ID
    local cp_file="$CHECKPOINT_DIR/$id_or_name.json"
    if [ -f "$cp_file" ]; then
        cat "$cp_file"
        return
    fi
    
    # Then try by name
    for cp_file in "$CHECKPOINT_DIR"/*.json; do
        if [ -f "$cp_file" ]; then
            local name=$(jq -r '.name' "$cp_file")
            if [ "$name" = "$id_or_name" ]; then
                cat "$cp_file"
                return
            fi
        fi
    done
    
    echo "{\"error\": \"Checkpoint not found: $id_or_name\"}"
    exit 1
}

delete_checkpoint() {
    local id_or_name=$1
    
    # First try by ID
    local cp_file="$CHECKPOINT_DIR/$id_or_name.json"
    if [ -f "$cp_file" ]; then
        rm "$cp_file"
        echo "{\"status\": \"deleted\", \"checkpoint_id\": \"$id_or_name\"}"
        return
    fi
    
    # Then try by name
    for cp_file in "$CHECKPOINT_DIR"/*.json; do
        if [ -f "$cp_file" ]; then
            local name=$(jq -r '.name' "$cp_file")
            if [ "$name" = "$id_or_name" ]; then
                local id=$(jq -r '.checkpoint_id' "$cp_file")
                rm "$cp_file"
                echo "{\"status\": \"deleted\", \"checkpoint_id\": \"$id\", \"name\": \"$name\"}"
                return
            fi
        fi
    done
    
    echo "{\"error\": \"Checkpoint not found: $id_or_name\"}"
    exit 1
}

case "$ACTION" in
    "create")
        NAME=${NAME:-"checkpoint-$(date +%H%M%S)"}
        create_checkpoint "$NAME"
        ;;
    "list")
        list_checkpoints
        ;;
    "get")
        if [ -z "$NAME" ]; then
            echo "{\"error\": \"Checkpoint ID or name required\"}"
            exit 1
        fi
        get_checkpoint "$NAME"
        ;;
    "delete")
        if [ -z "$NAME" ]; then
            echo "{\"error\": \"Checkpoint ID or name required\"}"
            exit 1
        fi
        delete_checkpoint "$NAME"
        ;;
    *)
        echo "{\"error\": \"Unknown action. Use: create, list, get, delete\"}"
        exit 1
        ;;
esac
