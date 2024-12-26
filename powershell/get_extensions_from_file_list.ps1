param(
    [string]$FilePath
)

begin {
    $FileList = @()
    if ($FilePath) {
        if (Test-Path -LiteralPath $FilePath) {
            $FileList += Get-Content -LiteralPath $FilePath
        } else {
            Write-Warning "File not found: $FilePath"
        }
    }
}

process {
    if ($FilePath) {
        Write-Warning "Ignoring piped FileList because FilePath parameter is provided."
    } else {
        $FileList += $_
    }
}

end {
    if ($FileList) {
        $ExtensionCounts = @{}
        foreach ($File in $FileList) {
            $Extension = [System.IO.Path]::GetExtension($File)
            
            if (-not $Extension) {
                $Extension = "NO_EXTENSION"
            } else {
                $Extension = $Extension.TrimStart('.')
            }
            
            if ($ExtensionCounts.ContainsKey($Extension)) {
                $ExtensionCounts[$Extension]++
            } else {
                $ExtensionCounts[$Extension] = 1
            }
        }

        foreach ($Extension in $ExtensionCounts.Keys) {
            Write-Output "$Extension : $($ExtensionCounts[$Extension])"
        }
    } else {
        Write-Output "No FileList to process."
    }
}


