param(
    [Parameter(Mandatory=$true)][string]$SourcePath,
    [Parameter(Mandatory=$true)][string]$DestinationPath,
    [Parameter(Mandatory=$true)][string]$RuntimeRoot
)

$ErrorActionPreference = 'Stop'

function Convert-InlineItem {
    param(
        [string[]]$Block,
        [string]$Type
    )

    $idLineIndex = -1
    $id = ''
    for ($index = 0; $index -lt $Block.Count; $index++) {
        if ($Block[$index] -match '^    id: (.+)$') {
            $idLineIndex = $index
            $id = $matches[1].Trim()
            break
        }
    }
    if ($idLineIndex -lt 0) { throw "Toolbar item is missing an id: $($Block -join ' | ')" }

    $converted = New-Object Collections.Generic.List[string]
    [void]$converted.Add("  - id: $id")
    switch ($Type) {
        'Media' {
            [void]$converted.Add('    scopes:')
            [void]$converted.Add('      - Media')
        }
        'Power' {
            [void]$converted.Add('    scopes:')
            [void]$converted.Add('      - Power')
        }
        'Generic' {
            [void]$converted.Add('    scopes:')
            [void]$converted.Add('      - FocusedApp')
        }
        default { [void]$converted.Add('    scopes: []') }
    }

    $v2Index = -1
    $v2Value = $null
    for ($index = 0; $index -lt $Block.Count; $index++) {
        if ($Block[$index] -match '^    onClickV2:\s*(.*)$') {
            $v2Index = $index
            $v2Value = $matches[1].Trim()
            break
        }
    }

    for ($index = $idLineIndex + 1; $index -lt $Block.Count; $index++) {
        $line = $Block[$index]
        if ($line -match '^    withMediaControls:') { continue }
        if ($line -match '^    onClickV2:') {
            if ($v2Value -ne 'null') {
                [void]$converted.Add(($line -replace '^    onClickV2:', '    onClick:'))
            }
            continue
        }
        if ($v2Index -ge 0 -and $v2Value -ne 'null' -and $line -match '^    onClick:\s*null\s*$') {
            continue
        }
        if ($Type -eq 'Generic') {
            $line = $line.Replace('window.', 'focusedApp.')
        }
        [void]$converted.Add($line)
    }

    return ,$converted.ToArray()
}

function Get-NewMediaItems {
    param([string]$Root)
    $safeRoot = $Root.Replace('\', '/')
    $text = @"
  - id: media-screenshot
    scopes: []
    template: return '截图库'
    tooltip: return '直接截图与历史图片'
    badge: null
    onClick: open("$safeRoot/open-screenshot.cmd")
    style:
      fontFamily: Microsoft YaHei UI
      fontSize: 12
    remoteData: {}
  - id: media-recording
    scopes: []
    template: return '录像'
    tooltip: return '屏幕录像与历史视频'
    badge: null
    onClick: open("$safeRoot/open-recording.cmd")
    style:
      fontFamily: Microsoft YaHei UI
      fontSize: 12
    remoteData: {}
  - id: media-camera
    scopes: []
    template: return '摄像头'
    tooltip: return '桌面摄像头窗口与历史录像'
    badge: null
    onClick: open("$safeRoot/open-camera.cmd")
    style:
      fontFamily: Microsoft YaHei UI
      fontSize: 12
    remoteData: {}
  - id: language-toggle
    scopes: []
    template: return '中/EN'
    tooltip: return '切换简体中文与 English 输入'
    badge: null
    onClick: open("$safeRoot/toggle-language.cmd")
    style:
      fontFamily: Microsoft YaHei UI
      fontSize: 12
    remoteData: {}
"@
    return ,($text -split "`r?`n" | Where-Object { $_ -ne '' })
}

if (-not (Test-Path -LiteralPath $SourcePath)) { throw "Source toolbar does not exist: $SourcePath" }
$lines = [IO.File]::ReadAllLines($SourcePath, [Text.Encoding]::UTF8)
$sourceText = $lines -join "`n"
$requiredMediaIds = @('media-screenshot','media-recording','media-camera','language-toggle')
$alreadyMigrated = ($sourceText -notmatch '(?m)^  - type: ') -and
    (@($requiredMediaIds | Where-Object { $sourceText -notmatch ('(?m)^  - id: ' + [regex]::Escape($_) + '$') }).Count -eq 0)

if ($alreadyMigrated) {
    $destinationDirectory = Split-Path -Parent $DestinationPath
    if ($destinationDirectory) { New-Item -ItemType Directory -Force -Path $destinationDirectory | Out-Null }
    [IO.File]::WriteAllLines($DestinationPath, $lines, (New-Object Text.UTF8Encoding($false)))
    [pscustomobject]@{
        Source = $SourcePath
        Destination = $DestinationPath
        InlineItemCount = @($lines | Where-Object { $_ -match '^  - id: ' }).Count
        AddedItems = $requiredMediaIds
    }
    exit 0
}

$output = New-Object Collections.Generic.List[string]
$cursor = 0
$mediaItemsAdded = $false

while ($cursor -lt $lines.Count) {
    if ($lines[$cursor] -match '^  - type: (Text|Generic|Media|Power)\s*$') {
        $type = $matches[1]
        $end = $cursor + 1
        while ($end -lt $lines.Count -and
               $lines[$end] -notmatch '^  - ' -and
               $lines[$end] -notmatch '^(left|center|right):\s*$') {
            $end++
        }
        $block = @($lines[$cursor..($end - 1)])
        $converted = Convert-InlineItem -Block $block -Type $type
        foreach ($line in $converted) { [void]$output.Add($line) }

        $itemId = ($converted[0] -replace '^  - id:\s*', '').Trim()
        if ($itemId -eq 'practical-capture' -and -not $mediaItemsAdded) {
            foreach ($line in (Get-NewMediaItems -Root $RuntimeRoot)) { [void]$output.Add($line) }
            $mediaItemsAdded = $true
        }
        $cursor = $end
        continue
    }

    [void]$output.Add($lines[$cursor])
    $cursor++
}

if (-not $mediaItemsAdded) { throw 'The original screenshot item was not found; no changes were written.' }

$destinationDirectory = Split-Path -Parent $DestinationPath
if ($destinationDirectory) { New-Item -ItemType Directory -Force -Path $destinationDirectory | Out-Null }
[IO.File]::WriteAllLines($DestinationPath, $output, (New-Object Text.UTF8Encoding($false)))

$ids = @($output | Where-Object { $_ -match '^  - id: ' } | ForEach-Object { ($_ -replace '^  - id:\s*', '').Trim() })
[pscustomobject]@{
    Source = $SourcePath
    Destination = $DestinationPath
    InlineItemCount = $ids.Count
    AddedItems = $requiredMediaIds
}
