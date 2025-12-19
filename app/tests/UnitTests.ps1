# Test Runner
using module '..\src\Core\PhpCore.psm1'
using module '..\src\Services\Services.psm1'
using module '.\Mocks.psm1'

$ErrorActionPreference = "Stop"

Write-Host "==============================" -ForegroundColor Cyan
Write-Host "  PHP Manager - Unit Tests" -ForegroundColor Cyan
Write-Host "=============================="

# --------------------------------------------------
# Test 1: Domain Logic (Parsing)
# --------------------------------------------------
Write-Host "[Test 1] Domain Logic - Parsing Label"
$v = [PhpVersion]::new()
$v.ParseLabel("php-8.1.0-nts-Win32-vs16-x64")

if ($v.VersionString -eq "8.1.0" -and $v.Architecture -eq "x64" -and $v.ThreadSafety -eq "NTS") {
    Write-Host "  [PASS] Version Parsing Correct" -ForegroundColor Green
} else {
    Write-Error "  [FAIL] Parsing Logic: $($v.ToString())"
}

# --------------------------------------------------
# Test 2: Service Logic - Activation (Mocked)
# --------------------------------------------------
Write-Host "`n[Test 2] VersionManager - Activation Flow"

# Setup Mocks
$mockRepo = [InMemoryRepository]::new()
$mockEnv = [MockEnvironmentManager]::new()

# Seed Repo
$v1 = [PhpVersion]::new()
$v1.VersionString = "8.3.0"
$v1.Path = "mem:\php\8.3.0"
$mockRepo.AddFakeVersion($v1)

# Init Service
$svc = [VersionManagerService]::new($mockRepo, $mockEnv)

# Action
try {
    $svc.ActivateVersion($v1)
    
    # Assertions
    if ($mockEnv.GetSymlinkTarget("any") -eq $v1.Path) {
        Write-Host "  [PASS] Symlink Update Requested correctly" -ForegroundColor Green
    } else {
        Write-Error "  [FAIL] Symlink Target wrong: $($mockEnv.GetSymlinkTarget('any'))"
    }

    if ($mockEnv.GetPath() -match "current") {
        Write-Host "  [PASS] Path Update Requested correctly" -ForegroundColor Green
    } else {
        Write-Error "  [FAIL] Path not updated. Current: $($mockEnv.GetPath())"
    }

} catch {
    Write-Error "  [FAIL] Exception during activation: $_"
}

# --------------------------------------------------
# Test 3: Download Logic (Availability)
# --------------------------------------------------
Write-Host "`n[Test 3] DownloadManager - Availability"
$mockSource = [MockDownloadSource]::new()
$mockRepo2 = [InMemoryRepository]::new()

$vList = @(
    [PhpVersion]::new("php-8.4.0", "url", [PhpStatus]::Available),
    [PhpVersion]::new("php-8.3.0", "url", [PhpStatus]::Available)
)
$mockSource.SetAvailable($vList)

$dlSvc = [DownloadManagerService]::new($mockRepo2, $mockSource)
$results = $dlSvc.GetAvailableToDownload()

if ($results.Count -eq 2) {
    Write-Host "  [PASS] Download Source logic wired correctly" -ForegroundColor Green
} else {
    Write-Error "  [FAIL] Expected 2 versions, got $($results.Count)"
}

Write-Host "`n=============================="
Write-Host "  All Tests Completed"
Write-Host "=============================="
