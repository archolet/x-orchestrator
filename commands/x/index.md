---
description: Proje analizi ve otomatik rules oluşturma
allowed-tools: Read, Write, Bash, Grep, Glob
argument-hint: [--deep] [--update]
model: opus
---

# X-Orchestrator: Proje İndeksleme

Projeyi analiz eder, yapısını anlar ve uygun rules oluşturur.

## Argümanlar
$ARGUMENTS

- `--deep`: Derinlemesine analiz (daha uzun sürer)
- `--update`: Mevcut index'i güncelle

## İndeksleme İşlemi

### 1. Proje Yapısı Analizi

```bash
# Dosya yapısını tara
find . -type f -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
  -o -name "*.py" -o -name "*.java" -o -name "*.cs" -o -name "*.go" \
  | head -100
```

### 2. Tech Stack Tespiti

Dosya uzantıları ve config dosyalarına göre:

| Dosya | Tech |
|-------|------|
| package.json | Node.js/TypeScript |
| tsconfig.json | TypeScript |
| *.csproj | .NET |
| pom.xml | Java/Maven |
| build.gradle | Java/Gradle |
| requirements.txt | Python |
| go.mod | Go |
| pubspec.yaml | Flutter/Dart |

### 3. Architecture Pattern Tespiti

Klasör yapısına göre:

| Pattern | İpuçları |
|---------|----------|
| DDD | Domain/, Application/, Infrastructure/ |
| Clean Architecture | Core/, Application/, Infrastructure/, Presentation/ |
| CQRS | Commands/, Queries/, Handlers/ |
| Hexagonal | Adapters/, Ports/, Domain/ |
| MVC | Controllers/, Models/, Views/ |
| Feature-based | Features/, Modules/ |

### 4. Mevcut Rules Kontrolü

```bash
ls .claude/rules/
```

### 5. Önerilen Rules Oluşturma

Tespit edilen pattern'lara göre `~/.claude/x-orchestrator/rules-library/` içinden uygun rules'ları kopyala.

### 6. CLAUDE.md Güncelleme (veya Oluşturma)

Proje kökünde CLAUDE.md oluştur veya güncelle:

```markdown
# Project: [Proje Adı]

## Tech Stack
- Language: [Dil]
- Framework: [Framework]
- Architecture: [Pattern]

## Structure
[Klasör yapısı özeti]

## Key Modules
[Ana modüller]

## Coding Standards
[Tespit edilen standartlar]

## Build & Test
[Build ve test komutları]
```

### 7. Context Map Güncelleme

```bash
# .claude/x-state/context-map.json güncelle
~/.claude/x-orchestrator/hooks/context-manager.sh add_module "module_name" "path"
```

### 8. Output

```
╔══════════════════════════════════════════════════════════════╗
║               PROJECT INDEXED                                ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  📁 PROJE: /path/to/project                                 ║
║                                                              ║
║  🔧 TECH STACK                                               ║
║  ├── Language: TypeScript                                   ║
║  ├── Framework: Angular 17                                  ║
║  ├── Build: npm                                             ║
║  └── Test: Jest                                             ║
║                                                              ║
║  🏗️  ARCHITECTURE                                            ║
║  ├── Pattern: Feature-based + DDD                           ║
║  ├── Modules: 12                                            ║
║  └── Components: 45                                         ║
║                                                              ║
║  📋 RULES EKLENEN                                            ║
║  ├── architecture/ddd.md                                    ║
║  ├── principles/solid.md                                    ║
║  └── patterns/repository.md                                 ║
║                                                              ║
║  📝 CLAUDE.md                                                ║
║  └── Güncellendi (son: 2025-12-14)                          ║
║                                                              ║
║  💡 Artık /x:prompt ile projede çalışabilirsiniz            ║
╚══════════════════════════════════════════════════════════════╝
```

## --deep Flag'i

Deep analiz ekstra şunları yapar:
- Tüm import/dependency grafiğini çıkar
- Circular dependency tespit et
- Code coverage analizi
- Complexity metrics
- Hot paths tespit et
