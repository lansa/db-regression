param (
    [Parameter(Mandatory = $false)]
    [string]
    $LansaVersion
)

[string[]] $Roots = @("C:\Program Files (x86)\AZURESQL", "C:\Program Files (x86)\LANSA", "C:\Program Files (x86)\MYSQL", "C:\Program Files (x86)\SQLANYWHERE", "C:\Program Files (x86)\ORACLE")
#[string[]] $Roots = @("C:\Program Files (x86)\AZURESQL")

Push-Location
Write-Host "Pulling all repos..."

try {
    if ([string]::IsNullOrEmpty($LansaVersion) ) {
        $Branch = 'debug/paas'
    } else {
        $Branch = "L4W$($LansaVersion)"
    }

    Write-Host "Getting branch $Branch"

    foreach ($Root in $Roots) {
        Set-Location "$Root\lansa\VersionControl"
        Get-Location | Write-Host
        Write-Host "Clean out current git state so that following operations can succeed."
        git reset --hard HEAD | Write-Host
        git clean -f | Write-Host
        Write-Host "Get current remote state, including any new branches"
        git fetch --all | Write-Host
        Write-Host "Get the requested branch, including if its a new branch in this local repo"
        git checkout $Branch | Write-Host
        Write-Host "Merge in any changes to an existing branch"
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