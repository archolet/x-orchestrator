#!/bin/bash
# X-Orchestrator v3.1 - Context Manager
# Manages hot files and context map

set -e

ACTION="$1"
FILE_PATH="$2"

X_STATE_DIR="$PWD/.claude/x-state"
CONTEXT_FILE="$X_STATE_DIR/context-map.json"
MAX_HOT_FILES=20
DECAY_FACTOR=0.9

mkdir -p "$X_STATE_DIR"

# Initialize context file if not exists
if [ ! -f "$CONTEXT_FILE" ]; then
    cat > "$CONTEXT_FILE" << EOF
{
  "project": "$PWD",
  "last_indexed": null,
  "modules": [],
  "hot_files": [],
  "rules_applied": []
}
EOF
fi

add_hot_file() {
    local file=$1
    local now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Check if file already in hot files
    local exists=$(jq -r --arg f "$file" '.hot_files | map(select(.path == $f)) | length' "$CONTEXT_FILE")
    
    if [ "$exists" -gt 0 ]; then
        # Increment access count
        jq --arg f "$file" --arg now "$now" '
            .hot_files = [.hot_files[] | if .path == $f then .access_count += 1 | .last_accessed = $now else . end]
        ' "$CONTEXT_FILE" > "${CONTEXT_FILE}.tmp" && mv "${CONTEXT_FILE}.tmp" "$CONTEXT_FILE"
    else
        # Add new hot file
        jq --arg f "$file" --arg now "$now" '
            .hot_files += [{path: $f, access_count: 1, last_accessed: $now, added_at: $now}]
        ' "$CONTEXT_FILE" > "${CONTEXT_FILE}.tmp" && mv "${CONTEXT_FILE}.tmp" "$CONTEXT_FILE"
    fi
    
    # Limit hot files count
    jq --argjson max "$MAX_HOT_FILES" '
        .hot_files = (.hot_files | sort_by(-.access_count) | .[:$max])
    ' "$CONTEXT_FILE" > "${CONTEXT_FILE}.tmp" && mv "${CONTEXT_FILE}.tmp" "$CONTEXT_FILE"
    
    echo "{\"status\": \"added\", \"file\": \"$file\"}"
}

get_hot_files() {
    jq '.hot_files | sort_by(-.access_count)' "$CONTEXT_FILE"
}

decay_scores() {
    jq --argjson decay "$DECAY_FACTOR" '
        .hot_files = [.hot_files[] | .access_count = (.access_count * $decay | floor)]
        | .hot_files = [.hot_files[] | select(.access_count > 0)]
    ' "$CONTEXT_FILE" > "${CONTEXT_FILE}.tmp" && mv "${CONTEXT_FILE}.tmp" "$CONTEXT_FILE"
    
    echo "{\"status\": \"decayed\", \"decay_factor\": $DECAY_FACTOR}"
}

clear_hot_files() {
    jq '.hot_files = []' "$CONTEXT_FILE" > "${CONTEXT_FILE}.tmp" && mv "${CONTEXT_FILE}.tmp" "$CONTEXT_FILE"
    echo "{\"status\": \"cleared\"}"
}

get_context() {
    cat "$CONTEXT_FILE"
}

case "$ACTION" in
    "add")
        if [ -z "$FILE_PATH" ]; then
            echo "{\"error\": \"File path required\"}"
            exit 1
        fi
        add_hot_file "$FILE_PATH"
        ;;
    "get_hot")
        get_hot_files
        ;;
    "decay")
        decay_scores
        ;;
    "clear")
        clear_hot_files
        ;;
    "context")
        get_context
        ;;
    *)
        echo "{\"error\": \"Unknown action. Use: add, get_hot, decay, clear, context\"}"
        exit 1
        ;;
esac
