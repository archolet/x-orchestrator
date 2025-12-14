---
description: Rules yönetimi - ekleme, listeleme, senkronizasyon
allowed-tools: Read, Write, Bash, Glob
argument-hint: <add|list|sync> [rule-name]
model: opus
---

# X-Orchestrator: Rules Yönetimi

Proje rules'larını yönetir.

## Argümanlar
$ARGUMENTS

- `add <rule>`: Rule ekle (library'den veya URL'den)
- `list`: Mevcut rules'ları listele
- `sync`: Library'den güncellemeleri çek
- `remove <rule>`: Rule kaldır

## Rules Library

```
~/.claude/x-orchestrator/rules-library/
├── architecture/
│   ├── ddd.md
│   ├── cqrs.md
│   ├── clean-arch.md
│   └── hexagonal.md
├── principles/
│   ├── solid.md
│   └── dry-kiss.md
└── patterns/
    ├── repository.md
    ├── unit-of-work.md
    └── mediator.md
```

## add Komutu

### Library'den Ekleme

```bash
/x:rules add solid
/x:rules add architecture/ddd
```

```bash
# Library'den proje rules'a kopyala
cp ~/.claude/x-orchestrator/rules-library/$RULE.md .claude/rules/
```

### URL'den Ekleme

```bash
/x:rules add https://example.com/my-rule.md
```

```bash
# URL'den indir
curl -o .claude/rules/custom-rule.md $URL
```

### Output

```
╔══════════════════════════════════════════════════════════════╗
║               RULE ADDED                                     ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  ✅ solid.md                                                 ║
║  📁 .claude/rules/solid.md                                  ║
║                                                              ║
║  📝 İçerik:                                                  ║
║  SOLID prensiplerini uygula:                                ║
║  - Single Responsibility                                    ║
║  - Open/Closed                                              ║
║  - Liskov Substitution                                      ║
║  - Interface Segregation                                    ║
║  - Dependency Inversion                                     ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

## list Komutu

```bash
/x:rules list
```

```
╔══════════════════════════════════════════════════════════════╗
║               PROJECT RULES                                  ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  📁 .claude/rules/                                          ║
║                                                              ║
║  # │ Rule          │ Type         │ Path Match              ║
║────┼───────────────┼──────────────┼─────────────────────────║
║  1 │ solid.md      │ Principles   │ **/*                    ║
║  2 │ ddd.md        │ Architecture │ src/Domain/**           ║
║  3 │ api-style.md  │ Custom       │ src/Api/**              ║
║                                                              ║
║  📚 LIBRARY'DE MEVCUT                                        ║
║  • architecture/: 4 rule                                    ║
║  • principles/: 2 rule                                      ║
║  • patterns/: 3 rule                                        ║
║                                                              ║
║  💡 Eklemek için: /x:rules add <rule-name>                  ║
╚══════════════════════════════════════════════════════════════╝
```

## sync Komutu

```bash
/x:rules sync
```

Library'deki güncellemeleri kontrol et ve uygula.

```
╔══════════════════════════════════════════════════════════════╗
║               RULES SYNC                                     ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  🔄 GÜNCELLENEN                                              ║
║  ├── solid.md (v1.1 → v1.2)                                 ║
║  └── ddd.md (v2.0 → v2.1)                                   ║
║                                                              ║
║  ✅ GÜNCEL                                                   ║
║  └── api-style.md                                           ║
║                                                              ║
║  🆕 YENİ (Library'de)                                        ║
║  └── patterns/event-sourcing.md                             ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

## remove Komutu

```bash
/x:rules remove solid
```

```
╔══════════════════════════════════════════════════════════════╗
║               RULE REMOVED                                   ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  🗑️  solid.md kaldırıldı                                     ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

## Rule Format

Her rule `.md` dosyası frontmatter içerebilir:

```markdown
---
name: SOLID Principles
version: 1.2
applies_to: "**/*.ts"
priority: high
---

# SOLID Prensipleri

Bu dosyadaki kod SOLID prensiplerini uygulamalı:

1. **Single Responsibility**: Her sınıf tek bir sorumluluğa sahip olmalı
2. **Open/Closed**: Genişlemeye açık, değişikliğe kapalı
...
```
