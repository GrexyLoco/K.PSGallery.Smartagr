# Semantic Version Utilities - Parsing, validation, and comparison functions

function ConvertTo-SemanticVersionObject {
    <#
    .SYNOPSIS
        Converts a Git tag name to a structured semantic version object.
    
    .DESCRIPTION
        Parses a Git tag name and extracts semantic version components including
        major, minor, patch, pre-release identifiers, and build metadata.
        
        Supports multiple formats:
        - v1.2.3, 1.2.3 (standard versions)
        - v1.2.3-alpha.1 (pre-release)
        - v1.2.3+build.123 (build metadata)
        - v1.2.3-alpha.1+build.123 (combined)
    
    .PARAMETER TagName
        Git tag name to parse
    
    .OUTPUTS
        [PSCustomObject] Structured version object with Tag, Version, IsPreRelease, and metadata properties
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TagName
    )
    
    try {
        Write-SafeDebugLog "Parsing semantic version tag" -Context "TagName: $TagName"
        
        # Extract version string (remove 'v' prefix if present)
        $versionString = if ($TagName.StartsWith('v')) {
            $TagName.Substring(1)
        } else {
            $TagName
        }
        
        Write-SafeDebugLog "Extracted version string" -Context "Original: $TagName`nVersionString: $versionString"
        
        # Parse using PowerShell's semantic version class
        $semVer = [System.Management.Automation.SemanticVersion]::new($versionString)
        
        # Determine pre-release information
        $isPreRelease = -not [string]::IsNullOrEmpty($semVer.PreReleaseLabel)
        $preReleaseLabel = if ($isPreRelease) {
            # Extract just the label part (alpha, beta, rc, etc.)
            if ($semVer.PreReleaseLabel -match '^([a-zA-Z]+)') {
                $matches[1]
            } else {
                $semVer.PreReleaseLabel
            }
        } else {
            $null
        }
        
        $parsedVersion = [PSCustomObject]@{
            Tag = $TagName
            Version = $semVer
            IsPreRelease = $isPreRelease
            PreReleaseLabel = $preReleaseLabel
            Major = $semVer.Major
            Minor = $semVer.Minor
            Patch = $semVer.Patch
            BuildLabel = $semVer.BuildLabel
        }
        
        Write-SafeDebugLog "Successfully parsed semantic version" -Context "Tag: $TagName`nMajor: $($semVer.Major)`nMinor: $($semVer.Minor)`nPatch: $($semVer.Patch)`nIsPreRelease: $isPreRelease"
        
        return $parsedVersion
        
    }
    catch {
        $warningMsg = "Failed to parse semantic version from tag '$TagName': $($_.Exception.Message)"
        Write-SafeWarningLog $warningMsg
        return $null
    }
}

