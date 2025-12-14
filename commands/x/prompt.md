---
description: Akıllı prompt analizi ve execution - X-Orchestrator v3.1
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Task, WebSearch, mcp__context7, mcp__sequentialthinking
argument-hint: <istek> [--ultrathink] [--c7] [--seq] [--websearch] [--no-confirm] [--dry-run]
model: opus
---

# X-Orchestrator: Akıllı Prompt Analizi

$ARGUMENTS içindeki isteği işle.

## FLAG PARSER

### Desteklenen Flag'ler
| Flag | Kısa | Açıklama | Otomatik Tetikleyici |
|------|------|----------|---------------------|
| `--ultrathink` | `-u` | Maximum reasoning (31999 token thinking) | Mimari değişiklik, karmaşık refactoring |
| `--c7` | `-c` | Context7 MCP ile dokümantasyon | Paket güncelleme, framework kullanımı |
| `--seq` | `-s` | Sequential Thinking ile adım adım | Multi-step task, 5+ dosya değişikliği |
| `--websearch` | `-w` | Zorla web araması | Versiyon kontrolü, güncel bilgi |
| `--no-confirm` | `-y` | Onay sormadan çalıştır | - |
| `--dry-run` | `-d` | Sadece plan göster | - |
| `--deep` | | Derinlemesine analiz | - |

### Flag Parsing
1. $ARGUMENTS içindeki flag'leri tespit et
2. Flag'leri ayır, asıl prompt'u çıkar
3. Her flag için ilgili tool/MCP'yi aktifleştir

### Otomatik Flag Tetikleme (AUTO-FLAGS)
Aşağıdaki keyword'ler tespit edilirse flag OTOMATIK aktifleşir:

**--ultrathink otomatik:**
- "karmaşık", "complex", "mimari", "architecture"
- "refactor", "redesign", "migration"
- "tüm", "hepsi", "all", "entire"
- 10+ dosya etkilenecekse

**--c7 otomatik:**
- "paket", "package", "NuGet", "npm", "pip"
- "güncelle", "update", "upgrade"
- Framework isimleri: "Angular", "React", "EF Core", "ASP.NET"

**--seq otomatik:**
- "adım adım", "step by step"
- "sırayla", "sequential"
- 5+ adımlık plan gerekiyorsa

**--websearch otomatik:**
- Versiyon numarası içeren istekler
- "latest", "en son", "güncel", "current"
- "2024", "2025" gibi yıl referansları

## PHASE 0: PRE-FLIGHT & FLAG ACTIVATION

### 0.1 Flag Parse
```
Örnek: "/x:prompt --c7 --ultrathink paketleri güncelle"
→ Flags: [c7, ultrathink]
→ Prompt: "paketleri güncelle"
```

### 0.2 Auto-Flag Detection
Prompt'u analiz et ve otomatik flag'leri aktifleştir:
```
Örnek: "Tüm NuGet paketlerini son sürüme güncelle"
→ Auto-flags: [c7, websearch, ultrathink]
→ Sebep: "NuGet" → c7, "son sürüm" → websearch, "Tüm" → ultrathink
```

### 0.3 Flag Aktivasyonu
Aktif flag'lere göre araçları hazırla:

**--ultrathink aktifse:**
```
🧠 Ultrathink Mode: Aktif
Thinking budget: 31999 token
```
Prompt'un başına "Ultrathink." ekle.

**--c7 aktifse:**
```
📚 Context7 Mode: Aktif
```
İlgili teknoloji için `mcp__context7` ile dokümantasyon çek.

**--seq aktifse:**
```
🔢 Sequential Thinking Mode: Aktif
```
`mcp__sequentialthinking` ile adım adım reasoning yap.

**--websearch aktifse:**
```
🌐 Web Search Mode: Aktif
```
İlgili teknoloji/versiyon için web araması yap.

