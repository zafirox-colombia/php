using module "C:\php\app\src\Domain.psm1"
using module "C:\php\app\src\Infrastructure.psm1"

$ErrorActionPreference = "Stop"

Write-Host "Probando clases de Dominio..."
try {
    $v = [PhpVersion]::new()
    $v.ParseLabel("php-8.4.2-nts-Win32-vs17-x64")
    if ($v.VersionString -eq "8.4.2" -and $v.Architecture -eq "x64" -and $v.ThreadSafety -eq "NTS") {
        Write-Host " [OK] Domain Parsing Logic" -ForegroundColor Green
    }
    else {
        Write-Error " [FAIL] Domain Parsing Logic: $($v.ToString())"
    }
}
catch {
    Write-Error "Failed to use Domain classes: $_"
}

Write-Host "Probando WebScraperService (Live Request)..."
try {
    $scraper = [WebScraperService]::new()
    $versions = $scraper.GetAvailableVersions()
    if ($versions.Count -gt 0) {
        Write-Host " [OK] Scraper encontró $($versions.Count) versiones." -ForegroundColor Green
        $versions | Select-Object -First 3 | ForEach-Object { Write-Host "   - $($_.FullLabel)" }
    }
    else {
        Write-Warning " [WARN] Scraper no encontró versiones (¿Cambio en HTML?)"
    }
}
catch {
    Write-Error " [FAIL] Scraper Exception: $_"
}
