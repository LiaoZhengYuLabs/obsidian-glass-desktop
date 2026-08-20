param([int]$DelaySeconds = 2)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$startScript = $projectRoot + "\start.ps1"

if ($DelaySeconds -lt 0) { $DelaySeconds = 0 }
if ($DelaySeconds -gt 60) { $DelaySeconds = 60 }

Start-Sleep -Seconds $DelaySeconds
& $startScript -NoStartup
