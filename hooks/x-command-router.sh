#!/bin/bash
# X-Orchestrator v3.1 - Command Router
# Routes /x:* commands to appropriate handlers

set -e

PROMPT="$1"
X_DIR="$HOME/.claude/x-orchestrator"

# Extract command from prompt
if [[ "$PROMPT" =~ ^/x:([a-z]+)(.*)$ ]]; then
    COMMAND="${BASH_REMATCH[1]}"
    ARGS="${BASH_REMATCH[2]}"
    ARGS=$(echo "$ARGS" | sed 's/^[[:space:]]*//')
else
    echo '{"error": "Invalid /x: command format"}'
    exit 1
fi

# Log command execution
if [ -f "$X_DIR/hooks/telemetry-collector.sh" ]; then
    "$X_DIR/hooks/telemetry-collector.sh" "command_executed" "{\"command\": \"/x:$COMMAND\", \"args\": \"$ARGS\"}" 2>/dev/null || true
fi

# Route to appropriate handler
case "$COMMAND" in
    "prompt")
        echo "{\"command\": \"prompt\", \"args\": \"$ARGS\", \"handler\": \"slash_command\", \"file\": \"~/.claude/commands/x/prompt.md\"}"
        ;;
    "save")
        echo "{\"command\": \"save\", \"args\": \"$ARGS\", \"handler\": \"slash_command\", \"file\": \"~/.claude/commands/x/save.md\"}"
        ;;
    "load")
        echo "{\"command\": \"load\", \"args\": \"$ARGS\", \"handler\": \"slash_command\", \"file\": \"~/.claude/commands/x/load.md\"}"
        ;;
    "index")
        echo "{\"command\": \"index\", \"args\": \"$ARGS\", \"handler\": \"slash_command\", \"file\": \"~/.claude/commands/x/index.md\"}"
        ;;
    "new")
        echo "{\"command\": \"new\", \"args\": \"$ARGS\", \"handler\": \"slash_command\", \"file\": \"~/.claude/commands/x/new.md\"}"
        ;;
    "checkpoint")
        echo "{\"command\": \"checkpoint\", \"args\": \"$ARGS\", \"handler\": \"slash_command\", \"file\": \"~/.claude/commands/x/checkpoint.md\"}"
        ;;
    "status")
        echo "{\"command\": \"status\", \"args\": \"$ARGS\", \"handler\": \"slash_command\", \"file\": \"~/.claude/commands/x/status.md\"}"
        ;;
    "rules")
        echo "{\"command\": \"rules\", \"args\": \"$ARGS\", \"handler\": \"slash_command\", \"file\": \"~/.claude/commands/x/rules.md\"}"
        ;;
    "rollback")
        echo "{\"command\": \"rollback\", \"args\": \"$ARGS\", \"handler\": \"slash_command\", \"file\": \"~/.claude/commands/x/rollback.md\"}"
        ;;
    "analytics")
        echo "{\"command\": \"analytics\", \"args\": \"$ARGS\", \"handler\": \"slash_command\", \"file\": \"~/.claude/commands/x/analytics.md\"}"
        ;;
    *)
        echo "{\"error\": \"Unknown command: /x:$COMMAND\", \"available\": [\"prompt\", \"save\", \"load\", \"index\", \"new\", \"checkpoint\", \"status\", \"rules\", \"rollback\", \"analytics\"]}"
        exit 1
        ;;
esac
