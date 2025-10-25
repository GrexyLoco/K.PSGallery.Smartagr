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

<#
.SYNOPSIS
    Creates semantic release tags with smart tag management for Git repositories

.DESCRIPTION
    New-SemanticReleaseTags creates Git tags for a target semantic version with intelligent
    smart tag management. It validates the target version, creates the main release tag,
    and manages smart tags (vX, vX.Y) and moving tags (latest) according to semantic versioning principles.

.PARAMETER TargetVersion
    The semantic version to create tags for (e.g., "v1.2.3", "1.2.3", "v2.0.0-alpha.1")
    Accepts standard semantic versions with optional 'v' prefix and pre-release identifiers

.PARAMETER RepositoryPath
    Path to the Git repository where tags will be created
    Defaults to current directory if not specified

.PARAMETER Force
    Forces tag creation even if the target version already exists
    Use with caution as it will overwrite existing tags

.PARAMETER WhatIf
    Shows what operations would be performed without actually creating any tags
    Useful for validating the tag strategy before execution

.EXAMPLE
    New-SemanticReleaseTags -TargetVersion "v1.0.0"
    Creates release tag v1.0.0, smart tag v1→v1.0.0, and latest→v1.0.0

.EXAMPLE
    New-SemanticReleaseTags -TargetVersion "v1.2.3" -WhatIf
    Shows the tag creation strategy for v1.2.3 without creating any tags

.EXAMPLE
    New-SemanticReleaseTags -TargetVersion "v2.0.0-alpha" -Force
    Creates pre-release tags including v2→v2.0.0-alpha and latest→v2.0.0-alpha

.NOTES
    - Validates target version format and progression
    - Automatically determines smart tag strategy based on existing tags
    - Preserves historical smart tags when appropriate (major/minor version changes)
    - Moving tags (latest) always follow the newest version
    - Supports pre-release versions with appropriate tag handling
