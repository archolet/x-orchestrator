---
description: Proje analizi ve CLAUDE.md oluşturma - X-Orchestrator v3.1
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Search
argument-hint: [--deep] [--c7] [--seq] [--ultrathink]
model: opus
---

# X-Orchestrator: Proje İndeksleme

$ARGUMENTS içindeki flag'lere göre proje analizi yap.

## FLAG'LER

| Flag | Açıklama |
|------|----------|
| `--deep` | Derinlemesine analiz (dependency graph, kod satırı, vb.) |
| `--c7` | Context7 ile framework dokümantasyonu |
| `--seq` | Sequential thinking ile adım adım |
| `--ultrathink` | Maximum reasoning |

## KRİTİK KURALLAR

### 1. Dizin Tespiti (ÖNCELİKLİ!)
```bash
# MUTLAKA mevcut dizini tespit et
CURRENT_DIR=$(pwd)
echo "📍 Mevcut Dizin: $CURRENT_DIR"
```

### 2. CLAUDE.md Lokasyonu
**SADECE mevcut dizinde CLAUDE.md oluştur/güncelle!**
```
✅ DOĞRU: $CURRENT_DIR/CLAUDE.md
❌ YANLIŞ: Üst dizin, alt dizin, başka bir yer
```

### 3. İndeks Çıktısı
**Ekrana bastıktan sonra MUTLAKA dosyaya da yaz:**
```
$CURRENT_DIR/.claude/x-state/project-index.json
```

## PHASE 1: CURRENT DIRECTORY CHECK
```bash
# 1. Mevcut dizini al
pwd

# 2. Git root mu kontrol et (opsiyonel)
git rev-parse --show-toplevel 2>/dev/null || echo "Not a git repo"

# 3. Mevcut dizinde .csproj, package.json, vb. var mı?
ls -la *.csproj *.sln package.json Cargo.toml go.mod 2>/dev/null
```

**Output:**
```
📍 Çalışma Dizini: /path/to/current/directory
📁 Proje Tipi: [.NET/Node/Python/etc.]
```

## PHASE 2: PROJE ANALİZİ

### 2.1 Temel Analiz
- Tech stack tespiti
- Dosya sayıları
- Proje yapısı

### 2.2 Deep Analiz (--deep flag'i varsa)
- Dependency graph
- Kod satırı sayımı
- Paket versiyonları
- Circular dependency kontrolü

## PHASE 3: CLAUDE.md OLUŞTUR/GÜNCELLE

**Hedef dosya: `$CURRENT_DIR/CLAUDE.md`**
```markdown
# [Proje Adı]

## Tech Stack
| Category | Technology |
|----------|------------|
| Language | [dil] |
| Framework | [framework] |
...

## Project Structure
[yapı]

## Key Modules
[modüller]

## Build Commands
[komutlar]

## Statistics
- Files: X
- Lines: Y
- Last indexed: [tarih]
```

## PHASE 4: INDEX DOSYASI KAYDET

**Hedef dosya: `$CURRENT_DIR/.claude/x-state/project-index.json`**
```json
{
  "indexed_at": "2025-12-14T15:30:00Z",
  "directory": "/path/to/current",
  "tech_stack": {...},
  "statistics": {...},
  "modules": [...],
  "dependencies": {...}
}
```

## PHASE 5: INTELLIGENT RULES GENERATION

**KRİTİK: ŞABLON KOPYALAMA YASAK! Projeyi analiz et, O PROJEYE ÖZEL rules ÜRET!**

### 5.1 Proje Kimlik Analizi

Projenin ne olduğunu anla:
```bash
# Proje adı ve tipi
PROJECT_NAME=$(basename "$CURRENT_DIR")
PROJECT_TYPE="unknown"

# Tech stack tespiti
if ls *.csproj *.sln 2>/dev/null | grep -q .; then
    PROJECT_TYPE="dotnet"
elif [ -f "package.json" ]; then
    PROJECT_TYPE="node"
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    PROJECT_TYPE="python"
fi

echo "📁 Proje: $PROJECT_NAME"
echo "🔧 Tip: $PROJECT_TYPE"
```

