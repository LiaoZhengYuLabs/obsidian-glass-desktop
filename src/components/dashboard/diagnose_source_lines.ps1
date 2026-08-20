$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = $root + "\ObsidianAIDashboard.ps1"
$output = $root + "\source-line-diagnostics"
if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Recurse -Force }
[void](New-Item -ItemType Directory -Path $output -Force)
$lines = [IO.File]::ReadAllLines($source, [Text.Encoding]::UTF8)
for ($index = 0; $index -lt $lines.Length; $index++) {
    $line = $lines[$index]
    if ($line -match 'window\.(Width|Height)|DashboardViewbox|scale|CloseButton|contextTimer|MediaPlayPauseButton') {
        $safe = ($line.Trim() -replace '[\\/:*?"<>|\r\n]+', '_')
        if ($safe.Length -gt 130) { $safe = $safe.Substring(0, 130) }
        if (!$safe) { $safe = "blank" }
        $name = ($index + 1).ToString("0000") + "-" + $safe + ".txt"
        [IO.File]::WriteAllText(($output + "\" + $name), $line, (New-Object Text.UTF8Encoding($false)))
    }
}
