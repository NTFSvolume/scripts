param (
    [Parameter(Mandatory=$true)]
    [string]$FolderPath,
    [switch]$flat,
    [Alias("R")]
    [switch]$recurse
)

if (-not (Test-Path $FolderPath -PathType Container)) {
    Write-Host "Folder path doesn't exist: $FolderPath"
    exit
}

function  run  {
    $subfolders = Get-ChildItem -LP $FolderPath -Directory -Force

    $didSomething = $false

    foreach ($subfolder in $subfolders) {
        Write-Host "Processing subfolder: $($subfolder.FullName)"
        $contents = Get-ChildItem -LP $subfolder.FullName -Force
        Write-Host "Moving content from '$subfolder'"
        $skipExtensions = @(".part",".!qB",".tmp",".temp")
        foreach ($item in $contents) {
            if ($item.Extension -in $skipExtensions) {
                Write-Debug "Skipping $($item.Name)"
                continue
            }
            $destination = $FolderPath
            if ($flat){
                $flattenName = $subfolder.Name + "___" + $item.Name
                $destination = Join-Path $destination $flattenName
            }
            
            Write-Verbose "Moving $($item.Name) to $($destination)"
            
            try {
                Move-Item -LP $item -Destination $destination -ErrorAction Stop
                $didSomething = $true 
            } catch {
                Write-Warning $_
            }
        }
    }

    & (Join-Path $PSScriptRoot "delete_empty_files_and_folders.ps1") $FolderPath
    return $didSomething 
}

$running = $true
while ($running){
    $running = run 
    if (-not $recurse){
        break
    }
}
Write-Host "DONE" -ForegroundColor Green