param (
    [Parameter(Mandatory = $false)]
    [string]
    $LansaVersion
)

[string[]] $Roots = @("C:\Program Files (x86)\AZURESQL", "C:\Program Files (x86)\LANSA", "C:\Program Files (x86)\MYSQL", "C:\Program Files (x86)\SQLANYWHERE", "C:\Program Files (x86)\ORACLE")
#[string[]] $Roots = @("C:\Program Files (x86)\ORACLE")

Push-Location

$ErrorActionPreference = 'Continue'

function Show($label, $value) { Write-Host "$label : $value" }

function Run($title, [scriptblock]$sb) {
    Write-Host ""
    Write-Host "==== $title ===="
    try {
        & $sb 2>&1 | ForEach-Object { Write-Host ("$_") }
    } catch {
        Write-Host "ERROR: $_"
    }
}

Write-Host "==== Identity / environment ===="
Show 'whoami'               (whoami)
Show 'Is64BitProcess'       ([Environment]::Is64BitProcess)
Show 'HOME (process)'       $env:HOME
Show 'HOME (Machine)'       ([Environment]::GetEnvironmentVariable('HOME','Machine'))
Show 'USERPROFILE'          $env:USERPROFILE
Show 'GIT_SSH'              $env:GIT_SSH
Show 'GIT_SSH_COMMAND'      $env:GIT_SSH_COMMAND
Show 'PATH'                 $env:PATH

Run 'where git' { where.exe git }
Run 'where ssh' { where.exe ssh }
Run 'git --version' { git --version }
Run 'git config (ssh related)' { git config --show-origin --list | Select-String -Pattern 'ssh|include' }

$dirs = @(
    'C:\Windows\System32\config\systemprofile\.ssh',
    'C:\Windows\SysWOW64\config\systemprofile\.ssh',
    'C:\ProgramData\ssh',
    'C:\Program Files\Git\etc\ssh'
)
foreach ($d in $dirs) {
    Run "dir $d" {
        if (Test-Path $d) {
            Get-ChildItem $d -Force | ForEach-Object { "{0,-30} {1,8} {2}" -f $_.Name, $_.Length, $_.LastWriteTime }
        } else { "(does not exist)" }
    }
}

Run 'ssh -G github.com' { ssh -G github.com | Select-String 'knownhostsfile|stricthostkeychecking|identityfile' }

# Replace with a repo pull-all-repos.ps1 actually pulls
$repo = 'git@github.com:lansa/db-regression.git'
$env:GIT_TRACE = '1'
Run "git ls-remote $repo" { git ls-remote $repo HEAD | Select-Object -First 20 }
Remove-Item Env:\GIT_TRACE

Run 'ssh -v -T git@github.com' { ssh -v -T -o BatchMode=yes git@github.com }

Write-Host "Pulling all repos..."

try {
    if ([string]::IsNullOrEmpty($LansaVersion) ) {
        $Branch = 'debug/paas'
    } else {
        $Branch = "L4W$($LansaVersion)"
    }

    Write-Host "Getting branch $Branch"

    foreach ($Root in $Roots) {
        # Is this actually needed?
        # Write-Host "Copy User Lists from MSSQLS IDE WRITE location to Compiler's READ location! "
        # robocopy "C:\Program Files (x86)\LANSA\LANSA\LANSA\UserLists\WBP" "$Root\lansa\UserLists\WBP" *.txt /w:2 /xo
        
        Set-Location "$Root\lansa\VersionControl"
        Get-Location | Write-Host

        git show-ref --verify --quiet refs/heads/$branch
        if ( $LASTEXITCODE -ne 0) {
            Write-Host "$Branch branch does not exist. Switching to debug/paas"
            $Branch = 'debug/paas'
        }
        Write-Host "Clean out current git state so that following operations can succeed."
        git reset --hard HEAD | Write-Host
        if ( $LASTEXITCODE -ne 0) { throw }
        git clean -f | Write-Host
        if ( $LASTEXITCODE -ne 0) { throw }
        Write-Host "Get current remote state, including any new branches"
        git fetch --all | Write-Host
        if ( $LASTEXITCODE -ne 0) { throw }
        Write-Host "Get the requested branch, including if its a new branch in this local repo"
        git checkout $Branch | Write-Host
        if ( $LASTEXITCODE -ne 0) { throw }
        Write-Host "Merge in any changes to an existing branch"
        git pull | Write-Host
        if ( $LASTEXITCODE -ne 0) { throw }
        Write-Host
    }
} catch {
    $_ | Out-Default | Write-Host
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