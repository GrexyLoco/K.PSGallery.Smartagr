# Test SafeLogging Additional parameter
. "$PSScriptRoot\src\SafeLogging.ps1"

Write-Host "=== TEST 1: SafeInfoLog with Additional ==="
Write-SafeInfoLog -Message "Test Info Message" -Additional @{
    "Key1" = "Value1"
    "Key2" = "Value2"
    "Count" = 42
}

Write-Host "`n=== TEST 2: SafeDebugLog with Additional (needs -Verbose) ==="
Write-SafeDebugLog -Message "Test Debug Message" -Additional @{
    "DebugKey" = "DebugValue"
    "Tags" = "v0, v0.1, latest"
} -Verbose

Write-Host "`n=== TEST 3: SafeWarningLog with Additional ==="
Write-SafeWarningLog -Message "Test Warning" -Additional @{
    "WarningLevel" = "High"
    "Details" = "Something went wrong"
}

Write-Host "`n=== TEST 4: Check if LoggingModule command exists ==="
if (Get-Command 'Write-InfoLog' -ErrorAction SilentlyContinue) {
    Write-Host "✅ LoggingModule is available"
} else {
    Write-Host "❌ LoggingModule NOT available - using fallback"
}
