
# -----------------------------------------------------------------------------
# Core Domain Definitions
# -----------------------------------------------------------------------------

# --- Enums ---
enum PhpArchitecture {
    x86
    x64
}

enum PhpThreadSafety {
    NTS # Non Thread Safe
    ZTS # Thread Safe
}

enum PhpStatus {
    Available # Disponible para descargar
    Installed # Instalado localmente
    Active    # Actualmente en uso (PATH)
}

# --- Value Objects (DTOs) ---

class PhpVersion {
    [string]$VersionString
    [string]$FullLabel
    [version]$VersionNumber
    [PhpArchitecture]$Architecture
    [PhpThreadSafety]$ThreadSafety
    [PhpStatus]$Status
    [string]$Path           # Local Path
    [string]$DownloadUrl    # Remote URL

    PhpVersion() {}

    PhpVersion([string]$label, [string]$url, [PhpStatus]$status) {
        $this.FullLabel = $label
        $this.DownloadUrl = $url
        $this.Status = $status
        $this.ParseLabel($label)
    }

    [void] ParseLabel([string]$label) {
        # 1. Formato estándar o variantes con prefijo php- (incluyendo test-pack, nts, etc)
        # Busca "php-" seguido de cualquier cosa y luego digitos.digitos
        # Ejemplo: php-8.4.1, php-test-pack-8.5.1
        if ($label -match "php-.*?(\d+\.\d+(\.\d+)?)") {
            $this.VersionString = $matches[1]
        }
        # 2. Formato inicio numérico simple: 8.4, 8.4.1
        elseif ($label -match "^(\d+\.\d+(\.\d+)?)") {
             $this.VersionString = $matches[1]
        }
        
        # 3. Fallback: Buscar cualquier patrón de versión X.Y.Z en el string
        if ([string]::IsNullOrEmpty($this.VersionString)) {
            if ($label -match "(\d+\.\d+(\.\d+)?)") {
                 $this.VersionString = $matches[1]
            }
        }
        # Fallback: Usar todo el label si no hay match claro, pero es arriesgado. 
        # Mejor dejar null si no parece version, pero para "8.4" el de arriba funciona.
        
        if ($null -ne $this.VersionString) {
            # Handle versions like 8.4 vs 8.4.1
            if ($this.VersionString.Split(".").Count -eq 2) {
                $this.VersionNumber = [version]"$($this.VersionString).0"
            }
            else {
                $this.VersionNumber = [version]$this.VersionString
            }
        }

        if ($label -match "x64") {
            $this.Architecture = [PhpArchitecture]::x64
        }
        else {
            # Default to x86 unless x64 is explicit? Or x64 default nowadays?
            # Let's keep x86 default for safety if unknown or detect from binary if possible (expensive).
            # For "8.4" folder we don't know. Let's assume x64 if modern? 
            # No, keep logic: if not x64, it is x86.
            $this.Architecture = [PhpArchitecture]::x86
        }

        if ($label -match "nts") {
            $this.ThreadSafety = [PhpThreadSafety]::NTS
        }
        else {
            $this.ThreadSafety = [PhpThreadSafety]::ZTS
        }
    }

    [string] ToString() {
        return "$($this.VersionString) ($($this.ThreadSafety), $($this.Architecture))"
    }
}

# --- Interfaces (Abstract Base Classes) ---
# PowerShell 5/7 classes don't support 'interface' keyword, so we use empty virtual methods
# or throw "NotImplementedException".

class IPhpRepository {
    [string]$RootPath

    IPhpRepository([string]$root) {
        $this.RootPath = $root
    }

    [void] EnsureRootExists() { throw "Not Implemented" }
    
    [PhpVersion[]] GetInstalledVersions() { throw "Not Implemented" }
    
    [void] Install([string]$zipPath, [PhpVersion]$version) { throw "Not Implemented" }
    
    [void] Delete([PhpVersion]$version) { throw "Not Implemented" }

    [bool] Exists([PhpVersion]$version) { throw "Not Implemented" }
}

class IDownloadSource {
    [string]$BaseUrl

    [PhpVersion[]] GetAvailableVersions() { throw "Not Implemented" }
    
    [void] Download([PhpVersion]$version, [string]$destinationPath) { throw "Not Implemented" }
}

class IEnvironmentManager {
    [string]$Scope

    [string] GetPath() { throw "Not Implemented" }
    
    [void] SetPath([string]$newPath) { throw "Not Implemented" }
    
    [void] PrependToPath([string]$targetDir) { throw "Not Implemented" }

    [void] CreateSymlink([string]$linkPath, [string]$targetPath) { throw "Not Implemented" }

    [string] GetSymlinkTarget([string]$linkPath) { throw "Not Implemented" }
}
