# src/Infrastructure/Repositories/WindowsRegistryPathRepository.psm1
using module '..\..\Domain\Interfaces\Interfaces.psm1'
using module '..\..\Domain\ValueObjects\SystemPath.psm1'
using module '..\..\Domain\Enums\Enums.psm1'

class WindowsRegistryPathRepository : IPathRepository {
    
    [SystemPath] GetPath([PathScope]$scope) {
        $raw = ""
        if ($scope -eq [PathScope]::Process) {
            $raw = [Environment]::GetEnvironmentVariable("Path", "Process")
        }
        elseif ($scope -eq [PathScope]::User) {
             $raw = [Environment]::GetEnvironmentVariable("Path", "User")
        }
        elseif ($scope -eq [PathScope]::System) {
             $raw = [Environment]::GetEnvironmentVariable("Path", "Machine")
        }
        return [SystemPath]::new($raw)
    }

    [void] SetPath([PathScope]$scope, [SystemPath]$newPath) {
        $str = $newPath.ToString()
        if ($scope -eq [PathScope]::Process) {
            [Environment]::SetEnvironmentVariable("Path", $str, "Process")
        }
        elseif ($scope -eq [PathScope]::User) {
             [Environment]::SetEnvironmentVariable("Path", $str, "User")
        }
        elseif ($scope -eq [PathScope]::System) {
             [Environment]::SetEnvironmentVariable("Path", $str, "Machine")
        }
    }
}
