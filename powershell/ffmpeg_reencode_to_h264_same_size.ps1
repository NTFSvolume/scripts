param (
    [Parameter(Mandatory=$true)]
    [string]$inputVideoPath,
    [string]$outputDirectory="",
    [switch]$qsv
)

$bitrate = & ffprobe -v error -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 $inputVideoPath

if ($bitrate -gt 0){
    $bitrate_bps = [math]::round($bitrate, 2)
    $bitrate_kbps = [math]::round($bitrate / 1000, 2)
    $bitrate_mbps = [math]::round($bitrate / 1000000, 2)

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
        if (-not (Test-Path $outputDirectory)) {
            New-Item -ItemType Directory -Path $outputDirectory -Force
        }
    }

    $outputPath = Join-Path $outputDirectory  "${inputFileName}_$outputExtension"
    
    Write-Output "Re-encoding.... - Bitrate: $bitrate_bps bps ($bitrate_kbps kbps, $bitrate_mbps Mbps)"

    if ($qsv){
        #& ffmpeg -hide_banner -loglevel warning -stats -init_hw_device qsv=qsv -hwaccel qsv -hwaccel_output_format qsv -i $inputVideoPath -map_metadata 0 -b:v $bitrate -c:a aac -c:v h264_qsv -y $outputPath
        & ffmpeg -hide_banner -loglevel warning -stats -hwaccel vaapi -hwaccel_output_format vaapi -vaapi_device /dev/dri/renderD128  -i $inputVideoPath -map_metadata 0 -b:v $bitrate -c:a aac -c:v h264_vaapi -y $outputPath
    }else{
        Write-Warning "using CPU encoder"
        & ffmpeg -hide_banner -loglevel warning -stats -i $inputVideoPath -map_metadata 0 -b:v $bitrate -c:a aac -c:v libx264 -y $outputPath
    }

    Write-Host "Video re-encoding complete. Output file: $outputPath"
}else{
    Write-Warning "unable to detect bitrate"
}
