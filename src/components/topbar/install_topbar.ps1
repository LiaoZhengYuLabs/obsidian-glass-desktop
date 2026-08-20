$ErrorActionPreference = 'Stop'

$sourceRoot = Split-Path -Parent $PSCommandPath
$stateRoot = "$env:LOCALAPPDATA\ObsidianDesktopTopbar"
$startupRoot = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$dockConfig = 'C:\Program Files (x86)\Steam\steamapps\common\MyDockFinder\config.ini'
$csc = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$exePath = "$stateRoot\ObsidianDesktopTopbar.exe"
$startupFile = "$startupRoot\ObsidianDesktopTopbar.vbs"

New-Item -ItemType Directory -Force -Path $stateRoot | Out-Null
Get-Process -Name ObsidianDesktopTopbar -ErrorAction SilentlyContinue | Stop-Process -Force

if (-not (Test-Path -LiteralPath $csc)) {
    throw "未找到 Windows .NET 编译器: $csc"
}

& $csc /nologo /target:winexe /optimize+ /out:$exePath /r:System.Windows.Forms.dll /r:System.Drawing.dll "$sourceRoot\DesktopTopbar.cs"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exePath)) {
    throw '顶部栏编译失败。'
}

if (Test-Path -LiteralPath $dockConfig) {
    $backup = "$stateRoot\mydockfinder-config.before-obsidian-topbar.ini"
    if (-not (Test-Path -LiteralPath $backup)) {
        Copy-Item -LiteralPath $dockConfig -Destination $backup -Force
    }
    $content = [IO.File]::ReadAllText($dockConfig)
    $updated = $content -replace '(?im)^myfinder\s*=\s*[01]\s*$', 'myfinder=0'
    $updated = $updated -replace '(?im)^findermenu\s*=\s*[01]\s*$', 'findermenu=0'
    $updated = $updated -replace '(?im)^wifi\s*=\s*\d+\s*$', 'wifi=0'
    $updated = $updated -replace '(?im)^battery\s*=\s*\d+\s*$', 'battery=0'
    $updated = $updated -replace '(?im)^systemtime\s*=\s*\d+\s*$', 'systemtime=0'
    if ($updated -ne $content) {
        [IO.File]::WriteAllText($dockConfig, $updated, [Text.Encoding]::Default)
    }
}

Copy-Item -LiteralPath "$sourceRoot\ObsidianDesktopTopbar.vbs" -Destination $startupFile -Force

# MyFinder reads its setting on launch. Restart only MyDockFinder, leaving other software untouched.
$dockRoot = 'C:\Program Files (x86)\Steam\steamapps\common\MyDockFinder'
$dockExe = "$dockRoot\Mydock.exe"
if (Test-Path -LiteralPath $dockExe) {
    Get-CimInstance Win32_Process -Filter "Name = 'Dock_64.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.ExecutablePath -like "$dockRoot*" } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Milliseconds 500
    Start-Process -FilePath $dockExe
}

Start-Sleep -Milliseconds 400
Start-Process -FilePath $exePath

Write-Host 'Obsidian Glass 顶部栏已启动并已加入当前用户开机启动。'
