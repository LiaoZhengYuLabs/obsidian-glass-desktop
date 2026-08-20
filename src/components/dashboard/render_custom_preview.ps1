$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

function Read-XamlObject {
    param([string]$Path)
    $text = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
    return [Windows.Markup.XamlReader]::Parse($text)
}

function Add-PreviewWidget {
    param($Window, [string]$SlotName, [string]$WidgetName)
    $slot = $Window.FindName($SlotName)
    $widget = Read-XamlObject ($root + "\components\" + $WidgetName + "\view.xaml")
    [void]$slot.Children.Add($widget)
}

function Save-BoardPreview {
    param($Window, [string]$Path)
    $rootGrid = $Window.FindName("DashboardRoot")
    $originalBackground = $rootGrid.Background
    $rootGrid.Background = [Windows.Media.Brushes]::Black
    $size = New-Object Windows.Size 392, 500
    $rootGrid.Measure($size)
    $rootGrid.Arrange((New-Object Windows.Rect 0, 0, 392, 500))
    $rootGrid.UpdateLayout()
    $bitmap = New-Object Windows.Media.Imaging.RenderTargetBitmap 784, 1000, 192, 192, ([Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($rootGrid)
    $encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Create)
    try { $encoder.Save($stream) } finally { $stream.Dispose() }
    $rootGrid.Background = $originalBackground
}

$window = Read-XamlObject ($root + "\Dashboard.xaml")
Add-PreviewWidget $window "TimeWeatherSlot" "TimeWeatherWidget"
Add-PreviewWidget $window "MediaSlot" "MediaWidget"
Add-PreviewWidget $window "SystemMonitorSlot" "SystemMonitorWidget"
Add-PreviewWidget $window "TodoSlot" "TodoWidget"
Add-PreviewWidget $window "WorkspacePulseSlot" "WorkspacePulseWidget"
Add-PreviewWidget $window "AIAgentSlot" "AIAgentWidget"
Add-PreviewWidget $window "GithubSlot" "GithubWidget"
Add-PreviewWidget $window "QuickToolsSlot" "QuickToolsWidget"

$window.FindName("AmbientTab").IsChecked = $true
$window.FindName("WorkspaceTab").IsChecked = $false
Save-BoardPreview $window ($root + "\custom-preview-daily.png")

$window.FindName("AmbientTab").IsChecked = $false
$window.FindName("WorkspaceTab").IsChecked = $true
Save-BoardPreview $window ($root + "\custom-preview-workspace.png")

Write-Output "PREVIEWS_RENDERED"
