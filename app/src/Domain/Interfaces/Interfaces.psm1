# src/Domain/Interfaces/Interfaces.psm1
using module '..\ValueObjects\SystemPath.psm1'
using module '..\Enums\Enums.psm1'

class IPathRepository {
    [SystemPath] GetPath([PathScope]$scope) { throw "Abstract" }
    [void] SetPath([PathScope]$scope, [SystemPath]$newPath) { throw "Abstract" }
}

class IPathBackupStrategy {
    [void] Backup([SystemPath]$currentPath, [PathScope]$scope) { throw "Abstract" }
    [SystemPath] GetLatestBackup([PathScope]$scope) { return $null }
    [SystemPath[]] GetHistory([PathScope]$scope) { return @() }
}

class IPathValidator {
    [IntegrityStatus] Validate([SystemPath]$path) { return [IntegrityStatus]::Valid }
    [string[]] GetValidationErrors([SystemPath]$path) { return @() }
}
