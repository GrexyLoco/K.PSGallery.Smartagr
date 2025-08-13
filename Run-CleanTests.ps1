# Run-CleanTests.ps1 - Runs tests with proper module cleanup

[CmdletBinding()]
param(
    [string]$TestPath = './Tests',
    [string]$Output = 'Detailed',
    [switch]$PassThru
)

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
    Get-ChildItem -Path './Tests' -Filter "TestModule*.psd1" -ErrorAction SilentlyContinue | 
        Remove-Item -Force -ErrorAction SilentlyContinue
    
    Write-Host "✅ Cleanup completed" -ForegroundColor Green
}
