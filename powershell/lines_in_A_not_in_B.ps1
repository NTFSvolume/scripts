param (
    [string]$FileA,
    [string]$FileB,
    [string]$OutputFile
)

$LinesA = Get-Content -LP $FileA | Sort-Object -Unique
$LinesB = Get-Content -LP $FileB | Sort-Object -Unique
$LinesUniqueToA = $LinesA | Where-Object { $_ -notin $LinesB }
$LinesUniqueToA | Set-Content -LP $OutputFile
Write-Output "File '$OutputFile' has been created with unique lines from '$FileA'."