### 5.2 Kod Pattern Çıkarımı (Gerçek Analiz!)

Projedeki GERÇEK pattern'leri keşfet ve KAYDET:
```bash
# 1. Interface naming convention
echo "### Interface Patterns:"
grep -rh "^public interface\|^internal interface" . --include="*.cs" 2>/dev/null | head -10

# 2. Class naming convention
echo "### Class Patterns:"
grep -rh "^public class\|^internal class\|^public abstract class" . --include="*.cs" 2>/dev/null | head -10

# 3. Base class inheritance
echo "### Base Classes:"
grep -rh ": .*Base<\|: Entity<\|: AggregateRoot" . --include="*.cs" 2>/dev/null | head -10

# 4. Pipeline/Behavior pattern
echo "### Behaviors:"
grep -rh "IPipelineBehavior\|Behavior<" . --include="*.cs" 2>/dev/null | head -10

# 5. Dependency graph
echo "### Project References:"
grep -h "ProjectReference" **/*.csproj 2>/dev/null | head -10

# 6. DI Registration pattern
echo "### DI Extensions:"
grep -rh "public static.*ServiceCollection\|AddScoped\|AddSingleton\|AddTransient" . --include="*.cs" 2>/dev/null | head -10
```

### 5.3 Rules ÜRET (ŞABLON KOPYALAMA DEĞİL!)

Analiz sonucuna göre O PROJEYE ÖZEL rules dosyası OLUŞTUR:
```bash
PROJECT_RULES="$CURRENT_DIR/.claude/rules"
mkdir -p "$PROJECT_RULES"

# Analiz sonuçlarını topla
INTERFACES=$(grep -rh "^public interface" . --include="*.cs" 2>/dev/null | head -5)
CLASSES=$(grep -rh "^public class" . --include="*.cs" 2>/dev/null | head -5)
BEHAVIORS=$(grep -rh "Behavior<" . --include="*.cs" 2>/dev/null | wc -l)
REPOSITORIES=$(grep -rh "Repository" . --include="*.cs" 2>/dev/null | wc -l)

# Proje'ye özel rule dosyası ÜRET
cat > "$PROJECT_RULES/project-rules.md" << 'RULES_EOF'
# ${PROJECT_NAME} - Project Rules

## Bu Proje Hakkında
**Auto-Generated:** $(date +%Y-%m-%d)
**Analiz Edilen:** $(find . -name "*.cs" 2>/dev/null | wc -l) C# dosyası

---

## Naming Conventions (Bu Projede Tespit Edilen)

### Interface Pattern
```
${INTERFACES}
```
**Kural:** Bu projede interface'ler [tespit edilen pattern] formatında

### Class Pattern
```
${CLASSES}
```
**Kural:** Bu projede class'lar [tespit edilen pattern] formatında

---

## Dependency Rules (Bu Projede)

### Proje Referansları
$(grep -h "ProjectReference" **/*.csproj 2>/dev/null | sed 's/.*Include="\([^"]*\)".*/- \1/' | sort -u | head -10)

**Kural:** Bu bağımlılık yapısına uy, circular dependency oluşturma

---

## Code Patterns (Bu Projede Kullanılan)

### Repository Pattern
$(if [ $REPOSITORIES -gt 0 ]; then
    echo "✅ Kullanılıyor"
    echo "Base class: $(grep -rh "class.*Repository.*:" . --include="*.cs" 2>/dev/null | head -1)"
else
    echo "❌ Kullanılmıyor"
fi)

### Pipeline/Behavior Pattern
$(if [ $BEHAVIORS -gt 0 ]; then
    echo "✅ Kullanılıyor ($BEHAVIORS behavior tespit edildi)"
    grep -rh "class.*Behavior" . --include="*.cs" 2>/dev/null | head -5
else
    echo "❌ Kullanılmıyor"
fi)

### Entity Pattern
$(grep -rh "class.*: Entity\|class.*: IEntity" . --include="*.cs" 2>/dev/null | head -3)

---

## Folder Structure (Bu Projede)
```
$(find . -maxdepth 3 -type d | grep -v "node_modules\|bin\|obj\|.git\|.vs" | sort | head -25)
```

---

## Dosya Oluşturma Kuralları (Bu Proje İçin)

Yeni dosya oluştururken:
1. **Namespace:** $(grep -rh "^namespace" . --include="*.cs" 2>/dev/null | head -1 | sed 's/namespace //' | sed 's/;.*//')
2. **Using pattern:** $(grep -rh "^using" . --include="*.cs" 2>/dev/null | sort -u | head -5)

---

## Yasaklar (Bu Projede Kullanılmayanlar)

$(if [ $BEHAVIORS -eq 0 ]; then echo "- Pipeline/Behavior pattern kullanılmıyor, ekleme"; fi)
$(if [ $REPOSITORIES -eq 0 ]; then echo "- Repository pattern kullanılmıyor, ekleme"; fi)

---

## Notes
- Bu dosya /x:index tarafından otomatik üretildi
- Proje analiz edilerek O PROJEYE ÖZEL kurallar çıkarıldı
- Şablon kopyalama YAPILMADI

RULES_EOF

echo "✅ project-rules.md üretildi (şablondan değil, analiz sonucu!)"
```

