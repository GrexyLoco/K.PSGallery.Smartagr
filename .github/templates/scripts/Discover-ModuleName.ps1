<#
.SYNOPSIS
    Auto-discovers PowerShell module name from PSD1 manifest file.

.DESCRIPTION
    Searches for .psd1 manifest files in the current directory (recursive depth 1)
    and extracts the module name from the BaseName property. Falls back to repository
    name if no PSD1 file is found.

.PARAMETER RepositoryName
    The GitHub repository name to use as fallback if no PSD1 file is found.

.OUTPUTS
    Writes module-name to GITHUB_OUTPUT and summary to GITHUB_STEP_SUMMARY.

.EXAMPLE
    ./Discover-ModuleName.ps1 -RepositoryName "MyRepo"

.NOTES
    Platform-independent script for GitHub Actions workflows.
    Uses only cross-platform cmdlets (Get-ChildItem, Select-Object).
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryName
)

# Platform-independent output
Write-Output "🔍 Auto-discovering module name from PSD1 manifest..."

# Find PSD1 manifest (cross-platform file search)
$psd1 = Get-ChildItem -Filter '*.psd1' -File -Recurse -Depth 1 | Select-Object -First 1

if ($psd1) {
    $moduleName = $psd1.BaseName
    Write-Output "✅ Auto-discovered module name: $moduleName"
    
    # GitHub Actions output
    "module-name=$moduleName" >> $env:GITHUB_OUTPUT
    
    # GitHub Actions summary
    "## 🔍 Module Discovery" >> $env:GITHUB_STEP_SUMMARY
    "**Auto-discovered:** ``$moduleName``" >> $env:GITHUB_STEP_SUMMARY
    "**From:** ``$($psd1.Name)``" >> $env:GITHUB_STEP_SUMMARY
} else {
    Write-Output "⚠️ No PSD1 file found - using repository name as fallback"
    
    # GitHub Actions output
    "module-name=$RepositoryName" >> $env:GITHUB_OUTPUT
    
    # GitHub Actions summary
    "## 🔍 Module Discovery" >> $env:GITHUB_STEP_SUMMARY
    "**Fallback to repo name:** ``$RepositoryName``" >> $env:GITHUB_STEP_SUMMARY
}
