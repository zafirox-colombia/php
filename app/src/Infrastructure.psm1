using module '.\Domain.psm1'

# Interface Implícita para FileSystem
class FileSService {
    [string]$VersionsRoot

    FileSService([string]$root) {
        $this.VersionsRoot = $root
    }

    [void] EnsureRootExists() {
        if (-not (Test-Path $this.VersionsRoot)) {
            New-Item -Path $this.VersionsRoot -ItemType Directory -Force | Out-Null
        }
    }

    [PhpVersion[]] GetInstalledVersions() {
        $versions = @()
        if (Test-Path $this.VersionsRoot) {
            $dirs = Get-ChildItem -Path $this.VersionsRoot -Directory
            foreach ($d in $dirs) {
                $v = [PhpVersion]::new()
                $v.FullLabel = $d.Name
                $v.Path = $d.FullName
                $v.Status = [PhpStatus]::Installed
                $v.ParseLabel($d.Name)
                $versions += $v
            }
        }
        return $versions
    }

    [void] CreateSymlink([string]$linkPath, [string]$targetPath) {
        if (Test-Path $linkPath) {
            cmd /c rmdir "$linkPath"
        }
        cmd /c mklink /J "$linkPath" "$targetPath" | Out-Null
    }
}

# Interface Implícita para Web Scraper
class WebScraperService {
    [string]$BaseUrl = "https://windows.php.net/download/"

    [PhpVersion[]] GetAvailableVersions() {
        $response = Invoke-WebRequest -Uri $this.BaseUrl -UseBasicParsing
        $links = $response.Links | Where-Object { $_.href -match "\.zip$" -and $_.href -match "php-" }
        
        $versions = @()
        foreach ($link in $links) {
            $href = $link.href
            # href ejemplo: /downloads/releases/php-8.3.1-nts-Win32-vs16-x64.zip
            $fileName = $href.Split("/")[-1].Replace(".zip", "")
            
            # Reconstruir full URL
            if ($href.StartsWith("/")) {
                $fullUrl = "https://windows.php.net$href"
            }
            else {
                $fullUrl = "https://windows.php.net/downloads/releases/$href"
            }

            $v = [PhpVersion]::new($fileName, $fullUrl, [PhpStatus]::Available)
            $versions += $v
        }
        return $versions
    }
}

# Interface para Environment
class EnvironmentService {
    [string]$Scope = "User"

    [string] GetPath() {
        return [Environment]::GetEnvironmentVariable("Path", $this.Scope)
    }

    [void] SetPath([string]$newPath) {
        [Environment]::SetEnvironmentVariable("Path", $newPath, $this.Scope)
    }

    [void] PrependToPath([string]$targetDir) {
        $current = $this.GetPath()
        $parts = $current -split ";" | Where-Object { $_ -ne "" -and $_ -ne $targetDir }
        $newParts = @($targetDir) + $parts
        $newPath = $newParts -join ";"
        
        if ($current -ne $newPath) {
            $this.SetPath($newPath)
        }
    }
}
