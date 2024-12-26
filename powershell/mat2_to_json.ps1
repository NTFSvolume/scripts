param(
    [Parameter(Mandatory = $true)]
    [string]$folderPath,
    [Alias('o')]
    [string]$outputPath = ""
)

function Invoke-Mat2{
    param (
        [string]$inputFile
    )
    $content = mat2 -s $inputFile

    if ($content.Count -lt 2) {
        Throw "The file must contain at least two lines."
    }
    $noise = "[+] Metadata for "
    $jsonKey = ($content[0]).Substring($noise.Length, $content[0].Length - 1 - $noise.Length)
    $jsonSubObjects = @{}

    foreach ($line in $content[1..($content.Count - 1)]) {
        $parts = $line -split ":", 2
        
        if ($parts.Count -eq 2) {
            $subKey = $parts[0].Trim()  # First part becomes the subkey, trim any extra spaces
            $subValue = $parts[1].Trim()  # Rest becomes the value, trim spaces
            $jsonSubObjects[$subKey] = $subValue
        }
    }

    $jsonData = @{ $jsonKey = $jsonSubObjects }
    $json = $jsonData | ConvertTo-Json -Depth 3
    Write-Host $jsonData
    return $json
}


function main {
    $videoExtensions = @(".mp4", ".avi", ".ts",".mkv",".mts", ".mov", ".wmv", ".flv", ".webm", ".mpeg", ".mpg", ".m4v", ".3gp", ".ogv")
    $files = Get-ChildItem -LP $folderPath -Recurse -File -Force | Where-Object { $_.Extension.ToLower() -in $videoExtensions }
    $lines = @()
    foreach ($file in $files){
        $lines += Invoke-Mat2 $file
    }
    $lines | Out-File (Join-Path $folderPath "mat2_output.jsonl") -Encoding utf8
}

main
