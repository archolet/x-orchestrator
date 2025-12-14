---
description: Önceki duruma geri dön
allowed-tools: Read, Bash
argument-hint: [point-id|latest] [--list]
model: opus
---

# X-Orchestrator: Rollback

Önceki checkpoint veya rollback point'e geri döner.

## Argümanlar
$ARGUMENTS

- `[point-id]`: Belirli bir rollback point
- `latest`: En son rollback point'e dön
- `--list`: Mevcut rollback point'leri listele

## Rollback Points vs Checkpoints

| Tip | Oluşum | Retention | Kullanım |
|-----|--------|-----------|----------|
| Rollback Point | Otomatik (pre-write) | 7 gün | Dosya bazlı restore |
| Checkpoint | Manuel (/x:checkpoint) | 7 gün | İsimlendirilmiş noktalar |

## --list Flag'i

```bash
~/.claude/x-orchestrator/hooks/rollback-engine.sh list
```

```
╔══════════════════════════════════════════════════════════════╗
║               ROLLBACK POINTS                                ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  🔄 ROLLBACK POINTS (Otomatik)                               ║
║  # │ ID                    │ Dosya            │ Zaman        ║
║────┼───────────────────────┼──────────────────┼──────────────║
║  1 │ rp-20251214-abc123    │ auth.service.ts  │ 14:30        ║
║  2 │ rp-20251214-def456    │ user.model.ts    │ 14:35        ║
║  3 │ rp-20251214-ghi789    │ api.controller.ts│ 14:40        ║
║                                                              ║
║  🔖 CHECKPOINTS (Manuel)                                     ║
║  # │ ID                    │ İsim             │ Zaman        ║
║────┼───────────────────────┼──────────────────┼──────────────║
║  1 │ cp-20251214-xyz123    │ Pre-refactor     │ 14:25        ║
║  2 │ cp-20251214-uvw456    │ After-tests      │ 14:45        ║
║                                                              ║
║  💡 Rollback: /x:rollback <id>                              ║
║  💡 En son: /x:rollback latest                              ║
╚══════════════════════════════════════════════════════════════╝
```

## Rollback İşlemi

### 1. Point Seç

```bash
# Belirli point
~/.claude/x-orchestrator/hooks/rollback-engine.sh get $POINT_ID

# En son
~/.claude/x-orchestrator/hooks/rollback-engine.sh latest
```

### 2. Mevcut Durumu Backup Et

Rollback öncesi mevcut durum otomatik backup'lanır.

### 3. Restore Et

```bash
~/.claude/x-orchestrator/hooks/rollback-engine.sh restore $POINT_ID
```

### 4. Doğrulama

Restore sonrası:
- Dosya integrity check
- Build/lint kontrolü
- Test çalıştırma (opsiyonel)

### 5. Output

```
╔══════════════════════════════════════════════════════════════╗
║               ROLLBACK COMPLETED                             ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  ✅ RESTORE EDİLDİ                                           ║
║                                                              ║
║  📁 Dosya: src/services/auth.service.ts                     ║
║  🔄 Point: rp-20251214-abc123                                ║
║  🕐 Orijinal: 14:30:00                                      ║
║                                                              ║
║  💾 BACKUP OLUŞTURULDU                                       ║
║  └── backup-20251214-145500                                 ║
║                                                              ║
║  ⚠️  Değişiklikleriniz backup'landı. Geri almak için:        ║
║      /x:rollback backup-20251214-145500                     ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

## Toplu Rollback

Birden fazla dosyayı rollback etmek için checkpoint kullan:

```bash
/x:rollback cp-20251214-xyz123
```

Bu, checkpoint'ten bu yana değişen tüm dosyaları restore eder.

## Dikkat

- Rollback işlemi geri alınabilir (backup oluşturulur)
- Committed olmayan değişiklikler korunur
- Git history etkilenmez
