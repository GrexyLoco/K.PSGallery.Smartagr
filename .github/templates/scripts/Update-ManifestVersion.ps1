<#
.SYNOPSIS
    Updates PowerShell module manifest version using K.PSGallery.ManifestVersioning.

.DESCRIPTION
    Installs and uses K.PSGallery.ManifestVersioning module to update the ModuleVersion
    field in .psd1 manifest files. Supports automatic Git commit and push with customizable
    commit message.

.PARAMETER NewVersion
    The semantic version to set in the manifest (e.g., "1.2.3").

.PARAMETER BumpType
    The type of version bump (major/minor/patch/manual).

.PARAMETER CommitChanges
    Whether to commit and push changes to Git (default: true).

.PARAMETER TriggeredBy
    GitHub actor who triggered the workflow (for commit message).

.OUTPUTS
    Sets GITHUB_OUTPUT variables: files-updated, files-found, old-version
    Writes detailed summary to GITHUB_STEP_SUMMARY.

.EXAMPLE
    ./Update-ManifestVersion.ps1 -NewVersion "1.2.3" -BumpType "patch" -CommitChanges $true -TriggeredBy "github-actions"

.NOTES
    Platform-independent script for GitHub Actions workflows.
    Requires K.PSGallery.ManifestVersioning module (auto-installed).
    Uses cross-platform PowerShell cmdlets only.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$NewVersion,
    
    [Parameter(Mandatory = $true)]
    [string]$BumpType,
    
    [Parameter(Mandatory = $false)]
    [bool]$CommitChanges = $true,
    
    [Parameter(Mandatory = $false)]
    [string]$TriggeredBy = 'github-actions'
)

Write-Output "## 📝 PowerShell Module Version Update" >> $env:GITHUB_STEP_SUMMARY
Write-Output "**Target Version:** ``$NewVersion``" >> $env:GITHUB_STEP_SUMMARY
Write-Output "" >> $env:GITHUB_STEP_SUMMARY

# Install K.PSGallery.ManifestVersioning module
Write-Output "📦 Installing K.PSGallery.ManifestVersioning..."
Install-Module -Name K.PSGallery.ManifestVersioning -Force -Scope CurrentUser -AllowClobber
Import-Module K.PSGallery.ManifestVersioning -Force

# Find PSD1 manifest
$psd1 = Get-ChildItem -Filter '*.psd1' -File -Recurse -Depth 1 | Select-Object -First 1

if (-not $psd1) {
    Write-Output "⚠️ No PSD1 file found - skipping version update"
    Write-Output "⚠️ **No PSD1 files found**" >> $env:GITHUB_STEP_SUMMARY
    "files-updated=0" >> $env:GITHUB_OUTPUT
    "files-found=0" >> $env:GITHUB_OUTPUT
    exit 0
}

Write-Output "📝 Found manifest: $($psd1.Name)"

# Prepare commit message for ManifestVersioning
$commitMessage = "🔖 Update module version to {version}

Auto-updated by release workflow
- Bump type: $BumpType
- Triggered by: $TriggeredBy"

# Update manifest version with Git integration
$result = Update-ModuleManifestVersion `
    -ManifestPath $psd1.FullName `
    -NewVersion $NewVersion `
    -CommitChanges $CommitChanges `
    -CommitMessage $commitMessage `
    -SkipCI $true

if ($result.Success) {
    Write-Output "✅ Successfully updated $($psd1.Name) from $($result.OldVersion) to $($result.NewVersion)"
    Write-Output "### Updated Files:" >> $env:GITHUB_STEP_SUMMARY
    Write-Output "- ✅ ``$($psd1.Name)`` → ``$NewVersion`` (was: ``$($result.OldVersion)``)" >> $env:GITHUB_STEP_SUMMARY
    
    if ($CommitChanges) {
        Write-Output "- 💾 **Changes committed and pushed to repository**" >> $env:GITHUB_STEP_SUMMARY
    }
    
    # Set outputs
    "files-updated=1" >> $env:GITHUB_OUTPUT
    "files-found=1" >> $env:GITHUB_OUTPUT
    "old-version=$($result.OldVersion)" >> $env:GITHUB_OUTPUT
} else {
    Write-Error "❌ Manifest update failed: $($result.ErrorMessage)"
    Write-Output "❌ **Update failed:** $($result.ErrorMessage)" >> $env:GITHUB_STEP_SUMMARY
    exit 1
}
