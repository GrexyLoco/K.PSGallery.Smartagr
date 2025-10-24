# K.PSGallery.Smartagr

[![PowerShell Gallery Version](https://img.shields.io/powershellgallery/v/K.PSGallery.Smartagr?logo=powershell&logoColor=white)](https://www.powershellgallery.com/packages/K.PSGallery.Smartagr)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/K.PSGallery.Smartagr?logo=powershell&logoColor=white)](https://www.powershellgallery.com/packages/K.PSGallery.Smartagr)
[![GitHub Release](https://img.shields.io/github/v/release/GrexyLoco/K.PSGallery.Smartagr?logo=github)](https://github.com/GrexyLoco/K.PSGallery.Smartagr/releases)
[![License](https://img.shields.io/github/license/GrexyLoco/K.PSGallery.Smartagr)](https://github.com/GrexyLoco/K.PSGallery.Smartagr/blob/master/LICENSE)
[![CI/CD](https://img.shields.io/github/actions/workflow/status/GrexyLoco/K.PSGallery.Smartagr/check_and_dispatch.yml?branch=master&label=CI%2FCD&logo=github)](https://github.com/GrexyLoco/K.PSGallery.Smartagr/actions)

**Smartagr**: Smart Git tag management with semantic versioning intelligence. The smart tag aggregator that automates creation and management of semantic version tags with intelligent strategies for major, minor, and patch releases.

---

## 📦 Release History

| Version | Release Date | Type | Highlights |
|---------|--------------|------|------------|
| [v0.1.11](https://github.com/GrexyLoco/K.PSGallery.Smartagr/releases/tag/v0.1.11) | Oct 24, 2025 | Patch | Current stable release |

**Current Stable**: [![v0.1.11](https://img.shields.io/badge/v0.1.11-stable-brightgreen?logo=github)](https://github.com/GrexyLoco/K.PSGallery.Smartagr/releases/tag/v0.1.11)  
**Smart Tags**: `latest`, `v0`, `v0.1` (all point to v0.1.11)

---

## 🎯 Smart Tag Intelligence

**Smartagr** (Smart Tags + Semantic Versioning + Aggregator) is an intelligent tag management system that automatically decides how to handle Git tags based on semantic versioning principles:

### 🧠 Smart Tag Strategy

- **Moving Tags**: `latest`, `v1`, `v1.2` - These tags move with new releases
- **Static Tags**: `v1.0.0`, `v1.2.3` - These are preserved as historical markers
- **Smart Decisions**: The system automatically determines when to move vs. preserve tags

### 📊 Tag Behavior Examples

| Scenario | New Release | Moving Tags | Static Tags Created | Previous Behavior |
|----------|-------------|-------------|-------------------|------------------|
| First release | `v1.0.0` | `latest`, `v1`, `v1.0` | `v1.0.0` | - |
| Patch update | `v1.0.1` | `latest`, `v1`, `v1.0` | `v1.0.1` | `v1.0.0` stays |
| Minor update | `v1.1.0` | `latest`, `v1`, `v1.1` | `v1.1.0` | `v1.0` becomes static |
| Major update | `v2.0.0` | `latest`, `v2`, `v2.0` | `v2.0.0` | All `v1.x` become static |

## 🚀 Quick Start

```powershell
# Import the module
Import-Module K.PSGallery.Smartagr

# Create tags for a new release
New-SemanticReleaseTags -TargetVersion "v1.2.0" -RepositoryPath "C:\MyRepo" -Verbose

# Get all semantic version tags
Get-SemanticVersionTags -RepositoryPath "C:\MyRepo"

# Find the latest semantic version
Get-LatestSemanticTag -RepositoryPath "C:\MyRepo"
```

## 📦 Installation

```powershell
# From PowerShell Gallery
Install-Module K.PSGallery.Smartagr -Scope CurrentUser

# Or import directly (for development)
Import-Module ./K.PSGallery.Smartagr.psd1
```

## 💡 Core Functions

### `New-SemanticReleaseTags`
Creates semantic version tags with smart tag intelligence.

```powershell
New-SemanticReleaseTags -TargetVersion "v1.2.0" -RepositoryPath "C:\MyRepo"

# Pre-release versions with standard identifiers
New-SemanticReleaseTags -TargetVersion "v2.0.0-alpha.1" -RepositoryPath "C:\MyRepo"
New-SemanticReleaseTags -TargetVersion "v2.0.0-beta" -RepositoryPath "C:\MyRepo"
New-SemanticReleaseTags -TargetVersion "v2.0.0-rc.2" -RepositoryPath "C:\MyRepo"
```

**Example Output:**
```
Creating semantic release tags for version: v1.2.0
✓ Created tag: v1.2.0
✓ Created smart tag: v1.2 (pointing to v1.2.0)
✓ Created smart tag: v1 (pointing to v1.2.0)
✓ Updated smart tag: latest (pointing to v1.2.0)
✓ Successfully created 4 tags
```

**Parameters:**
- `TargetVersion`: Strict semantic version (e.g., "v1.2.0", "2.0.0-alpha.1", "v1.0.0-beta", "v2.0.0-rc.2")
- `RepositoryPath`: Path to Git repository
- `Force`: Override duplicate version checks  
- `PushToRemote`: Automatically push tags to remote

**Supported Pre-release Identifiers:**
- `alpha` - Early development versions (e.g., "v1.0.0-alpha", "v1.0.0-alpha.1")
- `beta` - Feature-complete but potentially unstable (e.g., "v1.0.0-beta", "v1.0.0-beta.2")  
- `rc` - Release candidates ready for production (e.g., "v1.0.0-rc", "v1.0.0-rc.1")

### `Get-SemanticVersionTags`
Retrieves and analyzes semantic version tags.

```powershell
# Get all semantic version tags
$tags = Get-SemanticVersionTags -RepositoryPath "C:\MyRepo"

# Filter by version range
$tags = Get-SemanticVersionTags -RepositoryPath "C:\MyRepo" -MinVersion "1.0.0" -MaxVersion "2.0.0"
```

**Example Output:**
```
TagName    Version    IsPreRelease SmartTags
-------    -------    ------------ ---------
v2.1.0     2.1.0      False        {v2.1, v2, latest}
v2.0.1     2.0.1      False        {v2.0}
v2.0.0     2.0.0      False        {}
v1.5.2     1.5.2      False        {v1.5, v1}
v1.0.0     1.0.0      False        {}
```

```powershell
# Include pre-release versions
$tags = Get-SemanticVersionTags -RepositoryPath "C:\MyRepo" -IncludePreRelease
```

**Parameters:**
- `RepositoryPath`: Path to Git repository
- `MinVersion`: Minimum version to include (optional)
- `MaxVersion`: Maximum version to include (optional)
- `IncludePreRelease`: Include pre-release versions

### `Get-LatestSemanticTag`
Finds the latest semantic version tag.

```powershell
# Get latest stable version
$latest = Get-LatestSemanticTag -RepositoryPath "C:\MyRepo"

# Include pre-release versions
$latest = Get-LatestSemanticTag -RepositoryPath "C:\MyRepo" -IncludePreRelease
```

**Example Output:**
```
TagName    Version    IsPreRelease SmartTags
-------    -------    ------------ ---------
v2.1.0     2.1.0      False        {v2.1, v2, latest}
```

**Parameters:**
- `RepositoryPath`: Path to Git repository
- `IncludePreRelease`: Include pre-release versions in search

### `New-GitHubRelease`
Creates GitHub Releases with automatic tag creation and smart release notes.

```powershell
# Create release with smart tags
New-GitHubRelease -Version "v1.2.0" -CreateTags -PushTags

# Create draft pre-release
New-GitHubRelease -Version "v2.0.0-alpha.1" -Draft -CreateTags

# Create release with custom notes
New-GitHubRelease -Version "v1.5.0" -ReleaseNotesFile "CHANGELOG.md" -CreateTags
```

**Example Output:**
```
Creating GitHub release v1.2.0 with smart tags
✓ Created tag: v1.2.0
✓ Created smart tag: v1.2 (pointing to v1.2.0)
✓ Created smart tag: v1 (pointing to v1.2.0)
✓ Updated smart tag: latest (pointing to v1.2.0)
✅ GitHub Release created: v1.2.0
🔗 Release URL: https://github.com/owner/repo/releases/tag/v1.2.0
```

**Parameters:**
- `Version`: Semantic version for the release
- `CreateTags`: Also create smart tags with New-SemanticReleaseTags
- `PushTags`: Push created tags to remote repository
- `Draft`: Create as draft release
- `Prerelease`: Mark as prerelease (auto-detected from version)
- `ReleaseNotes`: Custom release notes text
- `ReleaseNotesFile`: Path to file containing release notes
- `GenerateNotes`: Use GitHub's automatic release notes generation

**Requirements:**
- GitHub CLI (`gh`) installed and authenticated
- Repository must be hosted on GitHub

## 🔧 Advanced Configuration

### Smart Tag Customization

```powershell
# Control which smart tags to create
New-SemanticReleaseTags -TargetVersion "v1.2.0" -RepositoryPath "C:\MyRepo" `
    -CreateMajorTag:$false -CreateMinorTag:$true -CreateLatestTag:$true
```

### Pre-release Handling

Pre-release versions (alpha, beta, rc) are handled with special care to avoid disrupting stable release workflows:

```powershell
# Pre-release versions create exact tags only - no smart tags affected
New-SemanticReleaseTags -TargetVersion "v1.2.0-alpha.1" -RepositoryPath "C:\MyRepo"
# Creates: v1.2.0-alpha.1 (only)
# Preserves: v1, v1.2, latest (pointing to stable versions)

# Multiple pre-release iterations
New-SemanticReleaseTags -TargetVersion "v1.2.0-beta.1" -RepositoryPath "C:\MyRepo"
# Creates: v1.2.0-beta.1 (only)
# Smart tags remain unchanged

# Final release updates smart tags
New-SemanticReleaseTags -TargetVersion "v1.2.0" -RepositoryPath "C:\MyRepo"
# Creates: v1.2.0, v1.2, v1, latest
```

**Pre-release Behavior Rules:**
- ✅ Creates exact version tag (e.g., `v1.2.0-alpha.1`)
- ❌ Never updates smart tags (`v1`, `v1.2`, `latest`)
- ✅ Allows parallel stable and pre-release development
- ✅ Supports standard pre-release identifiers: `alpha`, `beta`, `rc`

## 🧪 Smart Tag Logic

### Moving vs. Static Tags

The module implements sophisticated logic to determine when tags should move vs. become static:

1. **Patch Releases** (v1.0.0 → v1.0.1):
   - Move: `v1`, `v1.0`, `latest`
   - Keep static: `v1.0.0`

2. **Minor Releases** (v1.0.5 → v1.1.0):
   - Move: `v1`, `latest`
   - New: `v1.1`
   - Become static: `v1.0`

3. **Major Releases** (v1.5.3 → v2.0.0):
   - Move: `latest`
   - New: `v2`, `v2.0`
   - Become static: All `v1.x` tags

### Version Validation

```powershell
# The module validates versions before creating tags
# Prevents: Version regression, duplicate tags, invalid formats
New-SemanticReleaseTags -TargetVersion "v1.0.0" -RepositoryPath "C:\MyRepo" -Verbose

# Override validation (use with caution)
New-SemanticReleaseTags -TargetVersion "v1.0.0" -RepositoryPath "C:\MyRepo" -Force
```

## 🏗️ Architecture

```
K.PSGallery.Smartagr/
├── K.PSGallery.Smartagr.psd1     # Module manifest
├── K.PSGallery.Smartagr.psm1     # Main module (public functions)
├── src/
│   ├── GitOperations.ps1          # Git CLI operations
│   └── SemanticVersionUtilities.ps1 # Version parsing & strategy
├── Tests/
│   └── K.PSGallery.Smartagr.Tests.ps1 # Pester tests
└── Demo.ps1                       # Usage examples
```

## 📋 Requirements

- **PowerShell 7.0+**: Modern PowerShell with enhanced semantic versioning support
- **Git CLI**: Available in PATH for repository operations
- **Pester 5+**: For running tests (development only)

## 🧪 Testing

```powershell
# Run all tests
Invoke-Pester -Path ./Tests/

# Run specific test categories
Invoke-Pester -Path ./Tests/ -Tag "Unit"

# Test with coverage
Invoke-Pester -Path ./Tests/ -CodeCoverage ./src/*.ps1
```

## 🤝 Contributing

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Development Setup

```powershell
# Clone and setup
git clone https://github.com/your-org/K.PSGallery.Smartagr.git
cd K.PSGallery.Smartagr

# Import for development
Import-Module ./K.PSGallery.Smartagr.psd1 -Force

# Run tests
Invoke-Pester -Path ./Tests/
```

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Related Projects

- [K.PSGallery.SemanticVersioning](https://github.com/your-org/K.PSGallery.SemanticVersioning) - Parent semantic versioning module
- [K.Actions.NextVersion](https://github.com/your-org/K.Actions.NextVersion) - GitHub Actions for version management

## 📊 Changelog

### v1.0.0
- ✨ Initial release with smart tag intelligence
- 🎯 Support for moving and static tag strategies
- 🔧 Comprehensive semantic version validation
- 📚 Full PowerShell 7+ compatibility
- 🧪 Complete test coverage with Pester 5

---

**Smartagr** - Where smart meets tags! 🏷️✨
