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
Write-Verbose "Loading K.PSGallery.Smartagr module..."

# Import LoggingModule for structured logging (optional)
$script:LoggingAvailable = $false
try {
    Import-Module K.PSGallery.LoggingModule -Force -ErrorAction Stop
    $script:LoggingAvailable = $true
    Write-InfoLog "K.PSGallery.Smartagr module initialization started"
}
catch {
    Write-Warning "K.PSGallery.LoggingModule not available. Install with: Install-Module K.PSGallery.LoggingModule"
    Write-Warning "Continuing with basic logging only"
}

# Helper function for safe logging
function Write-SafeLog {
    param(
        [string]$Level,
        [string]$Message,
        [string]$Context = ""
    )
    
    if ($script:LoggingAvailable) {
        switch ($Level) {
            "DEBUG" { Write-DebugLog $Message -Context $Context }
            "INFO" { Write-InfoLog $Message -Context $Context }
            "WARNING" { Write-WarningLog $Message -Context $Context }
            "ERROR" { Write-ErrorLog $Message -Context $Context }
            default { Write-InfoLog $Message -Context $Context }
        }
    } else {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] [$Level] $Message"
        if ($Context) {
            $logMessage += " | Context: $Context"
        }
        
        switch ($Level) {
            "ERROR" { Write-Error $logMessage }
            "WARNING" { Write-Warning $logMessage }
            default { Write-Verbose $logMessage }
        }
    }
}

# Import supporting functions from src directory
$srcPath = Join-Path $PSScriptRoot 'src'
if (Test-Path $srcPath) {
    Get-ChildItem -Path $srcPath -Filter '*.ps1' -Recurse | ForEach-Object {
        Write-Verbose "Loading function file: $($_.Name)"
        . $_.FullName
        Write-SafeLog "DEBUG" "Loaded source file: $($_.Name)" "Path: $($_.FullName)"
    }
    Write-SafeLog "INFO" "Successfully loaded all source files from src directory" "SourcePath: $srcPath"
} else {
    Write-SafeLog "WARNING" "Source directory not found" "ExpectedPath: $srcPath"
}
#endregion

#region Public Functions

