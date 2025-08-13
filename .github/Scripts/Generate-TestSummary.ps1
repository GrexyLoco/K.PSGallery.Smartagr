# 📋 Generate-TestSummary.ps1  
# Generates comprehensive test summary for GitHub Actions

[CmdletBinding()]
param(
    [int]$TotalTests = 0,
    [int]$PassedTests = 0,
    [int]$FailedTests = 0,
    [int]$SkippedTests = 0,
    [string]$Duration = "0s",
    [string]$TestResultsPath = ""
)

Write-Host "📋 Generating Test Summary..." -ForegroundColor Cyan

# Calculate percentages
$passRate = if ($TotalTests -gt 0) { [math]::Round(($PassedTests / $TotalTests) * 100, 1) } else { 0 }
$failRate = if ($TotalTests -gt 0) { [math]::Round(($FailedTests / $TotalTests) * 100, 1) } else { 0 }

# Determine status emoji and color
$statusEmoji = if ($FailedTests -eq 0) { "✅" } else { "❌" }
$statusText = if ($FailedTests -eq 0) { "PASSED" } else { "FAILED" }
$statusColor = if ($FailedTests -eq 0) { "green" } else { "red" }

# Generate GitHub Step Summary
if ($env:GITHUB_STEP_SUMMARY) {
    $summary = @"
## $statusEmoji Test Results Summary

| Metric | Value | Percentage |
|--------|-------|------------|
| **Total Tests** | $TotalTests | 100% |
| **✅ Passed** | $PassedTests | $passRate% |
| **❌ Failed** | $FailedTests | $failRate% |
| **⏭️ Skipped** | $SkippedTests | $([math]::Round(($SkippedTests / $TotalTests) * 100, 1))% |
| **⏱️ Duration** | $Duration | - |

### Status: **$statusText**

"@

    if ($FailedTests -gt 0) {
        $summary += @"
### ⚠️ Action Required
- $FailedTests test(s) failed
- Please review the test output above for details
- Fix failing tests before merging

"@
    } else {
        $summary += @"
### 🎉 All Tests Passed!
- All $TotalTests tests executed successfully
- No issues found in the codebase
- Ready for deployment

"@
    }

    if ($TestResultsPath -and (Test-Path $TestResultsPath)) {
        $summary += @"
### 📄 Test Results
- Detailed results available in artifacts
- XML report: ``$TestResultsPath``

"@
    }

    $summary | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding UTF8
    Write-Host "✅ GitHub Step Summary updated" -ForegroundColor Green
}

# Console output
Write-Host ""
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host "           TEST SUMMARY REPORT           " -ForegroundColor Cyan  
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Status: $statusEmoji $statusText" -ForegroundColor $statusColor
Write-Host "Total:  $TotalTests tests" -ForegroundColor White
Write-Host "Passed: $PassedTests ($passRate%)" -ForegroundColor Green
Write-Host "Failed: $FailedTests ($failRate%)" -ForegroundColor Red
Write-Host "Skipped: $SkippedTests" -ForegroundColor Yellow
Write-Host "Duration: $Duration" -ForegroundColor White
Write-Host ""
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan

if ($FailedTests -gt 0) {
    Write-Host "💥 Tests failed - check output above for details" -ForegroundColor Red
} else {
    Write-Host "🎉 All tests passed successfully!" -ForegroundColor Green
}
