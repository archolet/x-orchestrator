#!/bin/bash
# X-Orchestrator v3.1 - Subagent Complete Hook
# Handles agent completion events (async)

set -e

AGENT_NAME="$1"
RESULT_FILE="$2"

X_DIR="$HOME/.claude/x-orchestrator"
SESSION_FILE="$PWD/.claude/x-state/current-session.json"

# Parse result if provided
INPUT_TOKENS=0
OUTPUT_TOKENS=0
THINKING_TOKENS=0
DURATION_MS=0
SUCCESS=true

if [ -n "$RESULT_FILE" ] && [ -f "$RESULT_FILE" ]; then
    INPUT_TOKENS=$(jq -r '.input_tokens // 0' "$RESULT_FILE" 2>/dev/null || echo 0)
    OUTPUT_TOKENS=$(jq -r '.output_tokens // 0' "$RESULT_FILE" 2>/dev/null || echo 0)
    THINKING_TOKENS=$(jq -r '.thinking_tokens // 0' "$RESULT_FILE" 2>/dev/null || echo 0)
    DURATION_MS=$(jq -r '.duration_ms // 0' "$RESULT_FILE" 2>/dev/null || echo 0)
    SUCCESS=$(jq -r '.success // true' "$RESULT_FILE" 2>/dev/null || echo true)
fi

# Record telemetry
if [ -f "$X_DIR/hooks/telemetry-collector.sh" ]; then
    "$X_DIR/hooks/telemetry-collector.sh" "agent_invoked" "{
        \"agent\": \"$AGENT_NAME\",
        \"input_tokens\": $INPUT_TOKENS,
        \"output_tokens\": $OUTPUT_TOKENS,
        \"thinking_tokens\": $THINKING_TOKENS,
        \"duration_ms\": $DURATION_MS,
        \"success\": $SUCCESS
    }" 2>/dev/null || true
fi

# Update session state
if [ -f "$SESSION_FILE" ]; then
    jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       '.last_activity = $now' \
       "$SESSION_FILE" > "${SESSION_FILE}.tmp" 2>/dev/null && \
    mv "${SESSION_FILE}.tmp" "$SESSION_FILE" || true
fi

echo "{\"status\": \"recorded\", \"agent\": \"$AGENT_NAME\"}"
