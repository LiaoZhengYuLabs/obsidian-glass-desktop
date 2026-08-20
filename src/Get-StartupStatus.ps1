[CmdletBinding()]
param(
    [string]$ConfigPath,
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\StartupKit.Common.ps1')

$packageRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $packageRoot 'config\obsidian-glass.example.json'
}
$configFullPath = Resolve-KitPath -Path $ConfigPath -BasePath $packageRoot
$config = Read-KitConfig -Path $configFullPath
$taskName = [string](Get-KitProperty -Object $config -Name 'taskName' -DefaultValue 'Obsidian Glass Desktop')
$projectRoot = Resolve-KitPath -Path ([string](Get-KitProperty -Object $config -Name 'projectRoot' -DefaultValue '.')) -BasePath $packageRoot
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
$installStatePath = Get-KitInstallStatePath
$shortcutPath = ''
if (Test-Path -LiteralPath $installStatePath -PathType Leaf) {
    $installState = (Get-Content -LiteralPath $installStatePath -Raw -Encoding UTF8 | ConvertFrom-Json)
    $shortcutPath = [string](Get-KitProperty -Object $installState -Name 'StartupShortcutPath' -DefaultValue '')
}

$componentStatus = @()
foreach ($component in @((Get-KitProperty -Object $config -Name 'components' -DefaultValue @()))) {
    $id = [string](Get-KitProperty -Object $component -Name 'id' -DefaultValue 'component')
    $enabled = [bool](Get-KitProperty -Object $component -Name 'enabled' -DefaultValue $false)
    $relative = [string](Get-KitProperty -Object $component -Name 'script' -DefaultValue '')
    if ([string]::IsNullOrWhiteSpace($relative)) {
        $relative = [string](Get-KitProperty -Object $component -Name 'executable' -DefaultValue '')
    }
    $resolved = Resolve-KitPath -Path $relative -BasePath $projectRoot
    $componentStatus += [ordered]@{
        Id = $id
        Enabled = $enabled
        Path = $resolved
        Exists = (![string]::IsNullOrWhiteSpace($resolved) -and (Test-Path -LiteralPath $resolved -PathType Leaf))
    }
}

$result = [ordered]@{
    ConfigPath = $configFullPath
    ProjectRoot = $projectRoot
    TaskName = $taskName
    ScheduledTaskPresent = ($null -ne $task)
    StartupShortcutPresent = (![string]::IsNullOrWhiteSpace($shortcutPath) -and (Test-Path -LiteralPath $shortcutPath -PathType Leaf))
    StateRoot = (Get-KitStateRoot)
    Components = $componentStatus
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
}
else {
    $result.GetEnumerator() | ForEach-Object {
        if ($_.Key -ne 'Components') {
            Write-Host ('{0}: {1}' -f $_.Key, $_.Value)
        }
    }
    Write-Host 'Components:'
    foreach ($item in $componentStatus) {
        Write-Host ('  {0} | enabled={1} | exists={2} | {3}' -f $item.Id, $item.Enabled, $item.Exists, $item.Path)
    }
}
