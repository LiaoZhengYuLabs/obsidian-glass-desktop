[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$ProjectRoot,
    [switch]$VerifyOnly
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\StartupKit.Common.ps1')

$packageRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $packageRoot 'config\obsidian-glass.example.json'
}
$configFullPath = Resolve-KitPath -Path $ConfigPath -BasePath $packageRoot
$config = Read-KitConfig -Path $configFullPath
$configuredRoot = [string](Get-KitProperty -Object $config -Name 'projectRoot' -DefaultValue '.')
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Resolve-KitPath -Path $configuredRoot -BasePath $packageRoot
}
else {
    $ProjectRoot = Resolve-KitPath -Path $ProjectRoot -BasePath $packageRoot
}

$delaySeconds = [int](Get-KitProperty -Object $config -Name 'startupDelaySeconds' -DefaultValue 0)
$components = @((Get-KitProperty -Object $config -Name 'components' -DefaultValue @()))
$logPath = Get-KitLogPath
$hadErrors = $false
$started = @()
$mutex = New-Object System.Threading.Mutex($false, 'Local\ObsidianGlassDesktop.Start')
$ownsMutex = $false

try {
    $ownsMutex = $mutex.WaitOne(0, $false)
    if (!$ownsMutex) {
        Write-KitLog -Message 'Another startup session is already running; skipping duplicate launch.' -Level 'WARN'
        exit 0
    }

    Write-KitLog -Message "Session root: $ProjectRoot"
    if (!(Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
        Write-KitLog -Message "Project root not found: $ProjectRoot" -Level 'ERROR'
        exit 1
    }

    if ($delaySeconds -gt 0 -and !$VerifyOnly) {
        Start-Sleep -Seconds $delaySeconds
    }

    foreach ($component in $components) {
        $enabled = [bool](Get-KitProperty -Object $component -Name 'enabled' -DefaultValue $false)
        if (!$enabled) {
            continue
        }

        $id = [string](Get-KitProperty -Object $component -Name 'id' -DefaultValue 'component')
        $scriptRelative = [string](Get-KitProperty -Object $component -Name 'script' -DefaultValue '')
        $executableRelative = [string](Get-KitProperty -Object $component -Name 'executable' -DefaultValue '')
        $componentDelay = [int](Get-KitProperty -Object $component -Name 'delaySeconds' -DefaultValue 0)
        $arguments = @((Get-KitProperty -Object $component -Name 'arguments' -DefaultValue @()))

        if (![string]::IsNullOrWhiteSpace($scriptRelative)) {
            $targetPath = Resolve-KitPath -Path $scriptRelative -BasePath $ProjectRoot
            $isPowerShellScript = $targetPath -match '\.ps1$'
        }
        elseif (![string]::IsNullOrWhiteSpace($executableRelative)) {
            $targetPath = Resolve-KitPath -Path $executableRelative -BasePath $ProjectRoot
            $isPowerShellScript = $false
        }
        else {
            Write-KitLog -Message "Component '$id' has no script or executable path." -Level 'WARN'
            $hadErrors = $true
            continue
        }

        if (!(Test-Path -LiteralPath $targetPath -PathType Leaf)) {
            Write-KitLog -Message "Component '$id' is missing: $targetPath" -Level 'WARN'
            $hadErrors = $true
            continue
        }

        if ($VerifyOnly) {
            Write-Host ("OK component {0}: {1}" -f $id, $targetPath)
            continue
        }

        if ($componentDelay -gt 0) {
            Start-Sleep -Seconds $componentDelay
        }

        if ($isPowerShellScript) {
            $argumentText = '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $targetPath
            $extraText = ConvertTo-KitArgumentString -Arguments $arguments
            if (![string]::IsNullOrWhiteSpace($extraText)) {
                $argumentText = $argumentText + ' ' + $extraText
            }
            $process = Start-Process -FilePath (Get-KitPowerShellPath) -ArgumentList $argumentText -WorkingDirectory $ProjectRoot -WindowStyle Hidden -PassThru
        }
        else {
            $argumentText = ConvertTo-KitArgumentString -Arguments $arguments
            $process = Start-Process -FilePath $targetPath -ArgumentList $argumentText -WorkingDirectory $ProjectRoot -PassThru
        }

        $started += [ordered]@{
            Id = $id
            Path = $targetPath
            ProcessId = $process.Id
            ProcessName = $process.ProcessName
            StartedAt = (Get-Date).ToString('o')
        }
        Write-KitLog -Message "Started component '$id' (PID $($process.Id))."
    }

    if (!$VerifyOnly) {
        $sessionState = [ordered]@{
            ConfigPath = $configFullPath
            ProjectRoot = $ProjectRoot
            StartedAt = (Get-Date).ToString('o')
            Components = $started
        }
        Write-KitJson -Object $sessionState -Path (Get-KitSessionStatePath)
    }

    if ($hadErrors) {
        Write-KitLog -Message 'Session completed with one or more missing component paths.' -Level 'WARN'
    }
    else {
        Write-KitLog -Message 'Session completed without path errors.'
    }

    if ($VerifyOnly) {
        if ($hadErrors) { exit 1 } else { exit 0 }
    }
}
finally {
    if ($ownsMutex) {
        $mutex.ReleaseMutex()
    }
    $mutex.Dispose()
}