#>
function New-SemanticReleaseTags {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetVersion,
        
        [Parameter()]
        [ValidateScript({
            if (-not (Test-Path $_ -PathType Container)) {
                throw "Repository path '$_' does not exist or is not a directory"
            }
            $true
        })]
        [string]$RepositoryPath = (Get-Location).Path,
        
        [Parameter()]
        [switch]$Force
    )
    
    try {
        Write-SafeInfoLog -Message "Starting semantic release tag creation" -Additional @{
            "TargetVersion" = $TargetVersion
        }
        
        # Strict validation: Only allow standard semantic versions with alpha, beta, rc pre-release labels
        $strictPattern = '^v?\d+\.\d+\.\d+(-(?:alpha|beta|rc)(?:\.\d+)?)?(\+.+)?$'
        if ($TargetVersion -notmatch $strictPattern) {
            throw "Invalid semantic version format: '$TargetVersion'. Only standard versions (e.g., v1.2.3) and pre-release versions with 'alpha', 'beta', or 'rc' labels are allowed (e.g., v1.2.3-alpha.1, v2.0.0-beta, v1.5.0-rc.2)."
        }
        
        # Normalize version format (ensure v prefix)
        $normalizedVersion = if ($TargetVersion.StartsWith('v')) { $TargetVersion } else { "v$TargetVersion" }
        Write-SafeDebugLog -Message "Version normalized" -Additional @{
            "Original" = $TargetVersion
            "Normalized" = $normalizedVersion
        }
        
        # Set working directory to repository path
        $originalLocation = Get-Location
        Set-Location -Path $RepositoryPath
        Write-SafeDebugLog -Message "Changed to repository directory" -Additional @{
            "RepositoryPath" = $RepositoryPath
        }
        
        try {
            # Validate Git repository (skip in WhatIf mode)
            if ($PSCmdlet.ShouldProcess("Validate repository", "Git repository at '$RepositoryPath'")) {
                Invoke-GitValidation -RepositoryPath $RepositoryPath
            }
            
            # Get existing tags
            $existingTags = Get-ExistingSemanticTags -RepositoryPath $RepositoryPath
            
            # Validate target version
            Write-SafeInfoLog -Message "Starting target version validation" -Additional @{
                "TargetVersion" = $normalizedVersion
                "ExistingTagCount" = $existingTags.Count
                "Force" = $Force.IsPresent
            }
            
            # Suppress validation result output to pipeline
            $validation = Test-TargetVersionValidity -TargetVersion $normalizedVersion -ExistingTags $existingTags -Force:$Force
            
            if (-not $validation.IsValid) {
                throw "Version validation failed: $($validation.ErrorMessage)"
            }
            
            # Calculate tag strategy
            $strategy = Get-SmartTagStrategy -TargetVersion $normalizedVersion -ExistingTags $existingTags
            
            # Execute or preview the strategy
            if ($PSCmdlet.ShouldProcess("Semantic version tags for $normalizedVersion", "Create tags")) {
                # Create the actual tags
                # 1. Create release tag (check for errors)
                $tagResult = New-GitTag -TagName $normalizedVersion -RepositoryPath $RepositoryPath
                if (-not $tagResult.Success) {
                    throw "Failed to create release tag '$normalizedVersion': $($tagResult.ErrorMessage)"
                }
                
                # 2. Create smart tags (pointing to release tag, suppress output)
                foreach ($smartTag in $strategy.SmartTagsToCreate) {
                    $tagResult = New-GitTag -TagName $smartTag.Name -TargetRef $normalizedVersion -RepositoryPath $RepositoryPath -Force
                    if (-not $tagResult.Success) {
                        throw "Failed to create smart tag '$($smartTag.Name)': $($tagResult.ErrorMessage)"
                    }
                }
                
                # 3. Update moving tags (pointing to release tag, suppress output)
                foreach ($movingTag in $strategy.MovingTagsToUpdate) {
                    $tagResult = New-GitTag -TagName $movingTag.Name -TargetRef $normalizedVersion -RepositoryPath $RepositoryPath -Force
                    if (-not $tagResult.Success) {
                        throw "Failed to create moving tag '$($movingTag.Name)': $($tagResult.ErrorMessage)"
                    }
                }
                
                # 4. Push all tags (check for errors)
                $pushResult = Push-GitTags -RepositoryPath $RepositoryPath
                if (-not $pushResult.Success) {
                    throw "Failed to push tags to remote: $($pushResult.ErrorMessage)"
                }
                
                Write-SafeInfoLog -Message "Successfully created semantic release tags" -Additional @{
                    "ReleaseTag" = $normalizedVersion
                    "SmartTagCount" = $strategy.SmartTagsToCreate.Count
                    "MovingTagCount" = $strategy.MovingTagsToUpdate.Count
                }
            }
            
            # Collect all created/updated tags for result (filter out empty values)
            $allTags = @($normalizedVersion)
            
            # DEBUG: Output strategy object details BEFORE filtering
            Write-SafeDebugLog -Message "=== STRATEGY DEBUG START ===" -Additional @{
                "SmartTagsCount" = $strategy.SmartTagsToCreate.Count
                "MovingTagsCount" = $strategy.MovingTagsToUpdate.Count
            }
            Write-SafeDebugLog -Message "SmartTagsToCreate JSON" -Additional @{
                "SmartTags" = ($strategy.SmartTagsToCreate | ConvertTo-Json -Depth 3)
            }
            Write-SafeDebugLog -Message "MovingTagsToUpdate JSON" -Additional @{
                "MovingTags" = ($strategy.MovingTagsToUpdate | ConvertTo-Json -Depth 3)
            }
            
            if ($strategy.SmartTagsToCreate) {
                $smartTagNames = @($strategy.SmartTagsToCreate | ForEach-Object { $_.Name } | Where-Object { $_ })
                Write-SafeDebugLog -Message "SmartTagNames extracted" -Additional @{
                    "Tags" = ($smartTagNames -join ', ')
                }
                $allTags += $smartTagNames
            }
            if ($strategy.MovingTagsToUpdate) {
                # MovingTagsToUpdate can be a single object or array - ensure array handling
                $movingTagsArray = @($strategy.MovingTagsToUpdate)
                $movingTagNames = @($movingTagsArray | ForEach-Object { $_.Name } | Where-Object { $_ })
                Write-SafeDebugLog -Message "MovingTagNames extracted" -Additional @{
                    "Tags" = ($movingTagNames -join ', ')
                    "MovingTagsArrayCount" = $movingTagsArray.Count
                    "MovingTagsArrayType" = $movingTagsArray.GetType().Name
                }
                $allTags += $movingTagNames
            }
            
            Write-SafeDebugLog -Message "AllTags final" -Additional @{
                "AllTags" = ($allTags -join ', ')
            }
            
            return @{
                Success = $true
                TargetVersion = $normalizedVersion
                ReleaseTag = $normalizedVersion
                SmartTags = @($strategy.SmartTagsToCreate | ForEach-Object { $_.Name } | Where-Object { $_ })
                MovingTags = @(@($strategy.MovingTagsToUpdate) | ForEach-Object { $_.Name } | Where-Object { $_ })
                AllTags = $allTags
                Message = "Semantic release tags created successfully"
            }
        }
        finally {
            # Restore original location
            Set-Location -Path $originalLocation
        }
    }
    catch {
        # Log the error with full details
        Write-SafeErrorLog -Message "Failed to create semantic release tags" -Additional @{
            "TargetVersion" = $TargetVersion
            "Error" = $_.Exception.Message
            "StackTrace" = $_.ScriptStackTrace
        }
        
        # CRITICAL: Output error to console for visibility in CI/CD logs
        Write-SafeWarningLog -Message "SMARTAGR TAG CREATION FAILED" -Additional @{
            "TargetVersion" = $TargetVersion
            "Error" = $_.Exception.Message
            "ErrorType" = $_.Exception.GetType().FullName
            "InnerException" = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $null }
            "StackTrace" = $_.ScriptStackTrace
        }
        
        # For validation errors (ArgumentException), rethrow to allow proper error handling
        if ($_.Exception -is [System.ArgumentException] -or $_.Exception.Message -match "Invalid semantic version format") {
            throw
        }
        
        # For operational errors, return structured result with detailed error info
        return @{
            Success = $false
            TargetVersion = $TargetVersion
            ReleaseTag = $null
            SmartTags = @()
            MovingTags = @()
            AllTags = @()
            Message = "Failed to create semantic release tags: $($_.Exception.Message)"
            Error = $_.Exception.Message
            ErrorType = $_.Exception.GetType().FullName
            StackTrace = $_.ScriptStackTrace
        }
    }
}

<#
.SYNOPSIS
    Creates a new Smart Release with automated version calculation and tag management

.DESCRIPTION
    New-SmartRelease automatically determines the next appropriate semantic version based on
    existing tags and release type, then creates all necessary tags with smart tag management.
    This function combines version calculation with tag creation for streamlined releases.

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
    New-SmartRelease -ReleaseType Minor
    Creates the next minor version (e.g., v1.1.0 if current is v1.0.3)

.EXAMPLE
    New-SmartRelease -ReleaseType Major -PreReleaseLabel "alpha"
    Creates the next major pre-release (e.g., v2.0.0-alpha)

.EXAMPLE
    New-SmartRelease -ReleaseType Patch -WhatIf
    Shows what patch version would be created

.NOTES
    - Automatically calculates next version based on existing tags
    - Follows semantic versioning principles for version progression
    - Integrates with New-SemanticReleaseTags for complete tag management
    - Supports pre-release versions with custom labels
#>
function New-SmartRelease {
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

#endregion
