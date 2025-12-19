using module '..\Core\PhpCore.psm1'
using module '..\Domain\Enums\Enums.psm1'
using module '..\Infrastructure\Infrastructure.psm1'
using module '..\Services\Services.psm1'
using module '..\Infrastructure\Repositories\WindowsRegistryPathRepository.psm1'
using module '..\Infrastructure\Strategies\JsonPathBackupStrategy.psm1'
using module '..\Infrastructure\Services\JobManagerService.psm1'
using module '..\Domain\Services\PathIntegrityValidator.psm1'
using module '..\Application\Services\EnvironmentService.psm1'

# -----------------------------------------------------------------------------
# Web Server & API Handler
# -----------------------------------------------------------------------------

param (
    [int]$Port = 8085
)

# --- Load Configuration ---
$ConfigPath = "C:\php\config.json"
$Config = @{ debug = @{ server_debug_enabled = $true } }
if (Test-Path $ConfigPath) {
    try { $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json } catch {}
}
$DebugEnabled = $Config.debug.server_debug_enabled -eq $true

# --- Logging Setup ---
$LogFile = "C:\php\server_debug.log"
function Log-Server($msg) {
    if (-not $DebugEnabled) { return }
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] $msg"
    Write-Host $line -ForegroundColor Cyan
    try { Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue } catch {}
}

# Global Trap for fatal startup errors
trap {
    # Always log fatal errors regardless of debug flag
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] FATAL CRASH: $($_.Exception.Message)"
    try { Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue } catch {}
    try { Add-Content -Path $LogFile -Value "[$ts] $($_.ScriptStackTrace)" -ErrorAction SilentlyContinue } catch {}
    exit 1
}

Log-Server "--- Server Process Started ---"
Log-Server "Root Path context: $PSScriptRoot"

# --- Bootstrap Services ---
Log-Server "Initializing Services..."

# Definir Root Path (C:\php\versions)
# Estamos en src\UI, así que subir 3 niveles nos lleva a app root, pero versions está fuera de app.
# Estructura: C:\php\app\src\UI\WebServer.ps1 -> C:\php\versions
$rootPath = Join-Path "$PSScriptRoot\..\..\..\.." "versions"
$rootPath = [System.IO.Path]::GetFullPath($rootPath)

# Fallback seguro absoluto si falla la relativa (ej. ejecutado desde otro cwd)
if ($rootPath -notmatch "php") { $rootPath = "C:\php\versions" }

if (-not (Test-Path $rootPath)) {
    Log-Server "Creating Root Path: $rootPath"
    New-Item -Path $rootPath -ItemType Directory -Force | Out-Null
}

try {
    $fsRepo = [FileSystemRepository]::new($rootPath)
    $fsRepo.EnsureRootExists()

    $webSource = [WebScraperSource]::new()

    # --- Clean Arch Bootstrap (Environment) ---
    $regRepo = [WindowsRegistryPathRepository]::new()
    $backupStrat = [JsonPathBackupStrategy]::new()
    $validator = [PathIntegrityValidator]::new()
    $jobManager = [JobManagerService]::new()

    $envService = [EnvironmentService]::new($regRepo, $backupStrat, $validator)

    $downloadSvc = [DownloadManagerService]::new($fsRepo, $webSource)
    $versionSvc = [VersionManagerService]::new($fsRepo, $envService)
    
    Log-Server "Services Initialized Successfully."
} catch {
    Log-Server "Dependency Injection Failed: $_"
    throw $_
}

# --- Http Listener ---
try {
    $listener = [System.Net.HttpListener]::new()
    $listener.Prefixes.Add("http://localhost:$Port/")
    $listener.Start()
    Log-Server "HTTP Listener Started on port $Port"
} catch {
    Log-Server "Failed to start HTTP Listener: $_"
    throw $_
}

Write-Host " [Info] Press Ctrl+C to stop."

# --- Helper: Send JSON ---
function Send-JsonResponse {
    param($context, $data, $code = 200)
    $json = $data | ConvertTo-Json -Depth 5
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
    $context.Response.StatusCode = $code
    $context.Response.ContentType = "application/json"
    $context.Response.ContentLength64 = $buffer.Length
    $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
    $context.Response.Close()
}

