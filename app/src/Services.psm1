using module '.\Domain.psm1'
using module '.\Infrastructure.psm1'

class DownloadManagerService {
    [WebScraperService]$Scraper
    [FileSService]$FileSystem

    DownloadManagerService([FileSService]$fs, [WebScraperService]$scr) {
        $this.FileSystem = $fs
        $this.Scraper = $scr
    }

    [PhpVersion[]] GetAvailableToDownload() {
        return $this.Scraper.GetAvailableVersions()
    }

    [void] DownloadAndInstall([PhpVersion]$version) {
        # 1. Definir rutas
        $zipPath = Join-Path $env:TEMP "$($version.FullLabel).zip"
        $extractPath = Join-Path $this.FileSystem.VersionsRoot $version.VersionString # ej: C:\php\versions\8.4.2

        if (Test-Path $extractPath) {
            Write-Warning "La versión $($version.VersionString) ya existe en $extractPath"
            return
        }

        # 2. Descargar
        Write-Progress -Activity "Descargando PHP $($version.VersionString)" -Status "Bajando $zipPath..."
        Invoke-WebRequest -Uri $version.DownloadUrl -OutFile $zipPath -UseBasicParsing

        # 3. Validar Descarga (Check básico de tamaño)
        $fileInfo = Get-Item $zipPath
        if ($fileInfo.Length -lt 1000000) {
            # < 1MB
            throw "El archivo descargado parece corrupto o muy pequeño ($($fileInfo.Length) bytes)."
        }

        # 4. Descomprimir
        Write-Progress -Activity "Instalando PHP $($version.VersionString)" -Status "Descomprimiendo..."
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

        # 5. Limpieza
        Remove-Item $zipPath -Force
        Write-Progress -Activity "Instalando PHP" -Completed
    }
}

class VersionManagerService {
    [FileSService]$FileSystem
    [EnvironmentService]$Env
    [string]$CurrentLink

    VersionManagerService([FileSService]$fs, [EnvironmentService]$envSvc) {
        $this.FileSystem = $fs
        $this.Env = $envSvc
        $this.CurrentLink = Join-Path $fs.VersionsRoot "..\current" # C:\php\current
    }

    [PhpVersion[]] GetInstalledVersions() {
        return $this.FileSystem.GetInstalledVersions()
    }

    [void] ActivateVersion([PhpVersion]$version) {
        # 1. Validar que exista
        if (-not (Test-Path $version.Path)) {
            throw "La ruta de la versión no existe: $($version.Path)"
        }

        # 2. Actualizar Symlink
        $this.FileSystem.CreateSymlink($this.CurrentLink, $version.Path)

        # 3. Asegurar PATH
        # Normalizamos la ruta para comparación
        $targetInPath = $this.CurrentLink
        $this.Env.PrependToPath($targetInPath)
    }

    [PhpVersion] GetActiveVersion() {
        if (Test-Path $this.CurrentLink) {
            $target = Get-Item $this.CurrentLink
            # Si es symlink/junction, obtener target
            if ($target.LinkType -match "Junction|SymbolicLink") {
                $realPath = $target.Target
                # En PowerShell Core target es una propiedad, en WinPS a veces hay que parsear. 
                # Asumimos que FileSService maneja la estructura limpia.
                
                # Buscar cual de las instaladas coincide con el path real
                $installed = $this.GetInstalledVersions()
                foreach ($v in $installed) {
                    # Comparación simple de paths
                    if ($v.Path.TrimEnd("\") -eq $realPath.TrimEnd("\")) {
                        $v.Status = [PhpStatus]::Active
                        return $v
                    }
                }
            }
        }
        return $null
    }
}