function New-SemanticReleaseTags {
    <#
    .SYNOPSIS
        Creates a complete semantic version release with all associated tags including smart tags and moving tags.

    .DESCRIPTION
        This function creates a comprehensive semantic version release by generating the primary release tag
        and all associated smart tags (v1, v1.2) and moving tags (latest). It intelligently handles tag
        progression logic where smart tags become static when major/minor versions advance.

        The function validates the target version, checks for conflicts, and creates tags in the correct
        order to maintain consistency. It supports both local tag creation and automatic remote pushing.

    .PARAMETER TargetVersion
        The semantic version to create as a release tag. Accepts formats like "v1.2.3", "1.2.3",
        "v2.0.0-alpha.1", etc. Must follow semantic versioning specification.

    .PARAMETER RepositoryPath
        Path to the Git repository where tags will be created. Defaults to the current working directory.
        The path must contain a valid Git repository with at least one commit.

    .PARAMETER CommitSha
        Specific commit SHA to tag. Defaults to HEAD (latest commit). The commit must exist and be
        accessible in the current repository state.

    .PARAMETER Force
        Forces creation of tags even if they already exist. This will overwrite existing tags with
        the same name. Use with caution as this can break existing references.

    .PARAMETER PushToRemote
        Automatically pushes all created tags to the remote repository after local creation.
        Requires appropriate remote access permissions.

    .OUTPUTS
        [PSCustomObject] Returns an object containing details about the created tags:
        - TargetVersion: The release version that was created
        - ReleaseTags: Array of release tags created
        - SmartTags: Array of smart tags created or updated
        - MovingTags: Array of moving tags created or updated
        - StaticTags: Array of tags that became static (historical preservation)
        - Success: Boolean indicating overall operation success
        - Warnings: Array of warning messages if any issues occurred

    .EXAMPLE
        New-SemanticReleaseTags -TargetVersion "v1.0.0"
        
        Creates the first release with tags:
        - v1.0.0 (release tag)
        - v1 → v1.0.0 (smart tag)
        - latest → v1.0.0 (moving tag)

    .EXAMPLE
        New-SemanticReleaseTags -TargetVersion "v1.2.3" -PushToRemote
        
        Creates a patch release and immediately pushes to remote:
        - v1.2.3 (release tag)
        - v1 → v1.2.3 (smart tag updated)
        - v1.2 → v1.2.3 (smart tag updated)
        - latest → v1.2.3 (moving tag updated)

    .EXAMPLE
        New-SemanticReleaseTags -TargetVersion "v2.0.0" -WhatIf
        
        Previews major version release showing that v1 and v1.x tags will become static:
        - v2.0.0 (release tag) [PREVIEW]
        - v1 → v1.3.4 (will become STATIC)
        - v1.3 → v1.3.4 (will become STATIC)
        - v2 → v2.0.0 (new smart tag) [PREVIEW]
        - latest → v2.0.0 (moving tag) [PREVIEW]

    .EXAMPLE
        New-SemanticReleaseTags -TargetVersion "v1.2.4" -RepositoryPath "C:\MyProject" -Force
        
        Forces creation in a specific repository, overwriting any existing tags:
        Useful for fixing incorrect releases or updating test environments.

    .NOTES
        Smart Tag Logic:
        - Patch updates (v1.2.3 → v1.2.4): Smart tags v1 and v1.2 move to new version
        - Minor updates (v1.2.3 → v1.3.0): Smart tag v1 moves, v1.2 becomes static
        - Major updates (v1.2.3 → v2.0.0): All v1.x smart tags become static, new v2 tags created
        
        This preserves historical references while keeping current smart tags up to date.

    .LINK
        Get-SemanticVersionTags
        Get-LatestSemanticTag
        https://semver.org/
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({
            if ($_ -match '^v?\d+\.\d+\.\d+(-(?:alpha|beta|rc)(?:\.\d+)?)?(\+[a-zA-Z0-9\-\.]+)?$') {
                $true
            } else {
                throw "TargetVersion '$_' is not a valid semantic version. Expected format: 'v1.2.3', '1.2.3' with optional pre-release identifiers 'alpha', 'beta', 'rc' (e.g., 'v1.2.3-alpha.1', 'v2.0.0-beta', 'v1.0.0-rc.2')."
            }
        })]
        [string]$TargetVersion,

        [Parameter()]
        [ValidateScript({
            if (Test-Path $_ -PathType Container) {
                if (Test-Path (Join-Path $_ '.git') -PathType Container) {
                    $true
                } else {
                    throw "RepositoryPath '$_' is not a Git repository (no .git folder found)."
                }
            } else {
                throw "RepositoryPath '$_' does not exist or is not a directory."
            }
        })]
        [string]$RepositoryPath = (Get-Location).Path,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$CommitSha = 'HEAD',

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$PushToRemote
    )

    begin {
        Write-SafeLog "INFO" "Starting semantic release tag creation" "TargetVersion: $TargetVersion"
        
        # Normalize target version (ensure v prefix)
        $normalizedVersion = if ($TargetVersion.StartsWith('v')) { $TargetVersion } else { "v$TargetVersion" }
        Write-SafeLog "DEBUG" "Version normalized" "Original: $TargetVersion`nNormalized: $normalizedVersion"
        
        # Initialize result object
        $result = [PSCustomObject]@{
            TargetVersion = $normalizedVersion
            ReleaseTags = @()
            SmartTags = @()
            MovingTags = @()
            StaticTags = @()
            Success = $false
            Warnings = @()
        }
    }

    process {
        try {
            Push-Location $RepositoryPath
            Write-SafeLog "DEBUG" "Changed to repository directory" "RepositoryPath: $RepositoryPath"
            
            # Validate Git repository and get current state
            Write-SafeLog "INFO" "Validating Git repository state"
            $gitStatus = Invoke-GitValidation -RepositoryPath $RepositoryPath
            if (-not $gitStatus.IsValid) {
                throw "Git repository validation failed: $($gitStatus.ErrorMessage)"
            }

            # Get existing tags and validate target version
            Write-Verbose "Analyzing existing tags..."
            $existingTags = Get-ExistingSemanticTags -RepositoryPath $RepositoryPath
            $validation = Test-TargetVersionValidity -TargetVersion $normalizedVersion -ExistingTags $existingTags -Force:$Force

            if (-not $validation.IsValid) {
                throw "Target version validation failed: $($validation.ErrorMessage)"
            }

            if ($validation.Warnings) {
                $result.Warnings += $validation.Warnings
            }

            # Calculate smart tag strategy
            Write-Verbose "Calculating smart tag strategy..."
            $tagStrategy = Get-SmartTagStrategy -TargetVersion $normalizedVersion -ExistingTags $existingTags
            
            if ($WhatIfPreference) {
                Write-Host "WhatIf: Would create the following tags:" -ForegroundColor Cyan
                Write-Host "  Release Tag: $normalizedVersion" -ForegroundColor Green
                foreach ($smartTag in $tagStrategy.SmartTagsToCreate) {
                    Write-Host "  Smart Tag: $($smartTag.Name) → $normalizedVersion" -ForegroundColor Yellow
                }
                foreach ($movingTag in $tagStrategy.MovingTagsToUpdate) {
                    Write-Host "  Moving Tag: $($movingTag.Name) → $normalizedVersion" -ForegroundColor Magenta
                }
                foreach ($staticTag in $tagStrategy.TagsToBecomeStatic) {
                    Write-Host "  Static Tag: $($staticTag.Name) → $($staticTag.CurrentTarget) (becomes STATIC)" -ForegroundColor DarkYellow
                }
                return $result
            }

            # Create release tag
            Write-Verbose "Creating release tag: $normalizedVersion"
            if ($PSCmdlet.ShouldProcess($normalizedVersion, "Create release tag")) {
                $releaseResult = New-GitTag -TagName $normalizedVersion -CommitSha $CommitSha -Force:$Force -RepositoryPath $RepositoryPath
                if ($releaseResult.Success) {
                    $result.ReleaseTags += $normalizedVersion
                    Write-Host "✅ Created release tag: $normalizedVersion" -ForegroundColor Green
                } else {
                    throw "Failed to create release tag: $($releaseResult.ErrorMessage)"
                }
            }

            # Create/update smart tags
            Write-Verbose "Creating/updating smart tags..."
            foreach ($smartTag in $tagStrategy.SmartTagsToCreate) {
                if ($PSCmdlet.ShouldProcess($smartTag.Name, "Create/update smart tag")) {
                    $smartResult = New-GitTag -TagName $smartTag.Name -TargetRef $normalizedVersion -Force:$true -RepositoryPath $RepositoryPath
                    if ($smartResult.Success) {
                        $result.SmartTags += $smartTag.Name
                        Write-Host "✅ Updated smart tag: $($smartTag.Name) → $normalizedVersion" -ForegroundColor Yellow
                    } else {
                        Write-Warning "Failed to create smart tag $($smartTag.Name): $($smartResult.ErrorMessage)"
                        $result.Warnings += "Smart tag creation failed: $($smartTag.Name)"
                    }
                }
            }

            # Update moving tags
            Write-Verbose "Updating moving tags..."
            foreach ($movingTag in $tagStrategy.MovingTagsToUpdate) {
                if ($PSCmdlet.ShouldProcess($movingTag.Name, "Update moving tag")) {
                    $movingResult = New-GitTag -TagName $movingTag.Name -TargetRef $normalizedVersion -Force:$true -RepositoryPath $RepositoryPath
                    if ($movingResult.Success) {
                        $result.MovingTags += $movingTag.Name
                        Write-Host "✅ Updated moving tag: $($movingTag.Name) → $normalizedVersion" -ForegroundColor Magenta
                    } else {
                        Write-Warning "Failed to update moving tag $($movingTag.Name): $($movingResult.ErrorMessage)"
                        $result.Warnings += "Moving tag update failed: $($movingTag.Name)"
                    }
                }
            }

            # Record static tags (for information purposes)
            $result.StaticTags += $tagStrategy.TagsToBecomeStatic | ForEach-Object { $_.Name }

            # Push to remote if requested
            if ($PushToRemote) {
                Write-Verbose "Pushing tags to remote repository..."
                if ($PSCmdlet.ShouldProcess("remote repository", "Push all tags")) {
                    $pushResult = Push-GitTags -RepositoryPath $RepositoryPath -Force:$Force
                    if (-not $pushResult.Success) {
                        Write-Warning "Failed to push tags to remote: $($pushResult.ErrorMessage)"
                        $result.Warnings += "Remote push failed: $($pushResult.ErrorMessage)"
                    } else {
                        Write-Host "✅ Successfully pushed all tags to remote repository" -ForegroundColor Cyan
                    }
                }
            }

            $result.Success = $true
            Write-Host "🎉 Successfully created semantic release: $normalizedVersion" -ForegroundColor Green

        }
        catch {
            $result.Success = $false
            Write-Error "Failed to create semantic release tags: $($_.Exception.Message)"
            throw
        }
        finally {
            Pop-Location
        }
    }

    end {
        return $result
    }
}

