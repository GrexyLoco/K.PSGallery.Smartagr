#
# SafeLogging.ps1
# Provides safe wrapper functions for logging that gracefully handle missing LoggingModule
#

function Write-SafeInfoLog {
    param([string]$Message, [hashtable]$Additional = @{})
    
    if (Get-Command 'Write-InfoLog' -ErrorAction SilentlyContinue) {
        # Convert hashtable to context string for LoggingModule
        $context = if ($Additional.Count -gt 0) {
            ($Additional.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" }) -join "`n"
        } else { "" }
        Write-InfoLog -Message $Message -Context $context
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
        # Convert hashtable to context string for LoggingModule
        $context = if ($Additional.Count -gt 0) {
            ($Additional.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" }) -join "`n"
        } else { "" }
        Write-WarningLog -Message $Message -Context $context
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
        # Convert hashtable to context string for LoggingModule
        $context = if ($Additional.Count -gt 0) {
            ($Additional.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" }) -join "`n"
        } else { "" }
        Write-ErrorLog -Message $Message -Context $context
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
        # Convert hashtable to context string for LoggingModule
        $context = if ($Additional.Count -gt 0) {
            ($Additional.GetEnumerator() | ForEach-Object { "$($_.Key): $($_.Value)" }) -join "`n"
        } else { "" }
        Write-DebugLog -Message $Message -Context $context
    } else {
        Write-Verbose "[DEBUG] - $Message"
        if ($Additional.Count -gt 0) {
            $Additional.GetEnumerator() | ForEach-Object {
                Write-Verbose "         ▶ $($_.Key): $($_.Value)"
            }
        }
    }
}
