param (
    [Parameter(Mandatory=$true)]
    [string]$inputVideoPath,
    [string]$manual,
    [switch]$qsv
)

$inputDirectory = Split-Path $inputVideoPath -Parent
$inputFileName = [System.IO.Path]::GetFileNameWithoutExtension($inputVideoPath)
$inputExtension = [System.IO.Path]::GetExtension($inputVideoPath).ToLower()

if ($inputFileName -like "*__CROPPED*") {
    Write-Output "File path contains '__CROPPED', skipping"
    exit 0
} 

$videoExtensions = @('mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv', 'webm', 'mpg', 'mpeg', '3gp', '3g2', 'm4v', 'mts', 'm2ts', 'ts', 'mxf', 'ogv', 'divx', 'xvid', 'rm', 'rmvb', 'vob')

if ($videoExtensions -notcontains $inputExtension.TrimStart('.')){
    Throw "File $inputExtension is not a video"
}

if ($inputExtension -eq ".mkv") {
    $outputExtension = ".mkv"
} else {
    $outputExtension = ".mp4"
}

$bitrate = & ffprobe -v error -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 $inputVideoPath

if ($bitrate){
    if ($manual){
        $crop=$manual
    }else{
        $cropdetectOutput = & ffmpeg -i $inputVideoPath -vf "cropdetect=24:16:0" -frames:v 100 -f null - 2>&1 | Select-String "crop="
        $crop = $cropdetectOutput[-1].ToString().Split("crop=")[1].Split(" ")[0]
    }
    $crop_values=$crop.Split(":")
    $crop_qsv="vpp_qsv=cw=$($crop_values[0]):ch=$($crop_values[1]):cx=$($crop_values[2]):cy=$($crop_values[3]),format=yuv420p"
    
    $outputDirectory = Join-Path $inputDirectory "__CROPPED"
    $outputPath = Join-Path $outputDirectory "${inputFileName}__CROPPED$outputExtension"

    New-Item -ItemType Directory -Path $outputDirectory -ErrorAction SilentlyContinue | Out-Null

    # Display the bitrate in bps, kbps, and Mbps
    $bitrate_bps = [math]::round($bitrate, 2)
    $bitrate_kbps = [math]::round($bitrate / 1000, 2)
    $bitrate_mbps = [math]::round($bitrate / 1000000, 2)

    Write-Host "cropping video to: [$crop] -> bitrate: [$bitrate_bps bps ($bitrate_kbps kbps, $bitrate_mbps Mbps)]"
    
    if ($qsv){
        & ffmpeg -hide_banner -loglevel warning -stats -init_hw_device qsv=qsv -hwaccel qsv -hwaccel_output_format qsv -i $inputVideoPath -map_metadata 0 -vf $crop_qsv -b:v $bitrate -c:a aac -c:v h264_qsv -y $outputPath
    }else{
        Write-Warning "using CPU encoder"
        & ffmpeg -hide_banner -loglevel warning -stats -i $inputVideoPath -map_metadata 0 -vf "crop=$crop" -b:v $bitrate -c:a aac -c:v libx264 $outputPath
    
    }

    Write-Host "DONE! Output: $outputPath"
}else{
    Write-Error "Unable to get bitrate of: $inputVideoPath"
}
