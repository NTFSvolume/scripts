param(
    [Parameter(Mandatory = $true)]
    [string]$inputFile
)

$inputFile = Convert-Path $inputFile

$parent="$(Split-Path $inputFile.FullName -Parent)";    
write-Output "Extracting $($inputFile.FullName) to $parent"

$arguments=@("e", "`"$($inputFile.FullName)`"", "-o`"$($parent)`"");
$ex = start-process -FilePath "7z" -ArgumentList $arguments -wait -PassThru;

if( $ex.ExitCode -eq 0)
{
    Write-Output "Extraction successful, deleting $($inputFile.FullName)"
    Remove-Item -Path $inputFile.FullName -Force
}

