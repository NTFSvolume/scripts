function Clear-HistoryFile {
    [CmdletBinding()]
    param ()

    $historyFilePath = (Get-PSReadlineOption).HistorySavePath

    if (-not $historyFilePath) {
        Throw "Unable to determine the history file path."
    }

    if (Test-Path -Path $historyFilePath) {
        try {
            Remove-Item -Path $historyFilePath -Force
            Write-Output "History file deleted successfully: $historyFilePath"
        } catch {
            Write-Error "Failed to delete history file: $_"
        }
    } else {
        Write-Output "No history file found at: $historyFilePath"
    }

    try {
        New-Item -Path $historyFilePath -ItemType File -Force
        Write-Output "New empty history file created at: $historyFilePath"
    } catch {
        Write-Error "Failed to create new empty history file: $_"
    }
}

Clear-HistoryFile
Clear-History