# Main script
param (
    [string]$inputPath
)
function Get-BaseDomain {
    param (
        [string]$url
    )
    $uri = [Uri]($url)
    $urlHost = $uri.Host
    
    $hostParts = $urlHost.Split('.')
    if ($hostParts.Length -ge 2) {
        $baseDomain = "$($hostParts[-2]).$($hostParts[-1])"
        return $baseDomain
    } else {
        return $host
    }
}

if (-Not (Test-Path -LP $inputPath)) {
    Throw "Input file not found: $inputPath"
}

$csvContent = Import-Csv -LP $inputPath -Header "URL","details" -Delimiter ","
$urls = $csvContent | Select-Object -ExpandProperty URL
$domainUrls = @{}

foreach ($url in $urls) {
    $baseDomain = Get-BaseDomain $url
    if ($baseDomain) {
        if (-Not $domainUrls.ContainsKey($baseDomain)) {
            $domainUrls[$baseDomain] = @()
        }
        $domainUrls[$baseDomain] += $url
    }
}

foreach ($domain in $domainUrls.Keys) {
    $directory = Split-Path -Path $inputPath
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($inputPath)
    $newFileName = $fileName + "_${domain}.txt"
    $outputPath = Join-Path -Path $directory -ChildPath $newFileName
    $domainUrls[$domain] | Out-File -LP $outputPath -Encoding utf8
    Write-Output "Created file: $outputPath"
}

Write-Output "DONE!"
