function Resolve-ShortcutTarget {
    param([string]$ShortcutPath)

    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($ShortcutPath)
        return [pscustomobject]@{
            TargetPath = [string]$shortcut.TargetPath
            Arguments = [string]$shortcut.Arguments
            IconLocation = [string]$shortcut.IconLocation
        }
    } catch {
        return $null
    }
}

function Find-StartMenuShortcut {
    param([string[]]$Patterns)

    if ($null -eq $script:dashboardStartMenuLinks) {
        $script:dashboardStartMenuLinks = @()
        $roots = @(
            [Environment]::GetFolderPath("StartMenu"),
            [Environment]::GetFolderPath("CommonStartMenu")
        )
        foreach ($root in $roots) {
            if (Test-Path -LiteralPath $root) {
                $script:dashboardStartMenuLinks += @(Get-ChildItem -LiteralPath $root -Filter "*.lnk" -Recurse -ErrorAction SilentlyContinue)
            }
        }
    }

    foreach ($pattern in $Patterns) {
        foreach ($link in $script:dashboardStartMenuLinks) {
            if ($link.BaseName -like $pattern) {
                return $link.FullName
            }
        }
    }
    return $null
}

function Find-FirstExistingPath {
    param([string[]]$Paths)

    foreach ($path in $Paths) {
        if (![string]::IsNullOrWhiteSpace($path) -and (Test-Path -LiteralPath $path)) {
            return $path
        }
    }
    return $null
}

function New-QuickToolRecord {
    param(
        [string]$Name,
        [string]$LaunchPath,
        [string]$Arguments,
        [string]$IconPath,
        [string]$FallbackIcon
    )

    return [pscustomobject]@{
        Name = $Name
        LaunchPath = $LaunchPath
        Arguments = $Arguments
        IconPath = if (![string]::IsNullOrWhiteSpace($IconPath)) { $IconPath } else { $FallbackIcon }
        IsAvailable = ![string]::IsNullOrWhiteSpace($LaunchPath)
    }
}

function Get-QuickTools {
    param([string]$DashboardRoot)

    $workspaceAssets = [IO.Path]::GetFullPath($DashboardRoot + "\..\ObsidianAIWorkspace\assets")
    $localApps = [Environment]::GetFolderPath("LocalApplicationData")
    $programFiles = [Environment]::GetFolderPath("ProgramFiles")
    $programFilesX86 = [Environment]::GetFolderPath("ProgramFilesX86")

    $codePath = Find-FirstExistingPath -Paths @(
        ($localApps + "\Programs\Microsoft VS Code\Code.exe"),
        ($programFiles + "\Microsoft VS Code\Code.exe"),
        ($programFilesX86 + "\Microsoft VS Code\Code.exe")
    )
    if ([string]::IsNullOrWhiteSpace($codePath)) {
        $codeShortcut = Find-StartMenuShortcut -Patterns @("*Visual Studio Code*", "*VS Code*")
        if ($codeShortcut) { $codePath = $codeShortcut }
    }

    $chatGptPath = Find-StartMenuShortcut -Patterns @("*ChatGPT*")
    $chatGptArgs = ""
    $chatGptIcon = $workspaceAssets + "\ChatGPT.ico"
    if ([string]::IsNullOrWhiteSpace($chatGptPath)) {
        $chatProcess = Get-Process -Name "ChatGPT" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $chatProcess) {
            try { $chatGptPath = $chatProcess.Path } catch {}
        }
    }
    if ([string]::IsNullOrWhiteSpace($chatGptPath)) {
        try {
            $startApp = Get-StartApps | Where-Object { $_.Name -match "ChatGPT" } | Select-Object -First 1
            if ($null -ne $startApp) {
                $chatGptPath = "$env:WINDIR\explorer.exe"
                $chatGptArgs = "shell:AppsFolder\" + [string]$startApp.AppID
            }
        } catch {}
    }

    $terminalPath = Find-FirstExistingPath -Paths @(
        ($localApps + "\Microsoft\WindowsApps\wt.exe"),
        ($programFiles + "\WindowsApps\wt.exe")
    )
    if ([string]::IsNullOrWhiteSpace($terminalPath)) {
        $terminalShortcut = Find-StartMenuShortcut -Patterns @("*Terminal*")
        if ($terminalShortcut) { $terminalPath = $terminalShortcut }
    }

    $chromePath = Find-FirstExistingPath -Paths @(
        ($programFiles + "\Google\Chrome\Application\chrome.exe"),
        ($programFilesX86 + "\Google\Chrome\Application\chrome.exe"),
        ($localApps + "\Google\Chrome\Application\chrome.exe")
    )
    $edgePath = Find-FirstExistingPath -Paths @(
        ($programFilesX86 + "\Microsoft\Edge\Application\msedge.exe"),
        ($programFiles + "\Microsoft\Edge\Application\msedge.exe")
    )
    $browserPath = if ($chromePath) { $chromePath } else { $edgePath }

    return @(
        New-QuickToolRecord -Name "VS Code" -LaunchPath $codePath -Arguments "" -IconPath $codePath -FallbackIcon ($workspaceAssets + "\Visual Studio Code.ico")
        New-QuickToolRecord -Name "ChatGPT" -LaunchPath $chatGptPath -Arguments $chatGptArgs -IconPath $chatGptIcon -FallbackIcon $chatGptIcon
        New-QuickToolRecord -Name "Terminal" -LaunchPath $terminalPath -Arguments "" -IconPath $terminalPath -FallbackIcon ""
        New-QuickToolRecord -Name "Browser" -LaunchPath $browserPath -Arguments "" -IconPath $browserPath -FallbackIcon ($workspaceAssets + "\Google Chrome.ico")
        New-QuickToolRecord -Name "File Explorer" -LaunchPath "$env:WINDIR\explorer.exe" -Arguments "" -IconPath "$env:WINDIR\explorer.exe" -FallbackIcon ""
    )
}

function Start-QuickTool {
    param($Tool)

    if ($null -eq $Tool -or !$Tool.IsAvailable) { return }
    if ([string]::IsNullOrWhiteSpace([string]$Tool.Arguments)) {
        Start-Process -FilePath ([string]$Tool.LaunchPath)
    } else {
        Start-Process -FilePath ([string]$Tool.LaunchPath) -ArgumentList ([string]$Tool.Arguments)
    }
}
