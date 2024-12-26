param (
    [Parameter(Mandatory)]
    [string]$InputFolder
)

$ResolvedFolder = Resolve-Path -LiteralPath $InputFolder

Get-ChildItem -LiteralPath $ResolvedFolder -File | ForEach-Object {
    $lowercaseName = $_.Name.ToLower()
    $initialChar = $lowercaseName.Substring(0, 1)
    $targetFolder = Join-Path -Path $ResolvedFolder -ChildPath $initialChar

    if (-not (Test-Path -LiteralPath $targetFolder)) {
        New-Item -ItemType Directory -Path $targetFolder
    }

    Move-Item -LiteralPath $_.FullName -Destination $targetFolder
}
