#!/bin/bash
# X-Orchestrator v3.1 - Error Handler
# Centralized error logging and recovery

set -e

ERROR_TYPE="$1"
ERROR_MESSAGE="$2"
ERROR_SOURCE="$3"

X_DIR="$HOME/.claude/x-orchestrator"
LOG_DIR="$X_DIR/logs"
LOG_FILE="$LOG_DIR/errors-$(date +%Y-%m-%d).log"
SESSION_FILE="$PWD/.claude/x-state/current-session.json"

mkdir -p "$LOG_DIR"

# Create error record
ERROR_ID="err-$(date +%Y%m%d%H%M%S)-$(openssl rand -hex 4)"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

ERROR_RECORD=$(cat << EOF
{
  "error_id": "$ERROR_ID",
  "timestamp": "$NOW",
  "type": "$ERROR_TYPE",
  "message": "$ERROR_MESSAGE",
  "source": "$ERROR_SOURCE",
  "project": "$PWD",
  "session_id": "$(jq -r '.session_id // "unknown"' "$SESSION_FILE" 2>/dev/null || echo 'unknown')"
}
EOF
)

# Append to log file
echo "$ERROR_RECORD" >> "$LOG_FILE"

# Record telemetry
if [ -f "$X_DIR/hooks/telemetry-collector.sh" ]; then
    "$X_DIR/hooks/telemetry-collector.sh" "error_occurred" "$ERROR_RECORD" 2>/dev/null || true
fi

# Handle specific error types
case "$ERROR_TYPE" in
    "mcp_failure")
        # Trigger circuit breaker
        if [ -f "$X_DIR/hooks/circuit-breaker.sh" ] && [ -n "$ERROR_SOURCE" ]; then
            "$X_DIR/hooks/circuit-breaker.sh" "$ERROR_SOURCE" "record_failure" "$ERROR_MESSAGE" 2>/dev/null || true
        fi
        ;;
    "disk_full")
        # Trigger cleanup
        if [ -f "$X_DIR/hooks/retention-cleanup.sh" ]; then
            "$X_DIR/hooks/retention-cleanup.sh" 2>/dev/null || true
        fi
        ;;
    "lock_conflict")
        # Log but don't retry automatically
        ;;
    *)
        # Generic error handling
        ;;
esac

echo "{\"status\": \"logged\", \"error_id\": \"$ERROR_ID\", \"type\": \"$ERROR_TYPE\"}"
