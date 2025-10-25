# Simulate exact workflow scenario
Write-Host "=== SIMULATING WORKFLOW BEHAVIOR ==="

# Simulate what New-SemanticReleaseTags returns
$result = @{
    Success = $true
    TargetVersion = "v0.1.26"
    ReleaseTag = "v0.1.26"
    SmartTags = @("v0", "v0.1")  # Already extracted Name properties
    MovingTags = @("latest")      # Already extracted Name properties
    AllTags = @("v0.1.26", "v0", "v0.1", "latest")
}

Write-Host "Result object:"
$result | ConvertTo-Json -Depth 2
Write-Host ""

Write-Host "=== WORKFLOW CODE (Current - BROKEN?) ==="
$smartTagsList = if ($result.SmartTags.Count -gt 0) { 
    ($result.SmartTags | ForEach-Object { "``$_``" }) -join ', ' 
} else { 
    "_(none)_" 
}
Write-Host "SmartTags formatted: $smartTagsList"
Write-Host ""

Write-Host "=== ALTERNATIVE: Direct join with format ==="
$smartTagsList2 = if ($result.SmartTags.Count -gt 0) {
    ($result.SmartTags | ForEach-Object { '`{0}`' -f $_ }) -join ', '
} else {
    "_(none)_"
}
Write-Host "SmartTags alternative: $smartTagsList2"
Write-Host ""

Write-Host "=== AllTags (Works correctly) ==="
Write-Host "AllTags: $($result.AllTags -join ', ')"
