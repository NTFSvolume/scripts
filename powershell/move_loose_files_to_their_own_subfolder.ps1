param (
    [Parameter(Mandatory=$true)]
    [string]$FolderPath 
)

if (-not (Test-Path -Path $FolderPath)) {
    Throw "The specified path does not exist."
}

Write-Output "Organizing files in folder: $FolderPath"

$Files = Get-ChildItem -Path $FolderPath -File -Force

foreach ($File in $Files) {
    $SubfolderPath = Join-Path -Path $FolderPath $File.BaseName
    Write-Output "Creating subfolder: $SubfolderPath"
    New-Item -Path $SubfolderPath -ItemType Directory -Force
    $NewFilePath = Join-Path -Path $SubfolderPath -ChildPath $($File.Name)
    Move-Item -Path $File -Destination $NewFilePath
}

Write-Output "Organizing complete."
