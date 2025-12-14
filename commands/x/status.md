---
description: X-Orchestrator durumunu görüntüle
allowed-tools: Read, Bash
argument-hint: [--health|--session|--locks]
model: opus
---

# X-Orchestrator: Durum Görüntüleme

Orchestrator'ın genel durumunu, MCP health'ini ve session bilgilerini gösterir.

## Argümanlar
$ARGUMENTS

- Boş: Genel özet
- `--health`: Detaylı MCP health check
- `--session`: Detaylı session bilgisi
- `--locks`: Lock durumları

## Genel Özet (Default)

### 1. Sistem Bilgilerini Topla

```bash
# Version
VERSION=$(jq -r '.current_version' ~/.claude/x-orchestrator/version.json)

# Health check
HEALTH=$(~/.claude/x-orchestrator/hooks/mcp-health-check-parallel.sh)

# Session
SESSION=$(cat .claude/x-state/current-session.json 2>/dev/null || echo '{}')

# Disk
DISK=$(~/.claude/x-orchestrator/hooks/disk-monitor.sh)
```

### 2. Output

```
╔══════════════════════════════════════════════════════════════╗
║               X-ORCHESTRATOR STATUS v3.1                     ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  🔧 SYSTEM                                                   ║
║  ├── Version: 3.1.0                                         ║
║  ├── Model: Opus 4.5                                        ║
║  └── Mode: Full (tüm MCP'ler aktif)                         ║
║                                                              ║
║  🌐 MCP HEALTH                                               ║
║  ├── Serena:     ✅ Connected                               ║
║  ├── Context7:   ✅ Connected                               ║
║  ├── mem0:       ✅ Connected                               ║
║  ├── Tavily:     ✅ Connected                               ║
║  ├── GitHub:     ⚠️  Circuit Half-Open                      ║
║  └── Sequential: ✅ Connected                               ║
║                                                              ║
║  📊 SESSION                                                  ║
║  ├── ID: session-20251214-abc123                            ║
║  ├── Süre: 45 dakika                                        ║
║  ├── Komutlar: 5                                            ║
║  ├── Checkpoints: 3                                         ║
║  └── Token: ~50,000                                         ║
║                                                              ║
║  💾 DISK                                                     ║
║  ├── Kullanım: 125 MB                                       ║
║  └── Durum: OK                                              ║
║                                                              ║
║  🔒 LOCK                                                     ║
║  └── Owner: developer@company.com (siz)                     ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

## --health Flag'i

Detaylı MCP health check:

```
╔══════════════════════════════════════════════════════════════╗
║                    MCP HEALTH DETAILS                        ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  SERENA                                                      ║
║  ├── Status: Connected                                      ║
║  ├── Circuit: Closed                                        ║
║  ├── Failures: 0                                            ║
║  └── Last Success: 2 dakika önce                            ║
║                                                              ║
║  GITHUB                                                      ║
║  ├── Status: Testing                                        ║
║  ├── Circuit: Half-Open                                     ║
║  ├── Failures: 3 (threshold: 5)                             ║
║  ├── Last Failure: rate_limit_exceeded                      ║
║  └── Next Retry: 30 saniye                                  ║
║                                                              ║
║  [Diğer MCP'ler...]                                         ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

## --session Flag'i

Detaylı session bilgisi:

```
╔══════════════════════════════════════════════════════════════╗
║                    SESSION DETAILS                           ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  📋 GENEL                                                    ║
║  ├── Session ID: session-20251214-abc123                    ║
║  ├── Başlangıç: 14:30:00                                    ║
║  ├── Süre: 45 dakika                                        ║
║  └── Status: Active                                         ║
║                                                              ║
║  📊 TELEMETRİ                                                ║
║  ├── Input Tokens: 35,000                                   ║
║  ├── Output Tokens: 12,000                                  ║
║  ├── Thinking Tokens: 25,000                                ║
║  ├── Toplam: 72,000                                         ║
║  └── Tahmini Maliyet: $2.15                                 ║
║                                                              ║
║  🔄 CHECKPOINTS                                              ║
║  ├── cp-1: Pre-auth-changes (14:35)                         ║
║  ├── cp-2: User-model-update (14:42)                        ║
║  └── cp-3: Service-refactor (14:50)                         ║
║                                                              ║
║  📝 SON İŞLEMLER                                             ║
║  ├── /x:prompt Auth refactor                                ║
║  ├── /x:checkpoint Pre-test                                 ║
║  └── /x:save Auth work                                      ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

## --locks Flag'i

Lock durumları:

```
╔══════════════════════════════════════════════════════════════╗
║                    LOCK STATUS                               ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  🔒 CURRENT LOCK                                             ║
║  ├── Owner: developer@company.com                           ║
║  ├── Acquired: 14:30:00                                     ║
║  ├── Expires: 15:30:00                                      ║
║  ├── Session: session-20251214-abc123                       ║
║  └── Auto-Renew: Active                                     ║
║                                                              ║
║  ℹ️  Lock size olmadan çalışılabilir: /x:unlock --force     ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```
