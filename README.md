# K.PSGallery.SemanticVersioning

## 🎯 Überblick

Dieses PowerShell-Modul bietet automatisierte Semantic Versioning Logik für PowerShell-Projekte. Es erkennt Version-Bumps basierend auf Git-Commits, prüft auf ungewöhnliche Versionen, unterstützt sichere Force-Releases und integriert sich optimal in CI/CD-Workflows.

## ✨ Features

- **🔍 Automatische Version-Erkennung**: Major/Minor/Patch-Bumps basierend auf Commit-Messages und Branch-Patterns
- **⚠️ Unusual Version Detection**: Erkennt ungewöhnliche erste Versionen (z.B. 2.0.0 statt 1.0.0) 
- **🛡️ Sichere Force-Release-Mechanik**: Mit Audit-Trail und zeitlich begrenzter Validation
- **🔗 GitHub Actions Integration**: Nahtlose Integration in Auto-Publish-Workflows
- **📊 Umfangreiche Logging**: Vollständige Nachverfolgung aller Versionierungs-Entscheidungen
- **🧪 Pester-kompatibel**: Vollständige Unit-Test-Abdeckung

## 📦 Installation

```powershell
Install-Module K.PSGallery.SemanticVersioning -Scope CurrentUser
```

## 🚀 Verwendung

### Basis-Funktionalität
```powershell
Import-Module K.PSGallery.SemanticVersioning

# Ermittle nächste Semantic Version
$result = Get-NextSemanticVersion -ManifestPath "./MyModule.psd1" -BranchName "main"

# Erste Release-Validierung
$firstRelease = Get-FirstSemanticVersion -CurrentVersion "1.0.0" -BranchName "main"
```

### Force-Release für ungewöhnliche Versionen
```powershell
# Wenn eine ungewöhnliche Version erkannt wird:
$mismatch = Set-MismatchRecord -Version "2.0.0" -BranchName "main"

# Force-Release nach Validation
$forceResult = Set-ForceSemanticVersion -Version "2.0.0" -BranchName "main"
```

## 🧪 Tests

```powershell
# Alle Tests ausführen
Invoke-Pester -Path './Tests' -Output Detailed
```

## 🔄 Auto-Publish

Das Modul ist für automatisches Publishing via GitHub Actions vorbereitet:
- Tests werden automatisch bei Push auf main/master ausgeführt  
- Bei erfolgreichen Tests wird Auto-Publish-Pipeline getriggert
- Siehe `.github/workflows/check_and_dispatch.yml`

## 📋 Abhängigkeiten

- **K.PSGallery.LoggingModule** (>= 1.1.46): Für erweiterte Logging-Funktionalität
- **PowerShell** >= 5.1
- **Git**: Für Repository-Analyse

## 📄 Lizenz

MIT License
