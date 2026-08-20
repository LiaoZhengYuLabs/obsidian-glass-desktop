[CmdletBinding()]
param(
    [ValidateSet('Primary','VirtualDesktop')]
    [string]$CaptureArea = 'Primary',
    [string]$Name = 'obsidian-glass-desktop'
)

$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'tools\New-DesktopPreview.ps1') -Name $Name -CaptureArea $CaptureArea
