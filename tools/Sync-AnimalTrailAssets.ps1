[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$SourceRoot,
    [switch]$IncludeAllCatalogAssets,
    [switch]$DownloadFromPetdex,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$packageRoot = Split-Path -Parent $PSScriptRoot
$wallpaperRoot = Join-Path $packageRoot 'src\components\wallpaper'
$animalRoot = Join-Path $wallpaperRoot 'animal-trail'
$heroNames = @('byte-bunny', 'silver-shorthair', 'prompt-penguin', 'fine-pup', 'little-deer', 'nightly-fox', 'cloudy', 'peri-the-owl')

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = $env:OBSIDIAN_GLASS_ANIMAL_SOURCE
}
if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Join-Path $packageRoot '..\..\AnimalTrailSystem\deploy\wallpaper\animal-trail'
}
if (Test-Path -LiteralPath $SourceRoot -PathType Container) {
    $SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
}

function Copy-RequiredFile {
    param([string]$RelativePath)
    $from = Join-Path $SourceRoot $RelativePath
    $to = Join-Path $animalRoot $RelativePath
    if (-not (Test-Path -LiteralPath $from -PathType Leaf)) {
        throw "Required animal-trail file was not found: $from"
    }
    $parent = Split-Path -Parent $to
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    Copy-Item -LiteralPath $from -Destination $to -Force
}

if (Test-Path -LiteralPath $SourceRoot -PathType Container) {
    foreach ($file in @('animal-trail.js', 'catalog\creatures.js', 'catalog\creatures.json', 'catalog\sync-report.json')) {
        Copy-RequiredFile -RelativePath $file
    }

    foreach ($hero in $heroNames) {
        $from = Join-Path $SourceRoot ('assets\' + $hero)
        $to = Join-Path $animalRoot ('assets\' + $hero)
        if (-not (Test-Path -LiteralPath $from -PathType Container)) {
            throw "Starter animal asset was not found: $from"
        }
        New-Item -ItemType Directory -Path $to -Force | Out-Null
        Copy-Item -LiteralPath $from -Destination $to -Recurse -Force
    }
    Write-Host 'Animal-trail engine, catalogue, and starter sprites synchronized from the local cache.' -ForegroundColor Green
}
elseif (-not $DownloadFromPetdex) {
    throw "Animal-trail source cache was not found: $SourceRoot. Set -SourceRoot or OBSIDIAN_GLASS_ANIMAL_SOURCE."
}

if ($IncludeAllCatalogAssets -and -not $Force) {
    throw 'The full catalogue cache is about 3 GB. Re-run with -IncludeAllCatalogAssets -Force after checking disk space and asset rights.'
}

if ($IncludeAllCatalogAssets -and (Test-Path -LiteralPath (Join-Path $SourceRoot 'catalog\assets') -PathType Container)) {
    $catalogSource = Join-Path $SourceRoot 'catalog\assets'
    $catalogTarget = Join-Path $animalRoot 'catalog\assets'
    New-Item -ItemType Directory -Path $catalogTarget -Force | Out-Null
    Copy-Item -LiteralPath $catalogSource -Destination $catalogTarget -Recurse -Force
    Write-Host 'Full local catalogue sprite cache synchronized.' -ForegroundColor Yellow
}

if ($DownloadFromPetdex) {
    $manifestPath = Join-Path $animalRoot 'catalog\creatures.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        $manifest = Invoke-RestMethod -Uri 'https://petdex.dev/api/manifest' -Method Get
        $manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    }
    $manifestItems = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $manifestItems = @($manifestItems)
    if ($IncludeAllCatalogAssets) {
        $itemsToDownload = $manifestItems
        $catalogTarget = Join-Path $animalRoot 'catalog\assets'
        New-Item -ItemType Directory -Path $catalogTarget -Force | Out-Null
    } else {
        $itemsToDownload = @($manifestItems | Where-Object { $heroNames -contains ([string]$_.slug) })
    }
    $downloaded = 0
    foreach ($item in $itemsToDownload) {
        $url = [string]$item.spritesheetUrl
        $slug = [string]$item.slug
        if ([string]::IsNullOrWhiteSpace($url) -or [string]::IsNullOrWhiteSpace($slug)) { continue }
        if ($heroNames -contains $slug) {
            $starterTarget = Join-Path $animalRoot ('assets\' + $slug)
            New-Item -ItemType Directory -Path $starterTarget -Force | Out-Null
            $target = Join-Path $starterTarget 'spritesheet.webp'
        } else {
            $target = Join-Path $catalogTarget ($slug + '.webp')
        }
        if (Test-Path -LiteralPath $target -PathType Leaf) { continue }
        if ($PSCmdlet.ShouldProcess($target, 'Download Petdex sprite')) {
            Invoke-WebRequest -Uri $url -OutFile $target -UseBasicParsing
            $downloaded++
        }
    }
    if ($IncludeAllCatalogAssets) {
        Write-Host ("Downloaded {0} catalogue sprites from Petdex." -f $downloaded) -ForegroundColor Yellow
    } else {
        Write-Host ("Downloaded {0} starter sprites from Petdex into the local cache." -f $downloaded) -ForegroundColor Yellow
    }
}

$files = Get-ChildItem -LiteralPath $animalRoot -File -Recurse -ErrorAction SilentlyContinue
[pscustomobject]@{
    Root = $animalRoot
    Files = $files.Count
    Bytes = [int64](($files | Measure-Object -Property Length -Sum).Sum)
    StarterAnimals = $heroNames.Count
    FullCatalogRequested = $IncludeAllCatalogAssets.IsPresent
} | Format-List
