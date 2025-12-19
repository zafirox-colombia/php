using module '..\src\Core\PhpCore.psm1'

# -----------------------------------------------------------------------------
# Mocks for Testing (In-Memory)
# -----------------------------------------------------------------------------

class InMemoryRepository : IPhpRepository {
    [System.Collections.ArrayList]$_store

    InMemoryRepository() : base("C:\Temp\MockPhp") {
        $this._store = [System.Collections.ArrayList]::new()
    }

    [void] EnsureRootExists() { 
        # No-op en memoria
    }

    [void] AddFakeVersion([PhpVersion]$v) {
        $v.Status = [PhpStatus]::Installed
        $this._store.Add($v) | Out-Null
    }

    [PhpVersion[]] GetInstalledVersions() {
        return [PhpVersion[]]$this._store.ToArray()
    }

    [bool] Exists([PhpVersion]$version) {
        foreach ($v in $this._store) {
            if ($v.VersionString -eq $version.VersionString) { return $true }
        }
        return $false
    }
}

class MockDownloadSource : IDownloadSource {
    [PhpVersion[]]$_available

    MockDownloadSource() {
        $this._available = @()
    }

    [void] SetAvailable([PhpVersion[]]$versions) {
        $this._available = $versions
    }

    [PhpVersion[]] GetAvailableVersions() {
        return $this._available
    }

    [void] Download([PhpVersion]$version, [string]$destinationPath) {
        # Simulate download by creating a dummy file
        "DUMMY CONTENT" | Set-Content $destinationPath
    }
}

class MockEnvironmentManager : IEnvironmentManager {
    [string]$_currentPath
    [string]$_symlinkTarget

    MockEnvironmentManager() {
        $this._currentPath = "C:\Windows;C:\Windows\System32"
    }

    [string] GetPath() {
        return $this._currentPath
    }

    [void] SetPath([string]$newPath) {
        $this._currentPath = $newPath
        Write-Host "[MockEnv] PATH updated to: $newPath"
    }

    [void] PrependToPath([string]$targetDir) {
        # Logic duplicated for simulation, or simplified
        $this._currentPath = "$targetDir;$($this._currentPath)"
    }

    [void] CreateSymlink([string]$linkPath, [string]$targetPath) {
        $this._symlinkTarget = $targetPath
        Write-Host "[MockEnv] Symlink created at $linkPath -> $targetPath"
    }

    [string] GetSymlinkTarget([string]$linkPath) {
        return $this._symlinkTarget
    }
}
