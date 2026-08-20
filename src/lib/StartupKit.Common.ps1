function Get-KitProperty {
    param(
        [object]$Object,
        [string]$Name,
        [object]$DefaultValue = $null
    )

    if ($null -eq $Object) {
        return $DefaultValue
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        return $DefaultValue
    }

    return $property.Value
}

function Get-KitPackageRoot {
    param([string]$SourceRoot)
    return (Split-Path -Parent $SourceRoot)
}

function Get-KitStateRoot {
    param([switch]$Ensure)

    $base = $env:LOCALAPPDATA
    if ([string]::IsNullOrWhiteSpace($base)) {
        $base = $env:TEMP
    }

    $stateRoot = Join-Path $base 'ObsidianGlassDesktop'
    if ($Ensure) {
        New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $stateRoot 'state') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $stateRoot 'logs') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $stateRoot 'backups') -Force | Out-Null
    }
    return $stateRoot
}

function Get-KitLogPath {
    $root = Get-KitStateRoot -Ensure
    return (Join-Path $root 'logs\obsidian-glass.log')
}

function Write-KitLog {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -LiteralPath (Get-KitLogPath) -Value $line -Encoding UTF8
    Write-Host $line
}

function Read-KitConfig {
    param([string]$Path)

    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Config file not found: $Path"
    }

    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    return ($content | ConvertFrom-Json)
}

function Resolve-KitPath {
    param(
        [string]$Path,
        [string]$BasePath
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    if ([IO.Path]::IsPathRooted($expanded)) {
        return $expanded
    }

    return ([IO.Path]::GetFullPath((Join-Path $BasePath $expanded)))
}

function Get-KitPowerShellPath {
    $candidate = Join-Path $PSHOME 'powershell.exe'
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return $candidate
    }

    return 'powershell.exe'
}

function ConvertTo-KitArgumentString {
    param([object[]]$Arguments)

    $parts = @()
    foreach ($argument in @($Arguments)) {
        if ($null -eq $argument) {
            continue
        }

        $value = [string]$argument
        if ($value -match '[\s"]') {
            $value = $value.Replace('"', '\"')
            $parts += ('"' + $value + '"')
        }
        else {
            $parts += $value
        }
    }

    return ($parts -join ' ')
}

function Write-KitJson {
    param(
        [object]$Object,
        [string]$Path
    )

    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    ($Object | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-KitInstallStatePath {
    return (Join-Path (Join-Path (Get-KitStateRoot) 'state') 'install-state.json')
}

function Get-KitSessionStatePath {
    return (Join-Path (Join-Path (Get-KitStateRoot) 'state') 'session-state.json')
}

function Test-KitTaskName {
    param([string]$TaskName)

    if ([string]::IsNullOrWhiteSpace($TaskName)) {
        return $false
    }

    if ($TaskName -match '[\\/:*?"<>|]') {
        return $false
    }

    return $true
}
