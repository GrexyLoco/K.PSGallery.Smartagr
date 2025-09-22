#
# SafeLogging.ps1
# Provides safe wrapper functions for logging that gracefully handle missing LoggingModule
#

function Write-SafeInfoLog {
    param([string]$Message, [hashtable]$Additional = @{})
    
    if (Get-Command 'Write-InfoLog' -ErrorAction SilentlyContinue) {
        Write-InfoLog -Message $Message -Additional $Additional
    } else {
        Write-Host "[INFO] - $Message" -ForegroundColor Green
        if ($Additional.Count -gt 0) {
            $Additional.GetEnumerator() | ForEach-Object {
                Write-Host "                               ▶ $($_.Key): $($_.Value)" -ForegroundColor Gray
            }
        }
    }
}

function Write-SafeWarningLog {
    param([string]$Message, [hashtable]$Additional = @{})
    
    if (Get-Command 'Write-WarningLog' -ErrorAction SilentlyContinue) {
        Write-WarningLog -Message $Message -Additional $Additional
    } else {
        Write-Host "[WARNING] - $Message" -ForegroundColor Yellow
        if ($Additional.Count -gt 0) {
            $Additional.GetEnumerator() | ForEach-Object {
                Write-Host "                                  ▶ $($_.Key): $($_.Value)" -ForegroundColor Gray
            }
        }
    }
}

function Write-SafeErrorLog {
    param([string]$Message, [hashtable]$Additional = @{})
    
    if (Get-Command 'Write-ErrorLog' -ErrorAction SilentlyContinue) {
        Write-ErrorLog -Message $Message -Additional $Additional
    } else {
        Write-Host "[ERROR] - $Message" -ForegroundColor Red
        if ($Additional.Count -gt 0) {
            $Additional.GetEnumerator() | ForEach-Object {
                Write-Host "                                ▶ $($_.Key): $($_.Value)" -ForegroundColor Gray
            }
        }
    }
}

function Write-SafeDebugLog {
    param([string]$Message, [hashtable]$Additional = @{})
    
    if (Get-Command 'Write-DebugLog' -ErrorAction SilentlyContinue) {
        Write-DebugLog -Message $Message -Additional $Additional
    } else {
        Write-Host "[DEBUG] - $Message" -ForegroundColor Cyan
        if ($Additional.Count -gt 0) {
            $Additional.GetEnumerator() | ForEach-Object {
                Write-Host "                                 ▶ $($_.Key): $($_.Value)" -ForegroundColor Gray
            }
        }
    }
}
