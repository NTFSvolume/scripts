param(
    [Parameter(Mandatory=$true)]
    [string]$inputFolder,
    [switch]$deleteOriginal 
)

$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

$dependencies=@("mkvmerge")

$start = Get-Date

if (-not (Test-Path $inputFolder)) {
    Write-Host "Input folder not found: $inputFolder"
    exit 1
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
function Assert-Dependencies{
    foreach ($dependencie in $dependencies){
        if (-not (Get-Command $dependencie -ErrorAction SilentlyContinue)){
            Throw "$dependencie is not installed"
        }
    }
    
}

Assert-Dependencies

Get-ChildItem (Join-Path $inputFolder "*.mp4") -File -Recurse | ForEach-Object {
    $input_file_path = $_.FullName
    $input_file_name = $_.Name
    $output_file_path = Join-Path $_.Directory.FullName ($_.BaseName + ".mkv")
    Write-Output "Creating MKV for: '$input_file_name'... " -NoNewline
   
    if ($deleteOriginal) {
       Format-MKVpropeditOutput {
        mkvmerge --gui-mode -o $output_file_path $input_file_path && Remove-Item $input_file_path -Force 
    }
    
    }else{
        Format-MKVpropeditOutput {
        mkvmerge --gui-mode -o $output_file_path $input_file_path
    }
    Write-Host "Done" -BackgroundColor Green -NoNewline
    Write-Host "" -BackgroundColor Black
    }
}

$elapsed = (Get-Date) - $start
Write-Output ("`nDONE - Elapsed time: " + $elapsed.ToString())
