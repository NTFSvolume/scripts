param(
    [Parameter(Mandatory = $true)]
    [string]$folderPath,
    [Alias('o')]
    [string]$outputPath = "",
    [Alias('c')]
    [int]$columns, 
    [Alias('r')]
    [int]$rows,
    [Alias('f')]
    [string]$files_from = "",
    [switch]$with_text,
    [switch]$on_place,
    [Alias('q')]
    [switch]$quiet,
    [Parameter(ValueFromRemainingArguments=$true)]
    [array]$additionalArgs
)

Set-StrictMode -Version Latest

$Global:TITLE_FONT_NAME = "NotoSansJP-Regular.ttf"
$Global:TIMESTAMP_FONT_NAME = "Helvetica-Bold.ttf"
$Global:UNKNOWN_ASPECT_RATIO = -1
$Global:LOGGER_PADDING = 7
$Global:LOGLEVEL_PADDING = 8
$Global:FONTS =  $null
$Global:MTN_HEADER_HEIGHT =  150
$Global:MTN_SIZE = 1500
$Global:MTN_GAP = 25
$Global:RATIOS = @(
    [pscustomobject]@{ Name = "5:4"; Value = 5/4 ; DefaultRows = 4; DefaultColumns = 4},
    [pscustomobject]@{ Name = "4:5"; Value = 4/5 ; DefaultRows = 3; DefaultColumns = 4},
    [pscustomobject]@{ Name = "4:3"; Value = 4/3 ; DefaultRows = 4; DefaultColumns = 3},
    [pscustomobject]@{ Name = "3:4"; Value = 3/4 ; DefaultRows = 3; DefaultColumns = 4 },
    [pscustomobject]@{ Name = "3:2"; Value = 3/2 ; DefaultRows = 4; DefaultColumns = 3},
    [pscustomobject]@{ Name = "2:3"; Value = 2/3 ; DefaultRows = 3; DefaultColumns = 5},
    [pscustomobject]@{ Name = "2:1"; Value = 2/1 ; DefaultRows = 4; DefaultColumns = 2},
    [pscustomobject]@{ Name = "1:2"; Value = 1/2 ; DefaultRows = 2; DefaultColumns = 4},
    [pscustomobject]@{ Name = "3:1"; Value = 3/1 ; DefaultRows = 5; DefaultColumns = 2},
    [pscustomobject]@{ Name = "1:3"; Value = 1/3 ; DefaultRows = 2; DefaultColumns = 5},
    [pscustomobject]@{ Name = "10:9"; Value = 10/9 ; DefaultRows = 3; DefaultColumns = 3},
    [pscustomobject]@{ Name = "9:10"; Value = 9/10 ; DefaultRows = 3; DefaultColumns = 4},
    [pscustomobject]@{ Name = "16:10"; Value = 16/10 ; DefaultRows = 5; DefaultColumns = 3},
    [pscustomobject]@{ Name = "9:17"; Value = 9/17 ; DefaultRows = 3; DefaultColumns = 6},
    [pscustomobject]@{ Name = "17:9"; Value = 17/9 ; DefaultRows = 6; DefaultColumns = 3},
    [pscustomobject]@{ Name = "10:16"; Value = 10/16 ; DefaultRows = 3; DefaultColumns = 5},
    [pscustomobject]@{ Name = "16:9"; Value = 16/9 ; DefaultRows = 5; DefaultColumns = 3},
    [pscustomobject]@{ Name = "9:16"; Value = 9/16 ; DefaultRows = 3; DefaultColumns = 5},
    [pscustomobject]@{ Name = "1:1"; Value = 1/1 ; DefaultRows= 4; DefaultColumns = 4}
)

function Assert-Dependencies ([array]$dependencies){
    foreach ($dependencie in $dependencies){
        if (-not (Get-Command $dependencie -ErrorAction SilentlyContinue)){
            Throw "'$dependencie' is not installed"
        }
    }
}

Assert-Dependencies @("mtn", "ffprobe")

#Clear-Host

#$Global:RATIOS | Sort-Object -Property Value | Format-Table| Out-Host

function Write-HostCustom(){
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$msg,
        [Parameter()]
        [string]$logLevel,
        [Parameter()]
        [string]$logLevelColor,
        [Parameter()]
        [string]$ForegroundColor = "white"
    )
    Write-Host "$($logLevel.ToUpper().PadRight($Global:LOGLEVEL_PADDING))" -NoNewline -ForegroundColor $logLevelColor
    Write-Host $msg -ForegroundColor $ForegroundColor
}

