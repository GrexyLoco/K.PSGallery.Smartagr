# 🔧 Setup-CleanTestEnvironment.ps1
# Configures clean Pester testing environment for GitHub Actions

[CmdletBinding()]
param(
    [string]$TestPath = './Tests',
    [string]$OutputPath = './TestResults.xml'
)

Write-Host "🔧 Setting up Clean Test Environment..." -ForegroundColor Cyan

# Force remove any existing modules to prevent conflicts
Write-Host "🧹 Cleaning up existing modules..." -ForegroundColor Yellow
Get-Module K.PSGallery.SemanticVersioning | Remove-Module -Force -ErrorAction SilentlyContinue

# Clear PowerShell module cache
Write-Host "🔄 Clearing module cache..." -ForegroundColor Yellow
if (Get-Module K.PSGallery.SemanticVersioning -ListAvailable -ErrorAction SilentlyContinue) {
    Remove-Module K.PSGallery.SemanticVersioning -Force -ErrorAction SilentlyContinue
}

# Install required modules
Write-Host "📦 Installing required modules..." -ForegroundColor Yellow

if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Host "📦 Installing Pester module..." -ForegroundColor Yellow
    Install-Module -Name Pester -Scope CurrentUser -Force -SkipPublisherCheck
} else {
    Write-Host "✅ Pester module already available" -ForegroundColor Green
}

if (-not (Get-Module -ListAvailable -Name K.PSGallery.LoggingModule)) {
    Write-Host "📦 Installing K.PSGallery.LoggingModule..." -ForegroundColor Yellow
    Install-Module -Name K.PSGallery.LoggingModule -Scope CurrentUser -Force
} else {
    Write-Host "✅ K.PSGallery.LoggingModule already available" -ForegroundColor Green
}

# Show environment information
Write-Host "💡 Environment Information:" -ForegroundColor Cyan
Write-Host "  PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor White
Write-Host "  Pester Version: $((Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1).Version)" -ForegroundColor White
Write-Host "  LoggingModule Version: $((Get-Module -ListAvailable -Name K.PSGallery.LoggingModule | Select-Object -First 1).Version)" -ForegroundColor White
Write-Host "  Test Path: $TestPath" -ForegroundColor White
Write-Host "  Output Path: $OutputPath" -ForegroundColor White

# Validate test path
if (-not (Test-Path $TestPath)) {
    Write-Host "⚠️ Test path not found: $TestPath" -ForegroundColor Red
    throw "Test path does not exist: $TestPath"
}

Write-Host "✅ Clean Test Environment Ready!" -ForegroundColor Green
