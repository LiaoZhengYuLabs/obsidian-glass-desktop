$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = $projectRoot + "\SeelenLivePreview.cs"
$executable = $projectRoot + "\SeelenLivePreview.exe"
$compiler = $env:WINDIR + "\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$automationClient = $env:WINDIR + "\Microsoft.NET\Framework64\v4.0.30319\WPF\UIAutomationClient.dll"
$automationTypes = $env:WINDIR + "\Microsoft.NET\Framework64\v4.0.30319\WPF\UIAutomationTypes.dll"
$windowsBase = $env:WINDIR + "\Microsoft.NET\Framework64\v4.0.30319\WPF\WindowsBase.dll"

if (!(Test-Path -LiteralPath $source)) {
    throw "SeelenLivePreview.cs is missing."
}
if (!(Test-Path -LiteralPath $compiler)) {
    throw "The Windows .NET Framework compiler is unavailable."
}

$needsBuild = !(Test-Path -LiteralPath $executable)
if (!$needsBuild) {
    $needsBuild = (Get-Item -LiteralPath $source).LastWriteTimeUtc -gt (Get-Item -LiteralPath $executable).LastWriteTimeUtc
}
if ($needsBuild) {
    & $compiler /nologo /target:winexe /optimize+ `
        /reference:System.dll `
        /reference:System.Core.dll `
        /reference:System.Drawing.dll `
        /reference:System.Windows.Forms.dll `
        /reference:$windowsBase `
        /reference:$automationClient `
        /reference:$automationTypes `
        /out:$executable $source
    if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $executable)) {
        throw "Seelen live preview compilation failed."
    }
}

if (!(Get-Process -Name "SeelenLivePreview" -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $executable -WorkingDirectory $projectRoot -WindowStyle Hidden
}

Write-Host "Seelen neutral live preview is running."
