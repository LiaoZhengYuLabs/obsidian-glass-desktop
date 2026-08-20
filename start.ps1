[CmdletBinding()]
param(
    [string]$ConfigPath,
    [switch]$VerifyOnly
)

$ErrorActionPreference = 'Stop'
$packageRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $packageRoot 'config\obsidian-glass.example.json'
}

& (Join-Path $packageRoot 'src\Start-DesktopSession.ps1') -ConfigPath $ConfigPath -VerifyOnly:$VerifyOnly
