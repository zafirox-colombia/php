# tests/Characterization_SystemPath.ps1

# Bootstrap
using module '..\app\src\Domain\ValueObjects\SystemPath.psm1'

Write-Host "--- Characterization Test: SystemPath VO ---" -ForegroundColor Cyan

# 1. Parsing
$raw = "C:\Windows;C:\Program Files\PHP\; C:\Users\Test "
$path = [SystemPath]::new($raw)
$entries = $path.GetEntries()

if ($entries.Count -ne 3) { Write-Error "Parsing failed count. Expected 3, got $($entries.Count)" }
if ($entries[1] -ne "C:\Program Files\PHP") { Write-Error "Normalization failed. Expected 'C:\Program Files\PHP', got '$($entries[1])'" }

Write-Host " [x] Parsing & Normalization" -ForegroundColor Green

# 2. Immutability & Append
$newPath = $path.Append("C:\NewDir")
if ($path.Contains("C:\NewDir")) { Write-Error "Immutability violation! Original changed." }
if (-not $newPath.Contains("C:\NewDir")) { Write-Error "Append failed." }

Write-Host " [x] Immutability & Append" -ForegroundColor Green

# 3. Prepend & Move
$prependPath = $path.Prepend("C:\NewFast")
$entriesPre = $prependPath.GetEntries()
if ($entriesPre[0] -ne "C:\NewFast") { Write-Error "Prepend failed. First item is $($entriesPre[0])" }

# 4. Remove
$removedPath = $path.Remove("C:\Program Files\PHP")
if ($removedPath.Contains("C:\Program Files\PHP")) { Write-Error "Remove failed." }

Write-Host " [x] Prepend & Remove" -ForegroundColor Green

Write-Host "--- All Tests Passed ---" -ForegroundColor Cyan
