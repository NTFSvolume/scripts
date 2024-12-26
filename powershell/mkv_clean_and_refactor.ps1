param(
    [Parameter(Mandatory=$true)]
    [string]$inputFolder,
    [Parameter(Mandatory=$true)]
    [string]$originalLanguage,
    [Alias('r')]
    [switch]$remove_unnecessary_streams
)

$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

$dependencies=@("mkclean","mkvpropedit","ffmpeg")

$start = Get-Date

if (-not (Test-Path $inputFolder)) {
    Throw "Input folder not found: $inputFolder"
}
function Assert-Dependencies{
    foreach ($dependencie in $dependencies){
        if (-not (Get-Command $dependencie -ErrorAction SilentlyContinue)){
            Write-Error "$dependencie is not installed"
            exit 1
        }
    }
}
function Format-MKVpropeditOutput {
    param (
        [scriptblock]$Command
    )
    $output = & $Command
    foreach ($line in $output) {
        if ($line.StartsWith("#GUI")) {
            if ($line.StartsWith("#GUI#error")) {
                Write-Error $line.Substring(10)
            } 
            elseif ($line.StartsWith("#GUI#warning")) {
                Write-Warning $line.Substring(12)
            }
        } 
    }
}

function main {
    Assert-Dependencies
    Get-ChildItem (Join-Path $inputFolder "*.mkv") -Recurse | ForEach-Object {
        $inputFile = $_.FullName
        $outputFile = Join-Path $_.Directory.FullName ("ffmpeg." + $_.Name)
        $mkvcleanOutputFile = Join-Path $_.Directory.FullName ("clean." + $_.Name)
        
        Write-Output ("Processing: " + $_.Name)
        
        Format-MKVpropeditOutput {
            & mkvpropedit --gui-mode -v $inputFile --tags all: --edit info --set title="" --delete-attachment "mime-type:image/jpeg" --delete-attachment "mime-type:image/png" --edit track:v1 --set name="" --set language=$originalLanguage 
        }
        
        if ($remove_unnecessary_streams) {
            Move-Item -LiteralPath $inputFile $outputFile

            $command = "& ffmpeg -hide_banner -loglevel warning -stats -analyzeduration 2147483647 -probesize 2147483647 -i `"" + $outputFile 
            
            if ($originalLanguage -eq "eng" -or $originalLanguage -eq "spa" -or $originalLanguage -eq "es-419") {
                $command += "`" -map_metadata 0 -movflags use_metadata_tags -map V -map a:m:language:eng? -map a:m:language:spa? -map s:m:language:eng? -map s:m:language:enm? -map s:m:language:spa? -c copy `"" 
            }
            else {
                $command += "`" -map_metadata 0 -movflags use_metadata_tags -map V -map a:m:language:eng? -map a:m:language:spa?  -map a:m:language:" + $originalLanguage + "? -map s:m:language:eng? -map s:m:language:enm? -map s:m:language:spa? -c copy `"" 
            }
            $command += $inputFile + "`" && Remove-Item -LiteralPath `"" + $outputFile + "`""
            Invoke-Expression $command
        }
        
        & mkclean --doctype 2 $inputFile && Remove-Item -LiteralPath $inputFile && Move-Item -LiteralPath $mkvcleanOutputFile $inputFile
        
        Format-MKVpropeditOutput {
            & mkvpropedit --gui-mode -v $inputFile --tags all: --edit info --set title="" --delete-attachment "mime-type:image/jpeg" --delete-attachment "mime-type:image/png" --edit track:v1 --set name="" --set language=$originalLanguage 
        }
    }

    $elapsed = (Get-Date) - $start
    Write-Output ("`nDONE - Elapsed time: " + "($elapsed)")
}

main
