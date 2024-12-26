param (
    [string]$FileA,
    [string]$FileB,
    [string]$OutputFile,
    [switch]$not
)

$LinesA = Get-Content -LiteralPath $FileA | Sort-Object -Unique
$LinesB = Get-Content -LiteralPath $FileB | Sort-Object -Unique
$LinesB = $LinesB | ForEach-Object { $_ -replace "\[.*?\]", "" }


if ($not){
    Write-Warning 'getting not matching lines'
    $NotMatchingLines = $LinesA | Where-Object { $lineA = $_; $LinesB | ForEach-Object { if (-not($lineA -like "*$_*")) { return $true } } }
    $NotMatchingLines | Set-Content -LiteralPath $OutputFile
    Write-Output "File '$OutputFile' has been created with lines from '$FileA' not containing substrings from '$FileB'."
    return
}
$MatchingLines = $LinesA | Where-Object { $lineA = $_; $LinesB | ForEach-Object { if ($lineA -like "*$_*") { return $true } } }
$MatchingLines | Set-Content -LiteralPath $OutputFile
Write-Output "File '$OutputFile' has been created with lines from '$FileA' containing substrings from '$FileB'."

