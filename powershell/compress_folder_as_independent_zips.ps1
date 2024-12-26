param(
    [Parameter(Mandatory=$true)]
    [string]$inputFolder,
    [Alias('s')]
    [int]$targetSizeMB = 2048,
    [Alias('o')]
    [string]$outputFolderRoot,
    [Alias('n')]
    [string]$outputFileName
)

$ErrorActionPreference = 'Stop'
function Assert-Dependencies ([array]$dependencies){
    foreach ($dependencie in $dependencies){
        if (-not (Get-Command $dependencie -ErrorAction SilentlyContinue)){
            Throw "'$dependencie' is not installed"
        }
    }
}

Assert-Dependencies @("rclone","7z")

$parentFolder = Split-Path $inputFolder -Parent
$tempDirName = "ArchiveScriptTemp_" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) $tempDirName
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
if (-not ($outputFolderRoot)){
    $outputFolderRoot = $parentFolder
} 

if (-not ($outputFileName)){
    $outputFileName = Split-Path $inputFolder -Leaf
}

$scriptConfig = [PSCustomObject]@{
    InputFolder = Resolve-Path -LiteralPath $inputFolder.TrimEnd('\').TrimEnd('/')
    OutputFolder = New-Item -ItemType Directory -Path $outputFolderRoot -Force -ErrorAction Stop 
    TargetSize = "${targetSizeMB}MB"
    OutputFileName = "$outputFileName.zip"
}

$scriptConfig | Format-List

$outputFolderAbs = Resolve-Path -LiteralPath $outputFolderRoot.TrimEnd('\').TrimEnd('/')

if ($scriptConfig.InputFolder.Path -eq $outputFolderAbs.Path){
    Throw "inputFolder and outputFolder can not be equal"
}
if ($outputFolderAbs.Path.StartsWith($scriptConfig.InputFolder.Path + [IO.Path]::DirectorySeparatorChar )) {
    Throw "outputFolder can not be a child of inputFolder"
} 

Write-Output "scanning input folder and splitting files into groups..."
$rcloneOutput = & rclone lsjson -R --config (New-TemporaryFile) --files-only $inputFolder

$fileList = $rcloneOutput | ConvertFrom-Json | ForEach-Object {
    [PSCustomObject]@{
        Size = [long]$_.Size
        RelativePath = $_.Path
    }
}

$currentGroup = [PSCustomObject]@{
    Size = [long]0
    Index = 1
    Files =  @()
}

foreach ($file in $fileList) {
    if (($currentGroup.Size + $file.Size) -gt ($targetSizeMB * 1MB)) {
        $tempFileName = "$($outputFileName | Split-Path -Leaf).part.$('{0:D3}' -f $currentGroup.Index).txt"
        $currentGroup.Files | Out-File -FilePath (Join-Path $tempDir $tempFileName) -Encoding utf8
        $currentGroup.Files = @()
        $currentGroup.Size = 0
        $currentGroup.Index++
    }

    $currentGroup.Files += $file.RelativePath
    $currentGroup.Size += $file.Size
}

if ($currentGroup.Files.Count -gt 0) {
    $tempFileName = "$($outputFileName  | Split-Path -Leaf).part.$('{0:D3}' -f $currentGroup.Index).txt"
    $currentGroup.Files | Out-File -FilePath (Join-Path $tempDir $tempFileName) -Encoding utf8
}


try{
    Push-Location -LiteralPath $inputFolder
    foreach ($fileListFile in (Get-ChildItem (Join-Path $tempDir "$($outputFileName  | Split-Path -Leaf).part*.txt"))) {
    $outputZip = Join-Path $scriptConfig.OutputFolder "$($fileListFile.BaseName).zip" -ErrorAction Stop 
    if ($currentGroup.Index -eq 1){
        Write-Warning "targetSize is greater than inputFolder size, a single ZIP will be created"
        $outputZip = $outputZip -replace ".part.001",""
    }
    Write-Output "`rcreating '$outputZip'"
    & 7z a -bso0 -bsp1 -mmt -tzip $outputZip -ir@"$fileListFile" 
    }
}
finally{
    Pop-Location
    Remove-Item -Path $tempDir -Recurse -Force
    Write-Output "DONE!" | Out-Host
}
