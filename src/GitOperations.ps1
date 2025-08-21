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
        Write-InfoLog "Starting Git repository validation" -Context "RepositoryPath: $RepositoryPath"
        
        # Check if git command is available
        git --version 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            $errorMsg = "Git CLI is not available in PATH. Please install Git."
            Write-ErrorLog $errorMsg
            $result.ErrorMessage = $errorMsg
            return $result
        }
        
        Write-DebugLog "Git CLI is available"
        
        # Check if we're in a Git repository
        git rev-parse --git-dir 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            $errorMsg = "Directory is not a Git repository."
            Write-ErrorLog $errorMsg -Context "Path: $RepositoryPath"
            $result.ErrorMessage = $errorMsg
            return $result
        }
        
        Write-DebugLog "Git repository structure validated"
        
        # Check if there's at least one commit
        git rev-parse HEAD 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            $errorMsg = "Repository has no commits. At least one commit is required."
            Write-ErrorLog $errorMsg
            $result.ErrorMessage = $errorMsg
            return $result
        }
        
        Write-DebugLog "Repository has commits available"
        
        # Check working directory status if required
        if ($RequireCleanWorkingDirectory) {
            $status = git status --porcelain 2>$null
            if ($status) {
                $errorMsg = "Working directory has uncommitted changes. Commit or stash changes before creating tags."
                Write-WarningLog $errorMsg -Context "UncommittedFiles: $($status -join ', ')"
                $result.ErrorMessage = $errorMsg
                return $result
            }
            Write-DebugLog "Working directory is clean"
        }
        
        $result.IsValid = $true
        Write-InfoLog "Git repository validation completed successfully"
        return $result
        
    }
    catch {
        $errorMsg = "Git validation failed: $($_.Exception.Message)"
        Write-ErrorLog $errorMsg -Context "RepositoryPath: $RepositoryPath"
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
        Write-InfoLog "Retrieving existing semantic version tags" -Context "RepositoryPath: $RepositoryPath"
        
        $allTags = git tag -l 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $allTags) {
            Write-InfoLog "No tags found in repository"
            return @()
        }
        
        Write-DebugLog "Retrieved all tags from repository" -Context "TotalTagCount: $($allTags.Count)"
        
        $semanticPattern = '^v?\d+\.\d+\.\d+(-[a-zA-Z0-9\-\.]+)?(\+[a-zA-Z0-9\-\.]+)?$'
        $semanticTags = $allTags | Where-Object { $_ -match $semanticPattern }
        
        Write-InfoLog "Filtered semantic version tags" -Context "SemanticTagCount: $($semanticTags.Count)`nTotalTagCount: $($allTags.Count)"
        
        $tagObjects = foreach ($tag in $semanticTags) {
            $parsed = ConvertTo-SemanticVersionObject -TagName $tag
            if ($parsed) {
                Write-DebugLog "Successfully parsed semantic tag" -Context "Tag: $tag`nVersion: $($parsed.Version)"
                $parsed
            }
        }
        
        $sortedTags = $tagObjects | Sort-Object { $_.Version } -Descending
        Write-InfoLog "Semantic tags retrieved and sorted successfully" -Context "FinalCount: $($sortedTags.Count)"
        
        return $sortedTags
        
    }
    catch {
        $errorMsg = "Failed to get existing semantic tags: $($_.Exception.Message)"
        Write-ErrorLog $errorMsg -Context "RepositoryPath: $RepositoryPath"
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
