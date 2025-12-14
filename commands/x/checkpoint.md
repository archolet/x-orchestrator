---
description: Manuel checkpoint oluştur
allowed-tools: Read, Bash
argument-hint: [isim]
model: opus
---

# X-Orchestrator: Manuel Checkpoint

Mevcut durumun manuel checkpoint'ini oluşturur. Rollback için kullanılabilir.

## Argümanlar
$ARGUMENTS

- `[isim]`: Checkpoint adı (opsiyonel, default: timestamp)

## Checkpoint İşlemi

### 1. Checkpoint Oluştur

```bash
~/.claude/x-orchestrator/hooks/checkpoint-manager.sh create "$CHECKPOINT_NAME"
```

### 2. Checkpoint Metadata

```json
{
  "checkpoint_id": "cp-20251214-abc123",
  "name": "Pre-refactor",
  "created_at": "2025-12-14T14:30:00Z",
  "project": "/path/to/project",
  "session_id": "session-xxx",
  "description": "Manuel checkpoint: Pre-refactor"
}
```

### 3. Output

```
╔══════════════════════════════════════════════════════════════╗
║               CHECKPOINT CREATED                             ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  🔖 ID: cp-20251214-abc123                                  ║
║  📝 İsim: Pre-refactor                                      ║
║  🕐 Zaman: 14:30:00                                         ║
║                                                              ║
║  💡 Rollback için: /x:rollback cp-20251214-abc123           ║
╚══════════════════════════════════════════════════════════════╝
```

## Checkpoint Listeleme

İsim yerine `--list` kullanılırsa:

```bash
~/.claude/x-orchestrator/hooks/checkpoint-manager.sh list
```

```
╔══════════════════════════════════════════════════════════════╗
║               CHECKPOINTS                                    ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  # │ ID                    │ İsim          │ Zaman          ║
║────┼───────────────────────┼───────────────┼────────────────║
║  1 │ cp-20251214-abc123    │ Pre-refactor  │ 14:30          ║
║  2 │ cp-20251214-def456    │ After-auth    │ 14:45          ║
║  3 │ cp-20251214-ghi789    │ Final         │ 15:00          ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

## Otomatik Checkpoints

Pre-write guard her önemli dosya değişikliğinden önce otomatik rollback point oluşturur.
Manuel checkpoint'ler bunlardan farklıdır:
- İsimlendirilmiş
- Session'a bağlı
- Daha uzun retention (7 gün)
