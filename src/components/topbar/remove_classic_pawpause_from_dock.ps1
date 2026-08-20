$ErrorActionPreference = 'Stop'

$dockRoot = 'C:\Program Files (x86)\Steam\steamapps\common\MyDockFinder'
$dockConfig = "$dockRoot\ico.ini"
$backupPath = "$dockConfig.before-remove-classic-pawpause"
$dockExe = "$dockRoot\Mydock.exe"

if (-not (Test-Path -LiteralPath $dockConfig)) {
    throw "未找到 MyDockFinder 配置: $dockConfig"
}

Get-CimInstance Win32_Process -Filter "Name = 'Dock_64.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.ExecutablePath -like "$dockRoot*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 500

if (-not (Test-Path -LiteralPath $backupPath)) {
    Copy-Item -LiteralPath $dockConfig -Destination $backupPath -Force
}

$content = [IO.File]::ReadAllText($dockConfig)
$matches = [regex]::Matches($content, '(?ms)^\[ico\d+\]\r?\n(.*?)(?=^\[ico\d+\]\r?\n|\z)')
$keptBodies = New-Object System.Collections.Generic.List[string]
$removed = New-Object System.Collections.Generic.List[string]

foreach ($match in $matches) {
    $body = $match.Groups[1].Value
    $tag = [regex]::Match($body, '(?m)^tag=(.+)\r?$').Groups[1].Value.Trim()
    if ($tag -eq 'ChatGPT Classic' -or $tag -eq 'PawPause') {
        $removed.Add($tag)
        continue
    }
    $keptBodies.Add($body.TrimEnd("`r", "`n"))
}

if ($removed.Count -gt 0) {
    $newContent = ''
    $index = 1
    foreach ($body in $keptBodies) {
        $newContent += "[ico$index]`r`n$body`r`n"
        $index++
    }
    [IO.File]::WriteAllText($dockConfig, $newContent, [Text.Encoding]::Unicode)
}

Start-Process -FilePath $dockExe
Write-Host "已从 Dock 移除: $($removed -join '、')"
