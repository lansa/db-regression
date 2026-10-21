# Copies the MTBVOM UserLists directory (including sub directories) over the UserLists directory of each
# LANSA instance, overwriting existing files.
# Workaround required for the pipeline when running as NT AUTHORITY\SYSTEM.
# The script throws, before copying anything, if the parent directory of any target does not exist; the
# UserLists directory itself is created if missing.

$ErrorActionPreference = 'Stop'

$source = 'C:\Program Files (x86)\LANSA\LANSA\MTBVOM\UserLists'

$targets = @(
    'C:\Program Files (x86)\LANSA\LANSA\UserLists',
    'C:\Program Files (x86)\AZURESQL\LANSA\UserLists',
    'C:\Program Files (x86)\ORACLE\LANSA\UserLists',
    'C:\Program Files (x86)\MYSQL\LANSA\UserLists',
    'C:\Program Files (x86)\SQLANYWHERE\LANSA\UserLists',
    'C:\DEV\Work\LANSA\UserLists'
)

if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    throw "Source directory not found: $source"
}

foreach ($target in $targets) {
    $parent = Split-Path -Path $target -Parent
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        throw "Parent directory $parent of target $target does not exist"
    }
}

$failed = 0

foreach ($target in $targets) {
    try {
        if (-not (Test-Path -LiteralPath $target -PathType Container)) {
            Write-Host "Creating $target"
            New-Item -Path $target -ItemType Directory -Force | Out-Null
        }

        Write-Host "Copying $source to $target"
        Copy-Item -Path (Join-Path $source '*') -Destination $target -Recurse -Force
    }
    catch {
        $failed++
        Write-Error "Failed to copy to ${target}: $($_.Exception.Message)" -ErrorAction Continue
    }
}

if ($failed -gt 0) {
    Write-Host "MirrorUserLists completed with $failed failure(s)"
    exit 1
}

Write-Host "MirrorUserLists completed successfully"
