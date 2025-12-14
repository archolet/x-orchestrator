# X-Orchestrator v3.1

> Enterprise-grade orchestration system for Claude Code 2.0.69+

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-2.0.69+-blue.svg)](https://claude.ai/claude-code)
[![Model](https://img.shields.io/badge/Model-Opus%204.5-purple.svg)](https://anthropic.com)

## Features

- **Always Opus 4.5 Strategy** - 35% cost savings with optimal model selection
- **Circuit Breaker Pattern** - MCP fault tolerance with automatic recovery
- **4-Agent Architecture** - Specialized agents for analysis, planning, coding, and review
- **Session Persistence** - Save and restore work sessions
- **Checkpoint & Rollback** - Auto-checkpoint before file modifications
- **Telemetry & Analytics** - Token usage and cost tracking
- **Rules Library** - Pre-built architecture and design patterns
- **Project Templates** - Scaffolding for .NET, Angular, Python, Java, Flutter

## Installation

```bash
# Clone the repository
git clone https://github.com/archolet/x-orchestrator.git

# Copy to Claude Code config directory
cp -r x-orchestrator ~/.claude/x-orchestrator
cp -r commands ~/.claude/commands
cp -r agents/*.md ~/.claude/agents/

# Make hooks executable
chmod +x ~/.claude/x-orchestrator/hooks/*.sh

# Copy settings (or merge with existing)
cp settings.json ~/.claude/settings.json
```

## Commands

| Command | Description |
|---------|-------------|
| `/x:prompt <request>` | Intelligent task orchestration with 7-phase execution |
| `/x:status [--health\|--session\|--locks]` | System status and health check |
| `/x:save [message]` | Save current session |
| `/x:load [session-id\|latest]` | Restore a saved session |
| `/x:index [--deep\|--update]` | Analyze project structure |
| `/x:new <template> [name]` | Scaffold new project |
| `/x:checkpoint [name]` | Create manual checkpoint |
| `/x:rollback [point-id\|latest]` | Restore previous state |
| `/x:rules <add\|list\|sync>` | Manage rules library |
| `/x:analytics [--daily\|--session\|--cost]` | View telemetry data |

## Agents

| Agent | Purpose | Tools |
|-------|---------|-------|
| `x-prompt-analyzer` | Analyze prompts for ambiguity and scope | Read, Grep, Glob |
| `x-plan-creator` | Create detailed execution plans | Read, Grep, Glob, Task |
| `x-code-generator` | Implement code following best practices | Read, Write, Edit, Bash, Grep, Glob, Task |
| `x-reviewer` | Review code with scoring (A-F) | Read, Grep, Glob |

## Rules Library

### Architecture
- `clean-arch.md` - Clean Architecture
- `ddd.md` - Domain-Driven Design
- `hexagonal.md` - Hexagonal (Ports & Adapters)
- `cqrs.md` - Command Query Responsibility Segregation

### Principles
- `solid.md` - SOLID Principles
- `dry-kiss.md` - DRY & KISS

### Patterns
- `repository.md` - Repository Pattern
- `unit-of-work.md` - Unit of Work Pattern
- `mediator.md` - Mediator Pattern

## Templates

| Template | Description |
|----------|-------------|
| `dotnet` | .NET 8+ Clean Architecture |
| `angular` | Angular 17+ Enterprise with NgRx |
| `python` | FastAPI Clean Architecture |
| `java` | Spring Boot Hexagonal |
| `flutter` | Flutter Clean + BLoC |

## Architecture

```
~/.claude/
├── x-orchestrator/
│   ├── config.json           # System configuration
│   ├── version.json          # Version tracking
│   ├── hooks/                # Lifecycle scripts (15 files)
│   ├── rules-library/        # Architecture patterns
│   │   ├── architecture/
│   │   ├── principles/
│   │   └── patterns/
│   ├── templates/            # Project scaffolding
│   ├── sessions/             # Saved sessions
│   ├── telemetry/            # Usage analytics
│   └── circuit-breaker/      # MCP state files
├── commands/x/               # Slash commands (10 files)
├── agents/                   # Agent definitions (4 files)
└── settings.json             # Global hooks config
```

## Requirements

- Claude Code 2.0.69+
- macOS / Linux
- Bash 4.0+
- jq (for JSON processing)

## License

MIT License - see [LICENSE](LICENSE) for details.

---

Built with Claude Opus 4.5
