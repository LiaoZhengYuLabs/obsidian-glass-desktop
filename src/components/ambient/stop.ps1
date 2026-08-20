$ErrorActionPreference = "SilentlyContinue"

Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" | Where-Object {
    $_.CommandLine -like "*DockVisibilityController.ps1*"
} | ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force
}
