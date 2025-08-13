# Run-CleanTests.ps1 - Runs tests with proper module cleanup
# Enhanced version compatible with GitHub Actions Scripts

[CmdletBinding()]
param(
    [string]$TestPath = './Tests',
    [string]$Output = 'Detailed',
    [string]$OutputPath = './TestResults.xml',
    [switch]$PassThru,
    [switch]$EnableCodeCoverage = $false
)

# Check if we're in a GitHub Actions environment
$isGitHubActions = $env:GITHUB_ACTIONS -eq 'true'

if ($isGitHubActions -and (Test-Path './.github/Scripts/Setup-CleanTestEnvironment.ps1')) {
    # Use GitHub Actions Scripts approach
    Write-Host "🎭 GitHub Actions environment detected - using Scripts approach" -ForegroundColor Cyan
    
    # Setup environment
    & "./.github/Scripts/Setup-CleanTestEnvironment.ps1" -TestPath $TestPath -OutputPath $OutputPath
    
    # Run tests
    $result = & "./.github/Scripts/Invoke-CleanPesterTests.ps1" -TestPath $TestPath -OutputPath $OutputPath -EnableCodeCoverage:$EnableCodeCoverage -PassThru:$PassThru
    
    # Generate summary (only in non-PassThru mode for GitHub Actions)
    if (-not $PassThru) {
        & "./.github/Scripts/Generate-TestSummary.ps1" -TotalTests $result.TotalCount -PassedTests $result.PassedCount -FailedTests $result.FailedCount -SkippedTests $result.SkippedCount -Duration $result.Duration -TestResultsPath $OutputPath
    }
    
    if ($PassThru) {
        return $result
    }
} else {
    # Use local approach (existing implementation)
    Write-Host "🏠 Local environment detected - using direct approach" -ForegroundColor Cyan
    
    # Force remove any existing modules before starting
    Write-Host "🧹 Cleaning up existing modules..." -ForegroundColor Yellow
    Get-Module K.PSGallery.SemanticVersioning | Remove-Module -Force -ErrorAction SilentlyContinue

    # Clear PowerShell module cache
    Write-Host "🔄 Clearing module cache..." -ForegroundColor Yellow
    if (Get-Module K.PSGallery.SemanticVersioning -ListAvailable -ErrorAction SilentlyContinue) {
        Remove-Module K.PSGallery.SemanticVersioning -Force -ErrorAction SilentlyContinue
    }

    Write-Host "🚀 Starting tests with clean environment..." -ForegroundColor Green

    try {
        if ($PassThru) {
            $result = Invoke-Pester -Path $TestPath -Output $Output -PassThru
            return $result
        } else {
            Invoke-Pester -Path $TestPath -Output $Output
        }
        
        Write-Host "✅ Tests completed" -ForegroundColor Green
        
    } finally {
        # Final cleanup
        Write-Host "🧹 Final cleanup..." -ForegroundColor Yellow
        Get-Module K.PSGallery.SemanticVersioning | Remove-Module -Force -ErrorAction SilentlyContinue
        
        # Clean up any test artifacts
        Get-ChildItem -Path $TestPath -Filter "TestModule*.psd1" -ErrorAction SilentlyContinue | 
            Remove-Item -Force -ErrorAction SilentlyContinue
        
        Write-Host "✅ Cleanup completed" -ForegroundColor Green
    }
}
