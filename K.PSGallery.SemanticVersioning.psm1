# Define safe logging wrapper functions (fallback to Write-Host if LoggingModule not available)
function Write-SafeInfoLog { 
    param($Message, $Context)
    try { Write-InfoLog -Message $Message -Context $Context } catch { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
}
function Write-SafeDebugLog { 
    param($Message, $Context)
    try { Write-DebugLog -Message $Message -Context $Context } catch { Write-Host "[DEBUG] $Message" -ForegroundColor Gray }
}
function Write-SafeWarningLog { 
    param($Message, $Context)
    try { Write-WarningLog -Message $Message -Context $Context } catch { Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
}
function Write-SafeErrorLog { 
    param($Message, $Context)
    try { Write-ErrorLog -Message $Message -Context $Context } catch { Write-Host "[ERROR] $Message" -ForegroundColor Red }
}
function Write-SafeTaskSuccessLog { 
    param($Message, $Context)
    try { Write-TaskSuccessLog -Message $Message -Context $Context } catch { Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
}
function Write-SafeTaskFailLog { 
    param($Message, $Context)
    try { Write-TaskFailLog -Message $Message -Context $Context } catch { Write-Host "[FAIL] $Message" -ForegroundColor Red }
}

# Try to import logging module dependency (optional)
try {
    Import-Module K.PSGallery.LoggingModule -Force -ErrorAction Stop
    Write-Host "✅ K.PSGallery.LoggingModule loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "⚠️ K.PSGallery.LoggingModule not found - using fallback logging" -ForegroundColor Yellow
}

# Dot-source alle Funktionen aus src/
$srcPath = Join-Path $PSScriptRoot "src"
if (Test-Path $srcPath) {
    $loadedFunctions = @()
    Get-ChildItem -Path "$srcPath\*.ps1" | ForEach-Object { 
        try {
            . $_.FullName 
            $loadedFunctions += $_.BaseName
        } catch {
            Write-Warning "Failed to load $($_.Name): $($_.Exception.Message)"
        }
    }
    Write-Host "📦 Loaded source files: $($loadedFunctions -join ', ')" -ForegroundColor Cyan
} else {
    Write-Warning "Source directory not found: $srcPath"
}

# Export module information
Write-Host "🚀 K.PSGallery.SemanticVersioning module loaded successfully" -ForegroundColor Green
