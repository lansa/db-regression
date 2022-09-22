[string[]] $Roots = @("C:\Program Files (x86)\AZURESQL", "C:\Program Files (x86)\LANSA", "C:\Program Files (x86)\SQLANYWHERE", "C:\Program Files (x86)\ORACLE")

Push-Location

foreach ($Root in $Roots) {
    Set-Location "$Root\lansa\VersionControl"
    Get-Location | Write-Host
    git pull | Write-Host
    Write-Host
}

Pop-Location