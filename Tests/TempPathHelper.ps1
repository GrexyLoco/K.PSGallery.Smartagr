# TempPathHelper.ps1 - Simple helper function to avoid code duplication
# This creates a standardized temp path helper that can be dot-sourced in tests

function script:Get-TestTempPath {
    param([string]$Suffix = "$(Get-Random)")
    
    if ($env:TEMP) {
        return Join-Path $env:TEMP $Suffix
    } elseif ($env:TMPDIR) {
        return Join-Path $env:TMPDIR $Suffix  
    } else {
        return Join-Path (Get-Location) "temp/$Suffix"
    }
}

function script:New-TestTempDirectory {
    param(
        [string]$Prefix = "TempDir"
    )
    
    $tempPath = Get-TestTempPath -Suffix "${Prefix}_$(Get-Random)"
    $parentDir = Split-Path $tempPath -Parent
    
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    
    New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
    return $tempPath
}

function script:New-TestTempFile {
    param(
        [string]$Prefix = "TempFile",
        [string]$Extension = "psd1"
    )
    
    $tempPath = Get-TestTempPath -Suffix "${Prefix}_$(Get-Random).$Extension"
    $parentDir = Split-Path $tempPath -Parent
    
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    
    return $tempPath
}
