<#
.SYNOPSIS
    Creates smart Git tags for semantic versioning with fallback to manual tagging.

.DESCRIPTION
    Attempts to use K.PSGallery.Smartagr module for intelligent tag management.
    Falls back to manual tag creation if Smartagr is not available. Creates
    moving tags (v1, v1.2, latest) based on bump type.

.PARAMETER NewVersion
    The new semantic version (e.g., "1.2.3").

.PARAMETER BumpType
    The type of version bump (major/minor/patch/manual).

.PARAMETER ReleaseAuthor
    Git commit author name for tagging.

.PARAMETER ReleaseEmail
    Git commit author email for tagging.

.OUTPUTS
    Writes tag creation summary to GITHUB_STEP_SUMMARY.

.EXAMPLE
    ./Create-SmartTags.ps1 -NewVersion "1.2.3" -BumpType "patch" -ReleaseAuthor "bot" -ReleaseEmail "bot@example.com"

.NOTES
    Platform-independent script for GitHub Actions workflows.
    Prefers K.PSGallery.Smartagr but has robust manual fallback.
    Skips smart tags for prerelease versions.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$NewVersion,
    
    [Parameter(Mandatory = $true)]
    [string]$BumpType,
    
    [Parameter(Mandatory = $true)]
    [string]$ReleaseAuthor,
    
    [Parameter(Mandatory = $true)]
    [string]$ReleaseEmail
)

$newTag = "v$NewVersion"

Write-Output "## 🏷️ Smart Tag Management" >> $env:GITHUB_STEP_SUMMARY
Write-Output "**Base Tag:** ``$newTag``" >> $env:GITHUB_STEP_SUMMARY
Write-Output "**Bump Type:** ``$BumpType``" >> $env:GITHUB_STEP_SUMMARY
Write-Output "" >> $env:GITHUB_STEP_SUMMARY

git config user.name "$ReleaseAuthor"
git config user.email "$ReleaseEmail"

# Check if K.PSGallery.Smartagr is available
try {
    Import-Module K.PSGallery.Smartagr -ErrorAction Stop
    Write-Output "✅ Using K.PSGallery.Smartagr for smart tag management"
    
    # Use Smartagr for intelligent tag management
    # New-SemanticReleaseTags creates: base tag (v1.2.3), minor tag (v1.2), major tag (v1), latest
    $tagResult = New-SemanticReleaseTags -TargetVersion $newTag -Force
    
    Write-Output "✅ **Smart tags created via Smartagr**" >> $env:GITHUB_STEP_SUMMARY
    if ($tagResult.AllTags) {
        Write-Output "- Tags: $($tagResult.AllTags -join ', ')" >> $env:GITHUB_STEP_SUMMARY
    }
}
catch {
    Write-Output "⚠️ K.PSGallery.Smartagr not available - using manual tag creation"
    Write-Output "⚠️ **Fallback to manual tagging** (Smartagr not available)" >> $env:GITHUB_STEP_SUMMARY
    
    # Fallback: Manual smart tag creation
    $version = $NewVersion -replace '^v', ''
    $parts = $version -split '\.'
    $major = "v$($parts[0])"
    $minor = "v$($parts[0]).$($parts[1])"
    
    # Skip smart tags for prereleases
    if ($NewVersion -match '(alpha|beta|rc|preview|pre)') {
        Write-Output "⏭️ Skipping smart tags (prerelease version)"
        return
    }
    
    # ─────────────────────────────────────────────────────────────────────────
    # 🏷️ STEP 1: Create the base tag first (required before smart tags)
    # ─────────────────────────────────────────────────────────────────────────
    Write-Output "🏷️ Creating base tag: $newTag"
    
    # Check if base tag already exists
    $existingTag = git tag -l $newTag 2>$null
    if (-not $existingTag) {
        git tag -a $newTag -m "Release $newTag"
        git push origin $newTag
        Write-Output "- 🆕 Created base tag: ``$newTag``" >> $env:GITHUB_STEP_SUMMARY
    } else {
        Write-Output "- ℹ️ Base tag already exists: ``$newTag``" >> $env:GITHUB_STEP_SUMMARY
    }
    
    # ─────────────────────────────────────────────────────────────────────────
    # 🏷️ STEP 2: Create/update smart tags pointing to base tag
    # ─────────────────────────────────────────────────────────────────────────
    switch ($BumpType) {
        'patch' {
            git tag -f $minor $newTag
            git push -f origin $minor
            git tag -f $major $newTag
            git push -f origin $major
            Write-Output "- ✅ Updated: ``$minor``, ``$major``" >> $env:GITHUB_STEP_SUMMARY
        }
        'minor' {
            git tag -f $minor $newTag
            git push -f origin $minor
            git tag -f $major $newTag
            git push -f origin $major
            Write-Output "- 🆕 Created: ``$minor``" >> $env:GITHUB_STEP_SUMMARY
            Write-Output "- ✅ Updated: ``$major``" >> $env:GITHUB_STEP_SUMMARY
        }
        'major' {
            git tag -f $minor $newTag
            git push -f origin $minor
            git tag -f $major $newTag
            git push -f origin $major
            Write-Output "- 🆕 Created: ``$minor``, ``$major``" >> $env:GITHUB_STEP_SUMMARY
        }
        default {
            git tag -f $minor $newTag
            git push -f origin $minor
            git tag -f $major $newTag
            git push -f origin $major
            Write-Output "- ✅ Updated: ``$minor``, ``$major``" >> $env:GITHUB_STEP_SUMMARY
        }
    }
    
    # Always update 'latest'
    git tag -f latest $newTag
    git push -f origin latest
    Write-Output "- ✅ Updated: ``latest``" >> $env:GITHUB_STEP_SUMMARY
}
