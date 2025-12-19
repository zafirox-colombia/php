
# Enums para tipado fuerte
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

# Value Object para representar una Versión de PHP
class PhpVersion {
    [string]$VersionString  # "8.4.1"
    [string]$FullLabel      # "php-8.4.1-Win32-vs17-x64"
    [version]$VersionNumber # System.Version object
    [PhpArchitecture]$Architecture
    [PhpThreadSafety]$ThreadSafety
    [PhpStatus]$Status
    [string]$Path           # Ruta local de instalación (si existe)
    [string]$DownloadUrl    # URL de descarga (si es remota)

    # Constructor vacío para serialización
    PhpVersion() {}

    # Constructor
    PhpVersion([string]$label, [string]$url, [PhpStatus]$status) {
        $this.FullLabel = $label
        $this.DownloadUrl = $url
        $this.Status = $status
        $this.ParseLabel($label)
    }

    # Método para parsear el nombre del archivo/carpeta
    [void] ParseLabel([string]$label) {
        # Ejemplo: php-8.4.1-Win32-vs17-x64
        
        # Detectar versión
        if ($label -match "php-(\d+\.\d+\.\d+)") {
            $this.VersionString = $matches[1]
            if ($this.VersionString.Split(".").Count -eq 2) {
                $this.VersionNumber = [version]"$($this.VersionString).0"
            }
            else {
                $this.VersionNumber = [version]$this.VersionString
            }
        }

        # Detectar Arqui
        if ($label -match "x64") {
            $this.Architecture = [PhpArchitecture]::x64
        }
        else {
            $this.Architecture = [PhpArchitecture]::x86
        }

        # Detectar ZTS/NTS
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
