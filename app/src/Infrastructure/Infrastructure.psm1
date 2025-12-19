using module '..\Core\PhpCore.psm1'

# -----------------------------------------------------------------------------
# Concrete Implementation: File System Repository
# -----------------------------------------------------------------------------
class FileSystemRepository : IPhpRepository {
    
    FileSystemRepository([string]$root) : base($root) {
    }

    [void] EnsureRootExists() {
        if (-not (Test-Path $this.RootPath)) {
            New-Item -Path $this.RootPath -ItemType Directory -Force | Out-Null
        }
    }

    [PhpVersion[]] GetInstalledVersions() {
        $versions = @()
        if (Test-Path $this.RootPath) {
            $dirs = Get-ChildItem -Path $this.RootPath -Directory
            foreach ($d in $dirs) {
                # Validar si parece una carpeta de PHP
                if ($d.Name -match "php-" -or $d.Name -match "\d+\.\d+") {
                    $v = [PhpVersion]::new()
                    $v.FullLabel = $d.Name
                    $v.Path = $d.FullName
                    $v.Status = [PhpStatus]::Installed
                    $v.ParseLabel($d.Name)
                    $versions += $v
                }
            }
        }
        return $versions
    }

    [bool] Exists([PhpVersion]$version) {
        # Prioridad: Si viene el Path absoluto (desde frontend), validarlo.
        if (-not [string]::IsNullOrEmpty($version.Path)) {
            return Test-Path $version.Path
        }
        
        # Fallback: Intentar construir path con VersionString (pero esto falla con prefijos php-)
        $target = Join-Path $this.RootPath $version.VersionString
        if (Test-Path $target) { return $true }

        # Fallback 2: Intentar con prefijo estándar si falla
        $targetStd = Join-Path $this.RootPath "php-$($version.VersionString)"
        return Test-Path $targetStd
    }

    # Helper para obtener path destino
    [string] GetInstallPath([PhpVersion]$version) {
        return Join-Path $this.RootPath $version.VersionString
    }
}

# -----------------------------------------------------------------------------
# Concrete Implementation: Web Scraper
# -----------------------------------------------------------------------------
class WebScraperSource : IDownloadSource {
    
    WebScraperSource() {
        $this.BaseUrl = "https://windows.php.net/download/"
    }

    [PhpVersion[]] GetAvailableVersions() {
        # NOTA: En un caso real, podríamos inyectar una interfaz IHttpClient para mockear la red.
        # Aquí simplificamos usando Invoke-WebRequest directo, pero encapsulado.
        
        $response = Invoke-WebRequest -Uri $this.BaseUrl -UseBasicParsing
        $links = $response.Links | Where-Object { $_.href -match "\.zip$" -and $_.href -match "php-" }
        
        $versions = @()
        foreach ($link in $links) {
            $href = $link.href
            $fileName = $href.Split("/")[-1].Replace(".zip", "")
            
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

    [void] Download([PhpVersion]$version, [string]$destinationPath) {
        Invoke-WebRequest -Uri $version.DownloadUrl -OutFile $destinationPath -UseBasicParsing
    }
}

# -----------------------------------------------------------------------------
# Concrete Implementation: Windows Environment
# -----------------------------------------------------------------------------
class WindowsEnvironmentManager : IEnvironmentManager {
    
    WindowsEnvironmentManager() {
        $this.Scope = "User"
    }

    [string] GetPath() {
        return [Environment]::GetEnvironmentVariable("Path", $this.Scope)
    }

    [void] SetPath([string]$newPath) {
        [Environment]::SetEnvironmentVariable("Path", $newPath, $this.Scope)
    }

    [void] PrependToPath([string]$targetDir) {
        $current = $this.GetPath()
        # Normalizar separadores y quitar vacíos
        $parts = $current -split ";" | Where-Object { $_ -ne "" }
        
        # Eliminar si ya existe para moverlo al principio
        $parts = $parts | Where-Object { $_.TrimEnd("\") -ne $targetDir.TrimEnd("\") }
        
        $newParts = @($targetDir) + $parts
        $newPath = $newParts -join ";"
        
        if ($current -ne $newPath) {
            $this.SetPath($newPath)
        }
    }

    [void] CreateSymlink([string]$linkPath, [string]$targetPath) {
        if (Test-Path $linkPath) {
            # Verificar si es directory y remover
            if ((Get-Item $linkPath) -is [System.IO.DirectoryInfo]) {
                 cmd /c rmdir "$linkPath"
            } else {
                 Remove-Item -Path $linkPath -Force
            }
        }
        
        # Crear Junction para directorios (más robusto en Windows local)
        cmd /c mklink /J "$linkPath" "$targetPath" | Out-Null
    }

    [string] GetSymlinkTarget([string]$linkPath) {
        if (Test-Path $linkPath) {
            $item = Get-Item $linkPath
            if ($item.LinkType -match "Junction|SymbolicLink" -or $item.Attributes.ToString() -match "ReparsePoint") {
                return $item.Target
            }
        }
        return $null
    }
}
