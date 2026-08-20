$ErrorActionPreference = "Stop"

$projectFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$pathsHelper = Join-Path (Split-Path -Parent (Split-Path -Parent $projectFolder)) "lib\ObsidianGlass.Paths.ps1"
if (Test-Path -LiteralPath $pathsHelper -PathType Leaf) { . $pathsHelper }
$dockFolder = Get-ObsidianGlassDockRoot
if ([string]::IsNullOrWhiteSpace($dockFolder)) { throw "MyDockFinder was not found. Set OBSIDIAN_GLASS_DOCK_ROOT first." }
$backupRoot = Join-Path (Join-Path $env:LOCALAPPDATA 'ObsidianGlassDesktop') 'backups'
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupFolder = "$backupRoot\wechat-preview-$stamp"
$pointerFile = "$backupRoot\latest-wechat-preview.txt"
$configFiles = @("$dockFolder\ico.ini", "$dockFolder\ico_bak.ini")
$shortcutPath = Get-ChildItem -LiteralPath ([Environment]::GetFolderPath('CommonStartMenu')) -Filter '微信.lnk' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1 | ForEach-Object { $_.FullName }
$encoding = [System.Text.Encoding]::Unicode

New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null
if (Test-Path -LiteralPath $shortcutPath) {
    Copy-Item -LiteralPath $shortcutPath -Destination $backupFolder -Force
}

foreach ($configFile in $configFiles) {
    if (-not (Test-Path -LiteralPath $configFile)) {
        throw "Dock configuration not found: $configFile"
    }

    Copy-Item -LiteralPath $configFile -Destination $backupFolder -Force
    $content = [System.IO.File]::ReadAllText($configFile, $encoding)
    $start = $content.IndexOf("[ico4]")
    $end = $content.IndexOf("[ico5]", $start)

    if ($start -lt 0 -or $end -le $start) {
        throw "WeChat Dock entry was not found in: $configFile"
    }

    $entry = $content.Substring($start, $end - $start)
    $wechatExe = Get-ChildItem -Path (Join-Path ${env:ProgramFiles} 'Tencent\Weixin'), (Join-Path ${env:ProgramFiles(x86)} 'Tencent\Weixin') -Filter 'Weixin.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 1 | ForEach-Object { $_.FullName }
    if ([string]::IsNullOrWhiteSpace($wechatExe)) { throw "Weixin.exe was not found." }
    $shortcutValue = if ([string]::IsNullOrWhiteSpace($shortcutPath)) { '' } else { $shortcutPath.ToLowerInvariant() }
    $entry = "[ico4]`r`n" +
        "tag=微信`r`n" +
        "appname=微信.lnk`r`n" +
        "filepath=" + $shortcutValue + "`r`n" +
        "realpath=" + $wechatExe.ToLowerInvariant() + "`r`n"
    $content = $content.Substring(0, $start) + $entry + $content.Substring($end)
    [System.IO.File]::WriteAllText($configFile, $content, $encoding)
}

[System.IO.File]::WriteAllText($pointerFile, $backupFolder, [System.Text.Encoding]::UTF8)
& "$projectFolder\start_wechat_preview_guard.ps1"
Write-Host "WeChat Dock process mapping repaired."
Write-Host "Backup: $backupFolder"
