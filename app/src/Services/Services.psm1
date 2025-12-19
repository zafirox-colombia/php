using module '..\Core\PhpCore.psm1'
using module '..\Domain\Interfaces\Interfaces.psm1'
using module '..\Domain\ValueObjects\SystemPath.psm1'
using module '..\Domain\Enums\Enums.psm1'
using module '..\Application\Services\EnvironmentService.psm1'

# -----------------------------------------------------------------------------
# Application Services
# -----------------------------------------------------------------------------

class DownloadManagerService {
    # Dependencies (Abstract)
    [IDownloadSource]$DownloadSource
    [IPhpRepository]$Repository

    DownloadManagerService([IPhpRepository]$repo, [IDownloadSource]$source) {
        $this.Repository = $repo
        $this.DownloadSource = $source
    }

    # Use Case: Get Available Versions
    [PhpVersion[]] GetAvailableToDownload() {
        return $this.DownloadSource.GetAvailableVersions()
    }

    # Use Case: Download and Install Version
    [void] DownloadAndInstall([PhpVersion]$version) {
        # 1. Definir rutas (Domain Logic delegated to Repository helper or kept here if specific)
        # Vamos a asumir una lógica estándar:
        $zipPath = Join-Path $env:TEMP "$($version.FullLabel).zip"
        
        # Check if already installed
        if ($this.Repository.Exists($version)) {
            Write-Warning "La versión $($version.VersionString) ya está instalada."
            return
        }

        # 2. Descargar
        Write-Progress -Activity "Descargando PHP $($version.VersionString)" -Status "Bajando..."
        $this.DownloadSource.Download($version, $zipPath)

        # 3. Validar Descarga (Basic Size Check)
        $fileInfo = Get-Item $zipPath
        if ($fileInfo.Length -lt 1000000) { # < 1MB
             Remove-Item $zipPath -Force
             throw "El archivo descargado parece corrupto ($($fileInfo.Length) bytes)."
        }

        # 4. Descomprimir e Instalar
        # Nota: La lógica de descompresión podría estar en una abstracción IZipService,
        # pero para simplificar, usaremos Expand-Archive nativo aqui o lo moveriamos al Repository.
        # Dado que el repositorio maneja "Install", podríamos moverlo allá?
        # Clean Arch: El repositorio maneja persistencia. Descomprimir es persistencia de archivos.
        
        # Vamos a extraer directamente al path del repositorio
        # Pero el repositorio en este diseño es IPhpRepository. 
        # Idealmente agregamos un método InstallFromZip al IPhpRepository para encapsular IO.
        
        # Como IPhpRepository.Install no estaba definido del todo para Zip, lo haremos híbrido aquí por ahora,
        # O usaremos FileSystemRepository logic si casteamos, pero eso rompe abstracción.
        # Lo mejor: Expandir a un path temporal y mover, o expandir directo.
        
        # Usaremos propiedad rootpath del repo (si es accesible) o asumimos contrato implícito.
        # Mejor: expandir y luego registrar.
        
        # Para mantener simpleza similar al original, asumiremos acceso a RootPath o calculamos destino.
        # Como definimos IPhpRepository con RootPath, lo usamos.
        
        $extractPath = Join-Path $this.Repository.RootPath $version.VersionString
        
        Write-Progress -Activity "Instalando PHP $($version.VersionString)" -Status "Descomprimiendo..."
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        
        # 5. Limpieza
        Remove-Item $zipPath -Force
        Write-Progress -Activity "Instalando PHP" -Completed
    }
}

class VersionManagerService {
    [IPhpRepository]$Repository
    [EnvironmentService]$EnvService
    [string]$CurrentLink

    VersionManagerService([IPhpRepository]$repo, [EnvironmentService]$envSvc) {
        $this.Repository = $repo
        $this.EnvService = $envSvc
        
        $rawLink = Join-Path $repo.RootPath "..\current" 
        # Canonicalize to remove ".." (e.g. C:\php\current)
        $this.CurrentLink = [System.IO.Path]::GetFullPath($rawLink)
    }

