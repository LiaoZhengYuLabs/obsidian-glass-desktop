$runtimeRoot = "$env:LOCALAPPDATA\ObsidianDockMediaProgress"
$startupRoot = [Environment]::GetFolderPath('Startup')

$checks = @()
$checks += [pscustomobject]@{ Name = '进度条程序'; Pass = Test-Path -LiteralPath "$runtimeRoot\DockMediaProgress.exe" }
$checks += [pscustomobject]@{ Name = '静默延迟启动'; Pass = Test-Path -LiteralPath "$startupRoot\Obsidian Dock Media Progress.lnk" }
$checks += [pscustomobject]@{ Name = '进度条进程'; Pass = [bool](Get-Process DockMediaProgress -ErrorAction SilentlyContinue) }

$checks | Format-Table -AutoSize
if ($checks.Pass -contains $false) { exit 1 }
