param (
    [Parameter(Mandatory=$true)]
    [string]$REMOTE_NAME,
    [string]$MOUNT_POINT = 'X:'
)

$originalHostTitle = $host.ui.RawUI.WindowTitle
$host.ui.RawUI.WindowTitle = "rclone [$REMOTE_NAME]"
$CLEAN_REMOTE_NAME = $REMOTE_NAME -replace ":", ""  
Write-Host -ForegroundColor Blue "Attempting to mount rclone remote '$REMOTE_NAME' on $MOUNT_POINT"
Write-Information "Attempting to mount rclone remote '$REMOTE_NAME' on $MOUNT_POINT"

if (Test-Path $MOUNT_POINT) {
    if ($IsWindows){
        Write-Warning "$MOUNT_POINT is not available, picking another drive letter"
        $MOUNT_POINT = "*"
    }
    if ($IsLinux){
        $files = Get-ChildItem -Path $MOUNT_POINT -Force
        if ($files.Count -gt 0) {
            Throw "The folder is NOT empty."
        } 
    }
}else{
    if ($IsLinux){
        Throw "The folder does NOT exists."
    }
}

$cacheDir = Join-Path $HOME ".rclonecache"
New-Item $cacheDir -Type Directory -Force | Out-Null

try {
    & rclone mount --bwlimit 180M --attr-timeout 1h --dir-cache-time 1h --log-level INFO `
    --vfs-disk-space-total-size 256T --poll-interval 15s --tpslimit 8 --vfs-refresh `
    --volname $CLEAN_REMOTE_NAME $REMOTE_NAME $MOUNT_POINT --no-modtime --no-checksum `
    --vfs-refresh --vfs-cache-mode writes (if($isWindows){ "--network-mode" }) `
    --vfs-cache-poll-interval 20s --vfs-cache-max-age 5m --cache-dir $cacheDir | ForEach-Object {
    if ($_ -like '*ERROR :*') {
            Write-Error $_
        } elseif ($_ -like '*DEBUG :*'){
			Write-Verbose $_
		}
		else {
            Write-Output $_ 
        }
    }
}
catch {
    Throw -ForegroundColor Red $_.Exception.Message
}
finally {
        $host.ui.RawUI.WindowTitle = $originalHostTitle
}

Write-Output "Exiting script..."
