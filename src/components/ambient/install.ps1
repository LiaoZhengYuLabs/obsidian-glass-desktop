$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$runtimeRoot = "$env:LOCALAPPDATA\ObsidianDockMediaProgress"
$startupRoot = [Environment]::GetFolderPath('Startup')
$shortcutPath = "$startupRoot\Obsidian Dock Media Progress.lnk"
$dockRoot = 'C:\Program Files (x86)\Steam\steamapps\common\MyDockFinder'
$backupRoot = "$projectRoot\backups\$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$statePath = "$projectRoot\install-state.json"

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

$dockerSettings = "$env:APPDATA\Docker\settings-store.json"
$dockerBackup = $null
if (Test-Path -LiteralPath $dockerSettings) {
    $dockerBackup = "$backupRoot\docker-settings-store.json"
    Copy-Item -LiteralPath $dockerSettings -Destination $dockerBackup -Force
    $settings = Get-Content -LiteralPath $dockerSettings -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($settings.PSObject.Properties.Name -contains 'AutoStart') { $settings.AutoStart = $false }
    else { $settings | Add-Member -NotePropertyName AutoStart -NotePropertyValue $false }
    $dockerJson = $settings | ConvertTo-Json -Depth 20
    [IO.File]::WriteAllText($dockerSettings, $dockerJson, (New-Object Text.UTF8Encoding($false)))
}

$startupApprovedKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
$startupApprovedBackup = $null
if (Test-Path -LiteralPath $startupApprovedKey) {
    $current = (Get-ItemProperty -LiteralPath $startupApprovedKey -Name 'Docker Desktop' -ErrorAction SilentlyContinue).'Docker Desktop'
    if ($null -ne $current) {
        $startupApprovedBackup = [Convert]::ToBase64String([byte[]]$current)
        $disabled = New-Object byte[] 12
        $disabled[0] = 3
        $timeBytes = [BitConverter]::GetBytes([DateTime]::Now.ToFileTime())
        [Array]::Copy($timeBytes, 0, $disabled, 4, 8)
        Set-ItemProperty -LiteralPath $startupApprovedKey -Name 'Docker Desktop' -Value $disabled -Type Binary
    }
}

$state = [ordered]@{
    installedAt = (Get-Date).ToString('o')
    runtimeRoot = $runtimeRoot
    shortcutPath = $shortcutPath
    dockerSettings = $dockerSettings
    dockerBackup = $dockerBackup
    dockerStartupApprovedBackup = $startupApprovedBackup
    backupRoot = $backupRoot
}
$state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $statePath -Encoding UTF8

Get-Process DockMediaProgress -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Process -FilePath $exePath -ArgumentList ('"' + $dockRoot + '"') -WindowStyle Hidden

Write-Output 'Dock 媒体进度条已安装。'
Write-Output 'Docker Desktop 开机自启已关闭；当前 Docker 进程未被结束。'
