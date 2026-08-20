param(
    [ValidateSet("fixed", "collapsed")]
    [string]$Mode = "fixed"
)

$stateRoot = $env:LOCALAPPDATA + "\ObsidianDockVisibility"
$statePath = $stateRoot + "\mode.txt"

if (!(Test-Path -LiteralPath $stateRoot)) {
    New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
}

Set-Content -LiteralPath $statePath -Value $Mode -NoNewline -Encoding ASCII
Write-Host ("Dock mode saved: " + $Mode)
