[string[]] $SecondaryRoots = @("C:\Program Files (x86)\AZURESQL", "C:\Program Files (x86)\LANSA", "C:\Program Files (x86)\SQLANYWHERE")

Push-Location

foreach ($Root in $SecondaryRoots) {
    Set-Location "$Root\lansa\VersionControl"
    Get-Location | Write-Host
    git pull | Write-Host
    Write-Host
}

Pop-Location