function Send-FileResponse {
    param($context, $path)
    if (Test-Path $path) {
        $buffer = [System.IO.File]::ReadAllBytes($path)
        $ext = [System.IO.Path]::GetExtension($path)
        $mime = switch ($ext) {
            ".html" { "text/html" }
            ".css"  { "text/css" }
            ".js"   { "application/javascript" }
            ".json" { "application/json" }
            default { "application/octet-stream" }
        }
        $context.Response.ContentType = $mime
        $context.Response.ContentLength64 = $buffer.Length
        $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
        $context.Response.Close()
    } else {
        $context.Response.StatusCode = 404
        $context.Response.Close()
    }
}

# --- Request Loop ---
try {
    while ($listener.IsListening) {
        try {
            $context = $listener.GetContext()
            $request = $context.Request
            $url = $request.Url.LocalPath
            $method = $request.HttpMethod

            Write-Host " [$method] $url" -ForegroundColor DarkGray

            # --- API Routes ---
            if ($url.StartsWith("/api/")) {
                if ($url -eq "/api/versions" -and $method -eq "GET") {
                    # List all (Merged)
                    $installed = $versionSvc.GetInstalledVersions()
                    
                    # Mark active
                    $active = $versionSvc.GetActiveVersion()
                    if ($active) {
                        foreach ($v in $installed) {
                            if ($v.Path -eq $active.Path) { $v.Status = [PhpStatus]::Active }
                        }
                    }
                    
                    $response = @{
                        installed = $installed
                    }
                    Send-JsonResponse $context $response
                }
                elseif ($url -eq "/api/available" -and $method -eq "GET") {
                     $available = $downloadSvc.GetAvailableToDownload()
                     Send-JsonResponse $context $available
                }
                elseif ($url -eq "/api/install" -and $method -eq "POST") {
                    # Decode Body
                    $reader = [System.IO.StreamReader]::new($request.InputStream)
                    $body = $reader.ReadToEnd() | ConvertFrom-Json
                    
                    # Instead of blocking download, we start a job
                    $vTarget = [PhpVersion]::new()
                    $vTarget.VersionString = $body.VersionString
                    $vTarget.FullLabel = $body.FullLabel
                    $vTarget.DownloadUrl = $body.DownloadUrl
                    
                    # Define dynamic paths
                    $zipPath = Join-Path $env:TEMP "$($vTarget.FullLabel).zip"
                    $extractPath = Join-Path $fsRepo.RootPath $vTarget.FullLabel
                    
                    if ($fsRepo.Exists($vTarget)) {
                        Send-JsonResponse $context @{ error = "Version already exists" } 400
                        continue
                    }
                    
                    $jobId = $jobManager.StartInstallJob($vTarget.DownloadUrl, $zipPath, $extractPath)
                    
                    Send-JsonResponse $context @{ jobId = $jobId; message = "Installation started" }
                }
                elseif ($url -eq "/api/uninstall" -and $method -eq "POST") {
                    # Decode Body TO allow deleting a version
                    $reader = [System.IO.StreamReader]::new($request.InputStream)
                    $body = $reader.ReadToEnd() | ConvertFrom-Json
                    
                    $targetPath = $body.Path
                    
                    # Validate safety: Must be within RootPath
                    $fullRoot = [System.IO.Path]::GetFullPath($fsRepo.RootPath)
                    $fullTarget = [System.IO.Path]::GetFullPath($targetPath)
                    
                    if ($fullTarget.StartsWith($fullRoot) -and $fullTarget.Length -gt $fullRoot.Length) {
                         if (Test-Path $fullTarget) {
                             Remove-Item $fullTarget -Recurse -Force
                             Send-JsonResponse $context @{ message = "Uninstalled successfully" }
                         } else {
                             Send-JsonResponse $context @{ error = "Path not found" } 404
                         }
                    } else {
                        Send-JsonResponse $context @{ error = "Invalid path security violation" } 403
                    }
                }
                elseif ($url.StartsWith("/api/jobs/") -and $method -eq "GET") {
                     $id = $url.Replace("/api/jobs/", "")
                     $status = $jobManager.GetJobStatus($id)
                     Send-JsonResponse $context $status
                }
                elseif ($url -eq "/api/activate" -and $method -eq "POST") {
                    # Decode Body
                    $reader = [System.IO.StreamReader]::new($request.InputStream)
                    $body = $reader.ReadToEnd() | ConvertFrom-Json
                    
                    $vTarget = [PhpVersion]::new()
                    $vTarget.VersionString = $body.VersionString
                    $vTarget.Path = $body.Path
                    
                    $versionSvc.ActivateVersion($vTarget)
                    
                    Send-JsonResponse $context @{ message = "Activated successfully" }
                }
                elseif ($url -eq "/api/debug/path" -and $method -eq "GET") {
                    try {
                        # Gather Debug Info
                        $currentUser = $envService.GetCurrentPath([PathScope]::User)
                        $historyUser = $envService.GetPathHistory([PathScope]::User)
                        
                        # Fix for History being null or empty
                        $historyStrings = if ($historyUser) { $historyUser | ForEach-Object { $_.ToString() } } else { @() }
                        # Explicitly cast to array to ensure JSON is [] not {}
                        $historyList = @($historyStrings)
                        
                        $debugInfo = @{
                            Current = @{
                                User = if ($currentUser) { $currentUser.GetEntries() } else { @() }
                            }
                            History = @{
                                User = $historyList
                            }
                        }
                        Send-JsonResponse $context $debugInfo
                    } catch {
                        Write-Error "Error in /api/debug/path: $_"
                        Write-Error $_.ScriptStackTrace
                        throw $_
                    }
                }
                elseif ($url -eq "/api/diagnose/path" -and $method -eq "GET") {
                    try {
                        # 1. Get selected (active) version from PHP Manager
                        $activeVersion = $versionSvc.GetActiveVersion()
                        $selectedVersion = if ($activeVersion) { $activeVersion.VersionString } else { "Ninguna" }
                        
                        # 2. Execute php -v to get system PHP version
                        $systemPhpVersion = "No detectado"
                        $systemPhpPath = ""
                        try {
                            # Use Start-Process to capture output more reliably
                            $phpOutput = & cmd /c "php -v" 2>&1 | Out-String
                            if ($phpOutput -and $phpOutput -match "PHP (\d+\.\d+\.\d+)") {
                                $systemPhpVersion = $matches[1]
                            } elseif ($phpOutput) {
                                # Might be an error message
                                $systemPhpVersion = "Error detectando version"
                            }
                            
                            # Also get where php.exe is located
                            $whereOutput = & cmd /c "where php" 2>&1 | Out-String
                            if ($whereOutput -and $whereOutput.Trim() -ne "" -and $whereOutput -notmatch "Could not find" -and $whereOutput -notmatch "no se encuentra") {
                                $lines = $whereOutput.Trim() -split "`r?`n"
                                if ($lines -and $lines.Count -gt 0) {
                                    $systemPhpPath = $lines[0].Trim()
                                }
                            }
                        } catch {
                            $systemPhpVersion = "Error al ejecutar php -v"
                        }
                        
                        # 3. Compare versions
                        $match = ($systemPhpVersion -eq $selectedVersion)
                        
                        # 4. Get conflicting paths in System PATH
                        $conflictingPaths = @()
                        $ourPath = "C:\php\current"
                        try {
                            $sysPath = $envService.GetCurrentPath([PathScope]::System)
                            $sysEntries = $sysPath.GetEntries()
                            foreach ($entry in $sysEntries) {
                                $normalizedEntry = $entry.ToLower().TrimEnd('\')
                                $normalizedOurs = $ourPath.ToLower().TrimEnd('\')
                                
                                if ($normalizedEntry -eq $normalizedOurs) { continue }
                                
                                # Check if path contains php.exe
                                $phpExe = Join-Path $entry "php.exe"
                                if (Test-Path $phpExe) {
                                    $conflictingPaths += $entry
                                }
                            }
                        } catch {}
                        
                        # 5. Check if our path is in System PATH (and at the start)
                        $ourPathInSystem = $false
                        $ourPathIsFirst = $false
                        try {
                            $sysPathStr = ([Environment]::GetEnvironmentVariable("Path", "Machine"))
                            if ($sysPathStr -match [regex]::Escape($ourPath)) {
                                $ourPathInSystem = $true
                                $ourPathIsFirst = $sysPathStr.StartsWith($ourPath, [System.StringComparison]::OrdinalIgnoreCase)
                            }
                        } catch {}
                        
                        # 6. Build recommendation
                        $recommendation = ""
                        $status = "ok"
                        
                        if ($match) {
                            $recommendation = "La version del sistema coincide con la version seleccionada."
                            $status = "ok"
                        } elseif ($conflictingPaths.Count -gt 0 -and -not $ourPathIsFirst) {
                            $recommendation = "Se detectaron rutas PHP conflictivas en el PATH Global del sistema. Para solucionarlo, agregue 'C:\php\current' al INICIO del PATH Global (Sistema)."
                            $status = "conflict"
                        } elseif (-not $ourPathInSystem) {
                            $recommendation = "C:\php\current no esta en el PATH Global. Agreguelo manualmente para que PHP Manager tenga prioridad."
                            $status = "missing"
                        } else {
                            $recommendation = "Posible conflicto de cache. Cierre y vuelva a abrir la terminal/CMD para aplicar los cambios."
                            $status = "cache"
                        }
                        
                        $diagResult = @{
                            selectedVersion    = $selectedVersion
                            systemPhpVersion   = $systemPhpVersion
                            systemPhpPath      = $systemPhpPath
                            match              = $match
                            status             = $status
                            conflictingPaths   = $conflictingPaths
                            ourPathInSystem    = $ourPathInSystem
                            ourPathIsFirst     = $ourPathIsFirst
                            recommendation     = $recommendation
                            targetPath         = $ourPath
                        }
                        
                        Send-JsonResponse $context $diagResult
                    } catch {
                        Write-Error "Error in /api/diagnose/path: $_"
                        Send-JsonResponse $context @{ error = $_.Exception.Message } 500
                    }
                }
                elseif ($url -eq "/api/config" -and $method -eq "GET") {
                    # Read config file
                    $configPath = "C:\php\config.json"
                    if (Test-Path $configPath) {
                        $configContent = Get-Content $configPath -Raw | ConvertFrom-Json
                        Send-JsonResponse $context $configContent
                    } else {
                        # Return defaults
                        Send-JsonResponse $context @{
                            debug = @{ launcher_debug_enabled = $false; server_debug_enabled = $true }
                            server = @{ port = 8085 }
                            browser = @{ use_app_mode = $true }
                        }
                    }
                }
                elseif ($url -eq "/api/config" -and $method -eq "POST") {
                    # Save config file
                    $reader = [System.IO.StreamReader]::new($request.InputStream)
                    $body = $reader.ReadToEnd() | ConvertFrom-Json
                    
                    $configPath = "C:\php\config.json"
                    $body | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
                    
                    Send-JsonResponse $context @{ message = "Config saved successfully" }
                }
                else {
                    Send-JsonResponse $context @{ error = "Endpoint not found" } 404
                }
                continue
            }

            # --- Static Files ---
            # Default to index.html
            if ($url -eq "/") { $url = "/index.html" }
            
            # Prevent traversal
            $safePath = Join-Path "$PSScriptRoot\public" $url.TrimStart("/")
            if ($safePath -match "\.\.") { 
                 $context.Response.StatusCode = 403
                 $context.Response.Close()
                 continue 
            }

            Send-FileResponse $context $safePath
        }
        catch {
            Write-Error " [Error] Unhandled Exception via WebServer Loop: $_"
            Write-Error $_.ScriptStackTrace
            
            # Attempt to send 500 if context is still open
            if ($context -and $context.Response -and $context.Response.OutputStream) {
                try {
                    $context.Response.StatusCode = 500
                    $context.Response.Close()
                } catch {}
            }
        }
    }
}
finally {
    $listener.Stop()
    $listener.Close()
}
