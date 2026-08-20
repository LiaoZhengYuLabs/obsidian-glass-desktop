[CmdletBinding()]
param(
    [string]$ConfigPath,
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'
$packageRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $packageRoot 'config\obsidian-glass.example.json'
}

& (Join-Path $packageRoot 'src\Get-StartupStatus.ps1') -ConfigPath $ConfigPath -AsJson:$AsJson
