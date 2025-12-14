#!/bin/bash
# X-Orchestrator v3.1 - Circuit Breaker Pattern
# Handles MCP failure tolerance

set -e

MCP_NAME=$1
ACTION=$2
ERROR_MSG=${3:-"unknown_error"}

CB_DIR="$HOME/.claude/x-orchestrator/circuit-breaker"
CB_FILE="$CB_DIR/$MCP_NAME.json"
CONFIG_FILE="$HOME/.claude/x-orchestrator/config.json"

mkdir -p "$CB_DIR"

# Get config values
get_config() {
    local key=$1
    local default=$2
    if [ -f "$CONFIG_FILE" ]; then
        local value=$(jq -r "$key // \"$default\"" "$CONFIG_FILE" 2>/dev/null)
        if [ "$value" = "null" ] || [ -z "$value" ]; then
            echo "$default"
        else
            echo "$value"
        fi
    else
        echo "$default"
    fi
}

FAILURE_THRESHOLD=$(get_config ".circuit_breaker.per_mcp.$MCP_NAME.failure_threshold // .circuit_breaker.default.failure_threshold" "3")
TIMEOUT_SECONDS=$(get_config ".circuit_breaker.per_mcp.$MCP_NAME.timeout_seconds // .circuit_breaker.default.timeout_seconds" "30")
SUCCESS_THRESHOLD=$(get_config ".circuit_breaker.default.success_threshold" "2")

# Initialize if not exists
if [ ! -f "$CB_FILE" ]; then
    cat > "$CB_FILE" << EOF
{
  "mcp": "$MCP_NAME",
  "state": "closed",
  "failure_count": 0,
  "success_count": 0,
  "last_failure": null,
  "last_success": null,
  "opened_at": null,
  "half_opened_at": null,
  "recent_errors": []
}
EOF
fi

get_state() {
    local state=$(jq -r '.state' "$CB_FILE")
    local opened_at=$(jq -r '.opened_at // ""' "$CB_FILE")
    local now=$(date +%s)

    if [ "$state" = "open" ] && [ -n "$opened_at" ] && [ "$opened_at" != "null" ]; then
        local opened_ts=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$opened_at" +%s 2>/dev/null || echo 0)
        local elapsed=$((now - opened_ts))

        if [ $elapsed -ge $TIMEOUT_SECONDS ]; then
            # Transition to half-open
            jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
               '. + {state: "half_open", half_opened_at: $now, success_count: 0}' \
               "$CB_FILE" > "${CB_FILE}.tmp" && mv "${CB_FILE}.tmp" "$CB_FILE"
            echo "half_open"
            return
        fi
    fi

    echo "$state"
}

check_allowed() {
    local state=$(get_state)

    case "$state" in
        "closed")
            echo '{"allowed": true, "state": "closed"}'
            ;;
        "open")
            local opened_at=$(jq -r '.opened_at' "$CB_FILE")
            echo "{\"allowed\": false, \"state\": \"open\", \"opened_at\": \"$opened_at\", \"timeout_seconds\": $TIMEOUT_SECONDS}"
            ;;
        "half_open")
            echo '{"allowed": true, "state": "half_open", "warning": "Circuit is testing"}'
            ;;
    esac
}

record_success() {
    local state=$(get_state)
    local now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    if [ "$state" = "half_open" ]; then
        local success_count=$(jq -r '.success_count // 0' "$CB_FILE")
        success_count=$((success_count + 1))

        if [ $success_count -ge $SUCCESS_THRESHOLD ]; then
            # Close the circuit
            jq --arg now "$now" \
               '. + {state: "closed", failure_count: 0, success_count: 0, last_success: $now, opened_at: null, half_opened_at: null}' \
               "$CB_FILE" > "${CB_FILE}.tmp" && mv "${CB_FILE}.tmp" "$CB_FILE"
            echo '{"action": "closed", "message": "Circuit recovered"}'
        else
            jq --argjson sc "$success_count" --arg now "$now" \
               '. + {success_count: $sc, last_success: $now}' \
               "$CB_FILE" > "${CB_FILE}.tmp" && mv "${CB_FILE}.tmp" "$CB_FILE"
            echo "{\"action\": \"testing\", \"success_count\": $success_count, \"threshold\": $SUCCESS_THRESHOLD}"
        fi
    else
        # Reset failure count on success in closed state
        jq --arg now "$now" \
           '. + {failure_count: 0, last_success: $now}' \
           "$CB_FILE" > "${CB_FILE}.tmp" && mv "${CB_FILE}.tmp" "$CB_FILE"
        echo '{"action": "success"}'
    fi
}

record_failure() {
    local state=$(get_state)
    local now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local failure_count=$(jq -r '.failure_count // 0' "$CB_FILE")
    failure_count=$((failure_count + 1))

    if [ "$state" = "half_open" ] || [ $failure_count -ge $FAILURE_THRESHOLD ]; then
        # Open the circuit
        jq --arg now "$now" \
           --arg err "$ERROR_MSG" \
           --argjson fc "$failure_count" \
           '. + {
             state: "open",
             failure_count: $fc,
             opened_at: $now,
             last_failure: $now,
             success_count: 0,
             recent_errors: ((.recent_errors // [])[-9:] + [{timestamp: $now, error: $err}])
           }' \
           "$CB_FILE" > "${CB_FILE}.tmp" && mv "${CB_FILE}.tmp" "$CB_FILE"
        echo "{\"action\": \"opened\", \"failure_count\": $failure_count, \"message\": \"Circuit opened due to failures\"}"
    else
        jq --arg now "$now" \
           --arg err "$ERROR_MSG" \
           --argjson fc "$failure_count" \
           '. + {
             failure_count: $fc,
             last_failure: $now,
             recent_errors: ((.recent_errors // [])[-9:] + [{timestamp: $now, error: $err}])
           }' \
           "$CB_FILE" > "${CB_FILE}.tmp" && mv "${CB_FILE}.tmp" "$CB_FILE"
        echo "{\"action\": \"recorded\", \"failure_count\": $failure_count, \"threshold\": $FAILURE_THRESHOLD}"
    fi
}

reset_circuit() {
    cat > "$CB_FILE" << EOF
{
  "mcp": "$MCP_NAME",
  "state": "closed",
  "failure_count": 0,
  "success_count": 0,
  "last_failure": null,
  "last_success": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "opened_at": null,
  "half_opened_at": null,
  "recent_errors": []
}
EOF
    echo '{"action": "reset", "state": "closed"}'
}

case "$ACTION" in
    "check")
        check_allowed
        ;;
    "record_success")
        record_success
        ;;
    "record_failure")
        record_failure
        ;;
    "get_state")
        get_state
        ;;
    "reset")
        reset_circuit
        ;;
    "status")
        cat "$CB_FILE"
        ;;
    *)
        echo '{"error": "Unknown action. Use: check, record_success, record_failure, get_state, reset, status"}'
        exit 1
        ;;
esac
