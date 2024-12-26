param(
    [Parameter(Mandatory=$true)]
    [string]$inputFolder
)

Get-ChildItem (Join-Path $inputFolder "*.mp4") -Recurse | ForEach-Object {
    $inputFile = $_
    $outputFile = Join-Path $_.Directory ("ffmpeg." + $inputFile.Name)
    & ffmpeg -hide_banner -loglevel warning -stats -i $inputFile  -map_metadata 0 -movflags use_metadata_tags -map 0 -map -0:v -map 0:V -c copy $outputFile && Remove-Item -LiteralPath $inputFile && Move-Item -LiteralPath $outputFile $inputFile
}