[CmdletBinding()]
param(
    [string[]]$Roots = @(),
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $packageRoot 'assets\manifest.local.json'
}
$items = @()

foreach ($root in @($Roots)) {
    if (!(Test-Path -LiteralPath $root -PathType Container)) {
        Write-Warning ("Asset root not found: " + $root)
        continue
    }

    $resolvedRoot = (Resolve-Path -LiteralPath $root).Path
    foreach ($file in Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File) {
        $relative = $file.FullName.Substring($resolvedRoot.Length).TrimStart('\', '/')
        $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $items += [ordered]@{
            relativePath = $relative
            sizeBytes = $file.Length
            sha256 = $hash
            review = 'confirm-license-before-publish'
        }
    }
}

$manifest = [ordered]@{
    schemaVersion = 1
    generatedAt = (Get-Date).ToString('o')
    policy = 'metadata-only-local-inventory'
    items = $items
}

$parent = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $parent -Force | Out-Null
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host ("Wrote asset manifest: " + $OutputPath)