function Test-TargetVersionValidity {
    <#
    .SYNOPSIS
        Validates a target version against existing tags and semantic versioning rules.
    
    .DESCRIPTION
        Comprehensive validation of a target version including:
        - Semantic version format compliance
        - Comparison with existing versions
        - Conflict detection
        - Version progression logic
    
    .PARAMETER TargetVersion
        The target version to validate
    
    .PARAMETER ExistingTags
        Array of existing semantic version tags
    
    .PARAMETER Force
        Skip certain validations when forcing creation
    
    .OUTPUTS
        [PSCustomObject] Validation result with IsValid, ErrorMessage, and Warnings properties
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TargetVersion,
        
        [Parameter()]
        [PSCustomObject[]]$ExistingTags = @(),
        
        [Parameter()]
        [switch]$Force
    )
    
    $result = [PSCustomObject]@{
        IsValid = $false
        ErrorMessage = ""
        Warnings = @()
    }
    
    try {
        Write-SafeInfoLog "Starting target version validation" -Context "TargetVersion: $TargetVersion`nExistingTagCount: $($ExistingTags.Count)`nForce: $Force"
        
        # Parse target version
        $targetObj = ConvertTo-SemanticVersionObject -TagName $TargetVersion
        if (-not $targetObj) {
            $errorMsg = "Target version '$TargetVersion' is not a valid semantic version."
            Write-SafeErrorLog $errorMsg
            $result.ErrorMessage = $errorMsg
            return $result
        }
        
        Write-SafeDebugLog "Target version parsed successfully" -Context "ParsedVersion: $($targetObj.Version)"
        
        # Check if version already exists
        $existingTag = $ExistingTags | Where-Object { $_.Tag -eq $TargetVersion }
        if ($existingTag -and -not $Force) {
            $result.ErrorMessage = "Version '$TargetVersion' already exists. Use -Force to overwrite."
            return $result
        }
        
        if ($ExistingTags.Count -gt 0) {
            # Get latest existing version
            $latestExisting = $ExistingTags | Sort-Object { $_.Version } -Descending | Select-Object -First 1
            
            # Check if target version is progression forward
            if ($targetObj.Version -le $latestExisting.Version) {
                if ($Force) {
                    $result.Warnings += "Target version '$TargetVersion' is not newer than latest existing version '$($latestExisting.Tag)'. Proceeding due to -Force."
                } else {
                    $result.ErrorMessage = "Target version '$TargetVersion' must be newer than latest existing version '$($latestExisting.Tag)'."
                    return $result
                }
            }
            
            # Check for large version jumps (potential typos)
            $majorJump = $targetObj.Major - $latestExisting.Major
            $minorJump = $targetObj.Minor - $latestExisting.Minor
            
            if ($majorJump -gt 1) {
                $result.Warnings += "Large major version jump detected ($($latestExisting.Major) → $($targetObj.Major)). Verify this is intentional."
            } elseif ($majorJump -eq 0 -and $minorJump -gt 5) {
                $result.Warnings += "Large minor version jump detected ($($latestExisting.Minor) → $($targetObj.Minor)). Verify this is intentional."
            }
        }
        
        $result.IsValid = $true
        return $result
        
    }
    catch {
        $result.ErrorMessage = "Version validation failed: $($_.Exception.Message)"
        return $result
    }
}

function Get-SmartTagStrategy {
    <#
    .SYNOPSIS
        Calculates the smart tag strategy for a target version release.
    
    .DESCRIPTION
        Determines which smart tags to create, update, or preserve based on the target version
        and existing tag structure. Implements the core logic for moving vs. static tags.
        
        Key Logic:
        - Patch updates: Current major/minor smart tags move with the new version
        - Minor updates: Major smart tag moves, previous minor smart tag becomes static
        - Major updates: All previous smart tags become static, new smart tags created
    
    .PARAMETER TargetVersion
        The version being released
    
    .PARAMETER ExistingTags
        Current semantic version tags in the repository
    
    .OUTPUTS
        [PSCustomObject] Strategy object with arrays of tags to create, update, and preserve
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TargetVersion,
        
        [Parameter()]
        [PSCustomObject[]]$ExistingTags = @()
    )
    
    $strategy = [PSCustomObject]@{
        SmartTagsToCreate = @()
        MovingTagsToUpdate = @()
        TagsToBecomeStatic = @()
    }
    
    try {
        $targetObj = ConvertTo-SemanticVersionObject -TagName $TargetVersion
        if (-not $targetObj) {
            throw "Invalid target version: $TargetVersion"
        }
        
        # Always update 'latest' tag
        $strategy.MovingTagsToUpdate += [PSCustomObject]@{
            Name = "latest"
            NewTarget = $TargetVersion
        }
        
        if ($ExistingTags.Count -eq 0) {
            # First release - create all smart tags
            $strategy.SmartTagsToCreate += [PSCustomObject]@{
                Name = "v$($targetObj.Major)"
                Target = $TargetVersion
            }
            
            if ($targetObj.Minor -gt 0 -or $targetObj.Patch -gt 0) {
                $strategy.SmartTagsToCreate += [PSCustomObject]@{
                    Name = "v$($targetObj.Major).$($targetObj.Minor)"
                    Target = $TargetVersion
                }
            }
        } else {
            # Get latest version for comparison
            $latestExisting = $ExistingTags | Sort-Object { $_.Version } -Descending | Select-Object -First 1
            
            $majorChange = $targetObj.Major -ne $latestExisting.Major
            $minorChange = $targetObj.Minor -ne $latestExisting.Minor
            
            if ($majorChange) {
                # Major version change - preserve old smart tags, create new ones
                $oldMajorTags = $ExistingTags | Where-Object { 
                    $_.Tag -match "^v$($latestExisting.Major)(\.\d+)?$" 
                }
                $strategy.TagsToBecomeStatic += $oldMajorTags
                
                # Create new major smart tags
                $strategy.SmartTagsToCreate += [PSCustomObject]@{
                    Name = "v$($targetObj.Major)"
                    Target = $TargetVersion
                }
                
                if ($targetObj.Minor -gt 0 -or $targetObj.Patch -gt 0) {
                    $strategy.SmartTagsToCreate += [PSCustomObject]@{
                        Name = "v$($targetObj.Major).$($targetObj.Minor)"
                        Target = $TargetVersion
                    }
                }
                
            } elseif ($minorChange) {
                # Minor version change - major tag moves, old minor becomes static
                $majorTag = "v$($targetObj.Major)"
                $oldMinorTag = "v$($latestExisting.Major).$($latestExisting.Minor)"
                
                # Major tag moves
                $strategy.SmartTagsToCreate += [PSCustomObject]@{
                    Name = $majorTag
                    Target = $TargetVersion
                }
                
                # Old minor tag becomes static
                $existingMinorTag = $ExistingTags | Where-Object { $_.Tag -eq $oldMinorTag }
                if ($existingMinorTag) {
                    $strategy.TagsToBecomeStatic += $existingMinorTag
                }
                
                # Create new minor tag
                $strategy.SmartTagsToCreate += [PSCustomObject]@{
                    Name = "v$($targetObj.Major).$($targetObj.Minor)"
                    Target = $TargetVersion
                }
                
            } else {
                # Patch version change - both major and minor tags move
                $majorTag = "v$($targetObj.Major)"
                $minorTag = "v$($targetObj.Major).$($targetObj.Minor)"
                
                $strategy.SmartTagsToCreate += [PSCustomObject]@{
                    Name = $majorTag
                    Target = $TargetVersion
                }
                
                $strategy.SmartTagsToCreate += [PSCustomObject]@{
                    Name = $minorTag
                    Target = $TargetVersion
                }
            }
        }
        
        return $strategy
        
    }
    catch {
        Write-Error "Failed to calculate smart tag strategy: $($_.Exception.Message)"
        throw
    }
}

