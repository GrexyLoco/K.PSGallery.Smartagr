<#
.SYNOPSIS
    Validates PowerShell module manifest (.psd1) for quality and completeness.

.DESCRIPTION
    This script performs comprehensive validation of module manifests to ensure they meet
    quality standards required for publishing to package repositories (GitHub Packages, PSGallery).
    
    Validates:
    - Required fields (Author, Description, Version, GUID, RootModule)
    - Recommended fields (Tags, ProjectUri, LicenseUri)
    - Field content quality (non-empty, meaningful values)
    - GUID format validation
    - Version format validation

.PARAMETER ModulePath
    Path to the module directory containing the .psd1 file.
    If not specified, searches in the current directory.

.PARAMETER ManifestPath
    Direct path to the .psd1 file.
    Takes precedence over ModulePath if specified.

.PARAMETER FailOnWarnings
    If specified, treats warnings as errors and fails the validation.

.EXAMPLE
    Test-ModuleManifestQuality.ps1
    # Validates manifest in current directory

.EXAMPLE
    Test-ModuleManifestQuality.ps1 -ManifestPath "./MyModule.psd1"
    # Validates specific manifest file

.EXAMPLE
    Test-ModuleManifestQuality.ps1 -ModulePath "./src/MyModule" -FailOnWarnings
    # Validates manifest with strict mode

.OUTPUTS
    Sets GitHub Action outputs:
    - manifest-valid: 'true' or 'false'
    - error-count: Number of errors found
    - warning-count: Number of warnings found

.NOTES
    Exit codes:
    - 0: Validation passed
    - 1: Validation failed (errors found)
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$ModulePath = '.',

    [Parameter()]
    [string]$ManifestPath,

    [Parameter()]
    [switch]$FailOnWarnings
)

# ═══════════════════════════════════════════════════════════════════════════
# 📋 Configuration
# ═══════════════════════════════════════════════════════════════════════════

$RequiredFields = @(
    @{ Name = 'RootModule';     Description = 'Main module file (.psm1)' }
    @{ Name = 'ModuleVersion';  Description = 'Semantic version number' }
    @{ Name = 'GUID';           Description = 'Unique module identifier' }
    @{ Name = 'Author';         Description = 'Module author name' }
    @{ Name = 'Description';    Description = 'Module description text' }
)

$RecommendedFields = @(
    @{ Name = 'CompanyName';          Description = 'Company/Organization name' }
    @{ Name = 'Copyright';            Description = 'Copyright statement' }
    @{ Name = 'PowerShellVersion';    Description = 'Minimum PowerShell version' }
    @{ Name = 'FunctionsToExport';    Description = 'Exported functions list' }
)

$RecommendedPSDataFields = @(
    @{ Name = 'Tags';         Description = 'Module tags for discovery' }
    @{ Name = 'ProjectUri';   Description = 'Project homepage URL' }
    @{ Name = 'LicenseUri';   Description = 'License file URL' }
)

# ═══════════════════════════════════════════════════════════════════════════
# 🔧 Helper Functions
# ═══════════════════════════════════════════════════════════════════════════

function Write-ValidationError {
    param([string]$Message, [string]$Field)
    $script:Errors += @{ Field = $Field; Message = $Message }
    Write-Output "❌ ERROR: $Message"
}

function Write-ValidationWarning {
    param([string]$Message, [string]$Field)
    $script:Warnings += @{ Field = $Field; Message = $Message }
    Write-Output "⚠️ WARNING: $Message"
}

function Write-ValidationSuccess {
    param([string]$Message)
    Write-Output "✅ $Message"
}

