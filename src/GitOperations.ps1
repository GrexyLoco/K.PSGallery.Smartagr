# Git Operations - Core Git functionality for tag management

function Invoke-GitValidation {
    <#
    .SYNOPSIS
        Validates that a directory contains a valid Git repository with necessary prerequisites.
    
    .DESCRIPTION
        Comprehensive validation of Git repository state including:
        - Git CLI availability
        - Valid Git repository structure
        - At least one commit exists
        - Working directory is clean (optional)
    
    .PARAMETER RepositoryPath
        Path to the Git repository to validate
    
    .PARAMETER RequireCleanWorkingDirectory
        Requires that there are no uncommitted changes
    
    .OUTPUTS
        [PSCustomObject] Validation result with IsValid and ErrorMessage properties
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryPath,
        
        [Parameter()]
        [switch]$RequireCleanWorkingDirectory
    )
    
    $result = [PSCustomObject]@{
        IsValid = $false
        ErrorMessage = ""
        Warnings = @()
    }
    
    try {
        Push-Location $RepositoryPath
        Write-SafeInfoLog "Starting Git repository validation" -Context "RepositoryPath: $RepositoryPath"
        
        # Check if git command is available
        git --version 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            $errorMsg = "Git CLI is not available in PATH. Please install Git."
            Write-SafeErrorLog $errorMsg
            $result.ErrorMessage = $errorMsg
            return $result
        }
        
        Write-SafeDebugLog "Git CLI is available"
        
        # Check if we're in a Git repository
        git rev-parse --git-dir 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            $errorMsg = "Directory is not a Git repository."
            Write-SafeErrorLog $errorMsg -Context "Path: $RepositoryPath"
            $result.ErrorMessage = $errorMsg
            return $result
        }
        
        Write-SafeDebugLog "Git repository structure validated"
        
        # Check if there's at least one commit
        git rev-parse HEAD 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            $errorMsg = "Repository has no commits. At least one commit is required."
            Write-SafeErrorLog $errorMsg
            $result.ErrorMessage = $errorMsg
            return $result
        }
        
        Write-SafeDebugLog "Repository has commits available"
        
        # Check working directory status if required
        if ($RequireCleanWorkingDirectory) {
            $status = git status --porcelain 2>$null
            if ($status) {
                $errorMsg = "Working directory has uncommitted changes. Commit or stash changes before creating tags."
                Write-SafeWarningLog $errorMsg -Context "UncommittedFiles: $($status -join ', ')"
                $result.ErrorMessage = $errorMsg
                return $result
            }
            Write-SafeDebugLog "Working directory is clean"
        }
        
        $result.IsValid = $true
        Write-SafeInfoLog "Git repository validation completed successfully"
        return $result
        
    }
    catch {
        $errorMsg = "Git validation failed: $($_.Exception.Message)"
        Write-SafeErrorLog $errorMsg -Context "RepositoryPath: $RepositoryPath"
        $result.ErrorMessage = $errorMsg
        return $result
    }
    finally {
        Pop-Location
    }
}

