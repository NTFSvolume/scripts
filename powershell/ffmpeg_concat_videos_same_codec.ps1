param(
    [Parameter(Mandatory = $true)]
    [string]$inputFolderMain,
    [Alias('n')]
    [int]$noise = 0 
)


function Get-FreeSpace{
    param(
        [string]$folder
    )
    $rootDrive = (Get-Item -LiteralPath $folder -Force).PSDrive.Name

    if ($IsLinux) {$drive = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -eq $rootDrive }
    } else {$drive = Get-PSDrive -Name $rootDrive}

    return $drive.Free 
    
}

function ConcatVideosSameCodec{
    param(
        [Parameter(Mandatory = $true)]
        [string]$inputFolder,
        [string]$pattern = '___SPLITTEDPART',
        [int]$noise = 0 #use 9 for bunkr files (8 caracters for bunkr_id (default) + 1 dash)
    )

    function Assert-Dependencies([array]$dependencies){
        foreach ($dependencie in $dependencies){
            if (-not (Get-Command $dependencie -ErrorAction SilentlyContinue)){
                Write-Error "$dependencie is not installed"
                if ($IsWindows){
                    if (Get-Command "winget" -ErrorAction SilentlyContinue){
                        $recommendedAction = "You can try to install it running in the terminal (as admin): winget install $dependencie --scope machine`nthen close and open a new terminal to be able to use it"
                    }
                }else{
                    if (Get-Command "apt" -ErrorAction SilentlyContinue){
                        $recommendedAction = "You can install it running: sudo apt install $dependencie"
                    }
                }
                if ($recommendedAction){
                    Write-Information $recommendedAction -InformationAction Continue
                }
                exit 1
            }
        }
    }
    
    Assert-Dependencies ffmpeg

    $videoExtensions = @(".mp4", ".avi", ".mkv", ".mov", ".wmv", ".flv", ".webm", ".mpeg", ".mpg", ".m4v", ".3gp", ".ogv")
    $MinFreeSpace = 10GB 
    function FixExtension ([string]$fileName) {
        foreach ($extension in $videoExtensions) {
            $invalidExtension = $extension -replace "\.", "-"
            if ($fileName.EndsWith($invalidExtension)){
                return $fileName.Substring(0, $fileName.Length - $extension.Length) + $extension
            }
        }
        return $fileName
    }

    $outputFolder = Join-Path $inputFolder "__MERGED_VIDEOS"
    $files = Get-ChildItem -LiteralPath $inputFolder -File -Force | Where-Object { $_.Extension -in $videoExtensions } | Sort-Object
    $filesPart001 = $files | Where-Object { $_.Name -like "*${pattern}001*" } | Sort-Object

    if ($files.Count -eq 0) {Throw "no video files found on $(Resolve-Path -LiteralPath $inputFolder)"}

    if ($filesPart001.Count -eq 0) {Throw "files in folder do not match pattern: $pattern"}
    
    $filesProcessed=@()

    New-Item -Path $outputFolder -ItemType Directory -Force | Out-Null

    foreach ($file in $filesPart001){
        while ((Get-FreeSpace $file) -lt $MinFreeSpace){
            Write-Warning "Not enough disk space. Available: $([math]::Round((Get-FreeSpace $file)/1GB, 2)) GB, Required: $($MinFreeSpace/1GB)GB"
            Read-Host "Clean up and them press enter to continue, or CTRL + C to cancel"
        }
        $fileBaseNameClean = $file.BaseName.Substring(0, $file.BaseName.Length - $noise)
        $patternCurrentFile = $fileBaseNameClean -replace "${pattern}001", ${pattern}
        $originalFileName = FixExtension ($fileBaseNameClean -replace "${pattern}001", '')
        $outputFileName = $originalFileName
        $filesThatMatchPattern = $files | Where-Object { $_.BaseName -like "*${patternCurrentFile}*" } | Sort-Object
        if ($filesThatMatchPattern.Length -eq 0){continue}
        $tempFile = New-TemporaryFile
        $lines = @()
        foreach ($filePart in $filesThatMatchPattern) {
            $lines += "file '$($filePart.FullName)'" 
        }
        # Replacement for Out-File to write as UTF-8 without BOM in Windows Powershell (5.1)
        New-Item -ItemType File -Force $tempFile -Value ($lines| Out-String) | Out-Null 

        try {
            & ffmpeg -hide_banner -loglevel error -stats -f concat -safe 0 -i $tempFile -map 0 -map_metadata 0 -c copy (Join-Path $outputFolder $outputFileName)
            if ($LASTEXITCODE -ne 0) {throw "ffmpeg command failed with exit code $LASTEXITCODE"}
            $filesProcessed += $filesThatMatchPattern
        }
        catch {
            Write-Error "$_"
            continue
        }
        finally {
            Remove-Item -LiteralPath $tempFile -Force
        }
    }

    if ($filesProcessed.Length -eq 0){
        Remove-Item -LiteralPath $outputFolder -Force
        Throw "None of the files in the folder were proccesed. Verify your input parameters"
    }

    foreach ($file in $filesProcessed){
        $MatchFolder = Join-Path $inputFolder "__PROCESSED_VIDEOS_PARTS"
        New-Item -Path $MatchFolder -ItemType Directory -Force | Out-Null
        Move-Item -LiteralPath $file -Destination $MatchFolder
    }

    $filesNotModified = $files | Where-Object { $_ -notin $filesProcessed }
    if ($filesNotModified.Count -gt 0) {
        $notMatchFolder = Join-Path $inputFolder "__UNPROCCESED_VIDEOS"
        Write-Warning "some files in the folder did not match the pattern '$pattern'.`nthey were moved to $(Resolve-Path -LiteralPath $notMatchFolder)"
        New-Item -Path $notMatchFolder -ItemType Directory -Force | Out-Null
        foreach ($file in $filesNotModified){
            Move-Item -LiteralPath $file -Destination $notMatchFolder
        }
    }
}

ConcatVideosSameCodec $inputFolderMain -noise $noise


