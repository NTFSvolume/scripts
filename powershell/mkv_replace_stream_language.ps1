param (
    [Parameter(Mandatory=$true)]
    [string]$folderPath,
    [Parameter(Mandatory=$true)]
    [string]$originalLanguage,
    [Parameter(Mandatory=$true)]
    [string]$desiredLanguage
)

$OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

$start = Get-Date

$mkvFiles = Get-ChildItem -Path $folderPath -Filter *.mkv -Recurse -Force

foreach ($file in $mkvFiles) {
    $mkvInfo = & mkvmerge --identification-format json --identify "$($file.FullName)" | ConvertFrom-Json
    $streamsInfo = $mkvInfo.tracks | Where-Object { $_.type -eq "audio" -or $_.type -eq "subtitles" }
    $modifiedStreams = @()

    foreach ($stream in $streamsInfo) {
        if ($stream.properties.language -eq $originalLanguage) {
            $modifiedStreams += $stream.id + 1
        }
    }

    foreach ($trackId in $modifiedStreams) {
        & mkvpropedit --gui-mode -v $file.FullName --edit track:$trackId --set "language=$desiredLanguage"
    }
    Write-Output "Language changed from $originalLanguage to $desiredLanguage for $($modifiedStreams.Count) stream(s) in $($file.Name)"
}

Write-Output "Modified files are saved in: $folderPath"

$elapsed = (Get-Date) - $start
Write-Output ("`nDONE - Elapsed time: " + "($elapsed)")

