# 🧪 Invoke-CleanPesterTests.ps1
# Executes clean Pester tests with comprehensive reporting

[CmdletBinding()]
param(
    [string]$TestPath = './Tests',
    [string]$OutputPath = './TestResults.xml',
    [switch]$EnableCodeCoverage = $false,
    [switch]$PassThru = $false
)

# Import Pester
Import-Module Pester -Force

# Configure Pester with clean environment
Write-Host "⚙️ Configuring Clean Pester Environment..." -ForegroundColor Yellow
$pesterConfig = New-PesterConfiguration
$pesterConfig.Run.Path = $TestPath
$pesterConfig.Run.PassThru = $true
$pesterConfig.Output.Verbosity = 'Detailed'
$pesterConfig.TestResult.Enabled = $true
$pesterConfig.TestResult.OutputFormat = 'NUnitXml'
$pesterConfig.TestResult.OutputPath = $OutputPath
$pesterConfig.CodeCoverage.Enabled = $EnableCodeCoverage
$pesterConfig.Should.ErrorAction = 'Stop'

# Run clean tests
Write-Host "🚀 Starting Clean Pester Tests..." -ForegroundColor Yellow
try {
    $testResults = Invoke-Pester -Configuration $pesterConfig
    
    # Generate comprehensive summary
    Write-Host "📊 Test Summary:" -ForegroundColor Cyan
    Write-Host "  Total Tests: $($testResults.TotalCount)" -ForegroundColor White
    Write-Host "  Passed: $($testResults.PassedCount)" -ForegroundColor Green
    Write-Host "  Failed: $($testResults.FailedCount)" -ForegroundColor Red
    Write-Host "  Skipped: $($testResults.SkippedCount)" -ForegroundColor Yellow
    Write-Host "  Duration: $($testResults.Duration)" -ForegroundColor White
    
    # Set GitHub outputs for workflow consumption
    if ($env:GITHUB_OUTPUT) {
        "total-tests=$($testResults.TotalCount)" >> $env:GITHUB_OUTPUT
        "passed-tests=$($testResults.PassedCount)" >> $env:GITHUB_OUTPUT
        "failed-tests=$($testResults.FailedCount)" >> $env:GITHUB_OUTPUT
        "skipped-tests=$($testResults.SkippedCount)" >> $env:GITHUB_OUTPUT
        "test-success=$($testResults.FailedCount -eq 0)" >> $env:GITHUB_OUTPUT
        "test-duration=$($testResults.Duration)" >> $env:GITHUB_OUTPUT
        "test-results-path=$OutputPath" >> $env:GITHUB_OUTPUT
    }
    
    # Clean up any test artifacts
    Write-Host "🧹 Cleaning up test artifacts..." -ForegroundColor Yellow
    Get-ChildItem -Path $TestPath -Filter "TestModule*.psd1" -ErrorAction SilentlyContinue | 
        Remove-Item -Force -ErrorAction SilentlyContinue
    
    # Final module cleanup
    Get-Module K.PSGallery.SemanticVersioning | Remove-Module -Force -ErrorAction SilentlyContinue
    
    # Return results if PassThru requested
    if ($PassThru) {
        return $testResults
    }
    
    # Fail if tests failed
    if ($testResults.FailedCount -gt 0) {
        Write-Host "❌ CLEAN PESTER TESTS FAILED!" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "✅ ALL CLEAN PESTER TESTS PASSED!" -ForegroundColor Green
    }
    
} catch {
    Write-Host "💥 ERROR during test execution: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "🔍 Full error: $($_ | Out-String)" -ForegroundColor Red
    exit 1
}
