function Get-TodoDocument {
    param([string]$DataPath)

    $data = Read-DashboardJson -Path $DataPath
    if ($null -eq $data) {
        $data = [pscustomobject]@{
            version = 2
            selectedDate = (Get-Date -Format "yyyy-MM-dd")
            plans = @()
        }
        Write-DashboardJson -Path $DataPath -Value $data
        return $data
    }

    if ($null -eq $data.PSObject.Properties["version"] -or [int]$data.version -lt 2) {
        $legacyDate = [string]$data.date
        if ([string]::IsNullOrWhiteSpace($legacyDate)) {
            $legacyDate = Get-Date -Format "yyyy-MM-dd"
        }
        $legacyTasks = @($data.tasks)
        $data = [pscustomobject]@{
            version = 2
            selectedDate = (Get-Date -Format "yyyy-MM-dd")
            plans = @([pscustomobject]@{ date = $legacyDate; tasks = $legacyTasks })
        }
        Write-DashboardJson -Path $DataPath -Value $data
    }

    if ($null -eq $data.PSObject.Properties["plans"]) {
        $data | Add-Member -NotePropertyName plans -NotePropertyValue @() -Force
    }
    return $data
}

function Get-TodoPlan {
    param(
        $Document,
        [string]$Date,
        [switch]$Create
    )

    $plan = @($Document.plans | Where-Object { [string]$_.date -eq $Date }) | Select-Object -First 1
    if ($null -eq $plan -and $Create) {
        $plan = [pscustomobject]@{ date = $Date; tasks = @() }
        $Document.plans = @($Document.plans) + @($plan)
    }
    return $plan
}

function Get-TodoSnapshot {
    param(
        [string]$DataPath,
        [string]$Date
    )

    if ([string]::IsNullOrWhiteSpace($Date)) {
        $Date = Get-Date -Format "yyyy-MM-dd"
    }
    $data = Get-TodoDocument -DataPath $DataPath
    $plan = Get-TodoPlan -Document $data -Date $Date
    return [pscustomobject]@{
        Date = $Date
        Tasks = if ($null -eq $plan) { @() } else { @($plan.tasks) }
    }
}

function Add-TodoTask {
    param(
        [string]$DataPath,
        [string]$Date,
        [string]$Title,
        [int]$MaxTasks = 12
    )

    $cleanTitle = ([string]$Title).Trim()
    if ([string]::IsNullOrWhiteSpace($cleanTitle)) { return $false }
    if ($cleanTitle.Length -gt 80) { $cleanTitle = $cleanTitle.Substring(0, 80) }

    $data = Get-TodoDocument -DataPath $DataPath
    $plan = Get-TodoPlan -Document $data -Date $Date -Create
    if (@($plan.tasks).Count -ge $MaxTasks) { return $false }
    $task = [pscustomobject]@{
        id = [Guid]::NewGuid().ToString("N")
        title = $cleanTitle
        done = $false
        priority = 0
    }
    $plan.tasks = @($plan.tasks) + @($task)
    $data.selectedDate = $Date
    Write-DashboardJson -Path $DataPath -Value $data
    return $true
}

function Set-TodoState {
    param(
        [string]$DataPath,
        [string]$Date,
        [string]$TaskId,
        [bool]$Done
    )

    $data = Get-TodoDocument -DataPath $DataPath
    $plan = Get-TodoPlan -Document $data -Date $Date
    if ($null -eq $plan) { return }
    foreach ($task in @($plan.tasks)) {
        if ([string]$task.id -eq $TaskId) { $task.done = $Done }
    }
    Write-DashboardJson -Path $DataPath -Value $data
}

function Set-TodoTitle {
    param(
        [string]$DataPath,
        [string]$Date,
        [string]$TaskId,
        [string]$Title
    )

    $cleanTitle = ([string]$Title).Trim()
    if ([string]::IsNullOrWhiteSpace($cleanTitle)) { return $false }
    if ($cleanTitle.Length -gt 80) { $cleanTitle = $cleanTitle.Substring(0, 80) }
    $data = Get-TodoDocument -DataPath $DataPath
    $plan = Get-TodoPlan -Document $data -Date $Date
    if ($null -eq $plan) { return $false }
    foreach ($task in @($plan.tasks)) {
        if ([string]$task.id -eq $TaskId) { $task.title = $cleanTitle }
    }
    Write-DashboardJson -Path $DataPath -Value $data
    return $true
}

function Set-TodoPriority {
    param(
        [string]$DataPath,
        [string]$Date,
        [string]$TaskId,
        [int]$Priority
    )

    $data = Get-TodoDocument -DataPath $DataPath
    $plan = Get-TodoPlan -Document $data -Date $Date
    if ($null -eq $plan) { return }
    foreach ($task in @($plan.tasks)) {
        if ([string]$task.id -eq $TaskId) {
            if ($null -eq $task.PSObject.Properties["priority"]) {
                $task | Add-Member -NotePropertyName priority -NotePropertyValue $Priority -Force
            } else {
                $task.priority = $Priority
            }
        }
    }
    Write-DashboardJson -Path $DataPath -Value $data
}

function Remove-TodoTask {
    param(
        [string]$DataPath,
        [string]$Date,
        [string]$TaskId
    )

    $data = Get-TodoDocument -DataPath $DataPath
    $plan = Get-TodoPlan -Document $data -Date $Date
    if ($null -eq $plan) { return }
    $plan.tasks = @($plan.tasks | Where-Object { [string]$_.id -ne $TaskId })
    Write-DashboardJson -Path $DataPath -Value $data
}
