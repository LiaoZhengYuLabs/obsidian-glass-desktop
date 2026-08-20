[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$packageRoot = Split-Path -Parent $PSScriptRoot
$errors = @()
$warnings = @()

$required = @(
    'README.md',
    'LICENSE',
    'SECURITY.md',
    'src\Install-StartupKit.ps1',
    'src\Start-DesktopSession.ps1',
    'src\Stop-DesktopSession.ps1',
    'src\Restore-StartupKit.ps1',
    'src\Get-StartupStatus.ps1',
    'src\lib\StartupKit.Common.ps1',
    'config\obsidian-glass.example.json',
    'assets\manifest.json',
    'docs\SCREENSHOT_CATALOG.md',
    'tools\New-DesktopPreview.ps1'
)

foreach ($relative in $required) {
    $full = Join-Path $packageRoot $relative
    if (!(Test-Path -LiteralPath $full -PathType Leaf)) {
        $errors += "Missing required file: $relative"
    }
}

$psFiles = Get-ChildItem -LiteralPath $packageRoot -Recurse -File | Where-Object { $_.Extension -in @('.ps1', '.psm1') }
foreach ($file in $psFiles) {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors.Count -gt 0) {
        foreach ($parseError in $parseErrors) {
            $errors += ("PowerShell parse error in {0}: {1}" -f $file.FullName, $parseError.Message)
        }
    }
}

$jsonFiles = Get-ChildItem -LiteralPath $packageRoot -Recurse -File -Filter *.json
foreach ($file in $jsonFiles) {
    try {
        Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null
    }
    catch {
        $errors += ("JSON parse error in {0}: {1}" -f $file.FullName, $_.Exception.Message)
    }
}

$forbiddenNames = @('WebView2Data', 'speech-runtime', '.edge-space-goal-profile', 'browser-profile')
foreach ($name in $forbiddenNames) {
    $hits = Get-ChildItem -LiteralPath $packageRoot -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -like ('*' + $name + '*') }
    if ($hits.Count -gt 0) {
        $errors += "Forbidden runtime artifact found: $name"
    }
}

$textFiles = Get-ChildItem -LiteralPath $packageRoot -Recurse -File | Where-Object { $_.Extension -in @('.ps1', '.psm1', '.json', '.md', '.txt') }
$userPathPattern = 'C:' + [char]92 + 'Users' + [char]92
$secretPatterns = @(
    [regex]::Escape($userPathPattern),
    'Bearer[\s:=]+[A-Za-z0-9._-]{12,}',
    'api[_-]?key[\s:=]+[^\s]+',
    'password[\s:=]+[^\s]+'
)
foreach ($file in $textFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    foreach ($pattern in $secretPatterns) {
        if ($content -match $pattern) {
            $warnings += "Manual privacy review needed in: $($file.FullName)"
            break
        }
    }
}

if ($warnings.Count -gt 0) {
    Write-Host 'Warnings:'
    $warnings | ForEach-Object { Write-Host ("- " + $_) }
}

if ($errors.Count -gt 0) {
    Write-Host 'FAIL'
    $errors | ForEach-Object { Write-Host ("- " + $_) }
    exit 1
}

Write-Host 'PASS: required files, PowerShell syntax, JSON syntax, and package safety checks passed.'
exit 0
