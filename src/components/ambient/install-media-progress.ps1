$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$runtimeRoot = "$env:LOCALAPPDATA\ObsidianDockMediaProgress"
$startupRoot = [Environment]::GetFolderPath('Startup')
$shortcutPath = "$startupRoot\Obsidian Dock Media Progress.lnk"
$pathsHelper = Join-Path (Split-Path -Parent (Split-Path -Parent $projectRoot)) "lib\ObsidianGlass.Paths.ps1"
if (Test-Path -LiteralPath $pathsHelper -PathType Leaf) { . $pathsHelper }
$backupRoot = Join-Path (Join-Path $env:LOCALAPPDATA 'ObsidianGlassDesktop') ('media-progress-backups\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$statePath = Join-Path (Join-Path $env:LOCALAPPDATA 'ObsidianGlassDesktop') 'media-progress-state.json'

New-Item -ItemType Directory -Force -Path $runtimeRoot, $backupRoot | Out-Null

$compiler = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$runtimeWinRt = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\System.Runtime.WindowsRuntime.dll"

if (-not (Test-Path -LiteralPath $compiler)) { throw '未找到 .NET Framework C# 编译器。' }
if (-not (Test-Path -LiteralPath $runtimeWinRt)) { throw '未找到 Windows Runtime 支持库。' }

$exePath = "$runtimeRoot\DockMediaProgress.exe"
$sourcePath = "$projectRoot\DockMediaProgress.cs"
$references = @(
    '/reference:System.dll',
    '/reference:System.Core.dll',
    '/reference:System.Drawing.dll',
    '/reference:System.Windows.Forms.dll',
    ('/reference:"' + $runtimeWinRt + '"')
)

$compileOutput = & $compiler /nologo /target:winexe /platform:anycpu /optimize+ /out:"$exePath" $references $sourcePath 2>&1
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exePath)) {
    $compileOutput | Set-Content -LiteralPath "$backupRoot\compile-error.txt" -Encoding UTF8
    throw "Dock 媒体进度条编译失败：$($compileOutput -join ' ')"
}

Copy-Item -LiteralPath "$projectRoot\DockMediaProgressLauncher.vbs" -Destination "$runtimeRoot\DockMediaProgressLauncher.vbs" -Force

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "$env:WINDIR\System32\wscript.exe"
$shortcut.Arguments = '"' + "$runtimeRoot\DockMediaProgressLauncher.vbs" + '"'
$shortcut.WorkingDirectory = $runtimeRoot
$shortcut.Description = '底部 Dock 当前媒体播放进度'
$shortcut.Save()

$state = [ordered]@{
    installedAt = (Get-Date).ToString('o')
    runtimeRoot = $runtimeRoot
    shortcutPath = $shortcutPath
    backupRoot = $backupRoot
}
$state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $statePath -Encoding UTF8

Get-Process DockMediaProgress -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Process -FilePath $exePath -WindowStyle Hidden

Write-Output 'Dock 媒体进度条已安装。'
Write-Output '未修改 Docker、系统设置或其他应用的开机自启。'
