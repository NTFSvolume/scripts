param (
    [string]$inputVideoPath
)

$inputDirectory = Split-Path $inputVideoPath -Parent
$inputFileName = [System.IO.Path]::GetFileNameWithoutExtension($inputVideoPath)
$inputExtension = [System.IO.Path]::GetExtension($inputVideoPath).ToLower()

if ($inputFileName -like "*__CROPPED*") {
    Write-Output "File path contains '__CROPPED', skipping"
    exit 0
} 

if ($inputExtension -eq ".mkv") {
    $outputExtension = ".mkv"
} else {
    $outputExtension = ".mp4"
}

$bitrate = & ffprobe -v error -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 $inputVideoPath

if ($bitrate){
    $outputDirectory = Join-Path $inputDirectory "__ROTATED"
    $outputPath = Join-Path $outputDirectory "${inputFileName}__ROTATED$outputExtension"
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    $bitrate_bps = [math]::round($bitrate, 2)
    $bitrate_kbps = [math]::round($bitrate / 1000, 2)
    $bitrate_mbps = [math]::round($bitrate / 1000000, 2)

    Write-Output "rotating 90° - Bitrate: $bitrate_bps bps ($bitrate_kbps kbps, $bitrate_mbps Mbps)"
    & ffmpeg -hide_banner -loglevel warning -stats -i $inputVideoPath -vf "transpose=1" -b:v $bitrate -c:a copy -c:v libx264 $outputPath
    Write-Host "DONE! Output: $outputPath"
}else{
    Write-Host "Unable to get bitrate of: $inputVideoPath"
}
