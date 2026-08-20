param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$statePath = $root + "\data\wechat-lockscreen-state.json"

if (!(Test-Path -LiteralPath $statePath)) {
    Write-Host "No lock screen backup has been recorded." -ForegroundColor Yellow
    exit 0
}

$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
$restorePath = ""
foreach ($candidate in @([string]$state.backupPath, [string]$state.previousPath)) {
    if (![string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) {
        $restorePath = $candidate
        break
    }
}
if ([string]::IsNullOrWhiteSpace($restorePath)) {
    throw "The original lock screen image and its backup are unavailable."
}

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$storageType = [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]
$lockScreenType = [Windows.System.UserProfile.LockScreen,Windows.System.UserProfile,ContentType=WindowsRuntime]
$operationAsTask = [System.WindowsRuntimeSystemExtensions].GetMethods() |
    Where-Object {
        $_.Name -eq "AsTask" -and
        $_.IsGenericMethod -and
        $_.GetGenericArguments().Count -eq 1 -and
        $_.GetParameters()[0].ParameterType.Name -eq "IAsyncOperation``1"
    } |
    Select-Object -First 1
$actionAsTask = [System.WindowsRuntimeSystemExtensions].GetMethods() |
    Where-Object {
        $_.Name -eq "AsTask" -and
        !$_.IsGenericMethod -and
        $_.GetParameters().Count -eq 1 -and
        $_.GetParameters()[0].ParameterType.Name -eq "IAsyncAction"
    } |
    Select-Object -First 1
if ($null -eq $operationAsTask -or $null -eq $actionAsTask) {
    throw "The Windows Runtime lock screen interface is unavailable."
}

$getFileOperation = $storageType::GetFileFromPathAsync($restorePath)
$getFileTask = $operationAsTask.MakeGenericMethod($storageType).Invoke($null, @($getFileOperation))
$storageFile = $getFileTask.GetAwaiter().GetResult()
$setImageTask = $actionAsTask.Invoke($null, @($lockScreenType::SetImageFileAsync($storageFile)))
[void]$setImageTask.GetAwaiter().GetResult()

Write-Host "The previous lock screen image was restored. The desktop wallpaper was not changed." -ForegroundColor Green
