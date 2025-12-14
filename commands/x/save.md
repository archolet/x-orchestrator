---
description: Mevcut session'ı kaydet
allowed-tools: Read, Bash
argument-hint: [mesaj]
model: opus
---

# X-Orchestrator: Session Kaydetme

Mevcut çalışma session'ını kaydeder. Daha sonra `/x:load` ile geri yüklenebilir.

## Argümanlar
$ARGUMENTS

Argüman boşsa, otomatik timestamp'li mesaj oluşturulur.

## Kaydetme İşlemi

### 1. Mevcut Session State'i Oku

```bash
cat .claude/x-state/current-session.json
```

### 2. Session'ı Güncelle

Session state'e save mesajını ve timestamp'i ekle:
- save_message: Kullanıcının mesajı veya otomatik mesaj
- saved_at: ISO timestamp
- context_snapshot: Mevcut context özeti

### 3. Global Storage'a Kopyala

```bash
PROJECT_HASH=$(echo "$PWD" | md5 | cut -c1-8)
SESSION_ID=$(jq -r '.session_id' .claude/x-state/current-session.json)
cp .claude/x-state/current-session.json ~/.claude/x-orchestrator/sessions/$PROJECT_HASH/$SESSION_ID.json
```

### 4. Telemetry'yi de Kaydet

```bash
cp .claude/x-state/telemetry.json ~/.claude/x-orchestrator/telemetry/sessions/$SESSION_ID.json
```

### 5. Output

```
╔══════════════════════════════════════════════════════════════╗
║  💾 SESSION SAVED                                            ║
╠══════════════════════════════════════════════════════════════╣
║  Session ID: session-20251214-abc123                        ║
║  Mesaj: [kullanıcı mesajı]                                  ║
║  Zaman: 2025-12-14 14:30:00                                 ║
║                                                              ║
║  📊 Session Özeti:                                          ║
║  • Süre: 45 dakika                                          ║
║  • Komutlar: 5                                              ║
║  • Dosya değişikliği: 3                                     ║
║  • Token: ~50k                                              ║
║                                                              ║
║  💡 Yüklemek için: /x:load session-20251214-abc123          ║
║  💡 Son session: /x:load latest                             ║
╚══════════════════════════════════════════════════════════════╝
```

## Auto-Save

Config'de `auto_save: true` ise, her 5 dakikada otomatik save yapılır.
Bu manuel save, otomatik save'lerin üzerine yazar.