    [PhpVersion[]] GetInstalledVersions() {
        return $this.Repository.GetInstalledVersions()
    }

    [void] ActivateVersion([PhpVersion]$version) {
        # 1. Validar que exista en repo
        if (-not ($this.Repository.Exists($version))) {
            throw "La versión $($version.VersionString) no está instalada o no se encuentra."
        }
        
        # 1.5 Validar Binario (php.exe) - CRITICAL FIX
        $binary = Join-Path $version.Path "php.exe"
        if (-not (Test-Path $binary)) {
            # Try to find if it's nested (Common with some zips)
            $subItems = Get-ChildItem -Path $version.Path -Directory
            if ($subItems.Count -eq 1) {
                 $nested = Join-Path $subItems[0].FullName "php.exe"
                 if (Test-Path $nested) {
                     throw "La versión parece estar anidada en una subcarpeta '$($subItems[0].Name)'. Por favor reinstale o mueva los archivos."
                 }
            }
            throw "Version Invalida: No se encontro 'php.exe' en $($version.Path). Es posible que haya descargado el CODIGO FUENTE (src) en lugar de los binarios. Por favor instale una version VS16/VS17 x64."
        }

        # 2. Actualizar Symlink (Esto requiere acceso a IO, podríamos moverlo a un FileSystemHelper o mantener aqui)
        # Por ahora lo mantenemos aquí o delegamos a un servicio infra legacy helper si es complejo.
        # EnvironmentService es solo para PATH/EnvVars. Symlinks son Filesystem.
        # Usaremos lógica nativa aquí por simplicidad de migración, pero idealmente: IFileSystem.CreateSymlink
        
        $this.CreateSymlink($this.CurrentLink, $version.Path)

        # 3. Asegurar PATH usando EnvironmentService Secure
        $this.EnvService.AddToPath([PathScope]::User, $this.CurrentLink)

        # 4. Handle WAMP/System Path Conflicts (Priority Fix)
        # If another PHP is in System PATH, it overrides User PATH.
        # We must prepend to System PATH to win, which requires Admin.
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if ($isAdmin) {
             # Check if we need to override system path (optimization: only if not present? AddToPath handles that)
             # But we generally want to avoid polluting System path unless necessary.
             # Heuristic: If System Path has "wamp" or "php", we claim priority.
             $sysPath = $this.EnvService.GetCurrentPath([PathScope]::System)
             if ($sysPath.ToString() -match "wamp|xampp|php") {
                 try {
                    $this.EnvService.AddToPath([PathScope]::System, $this.CurrentLink)
                 } catch {
                    Write-Warning "Could not update System Path despite Admin privileges: $_"
                 }
             }
        }
    }

    hidden [bool] IsAdmin() {
        return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    hidden [void] CreateSymlink([string]$link, [string]$target) {
        if (Test-Path $link) {
            if ((Get-Item $link) -is [System.IO.DirectoryInfo]) { cmd /c rmdir "$link" } else { Remove-Item $link -Force }
        }
        cmd /c mklink /J "$link" "$target" | Out-Null
    }

    [PhpVersion] GetActiveVersion() {
        if (Test-Path $this.CurrentLink) {
             $item = Get-Item $this.CurrentLink
             # Resolve target
             $realPath = $null
             if ($item.LinkType -match "Junction|SymbolicLink" -or $item.Attributes.ToString() -match "ReparsePoint") {
                $realPath = $item.Target
             }
             
             if ($realPath) {
                # Logic to find version that matches path
                 $installed = $this.Repository.GetInstalledVersions()
                 foreach ($v in $installed) {
                    if ($null -eq $v.Path) { continue }
                    if ($v.Path.TrimEnd('\') -eq $realPath.TrimEnd('\')) {
                        $v.Status = [PhpStatus]::Active
                        return $v
                    }
                 }
             }
        }
        return $null
    }
}
