#
# SafeLogging.ps1
# Provides safe wrapper functions for logging that gracefully handle missing LoggingModule
#

function Write-SafeInfoLog {
    param([string]$Message, [hashtable]$Additional = @{})
    
    if (Get-Command 'Write-InfoLog' -ErrorAction SilentlyContinue) {
        Write-InfoLog -Message $Message -Additional $Additional
    } else {
        Write-Output "[INFO] - $Message"
        if ($Additional.Count -gt 0) {
            $Additional.GetEnumerator() | ForEach-Object {
                Write-Output "         ▶ $($_.Key): $($_.Value)"
            }
        }
    }
}

function Write-SafeWarningLog {
    param([string]$Message, [hashtable]$Additional = @{})
    
    if (Get-Command 'Write-WarningLog' -ErrorAction SilentlyContinue) {
        Write-WarningLog -Message $Message -Additional $Additional
    } else {
        Write-Warning "$Message"
        if ($Additional.Count -gt 0) {
            $Additional.GetEnumerator() | ForEach-Object {
                Write-Warning "  ▶ $($_.Key): $($_.Value)"
            }
        }
    }
}

function Write-SafeErrorLog {
    param([string]$Message, [hashtable]$Additional = @{})
    
    if (Get-Command 'Write-ErrorLog' -ErrorAction SilentlyContinue) {
        Write-ErrorLog -Message $Message -Additional $Additional
    } else {
        Write-Error "$Message"
        if ($Additional.Count -gt 0) {
            $Additional.GetEnumerator() | ForEach-Object {
                Write-Error "  ▶ $($_.Key): $($_.Value)"
            }
        }
    }
}

function Write-SafeDebugLog {
    param([string]$Message, [hashtable]$Additional = @{})
    
    if (Get-Command 'Write-DebugLog' -ErrorAction SilentlyContinue) {
        Write-DebugLog -Message $Message -Additional $Additional
    } else {
        Write-Verbose "[DEBUG] - $Message"
        if ($Additional.Count -gt 0) {
            $Additional.GetEnumerator() | ForEach-Object {
                Write-Verbose "         ▶ $($_.Key): $($_.Value)"
            }
        }
    }
}
