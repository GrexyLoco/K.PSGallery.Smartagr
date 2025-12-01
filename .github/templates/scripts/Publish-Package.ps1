<#
.SYNOPSIS
    Publishes PowerShell module to GitHub Packages via K.PSGallery.PackageRepoProvider.

.DESCRIPTION
    Installs K.PSGallery.PackageRepoProvider from GitHub Packages and uses it for
    intelligent package publishing. Falls back to built-in Publish-PSResource
    if provider module installation fails.

.PARAMETER ModuleName
    Name of the PowerShell module to publish.

.PARAMETER NewVersion
    Version to publish (used for verification).

.PARAMETER GitHubToken
    GitHub token for package publishing authentication.

.PARAMETER RepositoryOwner
    GitHub repository owner (e.g., 'GrexyLoco').

.OUTPUTS
    Writes publish summary to GITHUB_STEP_SUMMARY.
    Sets GITHUB_OUTPUT variable: package-published (true/false)

.EXAMPLE
    ./Publish-Package.ps1 -ModuleName "MyModule" -NewVersion "1.2.3" -GitHubToken $env:GITHUB_TOKEN -RepositoryOwner "GrexyLoco"

.NOTES
    Platform-independent script for GitHub Actions workflows.
    Installs K.PSGallery.PackageRepoProvider from GitHub Packages, then uses it to publish.
    Handles repository registration, package publishing, and cleanup.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ModuleName,
    
    [Parameter(Mandatory = $true)]
    [string]$NewVersion,
    
    [Parameter(Mandatory = $true)]
    [string]$GitHubToken,
    
    [Parameter(Mandatory = $true)]
    [string]$RepositoryOwner
)

# ═══════════════════════════════════════════════════════════════════════════
# 📋 Summary Header
# ═══════════════════════════════════════════════════════════════════════════
Write-Output "## 📦 Package Publishing" >> $env:GITHUB_STEP_SUMMARY
Write-Output "" >> $env:GITHUB_STEP_SUMMARY
Write-Output "| Property | Value |" >> $env:GITHUB_STEP_SUMMARY
Write-Output "|----------|-------|" >> $env:GITHUB_STEP_SUMMARY
Write-Output "| **Module** | ``$ModuleName`` |" >> $env:GITHUB_STEP_SUMMARY
Write-Output "| **Version** | ``$NewVersion`` |" >> $env:GITHUB_STEP_SUMMARY
Write-Output "| **Target** | GitHub Packages |" >> $env:GITHUB_STEP_SUMMARY
Write-Output "" >> $env:GITHUB_STEP_SUMMARY

# ═══════════════════════════════════════════════════════════════════════════
# 🔧 Configuration
# ═══════════════════════════════════════════════════════════════════════════
$registryUri = "https://nuget.pkg.github.com/$RepositoryOwner/index.json"
$repoName = 'GitHubPackages'

