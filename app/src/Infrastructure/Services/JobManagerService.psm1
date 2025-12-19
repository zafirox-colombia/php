using module '..\..\Domain\Enums\Enums.psm1'
Add-Type -AssemblyName System.IO.Compression.FileSystem

class JobManagerService {
    hidden [hashtable]$_jobs = @{}

    [string] StartInstallJob([string]$url, [string]$zipPath, [string]$extractPath) {
        $id = [Guid]::NewGuid().ToString()
        
        $sb = {
            param($u, $z, $e)
            
            function Report($pct, $msg) {
                # Prefix with [PROGRESS] to easily parse
                Write-Output "[PROGRESS] | $pct | $msg"
            }

            try {
                Report 0 "Iniciando..."
                $p = [System.IO.Path]::GetDirectoryName($z)
                if (!(Test-Path $p)) { New-Item -Path $p -ItemType Directory | Out-Null }
                
                Report 5 "Iniciando descarga..."
                
                # Manual Stream Download for Progress
                # We use .NET HttpClient for better control (or WebRequest)
                $request = [System.Net.WebRequest]::Create($u)
                $request.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
                $response = $request.GetResponse()
                
                $totalBytes = $response.ContentLength
                if ($totalBytes -eq -1) { $totalBytes = 30 * 1024 * 1024 } # Fallback est 30MB
                
                $remoteStream = $response.GetResponseStream()
                $localStream = [System.IO.File]::Create($z)
                
                $buffer = New-Object byte[] 8192
                $bytesRead = 0
                $totalRead = 0
                $lastReport = 0
                
                try {
                    do {
                        $bytesRead = $remoteStream.Read($buffer, 0, $buffer.Length)
                        $localStream.Write($buffer, 0, $bytesRead)
                        $totalRead += $bytesRead
                        
                        # Calculate pct (5% start to 40% end = 35% range)
                        # We map 0..1 to 5..40
                        if ($totalBytes -gt 0) {
                            $downloadPct = ($totalRead / $totalBytes) * 35
                            $currentGlobalPct = 5 + [int]$downloadPct
                            
                            # Report every 5% change or 1MB
                            if ($currentGlobalPct -gt $lastReport) {
                                $lastReport = $currentGlobalPct
                                $mb = [math]::Round($totalRead / 1MB, 1)
                                Report $currentGlobalPct "Descargando ($mb MB)..."
                            }
                        }
                    } while ($bytesRead -gt 0)
                } finally {
                    $localStream.Close()
                    $remoteStream.Close()
                    $response.Close()
                }

                # Validation
                if (!(Test-Path $z)) { throw "Download failed: File not found." }
                $fi = Get-Item $z
                
                if ($fi.Length -lt 1000) { # Less than 1KB
                    $content = Get-Content $z -Raw -ErrorAction SilentlyContinue
                    throw "File too small ($($fi.Length) bytes). Content sample: $($content.Substring(0, [math]::Min($content.Length, 100)))" 
                }
                
                # Check Magic Number (PK)
                $bytes = Get-Content $z -Encoding Byte -TotalCount 2
                if ($bytes[0] -ne 0x50 -or $bytes[1] -ne 0x4B) {
                    throw "Invalid ZIP header (Magic Number mismatch). The file is likely corrupt."
                }
                
                Report 40 "Preparando instalación..."
                if (!(Test-Path $e)) { New-Item -Path $e -ItemType Directory | Out-Null }
                
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                $zipType = "System.IO.Compression.ZipFile" -as [type]
                $zipExtType = "System.IO.Compression.ZipFileExtensions" -as [type]
                
                if (-not $zipType) { 
                    throw "Could not load ZipFile type" 
                }

                $zip = $zipType::OpenRead($z)
                $count = $zip.Entries.Count
                $i = 0
                
                Report 45 "Descomprimiendo archivos..."
                
                foreach ($entry in $zip.Entries) {
                    $i++
                    
                    # Safe Path Extraction
                    $destinationPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($e, $entry.FullName))
                    
                    # Ensure strict child check? Skipped for MVP but recommended
                    
                    if ($entry.Name -eq "") { 
                        # Is Directory
                        if (!(Test-Path $destinationPath)) {
                            New-Item -Path $destinationPath -ItemType Directory -Force | Out-Null
                        }
                        continue 
                    }
                    
                    $parent = [System.IO.Path]::GetDirectoryName($destinationPath)
                    if (!(Test-Path $parent)) { New-Item -Path $parent -ItemType Directory -Force | Out-Null }
                    
                    # Extension method cannot be called directly on type if using variable?
                    # [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, ...)
                    # Actually ZipFileExtensions is for Extension Methods. 
                    # Note: entries have ExtractToFile method in .NET 4.5+?
                    # $entry.ExtractToFile(...) might work if extension is loaded.
                    # But if we use static helper:
                    $zipExtType::ExtractToFile($entry, $destinationPath, $true)
                    
                    # Report periodically (every ~5%)
                    if ($i % [math]::Ceiling($count / 20) -eq 0) {
                         $step = [int](($i / $count) * 50) # 50% allocated to unzip
                         $total = 45 + $step
                         Report $total "Instalando ($([int](($i/$count)*100))%)..."
                    }
                }
                $zip.Dispose()

                # --- VALIDATION (Critical Fix) ---
                Report 96 "Validando binarios..."
                $valid = $false
                
                # Direct check
                if (Test-Path ([System.IO.Path]::Combine($e, "php.exe"))) {
                    $valid = $true
                } else {
                    # Check first level subdirectory (common in some zips)
                    $subs = Get-ChildItem -Path $e -Directory
                    if ($subs.Count -eq 1) {
                         $subPath = $subs[0].FullName
                         if (Test-Path ([System.IO.Path]::Combine($subPath, "php.exe"))) {
                             # Move files up? Or just accept nested? 
                             # Ideally we move them up to keep standardized structure.
                             # For now, let's fail if structure is unexpected or just accept it but warn?
                             # Better: Move them up so standard paths work.
                             Report 97 "Corrigiendo estructura de carpeta..."
                             Get-ChildItem -Path $subPath | Move-Item -Destination $e -Force
                             Remove-Item -Path $subPath -Force
                             $valid = $true
                         }
                    }
                }
                
                if (-not $valid) {
                     Report 99 "Error: Paquete inválido. Eliminando..."
                     Remove-Item -Path $e -Recurse -Force
                     throw "El paquete descargado NO contiene 'php.exe'. Es probable que sea una versión 'src' (Código Fuente) o corrupta. Se ha eliminado automáticamente."
                }
                
                Report 99 "Limpiando temporales..."
                Remove-Item -Path $z -Force
                
                Report 100 "Instalación completada."
            }
            catch {
                Write-Error $_.Exception.Message
                throw $_
            }
        }

