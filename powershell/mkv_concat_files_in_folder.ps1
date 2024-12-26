param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$FolderPath
)

if (-not (Test-Path $FolderPath -PathType Container)) {
    Write-Host "Folder does not exist: $FolderPath"
    exit 1
}

$videoExtensions = @(".mp4", ".avi", ".mkv", ".mov", ".wmv", ".flv", ".webm", ".mpeg", ".mpg", ".m4v", ".3gp", ".ogv")
$videoFiles = (Get-ChildItem -Path $FolderPath -File -Force) | Where-Object { $_.Extension -in $videoExtensions } | Sort-Object

if ($videoFiles.Count -eq 0) {
    Throw "No video files found in the folder: $FolderPath"
}

$OutputFileName = Join-Path -Path $FolderPath -ChildPath ("merged." + $videoFiles[0].Name)

$MKVMergeArgs = @()
foreach ($file in $videoFiles) {
    $MKVMergeArgs += '"' + $file.FullName + '"'
}

$MKVMergeCommand = "mkvmerge " + ("[ " + ($MKVMergeArgs -join " ") + " ]" + " -o", '"' + $OutputFileName + '"')
Write-Output "Executing: $MKVMergeCommand"
Invoke-Expression -Command $MKVMergeCommand
