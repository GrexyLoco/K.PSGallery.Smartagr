# Deprecated Functions
# Contains functions that are kept for backward compatibility but are deprecated

<#
.SYNOPSIS
    Creates a new Smart Release with automated version calculation and tag management

.DESCRIPTION
    New-AutoVersionRelease automatically determines the next appropriate semantic version based on
    existing tags and release type, then creates all necessary tags with smart tag management.
    This function combines version calculation with tag creation for streamlined releases.
    
    NOTE: This function is deprecated. Use New-SmartRelease from GitHubReleaseManagement.ps1 for
    full GitHub Release integration with the Draft → Tags → Publish workflow.

.PARAMETER ReleaseType
    The type of release to create: Major, Minor, or Patch
    Determines how the next version number is calculated from existing tags

.PARAMETER RepositoryPath
    Path to the Git repository where the release will be created
    Defaults to current directory if not specified

.PARAMETER PreReleaseLabel
    Optional pre-release label (e.g., "alpha", "beta", "rc")
    Creates a pre-release version with the specified label

.PARAMETER Force
    Forces release creation even if conflicts exist
    Use with caution as it may overwrite existing tags

.PARAMETER WhatIf
    Shows what version and tags would be created without actually creating them
    Useful for previewing the release strategy

.EXAMPLE
    New-AutoVersionRelease -ReleaseType Minor
    Creates the next minor version (e.g., v1.1.0 if current is v1.0.3)

.EXAMPLE
    New-AutoVersionRelease -ReleaseType Major -PreReleaseLabel "alpha"
    Creates the next major pre-release (e.g., v2.0.0-alpha)

.EXAMPLE
    New-AutoVersionRelease -ReleaseType Patch -WhatIf
    Shows what patch version would be created

.NOTES
    - Automatically calculates next version based on existing tags
    - Follows semantic versioning principles for version progression
    - Integrates with New-SemanticReleaseTags for complete tag management
    - Supports pre-release versions with custom labels
    - DEPRECATED: Use New-SmartRelease for GitHub Release integration
#>
function New-AutoVersionRelease {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Major", "Minor", "Patch")]
        [string]$ReleaseType,
        
        [Parameter()]
        [ValidateScript({
            if (-not (Test-Path $_ -PathType Container)) {
                throw "Repository path '$_' does not exist or is not a directory"
            }
            $true
        })]
        [string]$RepositoryPath = (Get-Location).Path,
        
        [Parameter()]
        [ValidatePattern("^[a-zA-Z0-9\-\.]+$")]
        [string]$PreReleaseLabel,
        
        [Parameter()]
        [switch]$Force
    )
    
    try {
        Write-SafeInfoLog -Message "Starting Smart Release creation" -Additional @{
            "ReleaseType" = $ReleaseType
            "PreReleaseLabel" = $PreReleaseLabel
        }
        
        # Get existing tags to determine next version
        $existingTags = Get-GitTags -RepositoryPath $RepositoryPath
        
        # Calculate next version based on release type
        $nextVersion = Get-NextSemanticVersion -ReleaseType $ReleaseType -ExistingTags $existingTags -PreReleaseLabel $PreReleaseLabel
        
        Write-SafeInfoLog -Message "Calculated next version" -Additional @{
            "NextVersion" = $nextVersion
            "BaseVersionCount" = $existingTags.Count
        }
        
        # Create semantic release tags with the calculated version
        $result = New-SemanticReleaseTags -TargetVersion $nextVersion -RepositoryPath $RepositoryPath -Force:$Force -WhatIf:$WhatIf
        
        return @{
            Success = $result.Success
            NextVersion = $nextVersion
            Strategy = $result.Strategy
            Message = "Smart Release completed: $nextVersion"
        }
    }
    catch {
        Write-SafeErrorLog -Message "Failed to create Smart Release" -Additional @{
            "ReleaseType" = $ReleaseType
            "Error" = $_.Exception.Message
        }
        
        return @{
            Success = $false
            NextVersion = $null
            Strategy = $null
            Message = "Failed to create Smart Release: $($_.Exception.Message)"
        }
    }
}
