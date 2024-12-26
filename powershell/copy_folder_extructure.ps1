param (
    [Parameter(Mandatory=$true)]
    [string]$inputPath,
	[Parameter(Mandatory=$true)]
    [string]$outputPath
)

$dependencies=@("rclone")
function Assert-Dependencies{
    foreach ($dependencie in $dependencies){
        if (-not (Get-Command $dependencie -ErrorAction SilentlyContinue)){
            Throw "$dependencie is not installed"
        }
    }
    
}

Assert-Dependencies

$randomID = [guid]::NewGuid()
rclone copy -P $inputPath $outputPath --create-empty-src-dirs --include ".test_file_from_rclone_$randomID"