# ═══════════════════════════════════════════════════════════════════════════
# 📦 Install K.PSGallery.PackageRepoProvider from GitHub Packages
# ═══════════════════════════════════════════════════════════════════════════
function Install-PackageRepoProvider {
    param([string]$Token, [string]$Owner)
    
    Write-Output "📦 Installing K.PSGallery.PackageRepoProvider from GitHub Packages..."
    
    # Create credential for GitHub Packages
    $secureToken = ConvertTo-SecureString $Token -AsPlainText -Force
    $credential = New-Object PSCredential($Owner, $secureToken)
    
    # Register GitHub Packages as PSResource repository (for installation)
    $tempRepoName = 'GHPackages-Temp'
    $uri = "https://nuget.pkg.github.com/$Owner/index.json"
    
    # Remove if exists
    Unregister-PSResourceRepository -Name $tempRepoName -ErrorAction SilentlyContinue
    
    # Register
    Register-PSResourceRepository -Name $tempRepoName -Uri $uri -Trusted -ErrorAction Stop
    
    # Install the provider module
    Install-PSResource -Name 'K.PSGallery.PackageRepoProvider' `
        -Repository $tempRepoName `
        -Credential $credential `
        -Scope CurrentUser `
        -TrustRepository `
        -ErrorAction Stop
    
    # Import the module
    Import-Module K.PSGallery.PackageRepoProvider -Force -ErrorAction Stop
    
    Write-Output "✅ K.PSGallery.PackageRepoProvider installed and imported"
    
    # Cleanup temp repository
    Unregister-PSResourceRepository -Name $tempRepoName -ErrorAction SilentlyContinue
}

# ═══════════════════════════════════════════════════════════════════════════
# 🚀 Main Publishing Logic
# ═══════════════════════════════════════════════════════════════════════════
try {
    # Step 1: Install PackageRepoProvider from GitHub Packages
    Install-PackageRepoProvider -Token $GitHubToken -Owner $RepositoryOwner
    
    Write-Output "📝 Registering repository: $repoName"
    
    # Step 2: Register the target repository using PackageRepoProvider
    Register-PackageRepo `
        -RepositoryName $repoName `
        -RegistryUri $registryUri `
        -Token $GitHubToken `
        -Trusted
    
    Write-Output "🚀 Publishing module: $ModuleName"
    
    # Step 3: Publish the module
    Publish-Package `
        -RepositoryName $repoName `
        -Token $GitHubToken
    
    # Success summary
    Write-Output "### ✅ Published via K.PSGallery.PackageRepoProvider" >> $env:GITHUB_STEP_SUMMARY
    Write-Output "" >> $env:GITHUB_STEP_SUMMARY
    Write-Output "- **Registry:** ``$registryUri``" >> $env:GITHUB_STEP_SUMMARY
    Write-Output "- **Package:** ``$ModuleName@$NewVersion``" >> $env:GITHUB_STEP_SUMMARY
    
    "package-published=true" >> $env:GITHUB_OUTPUT
    
    Write-Output "✅ Successfully published $ModuleName@$NewVersion to GitHub Packages"
}
catch {
    Write-Output "⚠️ PackageRepoProvider failed: $($_.Exception.Message)"
    Write-Output "🔄 Falling back to Publish-PSResource..."
    Write-Output "### ⚠️ Fallback: Publish-PSResource" >> $env:GITHUB_STEP_SUMMARY
    
    # ═══════════════════════════════════════════════════════════════════════
    # 🔄 Fallback: Built-in Publish-PSResource
    # ═══════════════════════════════════════════════════════════════════════
    try {
        # Create credential
        $secureToken = ConvertTo-SecureString $GitHubToken -AsPlainText -Force
        $credential = New-Object PSCredential($RepositoryOwner, $secureToken)
        
        # Register repository
        Unregister-PSResourceRepository -Name $repoName -ErrorAction SilentlyContinue
        Register-PSResourceRepository -Name $repoName -Uri $registryUri -Trusted -ErrorAction Stop
        
        # Find module path (cross-platform)
        $moduleSubPath = Join-Path -Path '.' -ChildPath $ModuleName
        $modulePath = if (Test-Path $moduleSubPath) { $moduleSubPath } else { '.' }
        
        # Publish module
        Publish-PSResource `
            -Path $modulePath `
            -Repository $repoName `
            -ApiKey $GitHubToken `
            -ErrorAction Stop
        
        Write-Output "- ✅ Published via Publish-PSResource" >> $env:GITHUB_STEP_SUMMARY
        Write-Output "- **Package:** ``$ModuleName@$NewVersion``" >> $env:GITHUB_STEP_SUMMARY
        
        "package-published=true" >> $env:GITHUB_OUTPUT
        
        Write-Output "✅ Successfully published $ModuleName@$NewVersion via fallback"
    }
    catch {
        Write-Error "❌ Package publishing failed: $($_.Exception.Message)"
        Write-Output "### ❌ Publishing Failed" >> $env:GITHUB_STEP_SUMMARY
        Write-Output "" >> $env:GITHUB_STEP_SUMMARY
        Write-Output "``````" >> $env:GITHUB_STEP_SUMMARY
        Write-Output $_.Exception.Message >> $env:GITHUB_STEP_SUMMARY
        Write-Output "``````" >> $env:GITHUB_STEP_SUMMARY
        
        "package-published=false" >> $env:GITHUB_OUTPUT
        exit 1
    }
    finally {
        # Cleanup
        Unregister-PSResourceRepository -Name $repoName -ErrorAction SilentlyContinue
    }
}
finally {
    # Final cleanup - only if PackageRepoProvider was loaded
    if (Get-Command Remove-PackageRepo -ErrorAction SilentlyContinue) {
        Remove-PackageRepo -RepositoryName $repoName -ErrorAction SilentlyContinue
    }
}