function Write-Error(){
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$msg
    )
    if (-not $quiet){
        Write-HostCustom $msg "ERROR" "red"
    }
}

function Write-Debug(){
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$msg
    )
    if ($DebugPreference -eq "Continue"){Write-HostCustom $msg "Debug" "blue"}
}

function Write-Verbose(){
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$msg
    )
    if ($VerbosePreference -eq "Continue"){Write-HostCustom $msg "Verbose" "Cyan"}
}
function Write-Warning(){
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$msg
    )
    Write-HostCustom $msg "warning" "yellow"
}

function Write-Information(){
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$msg,
        [Parameter()]
        [string]$ForegroundColor = "white"
    )
    Write-HostCustom $msg "info" "white" -ForegroundColor $ForegroundColor
}

function Get-ClosestRatio {
    param (
        [double]$inputRatio
    )
    return $Global:RATIOS | Sort-Object { [math]::Abs($_.Value - $inputRatio) } | Select-Object -First 1
}

function Get-VideoOrientation {
    param([string]$videoPath)

    $logger = "ffprobe"
    $logger = $logger.PadRight($Global:LOGGER_PADDING)
    $info = $null
    #$info = & ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height,sample_aspect_ratio,display_aspect_ratio:stream_side_data=rotation -of json $videoPath
    $info = & ffprobe -v quiet -select_streams v:0 -show_entries stream=width,height,sample_aspect_ratio,display_aspect_ratio:stream_tags=rotate -of json $videoPath
    
    $json =  $info | ConvertFrom-Json

    try{
        $json.PSObject.Properties.Name -contains 'streams' | Out-Null
        $width = [int]$json.streams[0].width
        $height = [int]$json.streams[0].height
        $rotation = 0
        $dar = $sar = $null
        $darNumerator = $width
        $darDenominator = $height
        $sarNumerator = $sarDenominator = 1
        $isRotated = $false
        try{
            $dar = $json.streams[0].display_aspect_ratio
            $darParts = $dar -split ":"
            $darNumerator = [float]$darParts[0]
            $darDenominator = [float]$darParts[1]
            $sar = $json.streams[0].sample_aspect_ratio
            $sarParts = $sar -split ":"
            $sarNumerator = [float]$sarParts[0]
            $sarDenominator = [float]$sarParts[1]
        }catch{}

        try{
            $rotation = [int]($json.streams[0].tags | 
            Where-Object { $_.PSObject.Properties.Match('rotate') } | 
            Select-Object -First 1 -ExpandProperty "rotate")
        }catch{}
      
        $ratio = $darNumerator / $darDenominator
        $effectiveWidth = $width * $sarNumerator / $sarDenominator
        $effectiveHeight = $height
        
        if (([math]::Abs($rotation) -eq 90) -or ([math]::Abs($rotation) -eq 270) ){
            $ratio = 1 / $ratio
            $effectiveWidth = $height * $sarNumerator / $sarDenominator
            $effectiveHeight = $width
            $isRotated = $true
        }

        $defaultRatio = Get-ClosestRatio $ratio

        if ($width -gt $height){$largestSide = "W"}else {$largestSide = "H"}
        if ($effectiveWidth -gt $effectiveHeight){$effectiveLargestSide = "W"}else {$effectiveLargestSide = "H"}

        if ($largestSide -ne $effectiveLargestSide){
            $isRotated = $true
        }
        
        $neededRows =  ($Global:MTN_SIZE - $Global:MTN_GAP - $Global:MTN_HEADER_HEIGHT) / ($effectiveHeight + $Global:MTN_GAP )
        $neededColumns = ($Global:MTN_SIZE - $Global:MTN_GAP ) / ($effectiveWidth + $Global:MTN_GAP )
        $useRows = [math]::Round([math]::Max($defaultRatio.DefaultRows, $neededRows))
        $useColumns = [math]::Round([math]::Max($defaultRatio.DefaultColumns, $neededColumns))

        $videoInfo = [PSCustomObject]@{
            Path = $videoPath
            Width = $width
            Height = $height
            DAR = $dar
            SAR = $sar
            Rotation = $rotation
            IsRotated = $isRotated
            EfectiveResolution = "$effectiveWidth x $effectiveHeight"
            AspectRatio = Get-ClosestRatio $ratio
            NeededRows = $neededRows
            NeededColumns =  $neededColumns
        }

        $videoMtnParameters = [PSCustomObject]@{
            Rows = $useRows
            Columns = $useColumns
        }

        if ($DebugPreference -eq "Continue") {
            $videoInfo | Format-List | Out-Host
        } 
        
        return $videoMtnParameters

    }catch{
        Write-Warning ("[$logger]: unable to detect aspect ratio of:  '$videoPath'")
        $DEFAULT_RATIO = Get-ClosestRatio (16 / 9)
        $videoMtnParameters = [PSCustomObject]@{
            Rows = $DEFAULT_RATIO.DefaultRows
            Columns = $DEFAULT_RATIO.DefaultColumns
        }
        return $videoMtnParameters
    }
    
}