function Get-ExistingSemanticTags {
    <#
    .SYNOPSIS
        Retrieves all existing semantic version tags from a Git repository.
    
    .DESCRIPTION
        Scans the repository for all tags matching semantic version patterns
        and returns them as structured objects for further processing.
    
    .PARAMETER RepositoryPath
        Path to the Git repository
    
    .OUTPUTS
        [PSCustomObject[]] Array of tag objects with Name, Version, and metadata
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RepositoryPath
    )
    
    try {
        Push-Location $RepositoryPath
        Write-SafeInfoLog "Retrieving existing semantic version tags" -Context "RepositoryPath: $RepositoryPath"
        
        $allTags = git tag -l 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $allTags) {
            Write-SafeInfoLog "No tags found in repository"
            return @()
        }
        
        Write-SafeDebugLog "Retrieved all tags from repository" -Context "TotalTagCount: $($allTags.Count)"
        
        $semanticPattern = '^v?\d+\.\d+\.\d+(-[a-zA-Z0-9\-\.]+)?(\+[a-zA-Z0-9\-\.]+)?$'
        $semanticTags = $allTags | Where-Object { $_ -match $semanticPattern }
        
        Write-SafeInfoLog "Filtered semantic version tags" -Context "SemanticTagCount: $($semanticTags.Count)`nTotalTagCount: $($allTags.Count)"
        
        # Parse and filter out null values (failed parsing)
        $tagObjects = $semanticTags | ForEach-Object {
            $parsed = ConvertTo-SemanticVersionObject -TagName $_
            if ($parsed) {
                Write-SafeDebugLog "Successfully parsed semantic tag" -Context "Tag: $_`nVersion: $($parsed.Version)"
                $parsed
            }
            # Implicitly: if $parsed is $null, nothing is added to the array
        } | Where-Object { $_ -ne $null }  # Extra safety: filter out any nulls
        
        $sortedTags = $tagObjects | Sort-Object { $_.Version } -Descending
        Write-SafeInfoLog "Semantic tags retrieved and sorted successfully" -Context "FinalCount: $($sortedTags.Count)"
        
        return $sortedTags
        
    }
    catch {
        $errorMsg = "Failed to get existing semantic tags: $($_.Exception.Message)"
        Write-SafeErrorLog $errorMsg -Context "RepositoryPath: $RepositoryPath"
        return @()
    }
    finally {
        Pop-Location
    }
}

function New-GitTag {
    <#
    .SYNOPSIS
        Creates a new Git tag with proper error handling and validation.
    
    .DESCRIPTION
        Creates a Git tag with comprehensive error handling, conflict detection,
        and support for both lightweight and annotated tags.
    
    .PARAMETER TagName
        Name of the tag to create
    
    .PARAMETER CommitSha
        Commit SHA to tag (defaults to HEAD)
    
    .PARAMETER TargetRef
        Alternative way to specify target (e.g., another tag name)
    
    .PARAMETER Message
        Optional tag message (creates annotated tag)
    
    .PARAMETER Force
        Force creation, overwriting existing tags
    
    .PARAMETER RepositoryPath
        Path to Git repository
    
    .OUTPUTS
        [PSCustomObject] Result with Success, ErrorMessage, and TagName properties
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TagName,
        
        [Parameter()]
        [string]$CommitSha,
        
        [Parameter()]
        [string]$TargetRef,
        
        [Parameter()]
        [string]$Message,
        
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [string]$RepositoryPath = (Get-Location).Path
    )
    
    $result = [PSCustomObject]@{
        Success = $false
        ErrorMessage = ""
        TagName = $TagName
    }
    
    try {
        Push-Location $RepositoryPath
        
        # Determine target reference
        $target = if ($TargetRef) { $TargetRef } elseif ($CommitSha) { $CommitSha } else { "HEAD" }
        
        # Check if tag already exists
        $existingTag = git tag -l $TagName 2>$null
        if ($existingTag -and -not $Force) {
            $result.ErrorMessage = "Tag '$TagName' already exists. Use -Force to overwrite."
            return $result
        }
        
        # Delete existing tag if force is specified
        if ($existingTag -and $Force) {
            git tag -d $TagName 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) {
                $result.ErrorMessage = "Failed to delete existing tag '$TagName'."
                return $result
            }
        }
        
        # Create the tag
        if ($Message) {
            # Annotated tag
            git tag -a $TagName -m $Message $target 2>$null
        } else {
            # Lightweight tag
            git tag $TagName $target 2>$null
        }
        
        if ($LASTEXITCODE -eq 0) {
            $result.Success = $true
        } else {
            $result.ErrorMessage = "Git tag creation failed for '$TagName'."
        }
        
        return $result
        
    }
    catch {
        $result.ErrorMessage = "Exception creating tag '$TagName': $($_.Exception.Message)"
        return $result
    }
    finally {
        Pop-Location
    }
}

