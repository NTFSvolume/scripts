param(
    [Parameter(Mandatory = $true)]
    [string]$inputFolder
)
function delete_empty_files_and_folders {
    param(
        [Parameter(Mandatory = $true)]
        [string]$inputFolder
    )

    if (-not (Test-Path $inputFolder)) {
        Throw "Input folder not found: $inputFolder"
    }
    
    Get-ChildItem $inputFolder -File -Recurse | Where-Object { $_.Length -eq 0 } | ForEach-Object {
        Write-Host "Removing empty file: $($_.FullName)"
        Remove-Item -LiteralPath $_.FullName 
    }
    
    do {
        $emptyFolders = Get-ChildItem $inputFolder -Directory -Recurse | Where-Object { 
            @(Get-ChildItem -LiteralPath $_.FullName -File -Recurse).Count -eq 0 -and 
            @(Get-ChildItem -LiteralPath $_.FullName -Directory -Recurse).Count -eq 0 
        }

        foreach ($folder in $emptyFolders) {
            Write-Host "Removing empty folder: $($folder.FullName)"
            Remove-Item -LiteralPath $folder.FullName 
        }
    } while ($emptyFolders.Count -gt 0)
}

delete_empty_files_and_folders $inputFolder