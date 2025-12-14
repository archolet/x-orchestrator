#!/bin/bash
# X-Orchestrator v3.1 - Lock Auto-Renew
# Background process that renews locks every 5 minutes

set -e

PROJECT_DIR="$PWD"
USER_EMAIL=$(git config user.email 2>/dev/null || echo "unknown")
LOCK_FILE="$PROJECT_DIR/.claude/locks/$USER_EMAIL.lock"
RENEW_INTERVAL=300  # 5 minutes

while true; do
    sleep $RENEW_INTERVAL
    
    if [ -f "$LOCK_FILE" ]; then
        # Check if this is our lock
        LOCK_USER=$(jq -r '.user' "$LOCK_FILE" 2>/dev/null || echo "")
        
        if [ "$LOCK_USER" = "$USER_EMAIL" ]; then
            # Renew the lock
            NEW_EXPIRES=$(date -u -v+1H +%Y-%m-%dT%H:%M:%SZ)
            jq --arg exp "$NEW_EXPIRES" '.expires_at = $exp' "$LOCK_FILE" > "${LOCK_FILE}.tmp" 2>/dev/null && \
            mv "${LOCK_FILE}.tmp" "$LOCK_FILE" || true
        else
            # Lock taken by someone else, exit
            exit 0
        fi
    else
        # Lock file removed, exit
        exit 0
    fi
done
