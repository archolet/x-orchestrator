#!/bin/bash
# X-Orchestrator v3.1 - Session End Hook
# Cleanup and telemetry finalization

set -e

# Directories
X_DIR="$HOME/.claude/x-orchestrator"
PROJECT_DIR="${PWD}"
X_STATE_DIR="$PROJECT_DIR/.claude/x-state"
USER_EMAIL=$(git config user.email 2>/dev/null || echo "unknown")

# Stop lock auto-renew
if [ -f "$X_STATE_DIR/lock-renew.pid" ]; then
    PID=$(cat "$X_STATE_DIR/lock-renew.pid")
    kill "$PID" 2>/dev/null || true
    rm -f "$X_STATE_DIR/lock-renew.pid"
fi

# Release lock
LOCK_FILE="$PROJECT_DIR/.claude/locks/$USER_EMAIL.lock"
if [ -f "$LOCK_FILE" ]; then
    rm -f "$LOCK_FILE"
fi

# Update session state
if [ -f "$X_STATE_DIR/current-session.json" ]; then
    SESSION_ID=$(jq -r '.session_id' "$X_STATE_DIR/current-session.json")
    STARTED_AT=$(jq -r '.started_at' "$X_STATE_DIR/current-session.json")

    # Calculate duration
    START_TS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$STARTED_AT" +%s 2>/dev/null || echo 0)
    NOW_TS=$(date +%s)
    DURATION_SECONDS=$((NOW_TS - START_TS))
    DURATION_MINUTES=$((DURATION_SECONDS / 60))

    # Update session to completed
    jq --arg end "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       --argjson dur "$DURATION_MINUTES" \
       '. + {status: "completed", ended_at: $end, duration_minutes: $dur}' \
       "$X_STATE_DIR/current-session.json" > "${X_STATE_DIR}/current-session.json.tmp"
    mv "${X_STATE_DIR}/current-session.json.tmp" "$X_STATE_DIR/current-session.json"

    # Save session to global storage
    PROJECT_HASH=$(echo "$PROJECT_DIR" | md5 | cut -c1-8)
    SESSION_DIR="$X_DIR/sessions/$PROJECT_HASH"
    mkdir -p "$SESSION_DIR"
    cp "$X_STATE_DIR/current-session.json" "$SESSION_DIR/$SESSION_ID.json"

    # Update telemetry totals
    if [ -f "$X_STATE_DIR/telemetry.json" ]; then
        jq --argjson dur "$DURATION_MINUTES" \
           '.totals.duration_minutes = $dur' \
           "$X_STATE_DIR/telemetry.json" > "${X_STATE_DIR}/telemetry.json.tmp"
        mv "${X_STATE_DIR}/telemetry.json.tmp" "$X_STATE_DIR/telemetry.json"

        # Copy telemetry to global storage
        mkdir -p "$X_DIR/telemetry/sessions"
        cp "$X_STATE_DIR/telemetry.json" "$X_DIR/telemetry/sessions/$SESSION_ID.json"
    fi

    # Record session_end event
    if [ -f "$X_DIR/hooks/telemetry-collector.sh" ]; then
        TOKENS=$(jq -r '.totals.total_tokens // 0' "$X_STATE_DIR/telemetry.json" 2>/dev/null || echo 0)
        COST=$(jq -r '.totals.estimated_cost_usd // 0' "$X_STATE_DIR/telemetry.json" 2>/dev/null || echo 0)
        "$X_DIR/hooks/telemetry-collector.sh" "session_end" "{\"session_id\": \"$SESSION_ID\", \"duration_minutes\": $DURATION_MINUTES, \"total_tokens\": $TOKENS, \"cost_usd\": $COST}" 2>/dev/null || true
    fi

    # Cleanup old rollback points (keep last 5)
    if [ -d "$X_STATE_DIR/rollback-points" ]; then
        ls -t "$X_STATE_DIR/rollback-points"/*.json 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true
    fi

    echo "{\"status\": \"completed\", \"session_id\": \"$SESSION_ID\", \"duration_minutes\": $DURATION_MINUTES}"
else
    echo "{\"status\": \"no_active_session\"}"
fi
