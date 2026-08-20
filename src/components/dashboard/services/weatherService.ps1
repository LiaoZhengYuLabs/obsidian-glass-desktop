function Get-WeatherSnapshot {
    param([string]$DataPath)

    $data = Read-DashboardJson -Path $DataPath
    if ($null -eq $data) {
        return [pscustomobject]@{
            Location = "JIEYANG / RONGCHENG"
            Condition = "WEATHER SERVICE OFFLINE"
            Temperature = "--"
            Humidity = "--"
            AirQuality = "--"
            UpdatedAt = "NOT SYNCED"
            IsConfigured = $false
        }
    }

    $location = [string]$data.location.city + " / " + [string]$data.location.district
    $configured = ![string]::IsNullOrWhiteSpace([string]$data.provider.name)
    $observation = $data.observation
    if ($null -eq $observation) {
        return [pscustomobject]@{
            Location = $location
            Condition = if ($configured) { "WAITING FOR WEATHER DATA" } else { "WEATHER API REQUIRED" }
            Temperature = "--"
            Humidity = "--"
            AirQuality = "--"
            UpdatedAt = "NOT SYNCED"
            IsConfigured = $configured
        }
    }

    return [pscustomobject]@{
        Location = $location
        Condition = [string]$observation.condition
        Temperature = [string]$observation.temperature
        Humidity = [string]$observation.humidity
        AirQuality = [string]$observation.airQuality
        UpdatedAt = [string]$data.updatedAt
        IsConfigured = $configured
    }
}