        $psJob = Start-Job -ScriptBlock $sb -ArgumentList $url, $zipPath, $extractPath -Name "Install-$id"
        $this._jobs[$id] = $psJob
        return $id
    }

    [hashtable] GetJobStatus([string]$id) {
        if (-not $this._jobs.ContainsKey($id)) {
            return @{ Status = "Unknown"; Message = "Job not found"; Progress = 0 }
        }

        $job = $this._jobs[$id]
        
        # Fetch output
        $output = Receive-Job -Job $job -Keep
        
        # Parse last progress message
        $lastProgress = 0
        $lastMsg = "Procesando..."
        
        if ($output) {
            foreach ($line in $output) {
                if ($line -match "^\[PROGRESS\] \| (\d+) \| (.+)$") {
                    $lastProgress = [int]$matches[1]
                    $lastMsg = $matches[2]
                }
            }
        }
        
        # Map Status
        $status = [JobStatus]::Running
        if ($job.State -eq "Completed") { 
            $status = [JobStatus]::Completed 
            $lastProgress = 100
        }
        if ($job.State -eq "Failed") { 
            $status = [JobStatus]::Failed 
            $errors = $job.ChildJobs[0].Error
            if ($errors) {
                $lastMsg = "Error: " + $errors[0].Exception.Message
            }
        }

        return @{
            Id = $id
            Status = "$status"
            Message = "$lastMsg"
            Progress = $lastProgress
        }
    }
}
