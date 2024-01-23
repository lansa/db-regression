[string[]] $Roots = @("C:\Program Files (x86)\AZURESQL", "C:\Program Files (x86)\LANSA", "C:\Program Files (x86)\MYSQL", "C:\Program Files (x86)\SQLANYWHERE", "C:\Program Files (x86)\ORACLE")

Push-Location
Write-Host "Pulling all repos..."

try {
    foreach ($Root in $Roots) {
        Set-Location "$Root\lansa\VersionControl"
        Get-Location | Write-Host
        git pull | Write-Host
        Write-Host
    }
} catch {
    if ( $LASTEXITCODE -ne 0) {
        cmd /c exit $LASTEXITCODE
    } else {
        cmd /c exit 99
    }
    throw "pull-all-repos error"
} finally {
    Pop-Location
}
cmd /c exit 0