function Get-SemanticVersionTags {
    <#
    .SYNOPSIS
        Retrieves all semantic version tags from a Git repository with optional detailed information.

    .DESCRIPTION
        This function scans a Git repository for all tags that follow semantic versioning format
        and returns them in a structured format. It can include pre-release versions and provides
        detailed information when using the -Verbose parameter, including commit SHA, creation date,
        and tag message.

        The function recognizes multiple semantic version formats including v-prefixed versions,
        plain numeric versions, pre-release versions with suffixes, and build metadata.

    .PARAMETER RepositoryPath
        Path to the Git repository to scan for tags. Defaults to the current working directory.
        The path must contain a valid Git repository with at least one commit.

    .PARAMETER IncludePreRelease
        Include pre-release versions (alpha, beta, rc, etc.) in the results. By default, only
        stable release versions are returned.

    .PARAMETER SortOrder
        Specifies how to sort the returned tags. Valid values are:
        - 'Descending': Newest versions first (default)
        - 'Ascending': Oldest versions first

    .OUTPUTS
        [PSCustomObject[]] Returns an array of tag objects. Each object contains:
        - Tag: The tag name (e.g., "v1.2.3")
        - Version: Parsed semantic version object for easy comparison
        - IsPreRelease: Boolean indicating if this is a pre-release version
        - PreReleaseLabel: The pre-release label if applicable (alpha, beta, etc.)
        
        With -Verbose, additionally includes:
        - CommitSha: SHA of the commit the tag points to
        - CreatedDate: Date when the tag was created
        - Message: Tag message if any
        - AuthorName: Name of the person who created the tag
        - AuthorEmail: Email of the person who created the tag

    .EXAMPLE
        Get-SemanticVersionTags
        
        Returns all stable semantic version tags from the current repository, newest first:
        Tag      Version    IsPreRelease
        ---      -------    ------------
        v2.1.0   2.1.0      False
        v2.0.1   2.0.1      False
        v2.0.0   2.0.0      False
        v1.3.4   1.3.4      False

    .EXAMPLE
        Get-SemanticVersionTags -IncludePreRelease -Verbose
        
        Returns all semantic version tags including pre-releases with detailed information:
        Tag            Version    IsPreRelease  CommitSha  CreatedDate           Message
        ---            -------    ------------  ---------  -----------           -------
        v2.1.0-beta.1  2.1.0      True          abc123ef   2025-08-20 14:30:15   Beta release for testing
        v2.0.1         2.0.1      False         def456gh   2025-08-19 09:15:42   Hotfix for critical bug
        v2.0.0         2.0.0      False         789ijklm   2025-08-18 16:22:18   Major release v2.0.0

    .EXAMPLE
        Get-SemanticVersionTags -SortOrder Ascending | Select-Object -First 3
        
        Gets the three oldest semantic version tags:
        Useful for analyzing release history or finding the first releases.

    .EXAMPLE
        $tags = Get-SemanticVersionTags -RepositoryPath "C:\MyProject"
        $tags | Where-Object { $_.Version.Major -eq 1 }
        
        Gets all version 1.x tags from a specific repository:
        Useful for analyzing tags within a specific major version.

    .EXAMPLE
        Get-SemanticVersionTags | Where-Object { $_.IsPreRelease -eq $false } | Select-Object -First 1
        
        Gets the latest stable release tag (excludes pre-releases):
        Equivalent to Get-LatestSemanticTag but with more control.

    .NOTES
        Supported semantic version formats:
        - v1.2.3 (v-prefixed, recommended for Git tags)
        - 1.2.3 (plain numeric)
        - v1.2.3-alpha.1 (pre-release with label and number)
        - v1.2.3-beta (pre-release with label only)
        - v1.2.3+build.123 (with build metadata)
        - v1.2.3-alpha.1+build.123 (pre-release with build metadata)
        
        The function uses Git's native tag listing and parsing for maximum compatibility
        and performance across different Git versions and configurations.

    .LINK
        New-SemanticReleaseTags
        Get-LatestSemanticTag
        https://semver.org/
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateScript({
            if (Test-Path $_ -PathType Container) {
                if (Test-Path (Join-Path $_ '.git') -PathType Container) {
                    $true
                } else {
                    throw "RepositoryPath '$_' is not a Git repository (no .git folder found)."
                }
            } else {
                throw "RepositoryPath '$_' does not exist or is not a directory."
            }
        })]
        [string]$RepositoryPath = (Get-Location).Path,

        [Parameter()]
        [switch]$IncludePreRelease,

        [Parameter()]
        [ValidateSet('Descending', 'Ascending')]
        [string]$SortOrder = 'Descending'
    )

    begin {
        Write-Verbose "Scanning for semantic version tags in repository: $RepositoryPath"
    }

    process {
        try {
            Push-Location $RepositoryPath

            # Get all Git tags
            Write-Verbose "Retrieving all Git tags..."
            $allTags = git tag -l 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Failed to retrieve Git tags. Ensure you're in a valid Git repository."
                return @()
            }

            if (-not $allTags) {
                Write-Verbose "No Git tags found in repository."
                return @()
            }

            # Filter for semantic version tags
            Write-Verbose "Filtering for semantic version tags..."
            $semanticPattern = '^v?\d+\.\d+\.\d+(-[a-zA-Z0-9\-\.]+)?(\+[a-zA-Z0-9\-\.]+)?$'
            $semanticTags = $allTags | Where-Object { $_ -match $semanticPattern }

            if (-not $semanticTags) {
                Write-Verbose "No semantic version tags found."
                return @()
            }

            Write-Verbose "Found $($semanticTags.Count) semantic version tags."

            # Parse tags into objects
            $tagObjects = foreach ($tag in $semanticTags) {
                $parsed = ConvertTo-SemanticVersionObject -TagName $tag
                
                # Skip pre-release versions if not requested
                if (-not $IncludePreRelease -and $parsed.IsPreRelease) {
                    continue
                }

                # Add verbose information if requested
                if ($VerbosePreference -eq 'Continue') {
                    $tagInfo = Get-GitTagDetails -TagName $tag -RepositoryPath $RepositoryPath
                    $parsed | Add-Member -NotePropertyName 'CommitSha' -NotePropertyValue $tagInfo.CommitSha
                    $parsed | Add-Member -NotePropertyName 'CreatedDate' -NotePropertyValue $tagInfo.CreatedDate
                    $parsed | Add-Member -NotePropertyName 'Message' -NotePropertyValue $tagInfo.Message
                    $parsed | Add-Member -NotePropertyName 'AuthorName' -NotePropertyValue $tagInfo.AuthorName
                    $parsed | Add-Member -NotePropertyName 'AuthorEmail' -NotePropertyValue $tagInfo.AuthorEmail
                }

                $parsed
            }

            # Sort tags
            Write-Verbose "Sorting tags in $SortOrder order..."
            $sortedTags = if ($SortOrder -eq 'Descending') {
                $tagObjects | Sort-Object { $_.Version } -Descending
            } else {
                $tagObjects | Sort-Object { $_.Version }
            }

            Write-Verbose "Returning $($sortedTags.Count) semantic version tags."
            return $sortedTags

        }
        catch {
            Write-Error "Failed to retrieve semantic version tags: $($_.Exception.Message)"
            throw
        }
        finally {
            Pop-Location
        }
    }
}

