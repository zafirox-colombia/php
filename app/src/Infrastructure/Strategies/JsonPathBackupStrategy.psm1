# src/Infrastructure/Strategies/JsonPathBackupStrategy.psm1
using module '..\..\Domain\Interfaces\Interfaces.psm1'
using module '..\..\Domain\ValueObjects\SystemPath.psm1'
using module '..\..\Domain\Enums\Enums.psm1'

class JsonPathBackupStrategy : IPathBackupStrategy {
    hidden [string]$_backupFile

    JsonPathBackupStrategy() {
        # Define storage path (ensure directory exists in constructor or setup)
        $this._backupFile = Join-Path "$PSScriptRoot\..\..\..\data\backups" "path_history.json"
        $this._backupFile = [System.IO.Path]::GetFullPath($this._backupFile)
    }

    hidden [object[]] LoadHistory() {
        if (Test-Path $this._backupFile) {
            return Get-Content -Path $this._backupFile -Raw | ConvertFrom-Json
        }
        return @()
    }

    hidden [void] SaveHistory([object[]]$history) {
        $history | ConvertTo-Json -Depth 5 | Set-Content -Path $this._backupFile -Force
    }

    [void] Backup([SystemPath]$currentPath, [PathScope]$scope) {
        $history = $this.LoadHistory()
        
        $entry = @{
            Timestamp = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
            Scope     = "$scope"
            Path      = $currentPath.GetEntries()
        }
        
        $history += $entry
        $this.SaveHistory($history)
    }

    [SystemPath] GetLatestBackup([PathScope]$scope) {
        $history = $this.LoadHistory()
        # Filter by scope and take last
        $filtered = $history | Where-Object { $_.Scope -eq "$scope" }
        if ($filtered.Count -gt 0) {
            $last = $filtered[-1]
            return [SystemPath]::new(($last.Path -join ";"))
        }
        return $null
    }

    [SystemPath[]] GetHistory([PathScope]$scope) {
        $history = $this.LoadHistory()
        $filtered = $history | Where-Object { $_.Scope -eq "$scope" }
        
        $result = @()
        foreach ($h in $filtered) {
             $result += [SystemPath]::new(($h.Path -join ";"))
        }
        return $result
    }
}
