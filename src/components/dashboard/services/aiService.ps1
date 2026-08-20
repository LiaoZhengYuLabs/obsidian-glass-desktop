function Get-AIAgentSnapshot {
    param([string]$DataPath)

    $data = Read-DashboardJson -Path $DataPath
    if ($null -eq $data) {
        return [pscustomobject]@{
            CurrentProject = "NO PROJECT DATA"
            CurrentTask = "AI SERVICE OFFLINE"
            Progress = 0
            Agents = @()
        }
    }

    return [pscustomobject]@{
        CurrentProject = [string]$data.currentProject
        CurrentTask = [string]$data.currentTask
        Progress = [Math]::Max(0, [Math]::Min(100, [int]$data.progress))
        Agents = @($data.agents)
    }
}
