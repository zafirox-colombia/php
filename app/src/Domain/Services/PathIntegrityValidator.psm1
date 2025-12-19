# src/Domain/Services/PathIntegrityValidator.psm1
using module '..\ValueObjects\SystemPath.psm1'
using module '..\Enums\Enums.psm1'
using module '..\Interfaces\Interfaces.psm1'

class PathIntegrityValidator : IPathValidator {
    
    [IntegrityStatus] Validate([SystemPath]$path) {
        $errors = $this.GetValidationErrors($path)
        if ($errors.Count -eq 0) {
            return [IntegrityStatus]::Valid
        }
        
        # Determine severity
        if ($errors -match "Illegal") {
            return [IntegrityStatus]::Critical
        }
        return [IntegrityStatus]::Warning
    }

    [string[]] GetValidationErrors([SystemPath]$path) {
        $errors = @()
        $entries = $path.GetEntries()

        if ($entries.Count -eq 0) {
            $errors += "Critical: Path is empty."
        }

        foreach ($entry in $entries) {
            if ([string]::IsNullOrWhiteSpace($entry)) {
                 $errors += "Warning: Empty entry detected."
            }
            # Simple check for illegal chars (wild implementation)
            if ($entry -match "[<>\*]") {
                 $errors += "Critical: Illegal characters in entry '$entry'"
            }
        }
        
        # Check for massive duplication
        $unique = $entries | Select-Object -Unique
        if ($entries.Count -gt ($unique.Count + 5)) {
            $errors += "Warning: High duplication detected ($($entries.Count - $unique.Count) duplicates)."
        }

        return $errors
    }
}
