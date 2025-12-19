# Launcher para PHP Manager Ultimate

# Load configuration
$ConfigPath = "$PSScriptRoot\config.json"
$Config = @{ debug = @{ launcher_debug_enabled = $false; server_debug_enabled = $true }; browser = @{ use_app_mode = $true } }
if (Test-Path $ConfigPath) {
    try { $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json } catch {}
}

$DebugEnabled = $Config.debug.launcher_debug_enabled -eq $true
$DebugLog = "C:\php\launcher_debug.log"

function Log-Debug($msg) {
    if (-not $DebugEnabled) { return }
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$ts] $msg" | Out-File -FilePath $DebugLog -Append
    Write-Host "[$ts] $msg"
}

# Clear old log if debug enabled
if ($DebugEnabled) {
    "" | Out-File -FilePath $DebugLog -Force
}
Log-Debug "=== Launcher Started ===" 

# Check admin status (informational only)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Log-Debug "Running as Admin: $isAdmin"

$ErrorActionPreference = "Continue"

# Rutas
$AppRoot = "$PSScriptRoot\app"
$ServerScript = "$AppRoot\src\UI\WebServer.ps1"
$Url = "http://localhost:8085"

Log-Debug "ServerScript: $ServerScript"
Log-Debug "ServerScript Exists: $(Test-Path $ServerScript)"

Write-Host "Iniciando PHP Manager Ultimate..." -ForegroundColor Cyan

# 1. Iniciar Servidor
$portMain = 8085
try {
    $isListening = Get-NetTCPConnection -LocalPort $portMain -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Listen' }
    Log-Debug "Port $portMain already listening: $($null -ne $isListening)"
} catch {
    Log-Debug "ERROR checking port: $($_.Exception.Message)"
    $isListening = $null
}

if (-not $isListening) {
    Log-Debug "Starting server process..."
    Write-Host "Iniciando servidor web..."
    try {
        # Launch server in minimized window
        $proc = Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass", "-File `"$ServerScript`"" -WindowStyle Minimized -PassThru
        Log-Debug "Server process started with PID: $($proc.Id)"
        
        # Wait for server to start
        Start-Sleep -Seconds 3
        
        # Verify
        $isNowListening = Get-NetTCPConnection -LocalPort $portMain -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Listen' }
        Log-Debug "After wait - Port $portMain listening: $($null -ne $isNowListening)"
    } catch {
        Log-Debug "ERROR starting server: $($_.Exception.Message)"
    }
} else {
    Log-Debug "Server already running"
    Write-Host "El servidor ya parece estar corriendo."
}

# 2. Abrir Navegador (simple approach)
Log-Debug "Launching browser..."
Write-Host " [Browser] Abriendo..." -ForegroundColor Green

# Try to find Edge or Chrome for app mode
$edgePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"

$launched = $false

if (Test-Path $edgePath) {
    Log-Debug "Using Edge app mode"
    Start-Process $edgePath -ArgumentList "--app=$Url"
    $launched = $true
} elseif (Test-Path $chromePath) {
    Log-Debug "Using Chrome app mode"
    Start-Process $chromePath -ArgumentList "--app=$Url"
    $launched = $true
}

if (-not $launched) {
    Log-Debug "Using default browser"
    Start-Process $Url
}

Log-Debug "=== Launcher Completed ==="
