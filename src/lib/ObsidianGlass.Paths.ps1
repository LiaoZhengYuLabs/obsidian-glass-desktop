Set-StrictMode -Version 2.0

function Get-ObsidianGlassDockRoot {
    param([string]$RequestedPath)

    if (![string]::IsNullOrWhiteSpace($RequestedPath)) {
        $expanded = [Environment]::ExpandEnvironmentVariables($RequestedPath)
        if (Test-Path -LiteralPath $expanded -PathType Container) {
            return $expanded
        }
    }

    $candidates = @()
    if (![string]::IsNullOrWhiteSpace($env:OBSIDIAN_GLASS_DOCK_ROOT)) {
        $candidates += [Environment]::ExpandEnvironmentVariables($env:OBSIDIAN_GLASS_DOCK_ROOT)
    }

    $programFiles = ${env:ProgramFiles}
    $programFilesX86 = ${env:ProgramFiles(x86)}
    if (![string]::IsNullOrWhiteSpace($programFilesX86)) {
        $candidates += ($programFilesX86 + '\Steam\steamapps\common\MyDockFinder')
        $candidates += ($programFilesX86 + '\MyDockFinder')
    }
    if (![string]::IsNullOrWhiteSpace($programFiles)) {
        $candidates += ($programFiles + '\Steam\steamapps\common\MyDockFinder')
        $candidates += ($programFiles + '\MyDockFinder')
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            return $candidate
        }
    }

    return $null
}

function Get-ObsidianGlassUserShortcutRoot {
    $root = Join-Path $env:USERPROFILE 'AppShortcuts\DockLaunchers'
    if (Test-Path -LiteralPath $root -PathType Container) {
        return $root
    }
    return $null
}

function Find-ObsidianGlassShortcut {
    param(
        [string]$Name,
        [string]$FallbackPath
    )

    $candidates = @()
    $customRoot = Get-ObsidianGlassUserShortcutRoot
    if ($null -ne $customRoot) {
        $candidates += (Join-Path $customRoot ($Name + '.lnk'))
    }

    $startMenu = [Environment]::GetFolderPath('StartMenu')
    if (![string]::IsNullOrWhiteSpace($startMenu) -and (Test-Path -LiteralPath $startMenu)) {
        $found = Get-ChildItem -LiteralPath $startMenu -Filter ($Name + '.lnk') -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $found) {
            $candidates += $found.FullName
        }
    }

    if (![string]::IsNullOrWhiteSpace($FallbackPath)) {
        $candidates += [Environment]::ExpandEnvironmentVariables($FallbackPath)
    }

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }

    return $null
}
