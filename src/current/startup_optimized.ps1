param([switch]$VerifyOnly)

$ErrorActionPreference = 'SilentlyContinue'
$packageRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$stateRoot = Join-Path $env:LOCALAPPDATA 'ObsidianGlassDesktop\startup'
$logRoot = Join-Path $stateRoot 'logs'
$logPath = Join-Path $logRoot 'startup.log'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

function Write-StartupLog {
    param([string]$Message)
    Add-Content -LiteralPath $logPath -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '  ' + $Message) -Encoding UTF8
}

function Get-ComponentPath {
    param([string]$RelativePath)
    return Join-Path $packageRoot ('src\components\' + $RelativePath)
}

function Find-DockRoot {
    $helper = Join-Path $packageRoot 'src\lib\ObsidianGlass.Paths.ps1'
    if (Test-Path -LiteralPath $helper -PathType Leaf) {
        . $helper
        return Get-ObsidianGlassDockRoot
    }
    return $null
}

function Start-HiddenScript {
    param([string]$Path, [string]$Label, [string]$ExtraArguments)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-StartupLog ($Label + ' missing: ' + $Path)
        return $false
    }
    $args = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $Path + '"'
    if (![string]::IsNullOrWhiteSpace($ExtraArguments)) { $args += ' ' + $ExtraArguments }
    Start-Process -FilePath "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $args -WorkingDirectory (Split-Path -Parent $Path) -WindowStyle Hidden
    Write-StartupLog ($Label + ' requested.')
    return $true
}

function Start-OptionalProgram {
    param([string]$ProcessName, [string]$Path, [string]$Arguments, [string]$Label)
    if (Get-Process -Name $ProcessName -ErrorAction SilentlyContinue) { return $true }
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-StartupLog ($Label + ' unavailable: ' + $Path)
        return $false
    }
    if ([string]::IsNullOrWhiteSpace($Arguments)) {
        Start-Process -FilePath $Path -WindowStyle Hidden
    } else {
        Start-Process -FilePath $Path -ArgumentList $Arguments -WindowStyle Hidden
    }
    Write-StartupLog ($Label + ' started.')
    return $true
}

$createdNew = $false
$mutex = New-Object Threading.Mutex($true, 'Local\ObsidianGlassDesktop.CurrentStartup', [ref]$createdNew)
if (!$createdNew) { exit 0 }

try {
    if ($VerifyOnly) {
        $checks = @(
            [pscustomobject]@{ Name = 'Dashboard'; Path = (Get-ComponentPath 'dashboard\start.ps1') },
            [pscustomobject]@{ Name = 'Sidebar'; Path = (Get-ComponentPath 'sidebar\start.ps1') },
            [pscustomobject]@{ Name = 'Dock'; Path = (Get-ComponentPath 'dock\start.ps1') },
            [pscustomobject]@{ Name = 'Dock visibility'; Path = (Get-ComponentPath 'ambient\start.ps1') }
        )
        $checks | ForEach-Object {
            [pscustomobject]@{ Name = $_.Name; Exists = (Test-Path -LiteralPath $_.Path -PathType Leaf); Path = $_.Path }
        } | Format-Table -AutoSize
        $dockRoot = Find-DockRoot
        Write-Host ('MyDockFinder: ' + $(if ($dockRoot) { $dockRoot } else { 'not detected' }))
        Write-Host ('Lively Wallpaper package: ' + $(if (Get-AppxPackage -Name '12030rocksdanister.LivelyWallpaper' -ErrorAction SilentlyContinue) { 'detected' } else { 'not detected' }))
        exit 0
    }

    Write-StartupLog 'Current desktop startup sequence began.'
    $dockRoot = Find-DockRoot
    if ($dockRoot) {
        Start-OptionalProgram -ProcessName 'Dock_64' -Path (Join-Path $dockRoot 'Dock_64.exe') -Arguments '' -Label 'MyDockFinder' | Out-Null
    }

    Start-HiddenScript -Path (Get-ComponentPath 'dashboard\start.ps1') -Label 'Dashboard' -ExtraArguments '-NoStartup' | Out-Null
    Start-Sleep -Milliseconds 250
    Start-HiddenScript -Path (Get-ComponentPath 'sidebar\start.ps1') -Label 'Left Stage rail' -ExtraArguments '-NoStartup' | Out-Null
    Start-Sleep -Milliseconds 250
    Start-HiddenScript -Path (Get-ComponentPath 'dock\start.ps1') -Label 'Obsidian Dock' -ExtraArguments '-NoStartup' | Out-Null
    Start-Sleep -Milliseconds 250
    Start-HiddenScript -Path (Get-ComponentPath 'ambient\start.ps1') -Label 'Ambient visibility' | Out-Null

    if (!(Get-Process -Name 'Lively' -ErrorAction SilentlyContinue) -and (Get-AppxPackage -Name '12030rocksdanister.LivelyWallpaper' -ErrorAction SilentlyContinue)) {
        Start-Process -FilePath 'explorer.exe' -ArgumentList 'shell:AppsFolder\12030rocksdanister.LivelyWallpaper_97hta09mmv6hy!App' -WindowStyle Hidden
        Write-StartupLog 'Lively Wallpaper launch requested.'
    }

    $rainmeter = Join-Path ${env:ProgramFiles} 'Rainmeter\Rainmeter.exe'
    if (Test-Path -LiteralPath $rainmeter -PathType Leaf) {
        Start-OptionalProgram -ProcessName 'Rainmeter' -Path $rainmeter -Arguments '' -Label 'Rainmeter' | Out-Null
    }

    Write-StartupLog 'Current desktop startup sequence completed.'
} finally {
    if ($createdNew) { try { $mutex.ReleaseMutex() } catch {} }
    $mutex.Dispose()
}
