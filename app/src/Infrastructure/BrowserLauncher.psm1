# BrowserLauncher.psm1
# Módulo de Infraestructura para el lanzamiento de navegadores
# Implementa patrón Strategy para desacoplar el script de la forma de abrir la UI.

class BrowserLaunchStrategy {
    hidden [string] $Url

    BrowserLaunchStrategy([string]$url) {
        $this.Url = $url
    }

    [void] Open() {
        throw "Method 'Open' must be implemented in concrete strategy."
    }
}

# Estrategia Base: Comportamiento actual (DefaultSystemBrowser)
class SystemDefaultBrowserStrategy : BrowserLaunchStrategy {
    SystemDefaultBrowserStrategy([string]$url) : base($url) {}

    [void] Open() {
        Write-Host " [Browser] Abriendo navegador predeterminado: $($this.Url)..." -ForegroundColor Gray
        Start-Process $this.Url
    }
}

# Estrategia App Mode: Lanza Edge o Chrome en modo "aplicación"
class AppModeBrowserStrategy : BrowserLaunchStrategy {
    hidden [string] $BrowserPath

    AppModeBrowserStrategy([string]$url) : base($url) {
        $this.DetectBrowser()
    }

    [void] DetectBrowser() {
        # Prioridad 1: Edge (Común en Windows)
        $edgePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
        if (-not (Test-Path $edgePath)) {
            $edgePath = "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
        }

        # Prioridad 2: Chrome
        $chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
        if (-not (Test-Path $chromePath)) {
            $chromePath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
        }

        if (Test-Path $edgePath) {
            $this.BrowserPath = $edgePath
        } elseif (Test-Path $chromePath) {
            $this.BrowserPath = $chromePath
        } else {
            # Fallback en el método Open
            $this.BrowserPath = $null
        }
    }

    [void] Open() {
        if ($null -ne $this.BrowserPath) {
            Write-Host " [Browser] Abriendo App Mode con: $($this.BrowserPath)..." -ForegroundColor Cyan
            # Argumentos para modo app
            $args = @("--app=$($this.Url)", "--new-window")
            Start-Process -FilePath $this.BrowserPath -ArgumentList $args
        } else {
            Write-Host " [Warning] No se detectó Edge ni Chrome compatibles. Usando fallback..." -ForegroundColor Yellow
            $fallback = [SystemDefaultBrowserStrategy]::new($this.Url)
            $fallback.Open()
        }
    }
}

# Contexto / Servicio
class BrowserLauncherService {
    hidden [BrowserLaunchStrategy] $Strategy

    BrowserLauncherService([BrowserLaunchStrategy]$strategy) {
        $this.Strategy = $strategy
    }

    [void] Launch() {
        if ($null -eq $this.Strategy) {
            throw "BrowserStrategy no ha sido definida."
        }
        $this.Strategy.Open()
    }
}
