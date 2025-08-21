function New-GitHubRelease {
    <#
    .SYNOPSIS
        Creates a GitHub Release with automatic tag creation and comprehensive release notes.
    
    .DESCRIPTION
        Creates a GitHub Release using the GitHub CLI with intelligent release note generation,
        pre-release detection, and proper tag management. This function complements the smart tag
        functionality by creating official GitHub releases with rich metadata.
    
    .PARAMETER Version
        The semantic version for the release (e.g., "v1.2.0", "v2.0.0-alpha.1")
    
    .PARAMETER RepositoryPath
        Path to the Git repository. Defaults to current directory.
    
    .PARAMETER Title
        Custom release title. Defaults to auto-generated based on version.
    
    .PARAMETER ReleaseNotes
        Custom release notes. If not provided, generates automatic release notes.
    
    .PARAMETER ReleaseNotesFile
        Path to a file containing release notes.
    
    .PARAMETER Draft
        Create as draft release (not published immediately)
    
    .PARAMETER Prerelease
        Mark as prerelease (auto-detected from version if not specified)
    
    .PARAMETER GenerateNotes
        Generate release notes automatically using GitHub's generation feature
    
    .PARAMETER CreateTags
        Also create smart tags using New-SemanticReleaseTags
    
    .PARAMETER PushTags
        Push created tags to remote repository
    
    .OUTPUTS
        [PSCustomObject] Result with Success, ReleaseUrl, TagsCreated, and any warnings
    
    .EXAMPLE
        New-GitHubRelease -Version "v1.2.0"
        
        Creates a GitHub release v1.2.0 with automatic release notes and smart tags
    
    .EXAMPLE
        New-GitHubRelease -Version "v2.0.0-alpha.1" -Draft -CreateTags
        
        Creates a draft pre-release with smart tags for alpha version
    
    .EXAMPLE
        New-GitHubRelease -Version "v1.5.0" -ReleaseNotesFile "CHANGELOG.md" -CreateTags -PushTags
        
        Creates release with custom notes, smart tags, and pushes to remote
    
    .NOTES
        Requires GitHub CLI (gh) to be installed and authenticated.
        Pre-release versions are automatically detected based on semantic version format.
        Smart tags are created only for stable releases unless explicitly requested.
    
    .LINK
        New-SemanticReleaseTags
        https://cli.github.com/
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({
            if ($_ -match '^v?\d+\.\d+\.\d+(-(?:alpha|beta|rc)(?:\.\d+)?)?(\+[a-zA-Z0-9\-\.]+)?$') {
                $true
            } else {
                throw "Version '$_' is not a valid semantic version. Expected format: 'v1.2.3', '1.2.3' with optional pre-release identifiers 'alpha', 'beta', 'rc'."
            }
        })]
        [string]$Version,

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
        [string]$Title,

        [Parameter()]
        [string]$ReleaseNotes,

        [Parameter()]
        [ValidateScript({
            if (Test-Path $_ -PathType Leaf) {
                $true
            } else {
                throw "ReleaseNotesFile '$_' does not exist."
            }
        })]
        [string]$ReleaseNotesFile,

        [Parameter()]
        [switch]$Draft,

        [Parameter()]
        [switch]$Prerelease,

        [Parameter()]
        [switch]$GenerateNotes,

        [Parameter()]
        [switch]$CreateTags,

        [Parameter()]
        [switch]$PushTags
    )

    begin {
        Write-SafeLog "INFO" "Starting GitHub Release creation" "Version: $Version"
        
        # Validate GitHub CLI availability
        try {
            $ghVersion = gh --version 2>$null
            if ($LASTEXITCODE -ne 0) {
                throw "GitHub CLI (gh) is not installed or not in PATH. Please install from https://cli.github.com/"
            }
            Write-SafeLog "DEBUG" "GitHub CLI available" "Version: $($ghVersion -split "`n" | Select-Object -First 1)"
        }
        catch {
            throw "GitHub CLI validation failed: $($_.Exception.Message)"
        }

        # Test GitHub authentication
        try {
            gh auth status 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "GitHub CLI is not authenticated. Please run 'gh auth login' first."
            }
            Write-SafeLog "DEBUG" "GitHub CLI authentication verified"
        }
        catch {
            throw "GitHub authentication check failed: $($_.Exception.Message)"
        }
    }

    process {
        $result = [PSCustomObject]@{
            Success = $false
            ReleaseUrl = ""
            TagsCreated = @()
            Warnings = @()
            Version = $Version
        }

        try {
            Push-Location $RepositoryPath
            Write-SafeLog "DEBUG" "Changed to repository directory" "RepositoryPath: $RepositoryPath"

            # Normalize version (add v prefix if missing)
            $normalizedVersion = if ($Version.StartsWith('v')) { $Version } else { "v$Version" }
            Write-SafeLog "DEBUG" "Version normalized" "Original: $Version`nNormalized: $normalizedVersion"

            # Auto-detect prerelease from version
            $isPrerelease = $normalizedVersion -match '-(?:alpha|beta|rc)'
            if ($Prerelease) {
                $isPrerelease = $true
            }
            Write-SafeLog "DEBUG" "Pre-release detection" "IsPrerelease: $isPrerelease"

            # Generate title if not provided
            if (-not $Title) {
                $Title = if ($isPrerelease) {
                    "🧪 Prerelease $normalizedVersion"
                } else {
                    "🚀 Release $normalizedVersion"
                }
            }
            Write-SafeLog "DEBUG" "Release title determined" "Title: $Title"

            # Create smart tags first if requested
            if ($CreateTags) {
                Write-SafeLog "INFO" "Creating smart tags before GitHub release"
                if ($PSCmdlet.ShouldProcess($normalizedVersion, "Create smart tags")) {
                    try {
                        $tagResult = New-SemanticReleaseTags -TargetVersion $normalizedVersion -RepositoryPath $RepositoryPath -PushToRemote:$PushTags
                        if ($tagResult.Success) {
                            $result.TagsCreated = $tagResult.ReleaseTags + $tagResult.SmartTags + $tagResult.MovingTags
                            Write-SafeLog "INFO" "Smart tags created successfully" "TagsCreated: $($result.TagsCreated.Count)"
                        } else {
                            $result.Warnings += "Smart tag creation had issues"
                            Write-SafeLog "WARNING" "Smart tag creation completed with warnings"
                        }
                    }
                    catch {
                        $result.Warnings += "Smart tag creation failed: $($_.Exception.Message)"
                        Write-SafeLog "ERROR" "Smart tag creation failed" "Error: $($_.Exception.Message)"
                    }
                }
            }

            # Build GitHub CLI command
            $ghCommand = @('gh', 'release', 'create', $normalizedVersion)
            $ghCommand += @('--title', $Title)

            # Add release notes
            if ($ReleaseNotesFile) {
                $ghCommand += @('--notes-file', $ReleaseNotesFile)
                Write-SafeLog "DEBUG" "Using release notes from file" "File: $ReleaseNotesFile"
            }
            elseif ($ReleaseNotes) {
                $ghCommand += @('--notes', $ReleaseNotes)
                Write-SafeLog "DEBUG" "Using provided release notes"
            }
            elseif ($GenerateNotes) {
                $ghCommand += @('--generate-notes')
                Write-SafeLog "DEBUG" "Using auto-generated release notes"
            }
            else {
                # Default release notes
                $defaultNotes = @"
## 🚀 Release $normalizedVersion

This release was created automatically using K.PSGallery.Smartagr.

### 📋 Release Information
- **Version**: ``$normalizedVersion``
- **Type**: $(if ($isPrerelease) { 'Pre-release' } else { 'Stable Release' })
- **Branch**: ``$(git branch --show-current)``
- **Commit**: ``$(git rev-parse --short HEAD)``
- **Created**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')

$(if ($result.TagsCreated.Count -gt 0) {
"### 🏷️ Tags Created
" + ($result.TagsCreated | ForEach-Object { "- ``$_``" }) -join "`n"
})

---
*Generated by [K.PSGallery.Smartagr](https://github.com/GrexyLoco/K.PSGallery.Smartagr)*
"@
                $ghCommand += @('--notes', $defaultNotes)
                Write-SafeLog "DEBUG" "Using default generated release notes"
            }

            # Add prerelease and draft flags
            if ($isPrerelease) {
                $ghCommand += @('--prerelease')
                Write-SafeLog "DEBUG" "Marked as pre-release"
            }
            if ($Draft) {
                $ghCommand += @('--draft')
                Write-SafeLog "DEBUG" "Marked as draft"
            }

            # Execute GitHub release creation
            Write-SafeLog "INFO" "Creating GitHub release" "Command: $($ghCommand -join ' ')"
            if ($PSCmdlet.ShouldProcess($normalizedVersion, "Create GitHub Release")) {
                
                # Check if release already exists
                gh release view $normalizedVersion 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-SafeLog "WARNING" "Release already exists" "Version: $normalizedVersion"
                    
                    if ($PSCmdlet.ShouldContinue("Release $normalizedVersion already exists. Delete and recreate?", "Confirm Release Recreation")) {
                        Write-SafeLog "INFO" "Deleting existing release for recreation"
                        gh release delete $normalizedVersion --yes 2>$null
                        Start-Sleep -Seconds 2  # Wait for GitHub API
                    } else {
                        $result.Warnings += "Release creation skipped - already exists"
                        $result.Success = $true
                        return $result
                    }
                }

                # Create the release
                $releaseOutput = & $ghCommand[0] $ghCommand[1..($ghCommand.Length-1)] 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $result.Success = $true
                    $result.ReleaseUrl = ($releaseOutput | Where-Object { $_ -match '^https://github.com' } | Select-Object -First 1)
                    
                    Write-SafeLog "INFO" "GitHub release created successfully" "ReleaseUrl: $($result.ReleaseUrl)"
                    Write-Host "✅ GitHub Release created: $normalizedVersion" -ForegroundColor Green
                    
                    if ($result.ReleaseUrl) {
                        Write-Host "🔗 Release URL: $($result.ReleaseUrl)" -ForegroundColor Cyan
                    }
                } else {
                    $errorMsg = "GitHub release creation failed: $($releaseOutput -join ';')"
                    Write-SafeLog "ERROR" $errorMsg
                    
                    # Check if release was actually created despite the error
                    gh release view $normalizedVersion 2>$null | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-SafeLog "INFO" "Release exists despite error - treating as success"
                        $result.Success = $true
                        $result.Warnings += "Release created with warnings"
                        $result.ReleaseUrl = "https://github.com/$(gh repo view --json owner,name -q '.owner.login + "/" + .name')/releases/tag/$normalizedVersion"
                    } else {
                        throw $errorMsg
                    }
                }
            }

        }
        catch {
            $result.Success = $false
            $errorMsg = "Failed to create GitHub release: $($_.Exception.Message)"
            Write-SafeLog "ERROR" $errorMsg
            Write-Error $errorMsg
        }
        finally {
            Pop-Location
        }
    }

    end {
        Write-SafeLog "INFO" "GitHub Release creation completed" "Success: $($result.Success)"
        return $result
    }
}
