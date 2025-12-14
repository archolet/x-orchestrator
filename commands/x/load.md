---
description: Kaydedilmiş session'ı yükle
allowed-tools: Read, Bash
argument-hint: [session-id|latest]
model: opus
---

# X-Orchestrator: Session Yükleme

Daha önce kaydedilmiş bir session'ı yükler.

## Argümanlar
$ARGUMENTS

- Boş: Session listesini göster
- `latest`: En son session'ı yükle
- `session-id`: Belirtilen session'ı yükle

## Yükleme İşlemi

### 1. Session Listesi (Argüman boşsa)

```bash
PROJECT_HASH=$(echo "$PWD" | md5 | cut -c1-8)
ls -la ~/.claude/x-orchestrator/sessions/$PROJECT_HASH/
```

Output:
```
╔══════════════════════════════════════════════════════════════╗
║  📂 SAVED SESSIONS                                           ║
╠══════════════════════════════════════════════════════════════╣
║  # │ Session ID              │ Tarih       │ Mesaj          ║
║────┼─────────────────────────┼─────────────┼────────────────║
║  1 │ session-20251214-abc123 │ 14 Ara 2025 │ Auth refactor  ║
║  2 │ session-20251213-def456 │ 13 Ara 2025 │ API endpoints  ║
║  3 │ session-20251212-ghi789 │ 12 Ara 2025 │ Bug fixes      ║
╠══════════════════════════════════════════════════════════════╣
║  💡 Yüklemek için: /x:load <session-id>                     ║
║  💡 En son: /x:load latest                                  ║
╚══════════════════════════════════════════════════════════════╝
```

### 2. Session Yükleme

1. Session dosyasını bul:
   ```bash
   SESSION_FILE=~/.claude/x-orchestrator/sessions/$PROJECT_HASH/$SESSION_ID.json
   ```

2. Mevcut session'ı backup et:
   ```bash
   cp .claude/x-state/current-session.json .claude/x-state/current-session.backup.json
   ```

3. Session'ı yükle:
   ```bash
   cp $SESSION_FILE .claude/x-state/current-session.json
   ```

4. Session status'ü güncelle:
   - status: "resumed"
   - resumed_at: ISO timestamp
   - resumed_from: original session_id

### 3. Context Restoration

Session'daki context bilgilerini yükle:
- hot_files: Sık kullanılan dosyalar
- modules: Aktif modüller
- rules_applied: Uygulanan kurallar

### 4. Output

```
╔══════════════════════════════════════════════════════════════╗
║  ✅ SESSION LOADED                                           ║
╠══════════════════════════════════════════════════════════════╣
║  Session ID: session-20251214-abc123                        ║
║  Orijinal Tarih: 14 Ara 2025, 14:30                         ║
║  Mesaj: Auth modülü refactor                                ║
║                                                              ║
║  📊 Session Özeti:                                          ║
║  • Toplam komut: 5                                          ║
║  • Son işlem: UserService güncelleme                        ║
║  • Checkpoints: 3                                           ║
║                                                              ║
║  📁 Context Yüklendi:                                       ║
║  • Hot files: 4 dosya                                       ║
║  • Rules: solid.md, ddd.md                                  ║
║                                                              ║
║  💡 Kaldığınız yerden devam edebilirsiniz.                  ║
╚══════════════════════════════════════════════════════════════╝
```

### 5. Latest Shortcut

`/x:load latest` için:
```bash
LATEST=$(ls -t ~/.claude/x-orchestrator/sessions/$PROJECT_HASH/*.json | head -1)
```

## Notlar

- Session yüklendiğinde mevcut session backup'lanır
- Yüklenen session'ın context'i restore edilir
- Task history korunur
