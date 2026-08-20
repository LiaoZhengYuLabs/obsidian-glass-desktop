$ErrorActionPreference = "Stop"

$projectFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$pathsHelper = Join-Path (Split-Path -Parent (Split-Path -Parent $projectFolder)) "lib\ObsidianGlass.Paths.ps1"
if (Test-Path -LiteralPath $pathsHelper -PathType Leaf) { . $pathsHelper }
$dockFolder = Get-ObsidianGlassDockRoot
if ([string]::IsNullOrWhiteSpace($dockFolder)) { throw "MyDockFinder was not found." }
$backupRoot = "$projectFolder\backups"
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupFolder = "$backupRoot\wechat-preview-$stamp"
$pointerFile = "$backupRoot\latest-wechat-preview.txt"
$configFiles = @("$dockFolder\ico.ini", "$dockFolder\ico_bak.ini")
$shortcutPath = Get-ChildItem -LiteralPath ([Environment]::GetFolderPath("CommonStartMenu")) -Filter "微信.lnk" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
$encoding = [System.Text.Encoding]::Unicode

New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null
if (![string]::IsNullOrWhiteSpace($shortcutPath) -and (Test-Path -LiteralPath $shortcutPath)) {
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
    if ($entry -notmatch "(?im)^realpath=c:\\program files\\tencent\\weixin\\weixin\.exe\s*$") {
        throw "The ico4 entry does not point to Weixin.exe: $configFile"
    }

    $entry = "[ico4]`r`n" +
        "tag=微信`r`n" +
        "appname=微信.lnk`r`n" +
        ("filepath=" + $shortcutPath + "`r`n") +
        "realpath=c:\program files\tencent\weixin\weixin.exe`r`n"
    $content = $content.Substring(0, $start) + $entry + $content.Substring($end)
    [System.IO.File]::WriteAllText($configFile, $content, $encoding)
}

[System.IO.File]::WriteAllText($pointerFile, $backupFolder, [System.Text.Encoding]::UTF8)
& "$projectFolder\start_wechat_preview_guard.ps1"
Write-Host "WeChat Dock process mapping repaired."
Write-Host "Backup: $backupFolder"
