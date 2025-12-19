# src/Domain/ValueObjects/SystemPath.psm1

# Value Object representing the System PATH variable.
# Encapsulates parsing, normalization, and validation rules.
class SystemPath {
    hidden [string[]] $_entries
    hidden [string]   $_originalString

    SystemPath([string]$rawPath) {
        $this._originalString = $rawPath
        $this._entries = $this.ParseAndNormalize($rawPath)
    }

    # Helper: Parses raw string into clean array
    hidden [string[]] ParseAndNormalize([string]$input) {
        if ([string]::IsNullOrEmpty($input)) { return @() }
        
        $parts = $input -split ";"
        $clean = @()
        foreach ($p in $parts) {
            if (-not [string]::IsNullOrWhiteSpace($p)) {
                # Canonicalize: Trim spaces and trailing slashes for consistency
                $clean += $p.Trim().TrimEnd("\")
            }
        }
        return $clean
    }

    # Returns the standardized array of paths
    [string[]] GetEntries() {
        return $this._entries
    }

    # Returns true if the exact path exists (case-insensitive in Windows, but we strictly compare strings)
    [bool] Contains([string]$targetPath) {
        $normalizedTarget = $targetPath.Trim().TrimEnd("\")
        foreach ($e in $this._entries) {
            if ($e -eq $normalizedTarget) { return $true }
        }
        return $false
    }

    # Returns a NEW SystemPath with the added entry. (Immutability pattern)
    [SystemPath] Append([string]$newPath) {
        if ([string]::IsNullOrWhiteSpace($newPath)) { return $this }
        
        $normalized = $newPath.Trim().TrimEnd("\")
        
        # Avoid duplicates logic (Business Rule: Do not duplicate)
        if ($this.Contains($normalized)) {
            return $this
        }

        # Prepend or Append? Typically we want Prepend for PHP version switching to take precedence.
        # But this method implies generic Append. Let's support both or rename.
        # For this domain, Prepend is usually what we want for "Activating".
        # Let's start with basic append, and add Prepend.
        
        $newString = ($this._entries -join ";") + ";" + $normalized
        return [SystemPath]::new($newString)
    }

    [SystemPath] Prepend([string]$newPath) {
        if ([string]::IsNullOrWhiteSpace($newPath)) { return $this }
        $normalized = $newPath.Trim().TrimEnd("\")

        if ($this.Contains($normalized)) {
            # If exists, we must remove it from old position and move to front?
            # Or just return existing? For activation, we usually want to move to front.
            return $this.Remove($normalized).Prepend($normalized)
        }

        $newString = $normalized + ";" + ($this._entries -join ";")
        return [SystemPath]::new($newString)
    }

    [SystemPath] Remove([string]$targetPath) {
        $normalizedTarget = $targetPath.Trim().TrimEnd("\")
        $newEntries = $this._entries | Where-Object { $_ -ne $normalizedTarget }
        return [SystemPath]::new($newEntries -join ";")
    }

    # Formatting for export to parsing
    [string] ToString() {
        return $this._entries -join ";"
    }
}
