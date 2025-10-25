# Test backtick formatting for markdown
$tags = @('v0', 'v0.1', 'latest')

Write-Host "=== TEST 1: Using double backticks in YAML (escaped) ==="
$formatted1 = ($tags | ForEach-Object { "``$_``" }) -join ', '
Write-Host "Result: $formatted1"
Write-Host ""

Write-Host "=== TEST 2: Character-by-character iteration (THE BUG) ==="
# This simulates what happens when foreach iterates over STRING chars
foreach ($tag in $tags) {
    Write-Host "Processing tag: $tag (Type: $($tag.GetType().Name))"
    $chars = $tag | ForEach-Object { "``$_``" }
    Write-Host "  Chars result: $($chars -join ', ')"
}
Write-Host ""

Write-Host "=== TEST 3: Correct approach with explicit string handling ==="
$formatted3 = $tags | ForEach-Object { 
    $backtick = [char]96  # Backtick character
    "$backtick$_$backtick"
} 
Write-Host "Result: $($formatted3 -join ', ')"
