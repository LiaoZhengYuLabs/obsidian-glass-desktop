param(
    [Parameter(Mandatory = $true)]
    [string]$XSource,
    [Parameter(Mandatory = $true)]
    [string]$GitHubSource,
    [string]$DockRoot
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($DockRoot)) {
    $pathsHelper = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'lib\ObsidianGlass.Paths.ps1'
    if (Test-Path -LiteralPath $pathsHelper -PathType Leaf) {
        . $pathsHelper
        $DockRoot = Get-ObsidianGlassDockRoot
    }
}
if ([string]::IsNullOrWhiteSpace($DockRoot)) {
    throw 'MyDockFinder was not found. Pass -DockRoot explicitly.'
}

$launcherRoot = Join-Path $env:USERPROFILE 'AppShortcuts\DockLaunchers'
$cachePath = Join-Path $DockRoot 'cache.ico'
$dockExe = Join-Path $DockRoot 'Mydock.exe'
Add-Type -AssemblyName System.Drawing

function Convert-ArtToIcon {
    param([string]$Source, [string]$Destination)

    if (!(Test-Path -LiteralPath $Source -PathType Leaf)) {
        throw "Icon image not found: $Source"
    }

    $image = [System.Drawing.Image]::FromFile($Source)
    $side = [Math]::Min($image.Width, $image.Height)
    $sourceX = [int](($image.Width - $side) / 2)
    $sourceY = [int](($image.Height - $side) / 2)
    $bitmap = New-Object System.Drawing.Bitmap 256, 256, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.DrawImage($image, (New-Object System.Drawing.Rectangle 0, 0, 256, 256), $sourceX, $sourceY, $side, $side, [System.Drawing.GraphicsUnit]::Pixel)

        $pngStream = New-Object System.IO.MemoryStream
        $bitmap.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png)
        $pngBytes = $pngStream.ToArray()
        $fileStream = [System.IO.File]::Open($Destination, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $writer = New-Object System.IO.BinaryWriter($fileStream)
        try {
            $writer.Write([uint16]0)
            $writer.Write([uint16]1)
            $writer.Write([uint16]1)
            $writer.Write([byte]0)
            $writer.Write([byte]0)
            $writer.Write([byte]0)
            $writer.Write([byte]0)
            $writer.Write([uint16]1)
            $writer.Write([uint16]32)
            $writer.Write([uint32]$pngBytes.Length)
            $writer.Write([uint32]22)
            $writer.Write($pngBytes)
        } finally {
            $writer.Dispose()
            $pngStream.Dispose()
        }
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
        $image.Dispose()
    }
}

New-Item -ItemType Directory -Force -Path $launcherRoot | Out-Null
$xIcon = Join-Path $launcherRoot 'X.ico'
$githubIcon = Join-Path $launcherRoot 'GitHub.ico'
Convert-ArtToIcon -Source $XSource -Destination $xIcon
Convert-ArtToIcon -Source $GitHubSource -Destination $githubIcon

$shell = New-Object -ComObject WScript.Shell
foreach ($item in @(
    [pscustomobject]@{ Name = 'X'; Icon = $xIcon },
    [pscustomobject]@{ Name = 'GitHub'; Icon = $githubIcon }
)) {
    $shortcutPath = Join-Path $launcherRoot ($item.Name + '.lnk')
    if (!(Test-Path -LiteralPath $shortcutPath -PathType Leaf)) {
        throw "Dock shortcut not found: $shortcutPath"
    }
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.IconLocation = $item.Icon + ',0'
    $shortcut.Save()
}

Get-CimInstance Win32_Process -Filter "Name = 'Dock_64.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.ExecutablePath -like ($DockRoot + '*') } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 500
if (Test-Path -LiteralPath $cachePath -PathType Leaf) {
    Move-Item -LiteralPath $cachePath -Destination ($cachePath + '.before-art-icons') -Force
}
if (Test-Path -LiteralPath $dockExe -PathType Leaf) {
    Start-Process -FilePath $dockExe
}

Write-Host 'X and GitHub icon assets were applied.' -ForegroundColor Green
