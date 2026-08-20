[CmdletBinding()]
param(
    [switch]$VerifyOnly
)

$ErrorActionPreference = 'Stop'
$launcher = Join-Path $PSScriptRoot 'src\current\startup_optimized.ps1'
if (!(Test-Path -LiteralPath $launcher -PathType Leaf)) {
    throw "Current startup source is missing: $launcher"
}

& $launcher -VerifyOnly:$VerifyOnly
if (!$?) {
    exit 1
}
