[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$packageRoot = $PSScriptRoot

& (Join-Path $packageRoot 'src\Test-StartupKit.ps1')
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host 'PASS: 公开包语法、JSON、运行时排除项和基础隐私检查通过。' -ForegroundColor Green