function Test-GuidFormat {
    param([string]$Value)
    try {
        [guid]::Parse($Value) | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Test-VersionFormat {
    param([string]$Value)
    try {
        [version]::Parse($Value) | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Test-MeaningfulValue {
    param([string]$Value, [string]$FieldName)
    
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }
    
    # Check for placeholder/dummy values
    $placeholders = @(
        'Unknown', 'TODO', 'TBD', 'N/A', 'None', 'Test', 
        'Author', 'Company', 'Description', 'Your Name',
        'your-name', 'your-company', 'example.com'
    )
    
    foreach ($placeholder in $placeholders) {
        if ($Value -eq $placeholder -or $Value -like "*$placeholder*") {
            return $false
        }
    }
    
    # Check for dummy GUIDs
    if ($FieldName -eq 'GUID') {
        $dummyGuids = @(
            '00000000-0000-0000-0000-000000000000',
            'a1b2c3d4-e5f6-7890-abcd-ef1234567890'  # Common placeholder
        )
        if ($Value -in $dummyGuids) {
            return $false
        }
    }
    
    return $true
}

# ═══════════════════════════════════════════════════════════════════════════
# 🚀 Main Validation Logic
# ═══════════════════════════════════════════════════════════════════════════

$script:Errors = @()
$script:Warnings = @()

Write-Output ""
Write-Output "═══════════════════════════════════════════════════════════════════"
Write-Output "🔍 PowerShell Module Manifest Quality Gate"
Write-Output "═══════════════════════════════════════════════════════════════════"
Write-Output ""

# ─────────────────────────────────────────────────────────────────────────────
# 📁 Find Manifest File
# ─────────────────────────────────────────────────────────────────────────────

if ($ManifestPath) {
    $psd1Path = $ManifestPath
} else {
    $psd1Files = Get-ChildItem -Path $ModulePath -Filter "*.psd1" -File -Recurse -Depth 1 |
        Where-Object { $_.Name -notlike 'PSScriptAnalyzerSettings*' }
    
    if ($psd1Files.Count -eq 0) {
        Write-ValidationError -Message "No .psd1 manifest file found in '$ModulePath'" -Field 'Manifest'
        Write-Output ""
        Write-Output "manifest-valid=false" >> $env:GITHUB_OUTPUT
        Write-Output "error-count=1" >> $env:GITHUB_OUTPUT
        Write-Output "warning-count=0" >> $env:GITHUB_OUTPUT
        exit 1
    }
    
    if ($psd1Files.Count -gt 1) {
        Write-Output "📋 Found multiple .psd1 files, validating primary manifest..."
        # Prefer manifest matching directory name
        $dirName = (Get-Item $ModulePath).Name
        $psd1Path = $psd1Files | Where-Object { $_.BaseName -eq $dirName } | Select-Object -First 1
        if (-not $psd1Path) {
            $psd1Path = $psd1Files | Select-Object -First 1
        }
        $psd1Path = $psd1Path.FullName
    } else {
        $psd1Path = $psd1Files[0].FullName
    }
}

Write-Output "📄 Manifest: $psd1Path"
Write-Output ""

# ─────────────────────────────────────────────────────────────────────────────
# 📖 Load and Parse Manifest
# ─────────────────────────────────────────────────────────────────────────────

try {
    $manifest = Test-ModuleManifest -Path $psd1Path -ErrorAction Stop -WarningAction SilentlyContinue
    Write-ValidationSuccess "Manifest syntax is valid"
} catch {
    Write-ValidationError -Message "Manifest syntax error: $($_.Exception.Message)" -Field 'Syntax'
    Write-Output ""
    Write-Output "manifest-valid=false" >> $env:GITHUB_OUTPUT
    Write-Output "error-count=1" >> $env:GITHUB_OUTPUT
    Write-Output "warning-count=0" >> $env:GITHUB_OUTPUT
    exit 1
}

# Also load raw content for additional checks
$rawContent = Get-Content $psd1Path -Raw

Write-Output ""
Write-Output "─────────────────────────────────────────────────────────────────────"
Write-Output "📋 REQUIRED FIELDS"
Write-Output "─────────────────────────────────────────────────────────────────────"

# ─────────────────────────────────────────────────────────────────────────────
# ✅ Validate Required Fields
# ─────────────────────────────────────────────────────────────────────────────

foreach ($field in $RequiredFields) {
    $value = $manifest.($field.Name)
    
    if ([string]::IsNullOrWhiteSpace($value)) {
        Write-ValidationError -Message "Missing required field: $($field.Name) ($($field.Description))" -Field $field.Name
    }
    elseif (-not (Test-MeaningfulValue -Value $value -FieldName $field.Name)) {
        Write-ValidationError -Message "Invalid/placeholder value for $($field.Name): '$value'" -Field $field.Name
    }
    else {
        # Additional format validation
        switch ($field.Name) {
            'GUID' {
                if (-not (Test-GuidFormat -Value $value)) {
                    Write-ValidationError -Message "Invalid GUID format: '$value'" -Field 'GUID'
                } else {
                    Write-ValidationSuccess "$($field.Name): $value"
                }
            }
            'ModuleVersion' {
                if (-not (Test-VersionFormat -Value $value)) {
                    Write-ValidationError -Message "Invalid version format: '$value'" -Field 'ModuleVersion'
                } else {
                    Write-ValidationSuccess "$($field.Name): $value"
                }
            }
            'Author' {
                if ($value.Length -lt 2) {
                    Write-ValidationError -Message "Author name too short: '$value'" -Field 'Author'
                } else {
                    Write-ValidationSuccess "$($field.Name): $value"
                }
            }
            'Description' {
                if ($value.Length -lt 20) {
                    Write-ValidationWarning -Message "Description is very short ($($value.Length) chars): '$value'" -Field 'Description'
                } else {
                    Write-ValidationSuccess "$($field.Name): $($value.Substring(0, [Math]::Min(60, $value.Length)))..."
                }
            }
            default {
                Write-ValidationSuccess "$($field.Name): $value"
            }
        }
    }
}

Write-Output ""
Write-Output "─────────────────────────────────────────────────────────────────────"
Write-Output "📋 RECOMMENDED FIELDS"
Write-Output "─────────────────────────────────────────────────────────────────────"

# ─────────────────────────────────────────────────────────────────────────────
# ⚠️ Validate Recommended Fields
# ─────────────────────────────────────────────────────────────────────────────

foreach ($field in $RecommendedFields) {
    $value = $manifest.($field.Name)
    
    if ([string]::IsNullOrWhiteSpace($value) -or ($value -is [array] -and $value.Count -eq 0)) {
        Write-ValidationWarning -Message "Missing recommended field: $($field.Name) ($($field.Description))" -Field $field.Name
    } else {
        if ($value -is [array]) {
            Write-ValidationSuccess "$($field.Name): $($value.Count) items"
        } else {
            Write-ValidationSuccess "$($field.Name): $value"
        }
    }
}

Write-Output ""
Write-Output "─────────────────────────────────────────────────────────────────────"
Write-Output "📋 PSDATA METADATA"
Write-Output "─────────────────────────────────────────────────────────────────────"

# ─────────────────────────────────────────────────────────────────────────────
# ⚠️ Validate PSData Fields
# ─────────────────────────────────────────────────────────────────────────────

$psData = $manifest.PrivateData?.PSData

if (-not $psData) {
    Write-ValidationWarning -Message "Missing PrivateData.PSData section (required for gallery publishing)" -Field 'PSData'
} else {
    foreach ($field in $RecommendedPSDataFields) {
        $value = $psData.($field.Name)
        
        if ([string]::IsNullOrWhiteSpace($value) -or ($value -is [array] -and $value.Count -eq 0)) {
            Write-ValidationWarning -Message "Missing PSData.$($field.Name) ($($field.Description))" -Field "PSData.$($field.Name)"
        } else {
            if ($value -is [array]) {
                Write-ValidationSuccess "PSData.$($field.Name): $($value -join ', ')"
            } else {
                Write-ValidationSuccess "PSData.$($field.Name): $value"
            }
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# 📊 Summary
# ─────────────────────────────────────────────────────────────────────────────

Write-Output ""
Write-Output "═══════════════════════════════════════════════════════════════════"
Write-Output "📊 VALIDATION SUMMARY"
Write-Output "═══════════════════════════════════════════════════════════════════"
Write-Output ""

$errorCount = $script:Errors.Count
$warningCount = $script:Warnings.Count

Write-Output "❌ Errors:   $errorCount"
Write-Output "⚠️ Warnings: $warningCount"
Write-Output ""

# Output for GitHub Actions
if ($env:GITHUB_OUTPUT) {
    "error-count=$errorCount" >> $env:GITHUB_OUTPUT
    "warning-count=$warningCount" >> $env:GITHUB_OUTPUT
}

# Generate GitHub Step Summary
if ($env:GITHUB_STEP_SUMMARY) {
    $summaryBuilder = [System.Text.StringBuilder]::new()
    [void]$summaryBuilder.AppendLine("## 🔍 Module Manifest Quality Gate")
    [void]$summaryBuilder.AppendLine("")
    [void]$summaryBuilder.AppendLine("| Metric | Count |")
    [void]$summaryBuilder.AppendLine("|--------|-------|")
    [void]$summaryBuilder.AppendLine("| ❌ Errors | ``$errorCount`` |")
    [void]$summaryBuilder.AppendLine("| ⚠️ Warnings | ``$warningCount`` |")
    [void]$summaryBuilder.AppendLine("")
    
    if ($errorCount -gt 0) {
        [void]$summaryBuilder.AppendLine("### ❌ Errors")
        [void]$summaryBuilder.AppendLine("")
        foreach ($err in $script:Errors) {
            [void]$summaryBuilder.AppendLine("- **$($err.Field)**: $($err.Message)")
        }
        [void]$summaryBuilder.AppendLine("")
    }
    
    if ($warningCount -gt 0) {
        [void]$summaryBuilder.AppendLine("### ⚠️ Warnings")
        [void]$summaryBuilder.AppendLine("")
        foreach ($warn in $script:Warnings) {
            [void]$summaryBuilder.AppendLine("- **$($warn.Field)**: $($warn.Message)")
        }
        [void]$summaryBuilder.AppendLine("")
    }
    
    [void]$summaryBuilder.AppendLine("---")
    $summaryBuilder.ToString() >> $env:GITHUB_STEP_SUMMARY
}

# Determine exit status
$isValid = $errorCount -eq 0
if ($FailOnWarnings -and $warningCount -gt 0) {
    $isValid = $false
    Write-Output "⚠️ Treating warnings as errors (FailOnWarnings enabled)"
}

if ($env:GITHUB_OUTPUT) {
    "manifest-valid=$($isValid.ToString().ToLower())" >> $env:GITHUB_OUTPUT
}

if ($isValid) {
    Write-Output "✅ Module manifest passed quality gate!"
    exit 0
} else {
    Write-Output "❌ Module manifest FAILED quality gate!"
    Write-Output ""
    Write-Output "💡 Fix the errors above before publishing."
    Write-Output "   Required fields must have valid, non-placeholder values."
    exit 1
}
