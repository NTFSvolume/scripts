param (
    [Parameter(Mandatory=$true)]
    [string]$inputVideoPath,
    [Parameter(Mandatory=$true)]
    [int]$desiredSizeMB,
    [string]$outputDirectory="",
    [switch]$qsv
)
function New-Bitrate {
    param (
        [int]$desiredSizeMB,
        [int]$durationSeconds
    )
    return [math]::Floor(($desiredSizeMB * 8192) / $durationSeconds)
}

$durationOutput = & ffprobe -v error -select_streams v:0 -show_entries format=duration -of csv=p=0 $inputVideoPath
if ($durationOutput) {
    $duration = [float]$durationOutput
} else {
    Throw "Unable to determine video duration of '$inputVideoPath'"
}

$bitrate = New-Bitrate -desiredSizeMB $desiredSizeMB -durationSeconds $duration
$inputDirectory = Split-Path $inputVideoPath -Parent
$inputFileName = [System.IO.Path]::GetFileNameWithoutExtension($inputVideoPath)
$inputExtension = [System.IO.Path]::GetExtension($inputVideoPath).ToLower()

if ($inputExtension -eq ".mkv") {
    $outputExtension = ".mkv"
} else {
    $outputExtension = ".mp4"
}

if ($outputDirectory -eq "") {
    $outputDirectory = $inputDirectory
}else{
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$outputPath = Join-Path $outputDirectory  "${inputFileName}__REENCODED_TO_${desiredSizeMB}MB$outputExtension"
Write-Output "Encoding bitrate: ${bitrate}K"

$tempFile = New-TemporaryFile
$logFilePath = Join-Path $tempFile.Directory "ffmpeg_2pass_$($tempFile.BaseName).log"

if ($qsv){
    & ffmpeg -hide_banner -loglevel warning -stats -init_hw_device qsv=qsv -hwaccel qsv -hwaccel_output_format qsv -i $inputVideoPath -c:v h264_qsv -b:v "${bitrate}k" -pass 1 -passlogfile $logFilePath -an -f null -
    & ffmpeg -hide_banner -loglevel warning -stats -init_hw_device qsv=qsv -hwaccel qsv -hwaccel_output_format qsv -i $inputVideoPath -c:v h264_qsv -b:v "${bitrate}k" -pass 2 -passlogfile $logFilePath -c:a copy -y $outputPath
}else{
    Write-Warning "using CPU encoder"
    & ffmpeg -hide_banner -loglevel warning -stats -i $inputVideoPath -c:v libx264 -b:v "${bitrate}k" -pass 1 -passlogfile $logFilePath -an -f null -
    & ffmpeg -hide_banner -loglevel warning -stats -i $inputVideoPath -c:v libx264 -b:v "${bitrate}k" -pass 2 -passlogfile $logFilePath -c:a copy -y $outputPath
}

Write-Output "Video re-encoding complete. Output file: $outputPath"
