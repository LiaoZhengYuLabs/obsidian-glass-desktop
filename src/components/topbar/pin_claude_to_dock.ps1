$ErrorActionPreference = 'Stop'

$dockRoot = 'C:\Program Files (x86)\Steam\steamapps\common\MyDockFinder'
$dockConfig = "$dockRoot\ico.ini"
$launcherRoot = "$env:USERPROFILE\AppShortcuts\DockLaunchers"
$shortcutPath = "$launcherRoot\Claude.lnk"
$claudePath = "$env:LOCALAPPDATA\AnthropicClaude\Claude.exe"
$backupPath = "$dockConfig.before-claude-pin"
$dockExe = "$dockRoot\Mydock.exe"

if (-not (Test-Path -LiteralPath $claudePath)) {
    throw "未找到 Claude: $claudePath"
}
if (-not (Test-Path -LiteralPath $dockConfig)) {
    throw "未找到 MyDockFinder 配置: $dockConfig"
}

# Stop MyDockFinder before editing. Otherwise it can save its old in-memory list over this change on exit.
Get-CimInstance Win32_Process -Filter "Name = 'Dock_64.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.ExecutablePath -like "$dockRoot*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 500

New-Item -ItemType Directory -Force -Path $launcherRoot | Out-Null
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $claudePath
$shortcut.WorkingDirectory = Split-Path -Parent $claudePath
$shortcut.IconLocation = "$claudePath,0"
$shortcut.Description = 'Claude'
$shortcut.Save()

if (-not (Test-Path -LiteralPath $backupPath)) {
    Copy-Item -LiteralPath $dockConfig -Destination $backupPath -Force
}

$content = [IO.File]::ReadAllText($dockConfig)
if ($content -notmatch '(?m)^\[ico\d+\]\r?\ntag=Claude\r?$') {
    # Keep the existing fixed icons in their order and insert Claude immediately before the divider.
    $content = [regex]::Replace($content, '(?m)^\[ico(\d+)\]\r?$', {
        param($match)
        $number = [int]$match.Groups[1].Value
        if ($number -ge 15) { return "[ico$($number + 1)]" }
        return $match.Value
    })

    $claudeEntry = "[ico15]`r`ntag=Claude`r`nappname=claude.lnk`r`nfilepath=$shortcutPath`r`nrealpath=$claudePath`r`nvirtualpath=com.squirrel.AnthropicClaude.claude`r`n[ico16]`r`ndelimiter=1`r`n"
    $content = [regex]::Replace($content, '(?ms)^\[ico16\]\s*delimiter=1\s*', $claudeEntry, 1)
    [IO.File]::WriteAllText($dockConfig, $content, [Text.Encoding]::Unicode)
}

Start-Process -FilePath $dockExe

Write-Host 'Claude 已固定到 MyDockFinder。'
