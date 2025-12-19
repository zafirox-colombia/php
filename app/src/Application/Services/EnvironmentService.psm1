# src/Application/Services/EnvironmentService.psm1
using module '..\..\Domain\Interfaces\Interfaces.psm1'
using module '..\..\Domain\ValueObjects\SystemPath.psm1'
using module '..\..\Domain\Enums\Enums.psm1'

class EnvironmentService {
    hidden [IPathRepository]     $_repository
    hidden [IPathBackupStrategy] $_backup
    hidden [IPathValidator]      $_validator

    EnvironmentService([IPathRepository]$repo, [IPathBackupStrategy]$backup, [IPathValidator]$validator) {
        $this._repository = $repo
        $this._backup = $backup
        $this._validator = $validator
    }

    [SystemPath] GetCurrentPath([PathScope]$scope) {
        return $this._repository.GetPath($scope)
    }

    # Safe Update Method
    [void] UpdatePath([PathScope]$scope, [SystemPath]$newPath) {
        # 1. Validation
        $status = $this._validator.Validate($newPath)
        if ($status -eq [IntegrityStatus]::Critical) {
            $errors = $this._validator.GetValidationErrors($newPath)
            throw "PATH Integrity Check Failed: $($errors -join ", ")"
        }

        # 2. Backup
        $current = $this._repository.GetPath($scope)
        $this._backup.Backup($current, $scope)

        # 3. Persist
        $this._repository.SetPath($scope, $newPath)
    }

    [SystemPath[]] GetPathHistory([PathScope]$scope) {
        return $this._backup.GetHistory($scope)
    }

    # High-level helper for Version Manager
    [void] AddToPath([PathScope]$scope, [string]$entry) {
        $current = $this.GetCurrentPath($scope)
        # Assuming we want it at start (Prepend)
        $newPath = $current.Prepend($entry)
        
        # Only update if changed
        if ($current.ToString() -ne $newPath.ToString()) {
            $this.UpdatePath($scope, $newPath)
        }
    }
}
