param (
    [string]$folderPath,
    [int]$bitrate
)

if (-not (Test-Path $folderPath)) {
    throw "The folder path does not exist."
}

$videoExtensions = @(".mp4", ".avi", ".mkv", ".mov", ".wmv", ".flv", ".webm", ".mpeg", ".mpg", ".m4v", ".3gp", ".ogv")

$videos = Get-ChildItem -LiteralPath $folderPath -File -Force | Where-Object {$_.extension -in $videoExtensions} | ForEach-Object { $_.FullName }
if (-not $videos) {
    Throw "No video files found in the folder."
}

$maxWidth = 0
$maxHeight = 0
$maxBitrate = 0
function Get-VideoInfo {
    param (
        [string]$video
    )

    $ffprobeOutput = & ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 $video
    $bitrate = & ffprobe -v error -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 $video
    $lines = $ffprobeOutput -split "`n"
    $dimensions = $lines[0] -split "x"
    return [PSCustomObject]@{
        Width = [int]$dimensions[0]
        Height = [int]$dimensions[1]
        Bitrate = $bitrate
    }
}

# Iterate through each video to find the maximum dimensions and highest bitrate
foreach ($video in $videos) {
    $info = Get-VideoInfo -video $video
    if ($info.Width -gt $maxWidth) {
        $maxWidth = $info.Width
    }
    if ($info.Height -gt $maxHeight) {
        $maxHeight = $info.Height
    }
    if ($info.Bitrate -gt $maxBitrate) {
        $maxBitrate = $info.Bitrate
    }
}

if (-not $bitrate) {
    $bitrate = $maxBitrate
    Write-Warning "Using max bitrate from input files" 
}

$bitrate_bps = [math]::round($bitrate, 2)
$bitrate_kbps = [math]::round($bitrate / 1000, 2)
$bitrate_mbps = [math]::round($bitrate / 1000000, 2)
    
Write-Host "Output: ${maxWidth}x${maxHeight}  Bitrate: $bitrate_bps bps ($bitrate_kbps kbps, $bitrate_mbps Mbps) " 

# Construct the filter complex part for FFmpeg
$filterComplex = ""
for ($i = 0; $i -lt $videos.Length; $i++) {
    $filterComplex += "[${i}:v]scale=${maxWidth}:${maxHeight}:force_original_aspect_ratio=decrease,pad=${maxWidth}:${maxHeight}:-1:-1,setsar=1,fps=30,format=yuv420p[v${i}];"
}

for ($i = 0; $i -lt $videos.Length; $i++) {
    $filterComplex += "[${i}:a]aformat=sample_rates=48000:channel_layouts=stereo[a${i}];"
}

$videoLabels = ""
for ($i = 0; $i -lt $videos.Length; $i++) {
    $videoLabels += "[v${i}][a${i}]"
}

$filterComplex += "${videoLabels}concat=n=$($videos.Count):v=1:a=1[v][a]"

$ffmpegCommand = "ffmpeg -hide_banner -loglevel warning -stats "
foreach ($video in $videos) {
    $ffmpegCommand += "-i `"$video`" "
}

$outputPath = Join-Path $folderPath "ffmpeg_concat_padding_output.mkv"
$ffmpegCommand += "-filter_complex `"$filterComplex`" -map `"[v]`" -map `"[a]`" -c:v libx264 -b:v ${bitrate} -c:a aac -movflags +faststart $outputPath"

Invoke-Expression $ffmpegCommand