function Get-Fonts {
    [CmdletBinding()]
    $fontsDirectory = Join-Path -Path $HOME -ChildPath "fonts"
    if ($IsLinux){
        $fontsDirectory = Join-Path -Path $HOME -ChildPath ".fonts"
    }
    if ($IsWindows){
        Throw "Can not use -with_text when running on windows"
    }
       
    $titleFontPath = Join-Path -Path $fontsDirectory -ChildPath $Global:TITLE_FONT_NAME
    $timestampFontPath = Join-Path -Path $fontsDirectory -ChildPath $Global:TIMESTAMP_FONT_NAME
    
    try{
        Get-Item -LP $titleFontPath -Force -ErrorAction Stop | Out-Null
        Get-Item -LP $timestampFontPath -Force -ErrorAction Stop | Out-Null
    }
    catch{
        Throw "An error occurred while getting the fonts files: $($_.Exception.Message)" 
    }

   return [pscustomobject]@{ Title = $titleFontPath; Timestamp = $timestampFontPath }
}

function Invoke-mtn {
    [CmdletBinding()]
    param(
        [string]$inputPath,
        [string]$outputPath = ""
    )
    if ($outputPath -eq "") {
        $outputFolder = Split-Path -Path $inputPath  -Parent
    }
    else {
        $outputFolder = $outputPath
    }

    $logger = "mtn"
    $logger = $logger.PadRight($Global:LOGGER_PADDING)
    $mtnConfig = Get-VideoOrientation $inputPath
    $useRows = $mtnConfig.Rows
    $useColumns = $mtnConfig.Columns

    if ($columns){
        Write-Warning "Overriding rows to $columns"
        $useColumns = $columns
    }
    if ($rows){
        Write-Warning "Overriding rows to $rows"
        $useRows = $rows
    }
    
    $cmd = @( "-W", "$inputPath", "--shadow", "-o", ".jpg", 
            "-O", "$outputFolder", "-c", $useColumns, "-r", $useRows, "-w", $Global:MTN_SIZE, 
            "-g", $Global:MTN_GAP , "-H", "-X", "-D", 0 , "-P", "-h", 100)
        
    if ($with_text){
        $fontStyle = "101010:18:$($Global:FONTS.Timestamp):FFFFFF:000000:25"
        $cmd += @("-f", "$($Global:FONTS.Title)", "-F", $fontStyle )
    }
  
    $cmd += $additionalArgs

    $mtn_output = (& mtn $cmd ) 2>&1 
   
    $input_filename = Split-Path $inputPath -Leaf
    
    $output_path = Join-Path $outputFolder ($input_filename + ".jpg")
    if (Test-Path -LP $output_path) {
        Write-Debug "[$logger]: $mtn_output" 
        Write-Verbose "[$logger]: SUCCESS!! File saved at: '$output_path'" 
        return $true
    }

    Write-Error "[$logger]: could not generate thumbnail for: '$inputPath'" 
    Write-Debug "[$logger]: $mtn_output" 
    return $false
}