function Compare-SemanticVersions {
    <#
    .SYNOPSIS
        Compares two semantic versions and returns the relationship.
    
    .DESCRIPTION
        Performs semantic version comparison following semver.org rules.
        Handles pre-release versions, build metadata, and edge cases.
    
    .PARAMETER Version1
        First version to compare
    
    .PARAMETER Version2
        Second version to compare
    
    .OUTPUTS
        [int] -1 if Version1 < Version2, 0 if equal, 1 if Version1 > Version2
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Version1,
        
        [Parameter(Mandatory)]
        [string]$Version2
    )
    
    try {
        $v1Obj = ConvertTo-SemanticVersionObject -TagName $Version1
        $v2Obj = ConvertTo-SemanticVersionObject -TagName $Version2
        
        if (-not $v1Obj -or -not $v2Obj) {
            throw "Invalid semantic version format in comparison."
        }
        
        return $v1Obj.Version.CompareTo($v2Obj.Version)
        
    }
    catch {
        Write-Error "Failed to compare semantic versions '$Version1' and '$Version2': $($_.Exception.Message)"
        throw
    }
}

function Test-IsValidSemanticVersion {
    <#
    .SYNOPSIS
        Tests if a string represents a valid semantic version.
    
    .DESCRIPTION
        Validates semantic version format according to semver.org specification.
        Supports v-prefixed versions, pre-release labels, and build metadata.
    
    .PARAMETER Version
        Version string to validate
    
    .PARAMETER AllowVPrefix
        Allow 'v' prefix (default: true)
    
    .PARAMETER AllowPreRelease
        Allow pre-release versions (default: true)
    
    .OUTPUTS
        [bool] True if version is valid, false otherwise
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Version,
        
        [Parameter()]
        [bool]$AllowVPrefix = $true,
        
        [Parameter()]
        [bool]$AllowPreRelease = $true
    )
    
    try {
        # Check v-prefix restriction
        if (-not $AllowVPrefix -and $Version.StartsWith('v')) {
            return $false
        }
        
        $versionObj = ConvertTo-SemanticVersionObject -TagName $Version
        if (-not $versionObj) {
            return $false
        }
        
        # Check pre-release restriction
        if (-not $AllowPreRelease -and $versionObj.IsPreRelease) {
            return $false
        }
        
        return $true
        
    }
    catch {
        return $false
    }
}
