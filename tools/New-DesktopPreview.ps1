[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,80}$')]
    [string]$Name = 'desktop-preview',
    [ValidateSet('Primary', 'VirtualDesktop')]
    [string]$CaptureArea = 'Primary',
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $packageRoot = Split-Path -Parent $PSScriptRoot
    $OutputDirectory = Join-Path $packageRoot 'assets\screenshots'
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if ($CaptureArea -eq 'VirtualDesktop') {
    $bounds = [System.Windows.Forms.SystemInformation]::VirtualScreen
}
else {
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$destination = Join-Path $OutputDirectory ($Name + '-' + $stamp + '.png')
$bitmap = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)

try {
    $graphics.CopyFromScreen($bounds.Left, $bounds.Top, 0, 0, $bitmap.Size)
    $bitmap.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $graphics.Dispose()
    $bitmap.Dispose()
}

$file = Get-Item -LiteralPath $destination
[pscustomobject]@{
    Path = $file.FullName
    Width = $bounds.Width
    Height = $bounds.Height
    Bytes = $file.Length
    CaptureArea = $CaptureArea
} | Format-List
