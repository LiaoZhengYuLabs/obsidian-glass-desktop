function Get-GithubSnapshot {
    param(
        [string]$DataPath,
        [string]$DashboardRoot
    )

    $config = Read-DashboardJson -Path $DataPath
    if ($null -eq $config) {
        return [pscustomobject]@{
            Repository = "NO CONFIG"
            Commits = "--"
            Branch = "--"
            LatestCommit = "GITHUB SERVICE OFFLINE"
            Project = "--"
            NeedsToken = $false
        }
    }

    $repoPath = [string]$config.repositoryPath
    if (![IO.Path]::IsPathRooted($repoPath)) {
        $repoPath = [IO.Path]::GetFullPath($DashboardRoot + "\" + $repoPath)
    }

    $repository = Split-Path -Leaf $repoPath
    $branch = "NO LOCAL REPO"
    $commits = "--"
    $latest = "Configure repositoryPath"

    $git = Get-Command git.exe -ErrorAction SilentlyContinue
    $gitMarker = $repoPath + "\.git"
    if ($null -ne $git -and (Test-Path -LiteralPath $gitMarker)) {
        $oldPreference = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"
        try {
            $inside = & $git.Source -C $repoPath rev-parse --is-inside-work-tree 2>$null
            if ($inside -eq "true") {
                $top = & $git.Source -C $repoPath rev-parse --show-toplevel 2>$null
                if (![string]::IsNullOrWhiteSpace([string]$top)) {
                    $repository = Split-Path -Leaf ([string]$top)
                }
                $branch = [string](& $git.Source -C $repoPath branch --show-current 2>$null)
                $commits = [string](& $git.Source -C $repoPath rev-list --count HEAD 2>$null)
                $latest = [string](& $git.Source -C $repoPath log -1 --pretty=format:"%h  %s" 2>$null)
            }
        } finally {
            $ErrorActionPreference = $oldPreference
        }
    }

    return [pscustomobject]@{
        Repository = $repository
        Commits = $commits
        Branch = $branch
        LatestCommit = $latest
        Project = [string]$config.project
        NeedsToken = ![string]::IsNullOrWhiteSpace([string]$config.remote)
    }
}
