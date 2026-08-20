$runtimeRoot = "$env:LOCALAPPDATA\ObsidianDockMediaProgress"
$startupRoot = [Environment]::GetFolderPath('Startup')
$dockerSettings = "$env:APPDATA\Docker\settings-store.json"

$checks = @()
$checks += [pscustomobject]@{ Name = '进度条程序'; Pass = Test-Path -LiteralPath "$runtimeRoot\DockMediaProgress.exe" }
$checks += [pscustomobject]@{ Name = '静默延迟启动'; Pass = Test-Path -LiteralPath "$startupRoot\Obsidian Dock Media Progress.lnk" }
$checks += [pscustomobject]@{ Name = '进度条进程'; Pass = [bool](Get-Process DockMediaProgress -ErrorAction SilentlyContinue) }

$dockerAutoStart = $null
if (Test-Path -LiteralPath $dockerSettings) {
    $dockerAutoStart = (Get-Content -LiteralPath $dockerSettings -Raw -Encoding UTF8 | ConvertFrom-Json).AutoStart
}
$checks += [pscustomobject]@{ Name = 'Docker Desktop 自启关闭'; Pass = ($dockerAutoStart -eq $false) }

$checks | Format-Table -AutoSize
if ($checks.Pass -contains $false) { exit 1 }