function Push-GitTags {
    <#
    .SYNOPSIS
        Pushes Git tags to remote repository with error handling.
    
    .DESCRIPTION
        Safely pushes tags to remote repository with comprehensive error handling
        and support for force pushing when necessary.
    
    .PARAMETER RepositoryPath
        Path to Git repository
    
    .PARAMETER TagNames
        Specific tags to push (defaults to all tags)
    
    .PARAMETER Force
        Force push tags (overwrite remote tags)
    
    .OUTPUTS
        [PSCustomObject] Result with Success and ErrorMessage properties
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$RepositoryPath = (Get-Location).Path,
        
        [Parameter()]
        [string[]]$TagNames,
        
        [Parameter()]
        [switch]$Force
    )
    
    $result = [PSCustomObject]@{
        Success = $false
        ErrorMessage = ""
    }
    
    try {
        Push-Location $RepositoryPath
        
        # Check if remote exists
        $remotes = git remote 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $remotes) {
            $result.ErrorMessage = "No remote repository configured."
            return $result
        }
        
        if ($TagNames) {
            # Push specific tags
            foreach ($tag in $TagNames) {
                $pushArgs = @('push')
                if ($Force) { $pushArgs += '--force' }
                $pushArgs += @('origin', $tag)
                
                & git @pushArgs 2>$null
                if ($LASTEXITCODE -ne 0) {
                    $result.ErrorMessage = "Failed to push tag '$tag' to remote."
                    return $result
                }
            }
        } else {
            # Push all tags
            $pushArgs = @('push')
            if ($Force) { $pushArgs += '--force' }
            $pushArgs += @('origin', '--tags')
            
            & git @pushArgs 2>$null
            if ($LASTEXITCODE -ne 0) {
                $result.ErrorMessage = "Failed to push tags to remote."
                return $result
            }
        }
        
        $result.Success = $true
        return $result
        
    }
    catch {
        $result.ErrorMessage = "Exception pushing tags: $($_.Exception.Message)"
        return $result
    }
    finally {
        Pop-Location
    }
}

function Get-GitTagDetails {
    <#
    .SYNOPSIS
        Gets detailed information about a specific Git tag.
    
    .DESCRIPTION
        Retrieves comprehensive information about a Git tag including
        commit SHA, creation date, author, and tag message.
    
    .PARAMETER TagName
        Name of the tag to inspect
    
    .PARAMETER RepositoryPath
        Path to Git repository
    
    .OUTPUTS
        [PSCustomObject] Tag details including CommitSha, CreatedDate, Message, AuthorName, AuthorEmail
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TagName,
        
        [Parameter()]
        [string]$RepositoryPath = (Get-Location).Path
    )
    
    try {
        Push-Location $RepositoryPath
        
        # Get commit SHA
        $commitSha = git rev-list -n 1 $TagName 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Tag '$TagName' not found."
        }
        
        # Get tag object info (works for both lightweight and annotated tags)
        $tagInfo = git show --format="%H|%ai|%an|%ae|%s" -s $TagName 2>$null
        if ($LASTEXITCODE -eq 0 -and $tagInfo) {
            $parts = $tagInfo -split '\|'
            $createdDate = [DateTime]::Parse($parts[1])
            $authorName = $parts[2]
            $authorEmail = $parts[3]
            $message = $parts[4]
        } else {
            # Fallback for lightweight tags
            $commitInfo = git show --format="%H|%ai|%an|%ae|%s" -s $commitSha 2>$null
            $parts = $commitInfo -split '\|'
            $createdDate = [DateTime]::Parse($parts[1])
            $authorName = $parts[2]
            $authorEmail = $parts[3]
            $message = ""
        }
        
        return [PSCustomObject]@{
            TagName = $TagName
            CommitSha = $commitSha.Substring(0, 8)  # Short SHA
            CreatedDate = $createdDate
            Message = $message
            AuthorName = $authorName
            AuthorEmail = $authorEmail
        }
        
    }
    catch {
        Write-Error "Failed to get tag details for '$TagName': $($_.Exception.Message)"
        return [PSCustomObject]@{
            TagName = $TagName
            CommitSha = "unknown"
            CreatedDate = [DateTime]::MinValue
            Message = ""
            AuthorName = "unknown"
            AuthorEmail = "unknown"
        }
    }
    finally {
        Pop-Location
    }
}

