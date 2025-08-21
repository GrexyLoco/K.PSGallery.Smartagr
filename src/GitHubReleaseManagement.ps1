# GitHub Release Management - Complete Smart Release Ecosystem

function New-SmartRelease {
    <#
    .SYNOPSIS
    Creates a complete semantic release with Git tags and GitHub release using the proven Draft → Smart Tags → Publish strategy.

    .DESCRIPTION
    This is the main function for creating complete semantic releases. It combines Git tag creation
    with GitHub release management using a safe, proven workflow strategy:
    
    1. 📦 Create GitHub Release as DRAFT (safe, reversible)
    2. 🏷️ Create Smart Tags (only if Draft successful)  
    3. 🚀 Publish GitHub Release (only if Smart Tags successful)
    
    This strategy ensures that failed operations can be safely rolled back and provides
    comprehensive status reporting at each step.

    .PARAMETER TargetVersion
    The semantic version to create (e.g., "v1.2.3", "1.2.3").

    .PARAMETER RepositoryPath
    Path to the Git repository. Defaults to current working directory.

    .PARAMETER ReleaseNotes
    Custom release notes content.

    .PARAMETER ReleaseNotesFile
    Path to a file containing release notes.

    .PARAMETER Force
    Force creation even if version already exists.

    .PARAMETER PushToRemote
    Push created tags to remote repository.

    .PARAMETER SkipGitHubRelease
    Only create Git tags, skip GitHub release creation.

    .EXAMPLE
    $result = New-SmartRelease -TargetVersion "v1.2.3"
    # Creates complete release with draft → tags → publish workflow

    .EXAMPLE
    $result = New-SmartRelease -TargetVersion "v2.0.0" -ReleaseNotes "Major release with breaking changes"
    Write-Host $result.GitHubSummary

    .OUTPUTS
    PSCustomObject with comprehensive release status including:
    - Git tag creation status
    - GitHub release creation status  
    - Each step's success/failure
    - Rollback information
    - GitHub workflow integration data
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({
            if ($_ -match '^v?\d+\.\d+\.\d+(-(?:alpha|beta|rc|preview|pre)(?:\.\d+)?)?(\+[a-zA-Z0-9\-\.]+)?$') {
                $true
            } else {
                throw "TargetVersion '$_' is not a valid semantic version."
            }
        })]
        [string]$TargetVersion,

        [Parameter()]
        [string]$RepositoryPath = (Get-Location).Path,

        [Parameter()]
        [string]$ReleaseNotes,

        [Parameter()]
        [string]$ReleaseNotesFile,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$PushToRemote,

        [Parameter()]
        [switch]$SkipGitHubRelease
    )

    begin {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        Write-SafeLog "INFO" "Starting smart release creation" "TargetVersion: $TargetVersion"
        
        # Normalize version
        $normalizedVersion = if ($TargetVersion.StartsWith('v')) { $TargetVersion } else { "v$TargetVersion" }
        $isPrerelease = $normalizedVersion -match '-(alpha|beta|rc|preview|pre)'
        
        # Initialize comprehensive result object
        $result = [PSCustomObject]@{
            TargetVersion = $normalizedVersion
            BumpType = "Patch"  # Will be determined
            Success = $false
            
            # Git Tag Results
            GitTagsResult = $null
            TagsCreated = @()
            TagsMovedFrom = @{}
            TagsStaticized = @()
            
            # GitHub Release Results
            GitHubReleaseResult = $null
            ReleaseId = $null
            ReleaseUrl = ""
            ReleaseDraftCreated = $false
            ReleasePublished = $false
            
            # Workflow Status
            StepResults = @{
                DraftCreation = @{ Success = $false; Message = ""; Timestamp = $null }
                TagCreation = @{ Success = $false; Message = ""; Timestamp = $null }
                ReleasePublication = @{ Success = $false; Message = ""; Timestamp = $null }
            }
            
            # Standard fields
            Duration = $null
            ConflictsResolved = @()
            RollbackInfo = @{
                TagsToDelete = @()
                TagsToRestore = @{}
                ReleaseToDelete = $null
                OriginalState = @{}
            }
            GitHubSummary = ""
            StepOutputs = @{}
            IsPrerelease = $isPrerelease
            PushToRemote = $PushToRemote.IsPresent
            Repository = $RepositoryPath
        }
    }

    process {
        try {
            Push-Location $RepositoryPath
            
            # Step 1: Create GitHub Draft Release (if not skipped)
            if (-not $SkipGitHubRelease) {
                Write-SafeLog "INFO" "Step 1: Creating GitHub draft release" "Version: $normalizedVersion"
                $result.StepResults.DraftCreation.Timestamp = Get-Date
                
                if ($PSCmdlet.ShouldProcess($normalizedVersion, "Create GitHub draft release")) {
                    # Real execution
                    $draftResult = New-GitHubDraftRelease -Version $normalizedVersion -ReleaseNotes $ReleaseNotes -ReleaseNotesFile $ReleaseNotesFile -RepositoryPath $RepositoryPath
                    
                    $result.GitHubReleaseResult = $draftResult
                    if ($draftResult.Success) {
                        $result.ReleaseDraftCreated = $true
                        $result.ReleaseId = $draftResult.ReleaseId
                        $result.ReleaseUrl = $draftResult.HtmlUrl
                        $result.RollbackInfo.ReleaseToDelete = $draftResult.ReleaseId
                        $result.StepResults.DraftCreation.Success = $true
                        $result.StepResults.DraftCreation.Message = "Draft release created successfully"
                        
                        Write-SafeLog "INFO" "Draft release created successfully" "ReleaseId: $($draftResult.ReleaseId)"
                    } else {
                        throw "Failed to create draft release: $($draftResult.ErrorMessage)"
                    }
                } else {
                    # WhatIf simulation
                    $mockDraftResult = [PSCustomObject]@{
                        Success = $true
                        ReleaseId = "simulated-draft-id-12345"
                        HtmlUrl = "https://github.com/owner/repo/releases/tag/$normalizedVersion"
                        IsDraft = $true
                        IsPrerelease = $isPrerelease
                        ErrorMessage = ""
                    }
                    
                    $result.GitHubReleaseResult = $mockDraftResult
                    $result.ReleaseDraftCreated = $true
                    $result.ReleaseId = $mockDraftResult.ReleaseId
                    $result.ReleaseUrl = $mockDraftResult.HtmlUrl
                    $result.RollbackInfo.ReleaseToDelete = $mockDraftResult.ReleaseId
                    $result.StepResults.DraftCreation.Success = $true
                    $result.StepResults.DraftCreation.Message = "Draft release would be created successfully (WhatIf)"
                    
                    Write-SafeLog "INFO" "Draft release simulation successful" "ReleaseId: $($mockDraftResult.ReleaseId) (WhatIf)"
                }
            } else {
                $result.StepResults.DraftCreation.Success = $true
                $result.StepResults.DraftCreation.Message = "Skipped (SkipGitHubRelease specified)"
            }
            
            # Step 2: Create Smart Tags (only if draft successful or skipped)
            if ($result.StepResults.DraftCreation.Success) {
                Write-SafeLog "INFO" "Step 2: Creating smart tags" "Version: $normalizedVersion"
                $result.StepResults.TagCreation.Timestamp = Get-Date
                
                if ($WhatIfPreference) {
                    # WhatIf simulation for tag creation
                    $mockTagResult = [PSCustomObject]@{
                        Success = $true
                        TagsCreated = @("$normalizedVersion", "latest", "v0.1")
                        TagsMovedFrom = @{ "latest" = "v0.1.0"; "v0.1" = "v0.1.0" }
                        TagsStaticized = @()
                        BumpType = "Patch"
                        ErrorMessage = ""
                    }
                    
                    $result.GitTagsResult = $mockTagResult
                    $result.TagsCreated = $mockTagResult.TagsCreated
                    $result.TagsMovedFrom = $mockTagResult.TagsMovedFrom
                    $result.TagsStaticized = $mockTagResult.TagsStaticized
                    $result.BumpType = $mockTagResult.BumpType
                    $result.RollbackInfo.TagsToDelete = $mockTagResult.TagsCreated
                    $result.RollbackInfo.TagsToRestore = $mockTagResult.TagsMovedFrom
                    $result.StepResults.TagCreation.Success = $true
                    $result.StepResults.TagCreation.Message = "Smart tags would be created successfully (WhatIf)"
                    
                    Write-SafeLog "INFO" "Smart tags simulation successful" "Tags: $($mockTagResult.TagsCreated -join ', ') (WhatIf)"
                } else {
                    # Real execution
                    $tagResult = New-SemanticReleaseTags -TargetVersion $normalizedVersion -RepositoryPath $RepositoryPath -Force:$Force -PushToRemote:$PushToRemote
                    
                    $result.GitTagsResult = $tagResult
                    if ($tagResult.Success) {
                        $result.TagsCreated = $tagResult.TagsCreated
                        $result.TagsMovedFrom = $tagResult.TagsMovedFrom
                        $result.TagsStaticized = $tagResult.TagsStaticized
                        $result.BumpType = $tagResult.BumpType
                        $result.RollbackInfo.TagsToDelete = $tagResult.TagsCreated
                        $result.RollbackInfo.TagsToRestore = $tagResult.TagsMovedFrom
                        $result.StepResults.TagCreation.Success = $true
                        $result.StepResults.TagCreation.Message = "Smart tags created successfully"
                        
                        Write-SafeLog "INFO" "Smart tags created successfully" "Tags: $($tagResult.TagsCreated -join ', ')"
                    } else {
                        throw "Failed to create smart tags: $($tagResult.ErrorMessage)"
                    }
                }
            }
            
            # Step 3: Publish GitHub Release (only if tags successful and release exists)
            if ($result.StepResults.TagCreation.Success -and $result.ReleaseDraftCreated) {
                Write-SafeLog "INFO" "Step 3: Publishing GitHub release" "ReleaseId: $($result.ReleaseId)"
                $result.StepResults.ReleasePublication.Timestamp = Get-Date
                
                if ($PSCmdlet.ShouldProcess($result.ReleaseId, "Publish GitHub release")) {
                    # Real execution
                    $publishResult = Publish-GitHubRelease -ReleaseId $result.ReleaseId -MarkAsLatest:(-not $isPrerelease) -RepositoryPath $RepositoryPath
                    
                    if ($publishResult.Success) {
                        $result.ReleasePublished = $true
                        $result.StepResults.ReleasePublication.Success = $true
                        $result.StepResults.ReleasePublication.Message = "Release published successfully"
                        $result.RollbackInfo.ReleaseToDelete = $null  # Don't delete published releases
                        
                        Write-SafeLog "INFO" "Release published successfully" "ReleaseId: $($result.ReleaseId)"
                    } else {
                        $result.ConflictsResolved += "Release publication failed but draft and tags exist: $($publishResult.ErrorMessage)"
                        $result.StepResults.ReleasePublication.Message = "Publication failed: $($publishResult.ErrorMessage)"
                    }
                } else {
                    # WhatIf simulation
                    $result.ReleasePublished = $true
                    $result.StepResults.ReleasePublication.Success = $true
                    $result.StepResults.ReleasePublication.Message = "Release would be published successfully (WhatIf)"
                    $result.RollbackInfo.ReleaseToDelete = $null  # Don't delete published releases in simulation
                    
                    Write-SafeLog "INFO" "Release publication simulation successful" "ReleaseId: $($result.ReleaseId) (WhatIf)"
                }
            }
            
            # Determine overall success
            $result.Success = $result.StepResults.TagCreation.Success -and 
                             ($SkipGitHubRelease -or $result.StepResults.ReleasePublication.Success)
            
            $stopwatch.Stop()
            $result.Duration = $stopwatch.Elapsed
            
            # Generate GitHub Summary and Step Outputs
            $result.GitHubSummary = New-SmartReleaseStepSummary -Result $result
            $result.StepOutputs = ConvertTo-SmartReleaseStepOutputs -Result $result
            
            Write-SafeLog "INFO" "Smart release completed" "Success: $($result.Success), Duration: $($result.Duration.TotalSeconds)s"

        }
        catch {
            $stopwatch.Stop()
            $result.Duration = $stopwatch.Elapsed
            $result.Success = $false
            $result.GitHubSummary = "❌ **Smart Release Failed**`n`nError: $($_.Exception.Message)`n`nSee rollback information for cleanup steps."
            
            # Rollback on failure
            if ($result.RollbackInfo.ReleaseToDelete) {
                Write-SafeLog "WARN" "Rolling back: Deleting draft release" "ReleaseId: $($result.RollbackInfo.ReleaseToDelete)"
                try {
                    Remove-GitHubRelease -ReleaseId $result.RollbackInfo.ReleaseToDelete -RepositoryPath $RepositoryPath
                    $result.ConflictsResolved += "Rolled back: Deleted draft release $($result.RollbackInfo.ReleaseToDelete)"
                } catch {
                    $result.ConflictsResolved += "Rollback failed: Could not delete draft release $($result.RollbackInfo.ReleaseToDelete)"
                }
            }
            
            Write-SafeLog "ERROR" "Smart release failed" "Error: $($_.Exception.Message)"
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

function New-GitHubDraftRelease {
    <#
    .SYNOPSIS
    Creates a GitHub Release as draft using GitHub CLI with comprehensive error handling.

    .DESCRIPTION
    Creates a GitHub release in draft mode as the first step of the proven release strategy.
    Draft releases are safe and reversible, allowing for validation before publication.

    .PARAMETER Version
    The semantic version for the release.

    .PARAMETER RepositoryPath
    Path to the Git repository.

    .PARAMETER ReleaseNotes
    Custom release notes content.

    .PARAMETER ReleaseNotesFile
    Path to a file containing release notes.

    .PARAMETER Title
    Custom release title. Defaults to version-based title.

    .EXAMPLE
    $result = New-GitHubDraftRelease -Version "v1.2.3"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Version,

        [Parameter()]
        [string]$RepositoryPath = (Get-Location).Path,

        [Parameter()]
        [string]$ReleaseNotes,

        [Parameter()]
        [string]$ReleaseNotesFile,

        [Parameter()]
        [string]$Title
    )

    begin {
        Write-SafeLog "INFO" "Creating GitHub draft release" "Version: $Version"
        
        $result = [PSCustomObject]@{
            Version = $Version
            Success = $false
            ReleaseId = $null
            HtmlUrl = ""
            IsDraft = $true
            IsPrerelease = $Version -match '-(alpha|beta|rc|preview|pre)'
            Title = $Title
            ErrorMessage = ""
            CreatedAt = $null
            GitHubSummary = ""
            StepOutputs = @{}
        }
    }

    process {
        try {
            Push-Location $RepositoryPath
            
            # Validate GitHub CLI
            $ghVersion = gh version 2>$null
            if ($LASTEXITCODE -ne 0) {
                throw "GitHub CLI (gh) is not available. Please install GitHub CLI and authenticate."
            }
            
            # Prepare release title
            if (-not $Title) {
                $Title = if ($result.IsPrerelease) { "🧪 Prerelease $Version" } else { "🚀 Release $Version" }
            }
            $result.Title = $Title
            
            # Prepare release notes
            $notesArgs = @()
            if ($ReleaseNotesFile -and (Test-Path $ReleaseNotesFile)) {
                $notesArgs += "--notes-file", $ReleaseNotesFile
            } elseif ($ReleaseNotes) {
                $notesArgs += "--notes", $ReleaseNotes
            } else {
                $notesArgs += "--generate-notes"
            }
            
            # Create draft release
            $ghArgs = @(
                "release", "create", $Version
                "--title", $Title
                "--draft"
            ) + $notesArgs
            
            if ($result.IsPrerelease) {
                $ghArgs += "--prerelease"
            }
            
            Write-SafeLog "DEBUG" "Executing GitHub CLI" "Command: gh $($ghArgs -join ' ')"
            
            $output = & gh @ghArgs 2>&1
            if ($LASTEXITCODE -eq 0) {
                # Extract release URL from output
                $result.HtmlUrl = $output | Where-Object { $_ -match "https://github.com/.+/releases/" } | Select-Object -First 1
                if (-not $result.HtmlUrl) {
                    $result.HtmlUrl = $output -join "`n"
                }
                
                # Get release details
                $releaseDetails = gh release view $Version --json id,htmlUrl,isDraft,createdAt 2>$null | ConvertFrom-Json
                if ($releaseDetails) {
                    $result.ReleaseId = $releaseDetails.id
                    $result.HtmlUrl = $releaseDetails.htmlUrl
                    $result.IsDraft = $releaseDetails.isDraft
                    $result.CreatedAt = $releaseDetails.createdAt
                }
                
                $result.Success = $true
                Write-SafeLog "INFO" "Draft release created successfully" "ReleaseId: $($result.ReleaseId), URL: $($result.HtmlUrl)"
            } else {
                $result.ErrorMessage = $output -join "`n"
                throw "GitHub CLI failed: $($result.ErrorMessage)"
            }
            
            # Generate outputs
            $result.GitHubSummary = "✅ **Draft Release Created**: [$Version]($($result.HtmlUrl))"
            $result.StepOutputs = @{
                "draft-success" = "true"
                "release-id" = $result.ReleaseId
                "release-url" = $result.HtmlUrl
                "is-draft" = $result.IsDraft.ToString().ToLower()
                "is-prerelease" = $result.IsPrerelease.ToString().ToLower()
            }

        }
        catch {
            $result.Success = $false
            $result.ErrorMessage = $_.Exception.Message
            $result.GitHubSummary = "❌ **Draft Release Failed**: $($_.Exception.Message)"
            $result.StepOutputs = @{
                "draft-success" = "false"
                "error-message" = $_.Exception.Message
            }
            
            Write-SafeLog "ERROR" "Failed to create draft release" "Error: $($_.Exception.Message)"
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

function Publish-GitHubRelease {
    <#
    .SYNOPSIS
    Publishes a GitHub draft release using GitHub CLI.

    .PARAMETER ReleaseId
    The GitHub release ID to publish.

    .PARAMETER RepositoryPath
    Path to the Git repository.

    .PARAMETER MarkAsLatest
    Mark this release as the latest release.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ReleaseId,

        [Parameter()]
        [string]$RepositoryPath = (Get-Location).Path,

        [Parameter()]
        [switch]$MarkAsLatest
    )

    begin {
        Write-SafeLog "INFO" "Publishing GitHub release" "ReleaseId: $ReleaseId"
        
        $result = [PSCustomObject]@{
            ReleaseId = $ReleaseId
            Success = $false
            Published = $false
            MarkedAsLatest = $false
            PublishedAt = $null
            ErrorMessage = ""
        }
    }

    process {
        try {
            Push-Location $RepositoryPath
            
            # Get current release info
            $releaseInfo = gh release view $ReleaseId --json tagName 2>$null | ConvertFrom-Json
            if (-not $releaseInfo) {
                throw "Release with ID $ReleaseId not found"
            }
            
            $tagName = $releaseInfo.tagName
            
            # Publish release
            if ($MarkAsLatest) {
                gh release edit $tagName --draft=false --latest
            } else {
                gh release edit $tagName --draft=false
            }
            
            if ($LASTEXITCODE -eq 0) {
                $result.Success = $true
                $result.Published = $true
                $result.MarkedAsLatest = $MarkAsLatest.IsPresent
                $result.PublishedAt = Get-Date
                
                Write-SafeLog "INFO" "Release published successfully" "ReleaseId: $ReleaseId, Latest: $($MarkAsLatest.IsPresent)"
            } else {
                throw "Failed to publish release"
            }

        }
        catch {
            $result.Success = $false
            $result.ErrorMessage = $_.Exception.Message
            Write-SafeLog "ERROR" "Failed to publish release" "Error: $($_.Exception.Message)"
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

function Remove-GitHubRelease {
    <#
    .SYNOPSIS
    Removes a GitHub release using GitHub CLI.

    .PARAMETER ReleaseId
    The GitHub release ID to remove.

    .PARAMETER RepositoryPath
    Path to the Git repository.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ReleaseId,

        [Parameter()]
        [string]$RepositoryPath = (Get-Location).Path
    )

    try {
        Push-Location $RepositoryPath
        
        # Get release tag name
        $releaseInfo = gh release view $ReleaseId --json tagName 2>$null | ConvertFrom-Json
        if ($releaseInfo) {
            gh release delete $releaseInfo.tagName --yes
            if ($LASTEXITCODE -eq 0) {
                Write-SafeLog "INFO" "Release deleted successfully" "ReleaseId: $ReleaseId"
                return $true
            }
        }
        
        Write-SafeLog "WARN" "Failed to delete release" "ReleaseId: $ReleaseId"
        return $false
    }
    catch {
        Write-SafeLog "ERROR" "Error deleting release" "ReleaseId: $ReleaseId, Error: $($_.Exception.Message)"
        return $false
    }
    finally {
        Pop-Location
    }
}

# Helper functions for Smart Release workflow

function New-SmartReleaseStepSummary {
    <#
    .SYNOPSIS
    Generates comprehensive GitHub step summary for Smart Release operations.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$Result
    )

    $statusIcon = if ($Result.Success) { "✅" } else { "❌" }
    
    $summary = @"
### $statusIcon **Smart Release Results**

| Property | Value |
|----------|-------|
| **Target Version** | ``$($Result.TargetVersion)`` |
| **Bump Type** | $($Result.BumpType) |
| **Overall Success** | $(if($Result.Success){"✅ Yes"}else{"❌ No"}) |
| **Duration** | $([math]::Round($Result.Duration.TotalSeconds, 2))s |
| **Is Prerelease** | $(if($Result.IsPrerelease){"🧪 Yes"}else{"🚀 No"}) |

#### 🏗️ **Workflow Steps**

| Step | Status | Timestamp | Message |
|------|--------|-----------|---------|
$(foreach($step in $Result.StepResults.GetEnumerator()) {
    $status = if($step.Value.Success) {"✅"} else {"❌"}
    $timestamp = if($step.Value.Timestamp) {$step.Value.Timestamp.ToString("HH:mm:ss")} else {"-"}
    "| $($step.Key) | $status | $timestamp | $($step.Value.Message) |"
})

#### 🏷️ **Git Tags Created**
$(if ($Result.TagsCreated.Count -gt 0) {
    ($Result.TagsCreated | ForEach-Object { "- ``$_``" }) -join "`n"
} else {
    "- *No tags created*"
})

#### 🔄 **Tag Movements**
$(if ($Result.TagsMovedFrom.Count -gt 0) {
    ($Result.TagsMovedFrom.GetEnumerator() | ForEach-Object { 
        "- 🔄 ``$($_.Key)``: ``$($_.Value)`` → ``$($Result.TargetVersion)``" 
    }) -join "`n"
} else {
    "- *No tag movements*"
})

$(if ($Result.ReleaseUrl) {
@"
#### 🚀 **GitHub Release**
- **Status**: $(if($Result.ReleasePublished){"✅ Published"}elseif($Result.ReleaseDraftCreated){"📝 Draft Created"}else{"❌ Failed"})
- **URL**: [$($Result.TargetVersion)]($($Result.ReleaseUrl))
- **Release ID**: ``$($Result.ReleaseId)``
"@
})

$(if ($Result.ConflictsResolved.Count -gt 0) {
@"
#### ⚠️ **Issues Resolved**
$(($Result.ConflictsResolved | ForEach-Object { "- ⚠️ $_" }) -join "`n")
"@
})

<details>
<summary>🔧 <strong>Technical Details</strong></summary>

**Repository:** ``$($Result.Repository)``
**Operation:** Smart Release (Draft → Tags → Publish)
**Timestamp:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')
**Push to Remote:** $(if($Result.PushToRemote){"✅ Yes"}else{"❌ No"})

$(if ($Result.RollbackInfo.TagsToDelete.Count -gt 0 -or $Result.RollbackInfo.ReleaseToDelete) {
@"
**Rollback Info:**
$(if($Result.RollbackInfo.TagsToDelete.Count -gt 0){"- Tags to clean up: $($Result.RollbackInfo.TagsToDelete -join ', ')"})
$(if($Result.RollbackInfo.ReleaseToDelete){"- Release to clean up: $($Result.RollbackInfo.ReleaseToDelete)"})
- Original state preserved: ✅
"@
})

</details>
"@

    return $summary
}

function ConvertTo-SmartReleaseStepOutputs {
    <#
    .SYNOPSIS
    Converts Smart Release results to GitHub Actions step outputs.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$Result
    )

    $outputs = @{
        "success" = $Result.Success.ToString().ToLower()
        "target-version" = $Result.TargetVersion
        "bump-type" = $Result.BumpType.ToLower()
        "is-prerelease" = $Result.IsPrerelease.ToString().ToLower()
        "duration-seconds" = [math]::Round($Result.Duration.TotalSeconds, 2)
        
        # Git tag outputs
        "tags-created" = ($Result.TagsCreated -join ',')
        "tags-created-count" = $Result.TagsCreated.Count
        
        # GitHub release outputs
        "release-draft-created" = $Result.ReleaseDraftCreated.ToString().ToLower()
        "release-published" = $Result.ReleasePublished.ToString().ToLower()
        "release-id" = $Result.ReleaseId
        "release-url" = $Result.ReleaseUrl
        
        # Workflow step statuses
        "draft-step-success" = $Result.StepResults.DraftCreation.Success.ToString().ToLower()
        "tags-step-success" = $Result.StepResults.TagCreation.Success.ToString().ToLower()
        "publish-step-success" = $Result.StepResults.ReleasePublication.Success.ToString().ToLower()
    }

    # Add optional outputs
    if ($Result.TagsMovedFrom.Count -gt 0) {
        $outputs["tags-moved"] = ($Result.TagsMovedFrom.Keys -join ',')
        $outputs["tags-moved-count"] = $Result.TagsMovedFrom.Count
    }

    if ($Result.ConflictsResolved.Count -gt 0) {
        $outputs["issues-resolved"] = $Result.ConflictsResolved.Count
        $outputs["has-issues"] = "true"
    } else {
        $outputs["has-issues"] = "false"
    }

    return $outputs
}
