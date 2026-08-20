$ErrorActionPreference = 'Stop'

$dockRoot = 'C:\Program Files (x86)\Steam\steamapps\common\MyDockFinder'
$dockConfig = "$dockRoot\ico.ini"
$launcherRoot = "$env:USERPROFILE\AppShortcuts\DockLaunchers"
$backupPath = "$dockConfig.before-x-github-pin"
$dockExe = "$dockRoot\Mydock.exe"

if (-not (Test-Path -LiteralPath $dockConfig)) {
    throw "未找到 MyDockFinder 配置: $dockConfig"
}

Get-CimInstance Win32_Process -Filter "Name = 'Dock_64.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.ExecutablePath -like "$dockRoot*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 500

New-Item -ItemType Directory -Force -Path $launcherRoot | Out-Null
$shell = New-Object -ComObject WScript.Shell

function New-WebDockShortcut {
    param(
        [string]$Name,
        [string]$Url
    )

    $path = "$launcherRoot\$Name.lnk"
    $shortcut = $shell.CreateShortcut($path)
    $shortcut.TargetPath = "$env:WINDIR\explorer.exe"
    $shortcut.Arguments = $Url
    $shortcut.WorkingDirectory = $env:USERPROFILE
    $shortcut.IconLocation = "$env:WINDIR\System32\url.dll,0"
    $shortcut.Description = $Name
    $shortcut.Save()
    return $path
}

$xShortcut = New-WebDockShortcut -Name 'X' -Url 'https://x.com/'
$githubShortcut = New-WebDockShortcut -Name 'GitHub' -Url 'https://github.com/'

if (-not (Test-Path -LiteralPath $backupPath)) {
    Copy-Item -LiteralPath $dockConfig -Destination $backupPath -Force
}

$content = [IO.File]::ReadAllText($dockConfig)
$entries = New-Object System.Collections.Generic.List[object]
if ($content -notmatch '(?m)^tag=X\r?$') {
    $entries.Add([pscustomobject]@{ Tag = 'X'; Shortcut = $xShortcut })
}
if ($content -notmatch '(?m)^tag=GitHub\r?$') {
    $entries.Add([pscustomobject]@{ Tag = 'GitHub'; Shortcut = $githubShortcut })
}

if ($entries.Count -gt 0) {
    $divider = [regex]::Match($content, '(?m)^\[ico(\d+)\]\r?\ndelimiter=1\r?$')
    if (-not $divider.Success) {
        throw '未找到 Dock 固定区与文件区之间的分隔线。'
    }

    $dividerNumber = [int]$divider.Groups[1].Value
    $shiftBy = $entries.Count
    $content = [regex]::Replace($content, '(?m)^\[ico(\d+)\]\r?$', {
        param($match)
        $number = [int]$match.Groups[1].Value
        if ($number -ge $dividerNumber) { return "[ico$($number + $shiftBy)]" }
        return $match.Value
    })

    $replacement = ''
    $index = $dividerNumber
    foreach ($entry in $entries) {
        $replacement += "[ico$index]`r`ntag=$($entry.Tag)`r`nappname=$($entry.Tag).lnk`r`nfilepath=$($entry.Shortcut)`r`nrealpath=$env:WINDIR\explorer.exe`r`n"
        $index++
    }
    $replacement += "[ico$index]`r`ndelimiter=1"

    $oldDivider = "(?m)^\[ico$($dividerNumber + $shiftBy)\]\r?\ndelimiter=1\r?$"
    $content = [regex]::Replace($content, $oldDivider, $replacement, 1)
    [IO.File]::WriteAllText($dockConfig, $content, [Text.Encoding]::Unicode)
}

Start-Process -FilePath $dockExe
Write-Host 'X 和 GitHub 已固定到 MyDockFinder。'
