param (
    [Parameter(Mandatory=$true)]
    [string]$inputVideo,  
    [string]$aspect,
    [Parameter(Mandatory=$true)]
    [string]$ratio,
    [Parameter(Mandatory=$true)]
    [string]$anker,
    [switch]$qsv
)
function Get-VideoDimensions {
    param (
        [string]$videoFile
    )
    $dimensions = & ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x $videoFile
    $width, $height = $dimensions -split "x"
    return [PSCustomObject]@{ Width = $width; Height = $height }
}

$videoDimensions = Get-VideoDimensions -videoFile $inputVideo
$originalWidth = [int]$videoDimensions.Width
$originalHeight = [int]$videoDimensions.Height

switch ($ratio)
{
    "4:3" {$numerador = 4 ; $denominador = 3 ; Break}
    "16:9" {$numerador = 16 ; $denominador = 9 ; Break}
    "5:4" {$numerador = 5 ; $denominador = 4 ; Break}
    "1:1" {$numerador = 1 ; $denominador = 1 ; Break}
    "3:4" {$numerador = 3 ; $denominador = 4; Break}
    "9:16" {$numerador = 9 ; $denominador = 16; Break}
    "4:5" {$numerador = 4 ; $denominador = 5; Break}
    Default {
        Write-Warning "using non-standard ratio: $ratio"; 
        $parts = $ratio -split ":"
        $numerador = [int]$parts[0]
        $denominador = [int]$parts[1]
    }
}

switch ($anker){
    "w" {
    $newWidth = $originalWidth
    $newHeight = [math]::Round($originalWidth * $denominador / $numerador )
    $cropX = 0
    $cropY = [math]::Round(($originalHeight - $newHeight) / 2)
    }
    "h" {
    $newWidth = [math]::Round($originalHeight * $numerador / $denominador)
    $newHeight = $originalHeight
    $cropX = [math]::Round(($originalWidth - $newWidth) / 2)
    $cropY = 0
    }
    Default {
        Write-Error "invalid anker"; exit 1
    }
}

$inputDirectory = [System.IO.Path]::GetDirectoryName($inputVideo)
$inputFileName = [System.IO.Path]::GetFileName($inputVideo)
$outputFileName = "output." + $inputFileName
$outputVideo = [System.IO.Path]::Combine($inputDirectory, $outputFileName)
$crop="${newWidth}:${newHeight}:${cropX}:${cropY}"
$crop_qsv="vpp_qsv=cw=${newWidth}:ch=${newHeight}:cx=${cropX}:cy=${cropY},format=yuv420p"

$bitrate = & ffprobe -v error -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 $inputVideo
$bitrate_bps = [math]::round($bitrate, 2)
$bitrate_kbps = [math]::round($bitrate / 1000, 2)
$bitrate_mbps = [math]::round($bitrate / 1000000, 2)

if ($bitrate){
    Write-Output "cropping video to: [$crop] -> bitrate: [$bitrate_bps bps ($bitrate_kbps kbps, $bitrate_mbps Mbps)]"
    if ($qsv){
        & ffmpeg -hide_banner -loglevel warning -stats -init_hw_device qsv=qsv -hwaccel qsv -hwaccel_output_format qsv -i $inputVideo -map_metadata 0 -vf $crop_qsv -b:v $bitrate -c:a aac -c:v h264_qsv -y $outputVideo
    }else{
        Write-Warning "using CPU encoder"
        & ffmpeg -hide_banner -loglevel warning -stats -i $inputVideo -map_metadata 0 -vf "crop=$crop" -b:v $bitrate -c:a aac -c:v libx264 -y $outputVideo
    }

    Write-Output "DONE! Output: $outputVideo"
}else{
    Write-Error "unable to get bitrate of: $inputVideo"
}