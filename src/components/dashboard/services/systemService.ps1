function Get-DeviceProfile {
    if ($null -ne $script:dashboardDeviceProfile) {
        return $script:dashboardDeviceProfile
    }

    $manufacturer = ""
    $model = ""
    $computerName = $env:COMPUTERNAME
    $operatingSystem = "Windows"
    $osBuild = ""
    $processorName = ""
    $graphicsName = ""
    $memoryTotalGB = 0.0

    try {
        $computerSystem = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $manufacturer = [string]$computerSystem.Manufacturer
        $model = [string]$computerSystem.Model
        $memoryTotalGB = [Math]::Round(([double]$computerSystem.TotalPhysicalMemory / 1GB), 1)
    } catch {}
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $operatingSystem = ([string]$os.Caption -replace '^Microsoft\s+', '').Trim()
        $osBuild = [string]$os.BuildNumber
    } catch {}
    try {
        $processor = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
        $processorName = ([string]$processor.Name -replace '\s+', ' ').Trim()
    } catch {}
    try {
        $graphics = Get-CimInstance Win32_VideoController -ErrorAction Stop |
            Where-Object { ![string]::IsNullOrWhiteSpace([string]$_.Name) } |
            Sort-Object AdapterRAM -Descending |
            Select-Object -First 1
        $graphicsName = ([string]$graphics.Name -replace '\s+', ' ').Trim()
    } catch {}

    $script:dashboardDeviceProfile = [pscustomobject]@{
        ComputerName = $computerName
        Manufacturer = $manufacturer
        Model = $model
        OperatingSystem = $operatingSystem
        OsBuild = $osBuild
        ProcessorName = $processorName
        GraphicsName = $graphicsName
        MemoryTotalGB = $memoryTotalGB
    }
    return $script:dashboardDeviceProfile
}

function Get-SystemSnapshot {
    $cpu = 0.0
    $gpu = 0.0
    $ram = 0.0
    $ssd = 0.0
    $battery = $null
    $temperature = $null
    $network = 0.0

    try {
        if ($null -eq $script:dashboardCpuCounter) {
            $script:dashboardCpuCounter = New-Object Diagnostics.PerformanceCounter("Processor", "% Processor Time", "_Total")
            [void]$script:dashboardCpuCounter.NextValue()
            Start-Sleep -Milliseconds 120
        }
        $cpu = [double]$script:dashboardCpuCounter.NextValue()
    } catch {}

    try {
        Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue
        $computer = New-Object Microsoft.VisualBasic.Devices.ComputerInfo
        $totalMemory = [double]$computer.TotalPhysicalMemory
        $availableMemory = [double]$computer.AvailablePhysicalMemory
        if ($totalMemory -gt 0) {
            $ram = (1.0 - ($availableMemory / $totalMemory)) * 100.0
        }
    } catch {}

    try {
        $drive = New-Object IO.DriveInfo("C")
        if ([double]$drive.TotalSize -gt 0) {
            $ssd = (1.0 - ([double]$drive.AvailableFreeSpace / [double]$drive.TotalSize)) * 100.0
        }
    } catch {}

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        $power = [Windows.Forms.SystemInformation]::PowerStatus
        if ($power.BatteryChargeStatus -notmatch "NoSystemBattery|Unknown" -and $power.BatteryLifePercent -ge 0) {
            $battery = [double]$power.BatteryLifePercent * 100.0
        }
    } catch {}

    try {
        $nvidiaSmi = "$env:WINDIR\System32\nvidia-smi.exe"
        if (Test-Path -LiteralPath $nvidiaSmi) {
            $line = [string](& $nvidiaSmi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>$null | Select-Object -First 1)
            if (![string]::IsNullOrWhiteSpace($line)) {
                $parts = $line.Split(',')
                if ($parts.Count -ge 1) { [void][double]::TryParse($parts[0].Trim(), [ref]$gpu) }
                if ($parts.Count -ge 2) {
                    $parsedTemperature = 0.0
                    if ([double]::TryParse($parts[1].Trim(), [ref]$parsedTemperature)) {
                        $temperature = $parsedTemperature
                    }
                }
            }
        }
    } catch {}

    try {
        $totalBytes = 0.0
        $interfaces = [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
            Where-Object {
                $_.OperationalStatus -eq [Net.NetworkInformation.OperationalStatus]::Up -and
                $_.NetworkInterfaceType -ne [Net.NetworkInformation.NetworkInterfaceType]::Loopback -and
                $_.NetworkInterfaceType -ne [Net.NetworkInformation.NetworkInterfaceType]::Tunnel
            }
        foreach ($interface in $interfaces) {
            try {
                $statistics = $interface.GetIPv4Statistics()
                $totalBytes += [double]$statistics.BytesReceived + [double]$statistics.BytesSent
            } catch {}
        }

        $sampleTime = Get-Date
        if ($null -ne $script:dashboardLastNetworkTime) {
            $seconds = ($sampleTime - $script:dashboardLastNetworkTime).TotalSeconds
            if ($seconds -gt 0 -and $totalBytes -ge $script:dashboardLastNetworkBytes) {
                $network = (($totalBytes - $script:dashboardLastNetworkBytes) / $seconds) / 1MB
            }
        }
        $script:dashboardLastNetworkBytes = $totalBytes
        $script:dashboardLastNetworkTime = $sampleTime
    } catch {}

    $device = Get-DeviceProfile
    return [pscustomobject]@{
        Cpu = [Math]::Max(0, [Math]::Min(100, $cpu))
        Gpu = [Math]::Max(0, [Math]::Min(100, $gpu))
        Ram = [Math]::Max(0, [Math]::Min(100, $ram))
        Ssd = [Math]::Max(0, [Math]::Min(100, $ssd))
        Battery = $battery
        Temperature = $temperature
        NetworkMBps = [Math]::Max(0, $network)
        ComputerName = $device.ComputerName
        Manufacturer = $device.Manufacturer
        Model = $device.Model
        OperatingSystem = $device.OperatingSystem
        OsBuild = $device.OsBuild
        ProcessorName = $device.ProcessorName
        GraphicsName = $device.GraphicsName
        MemoryTotalGB = $device.MemoryTotalGB
        UpdatedAt = Get-Date
    }
}
