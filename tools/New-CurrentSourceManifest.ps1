[CmdletBinding()]
param(
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $packageRoot 'docs\current-source-manifest.json'
}

$outputFullPath = [IO.Path]::GetFullPath($OutputPath)
$excludedPatterns = @(
    '\\.git\\',
    '\\logs\\',
    '\\backups\\',
    '\\state\\',
    '\\catalog\\assets\\',
    '\\.edge-space-goal-profile',
    '\\speech-runtime\\',
    '\\WebView2Data\\',
    '\\__pycache__\\',
    '\\assets\\icons\\',
    '\\src\\components\\dashboard\\mode-deck-reference\.jpg$',
    '\\src\\components\\wallpaper\\space-environment-live\.png(\.jpg)?$',
    '\\src\\components\\wallpaper\\space-environment-test\.png$'
)

$files = Get-ChildItem -LiteralPath $packageRoot -Recurse -File | Where-Object {
    $full = $_.FullName
    ($full -ne $outputFullPath) -and (($excludedPatterns | Where-Object { $full -match $_ }).Count -eq 0)
}

$entries = @()
$totalBytes = [int64]0
foreach ($file in $files) {
    $relative = $file.FullName.Substring($packageRoot.Length + 1).Replace([IO.Path]::DirectorySeparatorChar, '/')
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $entries += [ordered]@{
        path = $relative
        bytes = [int64]$file.Length
        sha256 = $hash
    }
    $totalBytes += [int64]$file.Length
}

$manifest = [ordered]@{
    schemaVersion = 1
    package = 'Obsidian Glass Desktop'
    snapshotDate = '2026-08-21'
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    fileCount = $entries.Count
    totalBytes = $totalBytes
    excluded = @('runtime state', 'logs', 'backups', 'speech models', 'browser/WebView data', 'full Petdex sprite cache', 'the manifest itself')
    files = $entries
}

$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $outputFullPath -Encoding UTF8
Write-Host ('Manifest written: ' + $outputFullPath)
Write-Host ('Files: ' + $entries.Count + '; bytes: ' + $totalBytes)
