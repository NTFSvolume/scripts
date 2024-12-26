param (
    [Parameter(Mandatory=$true)]
    [string]$inputPath,
    [Alias("s")]
    [int]$targetSizeMB = 2000MB,
    [Alias("p")]
    [string]$splitSuffix = "___SPLITTEDPART"
)
function Split-Video {
    param (
        [Parameter(Mandatory=$true)]
        [string]$inputPath,
        [Alias("s")]
        [int]$targetSizeMB = 1900,
        [Alias("p")]
        [string]$splitSuffix = "___SPLITTEDPART"
    )

    if ($inputPath -Like "*$splitSuffix*"){
        Write-Output "skipping $inputPath, already contains split pattern"
        return
    }

    $inputFile = Get-Item -LiteralPath $inputPath -Force
    $targetSizeBytes = $targetSizeMB * 1MB
    $originalSizeBytes = $inputFile.Length
    $duration = [double](& ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $inputFile).Trim()
    
    if ($originalSizeBytes -le $targetSizeBytes) {
        Write-Warning "File $inputFile is already under target size"
        return
    }

    $ratio = $originalSizeBytes / $targetSizeBytes
    $chunkDuration = $duration / $ratio
    $numChunks = [math]::Ceiling($duration / $chunkDuration)

    for ($i = 0; $i -lt $numChunks; $i++) {
        $startTime = $i * $chunkDuration
        $outputFile = Join-Path $inputFile.Directory ($inputFile.Name + $splitSuffix + "{0:D3}" -f ($i + 1) + $inputFile.Extension)
        & ffmpeg -hide_banner -loglevel warning -stats -ss $startTime -i $inputFile -map 0 -map_metadata 0 -t $chunkDuration -c copy -avoid_negative_ts 2 $outputFile
    }
}

$scriptConfig = [PSCustomObject]@{
    InputPath = $inputPath
    SplitSuffix = $splitSuffix 
    TargetSizeMB = $targetSizeMB
}

$scriptConfig | Format-List 

Split-Video $inputPath -s $targetSizeMB -p $splitSuffix 
