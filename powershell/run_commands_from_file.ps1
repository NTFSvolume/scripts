param (
	[Parameter(Mandatory=$true)]
    [string]$FilePath
)
$originalTitle = $host.ui.RawUI.WindowTitle
$host.ui.RawUI.WindowTitle = "running commands from file"
$file_content = Get-Content $FilePath
$total = $file_content.Length
$index = 0
$start = Get-Date
$remain = 0
$prct = 0
Clear-Host

$PSStyle.Progress.View = "Classic"

try {
	foreach ($line in $file_content) {
		$percent = $prct * 100
		$status = ("Commands processed: ${index}/${total} " + $prct.ToString("(0.##%)") + " ETA: " + $remain)
		Write-Progress -Activity $status -PercentComplete $percent
		Invoke-Expression -Command $line
		++$index
		$prct = $index / $total
		$elapsed = (Get-Date) - $start
		$remain = ($elapsed * (1 - $prct) / $prct)
	}
}
finally {
	$host.ui.RawUI.WindowTitle = $originalTitle
}

Write-Output ("`nDONE - Elapsed time: " + "($elapsed)" + " Total Commands: $total")

