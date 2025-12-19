# src/Domain/Enums/Enums.psm1

# Scope of environment variable modification
enum PathScope {
    Process
    User
    System # Requires elevation
}

# Result of integrity check
enum IntegrityStatus {
    Valid
    Warning # Contains duplicates or non-canonical paths
    Critical # Contains illegal characters or emptied path
}

# Status of async jobs
enum JobStatus {
    Pending
    Running
    Completed
    Failed
}

# Re-exporting or redefining Architecture if needed to decouple from Legacy PhpCore
# For now, we will use PhpArchitecture from Core, but ideally it should be here.
# Let's define a clean Architecture enum for the Domain.
enum Architecture {
    x86
    x64
}
