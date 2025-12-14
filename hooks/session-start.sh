#!/bin/bash
# X-Orchestrator v3.1 - Session Start Hook
# Lazy initialization for optimal performance

set -e

# Directories
X_DIR="$HOME/.claude/x-orchestrator"
CONFIG_FILE="$X_DIR/config.json"
PROJECT_DIR="${PWD}"
X_STATE_DIR="$PROJECT_DIR/.claude/x-state"

# Create project-level directories if needed
mkdir -p "$X_STATE_DIR"
mkdir -p "$X_STATE_DIR/rollback-points"
mkdir -p "$PROJECT_DIR/.claude/locks"
mkdir -p "$PROJECT_DIR/.claude/rules"

# Generate session ID
SESSION_ID="session-$(date +%Y%m%d%H%M%S)-$(openssl rand -hex 4)"
USER_EMAIL=$(git config user.email 2>/dev/null || echo "unknown")
PROJECT_HASH=$(echo "$PROJECT_DIR" | md5 | cut -c1-8)

# Initialize session state
cat > "$X_STATE_DIR/current-session.json" << EOF
{
  "session_id": "$SESSION_ID",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "user": "$USER_EMAIL",
  "project": "$PROJECT_DIR",
  "project_hash": "$PROJECT_HASH",
  "status": "active",
  "context_usage": 0,
  "checkpoints": [],
  "rollback_points": [],
  "last_activity": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# Initialize session telemetry
cat > "$X_STATE_DIR/telemetry.json" << EOF
{
  "session_id": "$SESSION_ID",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "project": "$PROJECT_DIR",
  "user": "$USER_EMAIL",
  "events": [],
  "totals": {
    "input_tokens": 0,
    "output_tokens": 0,
    "thinking_tokens": 0,
    "total_tokens": 0,
    "estimated_cost_usd": 0,
    "duration_minutes": 0,
    "commands_executed": 0,
    "agents_invoked": 0,
    "errors": 0,
    "rollbacks": 0
  }
}
EOF

# Initialize context map
if [ ! -f "$X_STATE_DIR/context-map.json" ]; then
    cat > "$X_STATE_DIR/context-map.json" << EOF
{
  "project": "$PROJECT_DIR",
  "last_indexed": null,
  "modules": [],
  "hot_files": [],
  "rules_applied": []
}
EOF
fi

# Acquire lock
LOCK_FILE="$PROJECT_DIR/.claude/locks/$USER_EMAIL.lock"
if [ -f "$LOCK_FILE" ]; then
    EXISTING_USER=$(jq -r '.user' "$LOCK_FILE" 2>/dev/null || echo "")
    EXPIRES=$(jq -r '.expires_at' "$LOCK_FILE" 2>/dev/null || echo "")
    NOW=$(date +%s)
    EXPIRES_TS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$EXPIRES" +%s 2>/dev/null || echo 0)

    if [ "$EXPIRES_TS" -gt "$NOW" ] && [ "$EXISTING_USER" != "$USER_EMAIL" ]; then
        echo "{\"error\": \"Project locked by $EXISTING_USER until $EXPIRES\"}"
        exit 1
    fi
fi

# Create/update lock
LOCK_EXPIRES=$(date -u -v+1H +%Y-%m-%dT%H:%M:%SZ)
cat > "$LOCK_FILE" << EOF
{
  "user": "$USER_EMAIL",
  "acquired_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "expires_at": "$LOCK_EXPIRES",
  "session_id": "$SESSION_ID",
  "operation": "session"
}
EOF

# Start lock auto-renew in background
if [ -f "$X_DIR/hooks/lock-auto-renew.sh" ]; then
    nohup "$X_DIR/hooks/lock-auto-renew.sh" > /dev/null 2>&1 &
    echo $! > "$X_STATE_DIR/lock-renew.pid"
fi

# Run parallel health check
HEALTH_RESULT=""
if [ -f "$X_DIR/hooks/mcp-health-check-parallel.sh" ]; then
    HEALTH_RESULT=$("$X_DIR/hooks/mcp-health-check-parallel.sh" 2>/dev/null || echo '{"overall": "unknown"}')
fi

# Record telemetry event
if [ -f "$X_DIR/hooks/telemetry-collector.sh" ]; then
    "$X_DIR/hooks/telemetry-collector.sh" "session_start" "{\"session_id\": \"$SESSION_ID\", \"user\": \"$USER_EMAIL\"}" 2>/dev/null || true
fi

# Output session info
cat << EOF
{
  "status": "initialized",
  "session_id": "$SESSION_ID",
  "project": "$PROJECT_DIR",
  "user": "$USER_EMAIL",
  "lock_expires": "$LOCK_EXPIRES",
  "health": $HEALTH_RESULT,
  "message": "X-Orchestrator v3.1 session started"
}
EOF
