#Requires -Version 7.0

<#
.SYNOPSIS
    K.PSGallery.Smartagr - Smart Git Tag Management with Semantic Versioning Intelligence

.DESCRIPTION
    Smartagr (Smart Tags + Semantic Versioning + Aggregator) is an intelligent tag management 
    system that automatically decides how to handle Git tags based on semantic versioning principles.
    Focused exclusively on creating and managing Git tags with sophisticated version progression logic.
    
    Key Features:
    - Target version validation and conflict detection
    - Release tag creation with smart tag management
    - Moving tag intelligence (latest always follows newest)
    - Historical preservation (old smart tags become static on major/minor jumps)
    - PowerShell 7+ optimized with comprehensive parameter validation

.NOTES
    Module: K.PSGallery.Smartagr
    Author: K.PSGallery
    Version: 0.1.0
    PowerShell: 7.0+
    
    This module follows semantic versioning principles as defined at https://semver.org/
#>

#region Module Initialization

Write-Information "Loading K.PSGallery.Smartagr module.."

# Try to ensure LoggingModule is available for structured logging
try {
    if (-not (Get-Module -Name "K.PSGallery.LoggingModule" -ListAvailable)) {
        Write-Verbose "[INFO] - LoggingModule not found, attempting to install"
        Install-Module -Name "K.PSGallery.LoggingModule" -Force -Scope CurrentUser -ErrorAction Stop
        Write-Verbose "[INFO] - LoggingModule installed successfully"
    }
    
    if (-not (Get-Module -Name "K.PSGallery.LoggingModule")) {
        Import-Module -Name "K.PSGallery.LoggingModule" -Force -ErrorAction Stop
        Write-Verbose "[INFO] - LoggingModule imported successfully"
    }
} catch {
    Write-Warning "Could not install/import LoggingModule, using fallback logging. Error: $($_.Exception.Message)"
}

# SafeLogging functions are loaded via ScriptsToProcess in the manifest
# Verify they are available (fail fast if module package is corrupted)
if (-not (Get-Command 'Write-SafeInfoLog' -ErrorAction SilentlyContinue)) {
    # SafeLogging.ps1 should have been loaded via ScriptsToProcess
    # If not available, module package may be corrupted - try one more time to load it
    $safeLoggingPath = Join-Path $PSScriptRoot "src" "SafeLogging.ps1"
    if (Test-Path $safeLoggingPath) {
        . $safeLoggingPath
        Write-Verbose "SafeLogging functions loaded as fallback (ScriptsToProcess may have been skipped)"
    } else {
        throw "CRITICAL: SafeLogging functions not available and SafeLogging.ps1 not found at: $safeLoggingPath. Please reinstall the module with 'Install-Module K.PSGallery.Smartagr -Force'."
    }
}

Write-SafeInfoLog -Message "K.PSGallery.Smartagr module initialization started"
$moduleVersion = (Get-Content -Path "$PSScriptRoot\K.PSGallery.Smartagr.psd1" | Where-Object { $_ -match 'ModuleVersion' } | ForEach-Object { $_ -replace '.*=\s*''([^'']+)''', '$1' })
Write-SafeInfoLog "Current K.PSGallery.Smartagr module version: $moduleVersion"

# Load all other PowerShell files from the src directory (SafeLogging.ps1 already loaded via ScriptsToProcess)
$srcPath = Join-Path $PSScriptRoot "src"
if (Test-Path $srcPath) {
    # Exclude SafeLogging.ps1 as it's already loaded via ScriptsToProcess in manifest
    $sourceFiles = Get-ChildItem -Path $srcPath -Filter "*.ps1" -Recurse | Where-Object { $_.Name -ne "SafeLogging.ps1" }
    
    foreach ($file in $sourceFiles) {
        try {
            . $file.FullName
            Write-SafeDebugLog -Message "Loaded source file: $($file.Name)" -Additional @{
                "Path" = $file.FullName
            }
        }
        catch {
            Write-SafeErrorLog -Message "Failed to load source file: $($file.Name)" -Additional @{
                "Path" = $file.FullName
                "Error" = $_.Exception.Message
            }
            throw
        }
    }
    
    Write-SafeInfoLog -Message "Successfully loaded all source files from src directory" -Additional @{
        "SourcePath" = $srcPath
    }
} else {
    Write-SafeWarningLog -Message "Source directory not found" -Additional @{
        "ExpectedPath" = $srcPath
    }
}
#endregion

#region Exported Functions
# All exported functions are now defined in src/ files and loaded via ScriptsToProcess
# No functions should be defined here - this section is kept for clarity
#endregion