<#
.SYNOPSIS
    Retrieves all tags from the repository that follow semantic versioning.

.DESCRIPTION
    This function fetches all tags from the specified Git repository, then filters them to return only those
    that conform to semantic versioning standards (e.g., v1.2.3, 2.0.0-alpha).

.PARAMETER RepositoryPath
    The path to the Git repository. Defaults to the current directory.

.EXAMPLE
    Get-SemanticVersionTags
    Returns all semantic version tags from the current repository.

.OUTPUTS
    [string[]] An array of tags that are valid semantic versions.
#>
function Get-SemanticVersionTags {
    param(
        [string]$RepositoryPath = (Get-Location).Path
    )
    
    Write-SafeDebugLog -Message "Getting all semantic version tags" -Additional @{ "RepositoryPath" = $RepositoryPath }
    
    try {
        Push-Location $RepositoryPath
        
        # Get all tags from repository
        $allTags = git tag -l 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $allTags) {
            Write-SafeInfoLog -Message "No tags found in repository"
            return @()
        }
        
        # Filter for semantic version tags only (exclude smart tags like v0, v0.1, latest)
        $semanticTags = $allTags | Where-Object {
            # Must have full semantic version format (v0.0.0 with optional pre-release/build)
            $_ -match '^v?\d+\.\d+\.\d+' -and
            # Exclude smart tags (v0, v0.1) and moving tags (latest)
            $_ -notmatch '^(latest|v\d+|v\d+\.\d+)$'
        } | ForEach-Object {
            # Additional validation with Test-IsValidSemanticVersion
            if (Test-IsValidSemanticVersion -Version $_) {
                $_
            }
        } | Where-Object { $_ }  # Filter out any null values
        
        Write-SafeInfoLog -Message "Found $($semanticTags.Count) semantic version tags" -Additional @{ "TotalTags" = $allTags.Count }
        
        return $semanticTags
    }
    finally {
        Pop-Location
    }
}

<#
.SYNOPSIS
    Finds the latest (highest) semantic version tag in the repository.

.DESCRIPTION
    This function retrieves all semantic version tags and sorts them to find the highest, most recent version.
    It correctly handles pre-release and final versions to determine the latest tag.

.PARAMETER RepositoryPath
    The path to the Git repository. Defaults to the current directory.

.EXAMPLE
    Get-LatestSemanticTag
    Returns the latest semantic version tag (e.g., "v1.5.2").

.OUTPUTS
    [string] The latest semantic version tag found.
#>
function Get-LatestSemanticTag {
    param(
        [string]$RepositoryPath = (Get-Location).Path
    )
    
    Write-SafeDebugLog -Message "Getting the latest semantic tag" -Additional @{ "RepositoryPath" = $RepositoryPath }
    
    $semanticTags = Get-SemanticVersionTags -RepositoryPath $RepositoryPath
    
    if ($null -eq $semanticTags -or $semanticTags.Count -eq 0) {
        Write-SafeWarningLog -Message "No semantic version tags found in the repository."
        return $null
    }
    
    # Sort tags using semantic version comparison logic
    $sortedTags = $semanticTags | Sort-Object -Property @{ Expression = { [System.Version]($_.TrimStart('v')) } } -Descending
    
    $latestTag = $sortedTags[0]
    
    Write-SafeInfoLog -Message "Latest semantic tag found" -Additional @{ "LatestTag" = $latestTag }
    
    return $latestTag
}
