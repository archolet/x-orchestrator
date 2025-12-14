#!/bin/bash
# X-Orchestrator v3.1 - Retention Cleanup
# Cleans up old data based on retention policy

set -e

X_DIR="$HOME/.claude/x-orchestrator"
CONFIG_FILE="$X_DIR/config.json"

# Get retention settings from config
SESSIONS_DAYS=$(jq -r '.retention.sessions_days // 30' "$CONFIG_FILE" 2>/dev/null || echo 30)
ROLLBACK_DAYS=$(jq -r '.retention.rollback_points_days // 7' "$CONFIG_FILE" 2>/dev/null || echo 7)
ERROR_LOGS_DAYS=$(jq -r '.retention.error_logs_days // 90' "$CONFIG_FILE" 2>/dev/null || echo 90)
TELEMETRY_DAYS=$(jq -r '.retention.telemetry_daily_days // 365' "$CONFIG_FILE" 2>/dev/null || echo 365)
CIRCUIT_BREAKER_HOURS=$(jq -r '.retention.circuit_breaker_hours // 24' "$CONFIG_FILE" 2>/dev/null || echo 24)

DELETED_COUNT=0

# Clean old sessions
if [ -d "$X_DIR/sessions" ]; then
    DELETED=$(find "$X_DIR/sessions" -type f -name "*.json" -mtime +$SESSIONS_DAYS -delete -print | wc -l)
    DELETED_COUNT=$((DELETED_COUNT + DELETED))
fi

# Clean old telemetry (daily)
if [ -d "$X_DIR/telemetry/daily" ]; then
    DELETED=$(find "$X_DIR/telemetry/daily" -type f -name "*.json" -mtime +$TELEMETRY_DAYS -delete -print | wc -l)
    DELETED_COUNT=$((DELETED_COUNT + DELETED))
fi

# Clean old telemetry (sessions)
if [ -d "$X_DIR/telemetry/sessions" ]; then
    DELETED=$(find "$X_DIR/telemetry/sessions" -type f -name "*.json" -mtime +$SESSIONS_DAYS -delete -print | wc -l)
    DELETED_COUNT=$((DELETED_COUNT + DELETED))
fi

# Clean old error logs
if [ -d "$X_DIR/logs" ]; then
    DELETED=$(find "$X_DIR/logs" -type f -name "*.log" -mtime +$ERROR_LOGS_DAYS -delete -print | wc -l)
    DELETED_COUNT=$((DELETED_COUNT + DELETED))
fi

# Clean old circuit breaker states
if [ -d "$X_DIR/circuit-breaker" ]; then
    DELETED=$(find "$X_DIR/circuit-breaker" -type f -name "*.json" -mmin +$((CIRCUIT_BREAKER_HOURS * 60)) -delete -print | wc -l)
    DELETED_COUNT=$((DELETED_COUNT + DELETED))
fi

echo "{
  \"status\": \"completed\",
  \"deleted_files\": $DELETED_COUNT,
  \"retention_policy\": {
    \"sessions_days\": $SESSIONS_DAYS,
    \"rollback_days\": $ROLLBACK_DAYS,
    \"error_logs_days\": $ERROR_LOGS_DAYS,
    \"telemetry_days\": $TELEMETRY_DAYS,
    \"circuit_breaker_hours\": $CIRCUIT_BREAKER_HOURS
  }
}"