### 5.4 Generation Report

```
╔═══════════════════════════════════════════════════════════════╗
║  📋 INTELLIGENT RULES GENERATION RESULT                       ║
║  (Şablondan Değil, Gerçek Analiz Sonucu Üretildi!)           ║
╠═══════════════════════════════════════════════════════════════╣
║  🔍 ANALİZ EDİLEN:                                            ║
║  ├── [X] C# dosyası                                          ║
║  ├── [Y] .csproj dosyası                                     ║
║  └── [Z] proje referansı                                     ║
║                                                               ║
║  📝 TESPİT EDİLEN PATTERN'LER:                                ║
║  ├── Interface convention: I{Name}                           ║
║  ├── Class convention: {Name}Base<T>                         ║
║  ├── Behavior count: X adet                                  ║
║  ├── Repository usage: ✅/❌                                  ║
║  └── Entity pattern: Entity<TId>                             ║
║                                                               ║
║  📁 ÜRETİLEN RULES (şablon değil!):                          ║
║  └── project-rules.md (analiz sonucu, ~150 satır)            ║
║                                                               ║
║  📍 Location: $CURRENT_DIR/.claude/rules/                     ║
╚═══════════════════════════════════════════════════════════════╝
```

## PHASE 6: ÖZET GÖSTER
```
╔══════════════════════════════════════════════════════════════╗
║                    PROJECT INDEXED                            ║
╠══════════════════════════════════════════════════════════════╣
║  📍 Dizin: $CURRENT_DIR                                      ║
║  📝 CLAUDE.md: $CURRENT_DIR/CLAUDE.md (güncellendi)         ║
║  📊 Index: $CURRENT_DIR/.claude/x-state/project-index.json  ║
║  📋 Rules: X adet rule kopyalandı                            ║
║  ...                                                          ║
╚══════════════════════════════════════════════════════════════╝
```

## Dil Kuralları

- Açıklamalar Türkçe
- Teknik terimler İngilizce
- Kod comment'leri İngilizce

## KONTROL LİSTESİ (Her çalışmada)

- [ ] `pwd` ile mevcut dizin tespit edildi mi?
- [ ] CLAUDE.md MEVCUT DİZİNDE mi oluşturuldu?
- [ ] project-index.json kaydedildi mi?
- [ ] **ŞABLON KOPYALAMA YAPILMADI MI?** (KRİTİK!)
- [ ] **Projedeki gerçek kod analiz edildi mi?** (grep/find ile)
- [ ] **project-rules.md O PROJEYE ÖZEL üretildi mi?** (şablondan değil!)
- [ ] **Tespit edilen pattern'ler rules içinde mi?**
- [ ] Üst/alt dizinlere dokunulmadı mı?
