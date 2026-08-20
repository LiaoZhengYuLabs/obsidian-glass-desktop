[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\StartupKit.Common.ps1')

$statePath = Get-KitSessionStatePath
if (!(Test-Path -LiteralPath $statePath -PathType Leaf)) {
    Write-KitLog -Message 'No session state was found; nothing to stop.' -Level 'WARN'
    exit 0
}

$state = (Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json)
foreach ($entry in @($state.Components)) {
    $processId = [int](Get-KitProperty -Object $entry -Name 'ProcessId' -DefaultValue 0)
    if ($processId -le 0) {
        continue
    }

    $process = Get-Process -Id $processId -ErrorAction SilentlyContinue
    if ($null -eq $process) {
        continue
    }

    $label = [string](Get-KitProperty -Object $entry -Name 'Id' -DefaultValue 'component')
    if ($PSCmdlet.ShouldProcess("$label (PID $processId)", 'Stop recorded component process')) {
        Stop-Process -Id $processId -Force
        Write-KitLog -Message "Stopped recorded component '$label' (PID $processId)."
    }
}

if ($PSCmdlet.ShouldProcess($statePath, 'Remove recorded session state')) {
    Remove-Item -LiteralPath $statePath -Force -ErrorAction SilentlyContinue
    Write-KitLog -Message 'Recorded session state cleared.'
}