function Get-LatestSemanticTag {
    <#
    .SYNOPSIS
        Finds and returns the most recent semantic version tag in a Git repository.

    .DESCRIPTION
        This function efficiently locates the highest semantic version tag in a Git repository
        based on semantic versioning rules. It can optionally include pre-release versions
        in the comparison and provides detailed information about the latest release.

        The function is optimized for performance and uses semantic version comparison
        rather than alphabetical or chronological sorting to determine the "latest" tag.
        This ensures that v10.0.0 is correctly identified as newer than v2.0.0.

    .PARAMETER RepositoryPath
        Path to the Git repository to scan for the latest tag. Defaults to the current 
        working directory. The path must contain a valid Git repository with at least one commit.

    .PARAMETER IncludePreRelease
        Include pre-release versions (alpha, beta, rc, etc.) in the comparison to find the latest.
        By default, only stable release versions are considered.

        Note: When enabled, a pre-release version like "v2.1.0-alpha.1" could be returned as the
        latest even if a stable "v2.0.0" exists, since 2.1.0-alpha.1 > 2.0.0 semantically.

    .OUTPUTS
        [string] Returns the tag name of the latest semantic version, or $null if no semantic
        version tags are found. Examples: "v2.1.0", "v1.3.4-beta.2", $null

    .EXAMPLE
        Get-LatestSemanticTag
        
        Returns the latest stable semantic version tag:
        "v2.1.0"

    .EXAMPLE
        Get-LatestSemanticTag -IncludePreRelease
        
        Returns the latest semantic version tag including pre-releases:
        "v2.2.0-alpha.1"
        
        (This would be returned even if v2.1.0 stable exists, since 2.2.0-alpha.1 > 2.1.0)

    .EXAMPLE
        $latest = Get-LatestSemanticTag -RepositoryPath "C:\MyProject"
        if ($latest) {
            Write-Host "Latest version: $latest"
            
            # Get full details about this tag
            $details = Get-SemanticVersionTags -RepositoryPath "C:\MyProject" | 
                       Where-Object { $_.Tag -eq $latest }
            Write-Host "Released on: $($details.CreatedDate)"
        } else {
            Write-Host "No semantic version tags found."
        }

    .EXAMPLE
        # Compare with a target version
        $latest = Get-LatestSemanticTag
        $target = "v2.0.0"
        
        if ($latest) {
            $latestVersion = [System.Management.Automation.SemanticVersion]::new($latest.TrimStart('v'))
            $targetVersion = [System.Management.Automation.SemanticVersion]::new($target.TrimStart('v'))
            
            if ($targetVersion -gt $latestVersion) {
                Write-Host "Target version $target is newer than latest $latest"
            } else {
                Write-Host "Target version $target already exists or is older than $latest"
            }
        }

    .EXAMPLE
        # Use in CI/CD pipeline
        $currentLatest = Get-LatestSemanticTag
        $newVersion = "v1.2.4"
        
        if ($currentLatest -eq $newVersion) {
            Write-Warning "Version $newVersion already exists!"
            exit 1
        } else {
            Write-Host "Ready to create new release: $newVersion (current: $currentLatest)"
        }

    .NOTES
        Semantic Version Comparison Rules:
        - Major.Minor.Patch comparison (1.0.0 < 2.0.0 < 10.0.0)
        - Pre-release versions are lower than release versions (1.0.0-alpha < 1.0.0)
        - Pre-release labels are compared alphabetically (alpha < beta < rc)
        - Numeric pre-release identifiers are compared numerically (alpha.1 < alpha.2 < alpha.10)
        
        Performance Notes:
        - Uses Git's native tag listing for optimal performance
        - Semantic version parsing is done in PowerShell for accurate comparison
        - Caches are not used; each call queries Git directly for real-time accuracy

    .LINK
        New-SemanticReleaseTags
        Get-SemanticVersionTags
        https://semver.org/
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateScript({
            if (Test-Path $_ -PathType Container) {
                if (Test-Path (Join-Path $_ '.git') -PathType Container) {
                    $true
                } else {
                    throw "RepositoryPath '$_' is not a Git repository (no .git folder found)."
                }
            } else {
                throw "RepositoryPath '$_' does not exist or is not a directory."
            }
        })]
        [string]$RepositoryPath = (Get-Location).Path,

        [Parameter()]
        [switch]$IncludePreRelease
    )

    begin {
        Write-Verbose "Finding latest semantic version tag in repository: $RepositoryPath"
    }

    process {
        try {
            # Get all semantic version tags
            $tags = Get-SemanticVersionTags -RepositoryPath $RepositoryPath -IncludePreRelease:$IncludePreRelease -SortOrder Descending

            if (-not $tags -or $tags.Count -eq 0) {
                Write-Verbose "No semantic version tags found."
                return $null
            }

            # Return the first tag (highest version due to descending sort)
            $latestTag = $tags[0].Tag
            Write-Verbose "Latest semantic version tag: $latestTag"
            
            return $latestTag

        }
        catch {
            Write-Error "Failed to find latest semantic version tag: $($_.Exception.Message)"
            throw
        }
    }
}

#endregion

#region Module Export Control
# Export public functions - removed New-GitHubRelease as it's out of scope for Smartagr
Export-ModuleMember -Function 'New-SemanticReleaseTags', 'Get-SemanticVersionTags', 'Get-LatestSemanticTag', 'Move-SmartTags'
#endregion

#region Module Cleanup
Write-SafeLog "INFO" "K.PSGallery.Smartagr module loaded successfully" "ExportedFunctions: New-SemanticReleaseTags, Get-SemanticVersionTags, Get-LatestSemanticTag, New-GitHubRelease"
#endregion
