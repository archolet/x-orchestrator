#!/bin/bash
# X-Orchestrator v3.1 - Telemetry Collector
# Collects token usage, cost, and analytics data

set -e

EVENT_TYPE=$1
shift
EVENT_DATA="${@:-{}}"

TELEMETRY_DIR="$HOME/.claude/x-orchestrator/telemetry"
DAILY_FILE="$TELEMETRY_DIR/daily/$(date +%Y-%m-%d).json"
SESSION_FILE="$PWD/.claude/x-state/telemetry.json"
CONFIG_FILE="$HOME/.claude/x-orchestrator/config.json"

mkdir -p "$TELEMETRY_DIR/daily"
mkdir -p "$TELEMETRY_DIR/sessions"

# Get pricing from config
INPUT_PRICE=$(jq -r '.telemetry.pricing.input_per_million // 5' "$CONFIG_FILE" 2>/dev/null || echo 5)
OUTPUT_PRICE=$(jq -r '.telemetry.pricing.output_per_million // 25' "$CONFIG_FILE" 2>/dev/null || echo 25)

# Initialize daily file if not exists
if [ ! -f "$DAILY_FILE" ]; then
    cat > "$DAILY_FILE" << EOF
{
  "date": "$(date +%Y-%m-%d)",
  "sessions": [],
  "totals": {
    "sessions_count": 0,
    "total_duration_minutes": 0,
    "total_tokens": 0,
    "input_tokens": 0,
    "output_tokens": 0,
    "total_cost_usd": 0,
    "by_command": {},
    "by_agent": {},
    "errors": 0,
    "rollbacks": 0
  }
}
EOF
fi

# Create event
EVENT_ID="evt-$(date +%Y%m%d%H%M%S)-$(openssl rand -hex 4)"
NOW=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)

# Validate JSON
if ! echo "$EVENT_DATA" | jq . > /dev/null 2>&1; then
    EVENT_DATA="{}"
fi

EVENT=$(cat << EOF
{
  "event_id": "$EVENT_ID",
  "event_type": "$EVENT_TYPE",
  "timestamp": "$NOW",
  "data": $EVENT_DATA
}
EOF
)

# Append to session telemetry
if [ -f "$SESSION_FILE" ]; then
    jq --argjson evt "$EVENT" '.events += [$evt]' "$SESSION_FILE" > "${SESSION_FILE}.tmp" 2>/dev/null && \
    mv "${SESSION_FILE}.tmp" "$SESSION_FILE" || true
fi

