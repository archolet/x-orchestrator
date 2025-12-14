#!/bin/bash
# X-Orchestrator v3.1 - Disk Monitor
# Monitors disk space and triggers alerts

set -e

X_DIR="$HOME/.claude/x-orchestrator"
CONFIG_FILE="$X_DIR/config.json"

# Get thresholds from config
WARN_MB=$(jq -r '.disk_monitoring.warn_threshold_mb // 500' "$CONFIG_FILE" 2>/dev/null || echo 500)
CRITICAL_MB=$(jq -r '.disk_monitoring.critical_threshold_mb // 1000' "$CONFIG_FILE" 2>/dev/null || echo 1000)

# Get X-Orchestrator directory size
X_DIR_SIZE_KB=$(du -sk "$X_DIR" 2>/dev/null | cut -f1)
X_DIR_SIZE_MB=$((X_DIR_SIZE_KB / 1024))

# Get available disk space
AVAILABLE_KB=$(df -k "$X_DIR" | tail -1 | awk '{print $4}')
AVAILABLE_MB=$((AVAILABLE_KB / 1024))

# Determine status
if [ $X_DIR_SIZE_MB -ge $CRITICAL_MB ]; then
    STATUS="critical"
    ACTION="cleanup_required"
    
    # Trigger cleanup
    if [ -f "$X_DIR/hooks/retention-cleanup.sh" ]; then
        "$X_DIR/hooks/retention-cleanup.sh" 2>/dev/null || true
    fi
elif [ $X_DIR_SIZE_MB -ge $WARN_MB ]; then
    STATUS="warning"
    ACTION="cleanup_recommended"
else
    STATUS="ok"
    ACTION="none"
fi

cat << EOF
{
  "status": "$STATUS",
  "x_orchestrator_size_mb": $X_DIR_SIZE_MB,
  "available_disk_mb": $AVAILABLE_MB,
  "thresholds": {
    "warn_mb": $WARN_MB,
    "critical_mb": $CRITICAL_MB
  },
  "action": "$ACTION"
}
EOF