function main {
    if (-not (Test-Path -LP $folderPath)) {
        Throw "folder '$folderPath' does not exists" 
    }
    
    $folderPath = Get-Item -LP $folderPath -Force
    
    $videoExtensions = @(".mp4", ".avi", ".ts",".mkv",".mts", ".mov", ".wmv", ".m2ts", `
                        ".flv", ".webm", ".mpeg", ".mpg", ".m4v", ".3gp", ".ogv")

    if ($files_from){
        Write-Warning "Only generating thumbnails for files in '$files_from'" 
        $videoFiles = Get-Content -LP $files_from -Force
    }else{
        $videoFiles = Get-ChildItem -LP $folderPath -Recurse -File -Force | Where-Object { $_.Extension.ToLower() -in $videoExtensions }
    }

    $currentFileIndex = 0
    $totalVideoCount = ($videoFiles | Measure-Object).Count
    $input_path_root = $folderPath 
    
    if ($totalVideoCount -eq 0) {
        Throw "No video files found"
    } 
    
    if ($outputPath -eq "") {
        if ($on_place) {
            $output_path_root = $input_path_root 
            Write-Warning "using -on_place, output folder: '$output_path_root'" 
        }
        else {
            $output_path_root = New-Item -ItemType Directory -Force  (Join-Path $folderPath.Parent ($folderPath.Name + "_thumbs")) -ErrorAction Stop 
            Write-Warning "using default output folder: '$output_path_root'"
        }
    }
    else {
        $output_path_root = New-Item -Path $outputPath -ItemType Directory -Force -ErrorAction Stop 
    }

    $scriptConfig = [PSCustomObject]@{
        InputFolder = $folderPath
        OutputFolder = $output_path_root
        with_text = $with_text
        AdditionalArgs = $additionalArgs
    }
    
    $scriptConfig | Format-List 

    if ($with_text){
        $Global:FONTS = Get-Fonts -ErrorAction Stop
        if ($DebugPreference -eq "Continue"){
            $Global:FONTS | Format-List | Out-Host
        }
    }
    
    $PSStyle.Progress.View = "Minimal"

    Write-Information "Generating thumbnails for videos in: '$folderPath'"
    
    $successfullThumbs = 0
    $skipped = 0
    foreach ($file in $videoFiles ) {     
        $currentFileIndex++  
        if ($files_from){
            try{
                $file = Get-Item -LP (Join-Path $folderPath $file) -Force -ErrorAction Stop
            }catch{
                Write-Error $_
                continue
            }
        }
        $input_file_path_directory = $file.Directory
        $relativePath = $input_file_path_directory.FullName.Substring($input_path_root.FullName.TrimEnd([System.IO.Path]::DirectorySeparatorChar).Length)
        $output_file_path_directory = Join-Path $output_path_root $relativePath

        $output_path = Join-Path $output_file_path_directory ($file.Name + ".jpg")
   
        $isSuccessfull = $false
        if (Test-Path -LP $output_path) {
            Write-Verbose "output file '$output_path' already exist, omitted"
            $skipped += 1
            
        }else{
            Write-Verbose "generating thumbnail of: '$file'"
            Write-Debug "input_path_root resolved: '$input_path_root'" 
            Write-Debug "input_file_path_directory resolved: '$input_file_path_directory'"
            Write-Debug "relative path between input_path_root and input_file_path_directory: '$relativePath'"  
            Write-Debug "output_file_path_directory resolved: '$output_file_path_directory'" 
            
            New-Item -Path $output_file_path_directory -ItemType Directory -Force | Out-Null
            $isSuccessfull = Invoke-mtn -inputPath $file -outputPath $output_file_path_directory
        }
        
        if ($isSuccessfull){
            $successfullThumbs += 1
        }
        $progressPercentage = [math]::Floor(($currentFileIndex / $totalVideoCount) * 100)
        $indexPadding = $totalVideoCount.ToString().Length
        $activity = "File $(($currentFileIndex + 1).ToString().PadLeft($indexPadding))/$totalVideoCount ($($progressPercentage.ToString().PadLeft(3))%)"

        
        $PSStyle.Progress.MaxWidth = [math]::Min([Console]::BufferWidth,120)
        Write-Progress -Activity $activity -PercentComplete $progressPercentage #-Status $status
    }

    Write-Progress -Activity "File: " -Status "Progress: 100% Complete" -Completed
    $failed = $totalVideoCount - $successfullThumbs - $skipped
    $report = [pscustomobject]@{ Successfull = $successfullThumbs; Failed = $failed; Skipped = $skipped}
    if ($failed -gt 0){
        Write-Information "Finished with errors" -ForegroundColor red
    }else{
        Write-Information "DONE!" -ForegroundColor green
    }
    $report | Format-List | Out-Host
}

main 