# Update based on event type
case "$EVENT_TYPE" in
    "agent_invoked")
        INPUT_TOKENS=$(echo "$EVENT_DATA" | jq -r '.input_tokens // 0')
        OUTPUT_TOKENS=$(echo "$EVENT_DATA" | jq -r '.output_tokens // 0')
        THINKING_TOKENS=$(echo "$EVENT_DATA" | jq -r '.thinking_tokens // 0')
        AGENT=$(echo "$EVENT_DATA" | jq -r '.agent // "unknown"')
        TOTAL_TOKENS=$((INPUT_TOKENS + OUTPUT_TOKENS + THINKING_TOKENS))

        # Calculate cost
        INPUT_COST=$(echo "scale=6; $INPUT_TOKENS / 1000000 * $INPUT_PRICE" | bc)
        OUTPUT_COST=$(echo "scale=6; $OUTPUT_TOKENS / 1000000 * $OUTPUT_PRICE" | bc)
        EVENT_COST=$(echo "scale=4; $INPUT_COST + $OUTPUT_COST" | bc)

        # Update session totals
        if [ -f "$SESSION_FILE" ]; then
            jq --argjson it "$INPUT_TOKENS" \
               --argjson ot "$OUTPUT_TOKENS" \
               --argjson tt "$THINKING_TOKENS" \
               --argjson total "$TOTAL_TOKENS" \
               --argjson cost "$EVENT_COST" \
               '
               .totals.input_tokens += $it |
               .totals.output_tokens += $ot |
               .totals.thinking_tokens += $tt |
               .totals.total_tokens += $total |
               .totals.estimated_cost_usd = ((.totals.estimated_cost_usd // 0) + $cost) |
               .totals.agents_invoked += 1
               ' "$SESSION_FILE" > "${SESSION_FILE}.tmp" 2>/dev/null && \
            mv "${SESSION_FILE}.tmp" "$SESSION_FILE" || true
        fi

        # Update daily by_agent
        jq --arg a "$AGENT" --argjson t "$TOTAL_TOKENS" \
           '
           .totals.total_tokens += $t |
           .totals.by_agent[$a] = ((.totals.by_agent[$a] // 0) + 1)
           ' "$DAILY_FILE" > "${DAILY_FILE}.tmp" 2>/dev/null && \
        mv "${DAILY_FILE}.tmp" "$DAILY_FILE" || true
        ;;

    "command_executed")
        CMD=$(echo "$EVENT_DATA" | jq -r '.command // "unknown"')

        # Update session
        if [ -f "$SESSION_FILE" ]; then
            jq '.totals.commands_executed += 1' "$SESSION_FILE" > "${SESSION_FILE}.tmp" 2>/dev/null && \
            mv "${SESSION_FILE}.tmp" "$SESSION_FILE" || true
        fi

        # Update daily by_command
        jq --arg c "$CMD" \
           '.totals.by_command[$c] = ((.totals.by_command[$c] // 0) + 1)' \
           "$DAILY_FILE" > "${DAILY_FILE}.tmp" 2>/dev/null && \
        mv "${DAILY_FILE}.tmp" "$DAILY_FILE" || true
        ;;

    "error_occurred")
        if [ -f "$SESSION_FILE" ]; then
            jq '.totals.errors += 1' "$SESSION_FILE" > "${SESSION_FILE}.tmp" 2>/dev/null && \
            mv "${SESSION_FILE}.tmp" "$SESSION_FILE" || true
        fi

        jq '.totals.errors += 1' "$DAILY_FILE" > "${DAILY_FILE}.tmp" 2>/dev/null && \
        mv "${DAILY_FILE}.tmp" "$DAILY_FILE" || true
        ;;

    "rollback_triggered")
        if [ -f "$SESSION_FILE" ]; then
            jq '.totals.rollbacks += 1' "$SESSION_FILE" > "${SESSION_FILE}.tmp" 2>/dev/null && \
            mv "${SESSION_FILE}.tmp" "$SESSION_FILE" || true
        fi

        jq '.totals.rollbacks += 1' "$DAILY_FILE" > "${DAILY_FILE}.tmp" 2>/dev/null && \
        mv "${DAILY_FILE}.tmp" "$DAILY_FILE" || true
        ;;

    "session_start")
        jq '.totals.sessions_count += 1' "$DAILY_FILE" > "${DAILY_FILE}.tmp" 2>/dev/null && \
        mv "${DAILY_FILE}.tmp" "$DAILY_FILE" || true
        ;;

    "session_end")
        DURATION=$(echo "$EVENT_DATA" | jq -r '.duration_minutes // 0')
        TOKENS=$(echo "$EVENT_DATA" | jq -r '.total_tokens // 0')
        COST=$(echo "$EVENT_DATA" | jq -r '.cost_usd // 0')

        jq --argjson d "$DURATION" --argjson t "$TOKENS" --argjson c "$COST" \
           '
           .totals.total_duration_minutes += $d |
           .totals.total_tokens += $t |
           .totals.total_cost_usd = ((.totals.total_cost_usd // 0) + $c)
           ' "$DAILY_FILE" > "${DAILY_FILE}.tmp" 2>/dev/null && \
        mv "${DAILY_FILE}.tmp" "$DAILY_FILE" || true
        ;;
esac

echo "{\"status\": \"recorded\", \"event_id\": \"$EVENT_ID\", \"event_type\": \"$EVENT_TYPE\"}"