### 0.4 Flag Status Göster
```
╔═══════════════════════════════════════╗
║  🚀 X-ORCHESTRATOR FLAGS              ║
╠═══════════════════════════════════════╣
║  --ultrathink  ✅ (auto: "Tüm")       ║
║  --c7          ✅ (auto: "NuGet")     ║
║  --seq         ✅ (manual)            ║
║  --websearch   ✅ (auto: "güncelle")  ║
╚═══════════════════════════════════════╝
```

## PHASE 1: PROMPT ANALİZİ

1. Flag'ler ayrıldıktan sonra asıl isteği parse et
2. Belirsizlikleri tespit et
3. Etkilenecek dosyaları belirle
4. **--c7 aktifse:** İlgili paket/framework dokümantasyonu çek
5. **--websearch aktifse:** Versiyon doğrulaması yap

## PHASE 2: CONTEXT & DOCUMENTATION

### --c7 Aktifse
```
mcp__context7 kullanarak:
1. İlgili framework/library için dokümantasyon al
2. Best practices kontrol et
3. Breaking changes kontrol et
4. Migration guide varsa al
```

### --seq Aktifse
```
mcp__sequentialthinking kullanarak:
1. Problemi parçalara ayır
2. Her parça için çözüm düşün
3. Parçaları birleştir
4. Edge case'leri kontrol et
```

## PHASE 3: RULES & CONTEXT LOADING

1. `.claude/rules/` klasörünü kontrol et
2. Path-matching ile ilgili kuralları yükle

## PHASE 4: CLARIFICATION (Gerekirse)

Belirsizlik varsa kullanıcıya sor.

## PHASE 5: PLAN OLUŞTUR

**Plan şablonu (flag'lerle):**
```
╔══════════════════════════════════════════════════════════════╗
║  📋 EXECUTION PLAN                                           ║
╠══════════════════════════════════════════════════════════════╣
║  🚀 Aktif Flags: --ultrathink --c7 --websearch              ║
║                                                              ║
║  Hedef: [İstek özeti]                                        ║
║                                                              ║
║  🔍 Verification (--websearch):                             ║
║  • [Teknoloji] [Versiyon]: [Release durumu]                 ║
║                                                              ║
║  📚 Context7 Docs (--c7):                                   ║
║  • [Dokümantasyon özeti]                                    ║
║  • Breaking changes: [varsa listele]                        ║
║                                                              ║
║  📁 Etkilenecek Dosyalar:                                   ║
║  • [dosya listesi]                                          ║
║                                                              ║
║  📝 Adımlar (--seq ile planlandı):                          ║
║  1. [adım]                                                   ║
║  2. [adım]                                                   ║
║                                                              ║
║  ⚠️  Riskler:                                               ║
║  • [risk listesi]                                           ║
║                                                              ║
║  💰 Tahmini: ~[X]k token (~$[Y])                            ║
╠══════════════════════════════════════════════════════════════╣
║  [A] ✅ Onayla ve çalıştır                                  ║
║  [B] 📝 Planı düzenle                                       ║
║  [C] ❌ İptal                                               ║
╚══════════════════════════════════════════════════════════════╝
```

## PHASE 6-7: EXECUTION & POST

1. **--ultrathink aktifse:** Her adımda derinlemesine düşün
2. Rollback point oluştur
3. Adım adım execute et
4. Her adımda doğrula
5. Session state güncelle

## Dil Kuralları

- Açıklamalar Türkçe
- Teknik terimler İngilizce (function, class, deploy, refactor, vb.)
- Kod comment'leri İngilizce

## Örnek Kullanımlar
```
/x:prompt --ultrathink Auth modülünü refactor et
→ Flags: [ultrathink]
→ 🧠 Maximum reasoning aktif

/x:prompt --c7 --websearch Angular'ı güncelle
→ Flags: [c7, websearch]
→ 📚 Angular docs + 🌐 versiyon kontrolü

/x:prompt tüm NuGet paketlerini son sürüme güncelle
→ Auto-flags: [ultrathink, c7, websearch]
→ "tüm" → ultrathink, "NuGet" → c7, "son sürüm" → websearch
```
