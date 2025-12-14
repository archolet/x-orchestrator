---
description: Yeni proje veya modül scaffolding
allowed-tools: Read, Write, Bash, Grep, Glob
argument-hint: <template> [name] [--path=<path>]
model: opus
---

# X-Orchestrator: Template Scaffolding

Yeni proje veya modül oluşturur.

## Argümanlar
$ARGUMENTS

- `<template>`: Template adı (dotnet, angular, python, java, flutter, module)
- `[name]`: Proje/modül adı
- `--path=<path>`: Hedef klasör (default: current directory)

## Kullanılabilir Templates

```
╔══════════════════════════════════════════════════════════════╗
║               AVAILABLE TEMPLATES                            ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  📦 PROJECT TEMPLATES                                        ║
║  ├── dotnet         .NET Core Web API + Clean Architecture  ║
║  ├── angular        Angular 17 + Feature-based              ║
║  ├── python         Python + FastAPI + DDD                  ║
║  ├── java           Java Spring Boot + Hexagonal            ║
║  └── flutter        Flutter + BLoC + Clean Arch             ║
║                                                              ║
║  📁 MODULE TEMPLATES                                         ║
║  ├── module         Generic feature module                  ║
║  ├── api-module     REST API endpoint module                ║
║  ├── domain-module  DDD domain module                       ║
║  └── ui-module      Frontend UI module                      ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

## Template Yapısı

Her template `~/.claude/x-orchestrator/templates/<name>/` içinde:

```
templates/dotnet/
├── template.json       # Template metadata
├── scaffold/           # Dosya yapısı
│   ├── src/
│   │   ├── Domain/
│   │   ├── Application/
│   │   ├── Infrastructure/
│   │   └── WebApi/
│   └── tests/
├── rules/              # Önerilen rules
└── README.md           # Template açıklaması
```

## Scaffolding İşlemi

### 1. Template Kontrolü

```bash
TEMPLATE_DIR=~/.claude/x-orchestrator/templates/$TEMPLATE
if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "Template bulunamadı: $TEMPLATE"
    exit 1
fi
```

### 2. Template Metadata Oku

```bash
cat $TEMPLATE_DIR/template.json
```

```json
{
  "name": "dotnet-clean-arch",
  "description": ".NET Clean Architecture Template",
  "version": "1.0.0",
  "variables": ["PROJECT_NAME", "NAMESPACE"],
  "post_commands": ["dotnet restore", "dotnet build"]
}
```

### 3. Dosyaları Kopyala ve Transform Et

Tüm dosyalarda placeholder'ları değiştir:
- `{{PROJECT_NAME}}` → Gerçek proje adı
- `{{NAMESPACE}}` → Namespace
- `{{DATE}}` → Bugünün tarihi
- `{{AUTHOR}}` → Git user

### 4. Rules Kopyala

```bash
cp -r $TEMPLATE_DIR/rules/* .claude/rules/
```

### 5. Post-Scaffold Komutları

Template'e göre:
- dotnet: `dotnet restore && dotnet build`
- angular: `npm install`
- python: `pip install -r requirements.txt`
- java: `mvn install`
- flutter: `flutter pub get`

### 6. İndeksleme

```bash
# Otomatik /x:index çalıştır
```

### 7. Output

```
╔══════════════════════════════════════════════════════════════╗
║               PROJECT CREATED                                ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  📦 PROJE: MyNewProject                                     ║
║  📁 PATH: /Users/dev/projects/MyNewProject                  ║
║  🔧 TEMPLATE: dotnet-clean-arch                             ║
║                                                              ║
║  📂 OLUŞTURULAN YAPIT                                        ║
║  ├── src/                                                   ║
║  │   ├── Domain/                                            ║
║  │   ├── Application/                                       ║
║  │   ├── Infrastructure/                                    ║
║  │   └── WebApi/                                            ║
║  ├── tests/                                                 ║
║  ├── .claude/                                               ║
║  │   └── rules/                                             ║
║  └── CLAUDE.md                                              ║
║                                                              ║
║  ✅ POST-SCAFFOLD                                            ║
║  ├── dotnet restore ✓                                       ║
║  └── dotnet build ✓                                         ║
║                                                              ║
║  💡 Başlamak için: cd MyNewProject && /x:prompt             ║
╚══════════════════════════════════════════════════════════════╝
```

## Custom Template Oluşturma

1. `~/.claude/x-orchestrator/templates/my-template/` oluştur
2. `template.json` ekle
3. `scaffold/` içine dosya yapısını koy
4. `/x:new my-template` ile kullan
