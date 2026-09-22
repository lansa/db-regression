<#
.SYNOPSIS
    Probes the CloudFormation behaviour that aws_stack_provision.ps1 depends on, so the v4 ->
    v5 AWS Tools migration can be judged on measurement instead of assumption.

.DESCRIPTION
    READ-ONLY. Creates nothing, deletes nothing, modifies nothing. It only calls Get-CFNStack,
    Test-CFNStack and Get-CFNStackSummary.

    Run it on a machine with the OLD modules (an agent: Windows PowerShell 5.1 + monolithic
    AWSPowerShell 4.1.554) and again on one with the NEW modules (dev box: AWS.Tools v5), then
    diff the VERDICT lines. Anything that differs is a script change you must make.

    Three behaviours are tested, all three load-bearing in aws_stack_provision.ps1:

    1. Get-CFNStack on a MISSING stack.
       Sites: lines 194 and 317, 'catch [System.InvalidOperationException]'. This is how the
       script decides a stack does not exist and proceeds to create it. If the exception type
       changes, the catch stops matching and the failure surfaces as an unhandled error in the
       middle of a provision. Two sub-questions, both of which must hold:
         a. is the error TERMINATING (so try/catch sees it at all), and
         b. is it an InvalidOperationException (so the TYPED catch matches).
       (a) matters more than it looks: aws_stack_provision.ps1 sets
       $ErrorActionPreference = 'Continue' at line 14, so a merely non-terminating error would
       skip the catch entirely and fall through with $null, and the script would then try to
       delete a stack that is not there. The probe therefore runs under BOTH 'Continue' and
       'Stop'.

    2. (Get-CFNStack ...).StackStatus.Value on an EXISTING stack.
       Sites: lines 52, 182, 306. If StackStatus becomes a plain string rather than a
       ConstantClass, .Value silently yields $null, the CREATE_COMPLETE comparison never
       matches, and cfn_stack_status spins for its full 180 x 20s = 1 hour before failing.
       That is the same class of break as .ImageState -> .State in cookbooks e362488.

    3. Test-CFNStack -Status DELETE_IN_PROGRESS on a MISSING stack.
       Site: line 74, the remove_cfn_stack wait loop. It must RETURN $false for a stack that is
       gone. If it throws instead, remove_cfn_stack dies rather than completing.

    4. How to tell "no such stack" apart from every OTHER failure.
       Not a migration question - a defect that exists under v4 today. AWS raises
       InvalidOperationException for missing credentials, denied permissions, throttling and
       connectivity failures as well as for a missing stack, so the typed catch at lines 194 and
       317 cannot distinguish them: on a credentials failure it concludes the stack is absent and
       calls New-CFNStack. This test measures the two candidate discriminators:
         a. the AWS ErrorCode carried by the inner Amazon service exception - present for a
            service-side "does not exist", absent entirely for a client-side credentials error.
         b. Test-CFNStack with no -Status, which answers "does this stack exist" by RETURN VALUE
            and so needs no exception at all. If it returns $true for an existing stack (even one
            in ROLLBACK_COMPLETE) and $false for a missing one, the try/catch can go away.
            The decisive case is a stack that has been DELETED and is looked up by name:
            CloudFormation keeps those visible to ListStacks for 90 days while refusing
            DescribeStacks on them, and aws_stack_provision.ps1 deletes a stack and then
            immediately re-checks the same name.

.PARAMETER Region
    Defaults to us-east-1, matching Set-DefaultAWSRegion in the real script.

.PARAMETER ExistingStackName
    A stack that DOES exist, used only for test 2. If omitted, the first stack found in the
    account is used, read-only. Test 2 is skipped if the account has no stacks.

.PARAMETER ProfileName
    A stored AWS credential profile to use. Needed on the build agents, where an interactive
    logon has no credentials of its own - the release pipeline supplies them. Run without it
    first: if the preflight fails it lists the profiles and environment variables it can see.

.PARAMETER UseAwsTools
    Explicitly import AWS.Tools.* before testing, so this run measures the MODULAR v5 module set
    even on a machine that also has the monolithic AWSPowerShell installed.

    The agents need both families: the cookbooks bake scripts import AWS.Tools.*, while the
    'AWS Tools for Windows PowerShell Script' release task reinstalls the monolithic AWSPowerShell
    to CurrentUser scope any time it does not find it. With both present every AWS cmdlet name is
    exported twice, and which one an auto-loading script gets is decided by PSModulePath scan
    order - not by anything in this repo. So run this script BOTH ways on the same agent and diff
    the VERDICT blocks: without the switch you measure what aws_stack_provision.ps1 gets today,
    with it you measure what it would get if the scan order ever changed.

    An explicit Import-Module beats auto-loading, which is the whole point - it is also the fix
    the real script should adopt once the two VERDICT blocks are known to agree.

.PARAMETER TestBadCredentials
    Adds test 4c: repeat the probes in a CHILD process holding AWS's documented example keys, to
    prove a credentials failure is distinguishable from a missing stack. Off by default because
    it deliberately provokes failed authentication attempts, which some accounts alert on. It
    creates nothing and cannot affect this session's credentials - the keys only ever exist in
    the child.

.EXAMPLE
    # On the agent (old modules):
    powershell -NoProfile -File .\Test-CfnExceptionBehaviour.ps1
    # On the dev box (AWS.Tools v5):
    pwsh -NoProfile -File .\Test-CfnExceptionBehaviour.ps1
#>
[CmdletBinding()]
param(
    [string]$Region = 'us-east-1',
    [string]$ExistingStackName,
    [string]$ProfileName,
    [switch]$UseAwsTools,
    [switch]$TestBadCredentials
)

# Not 'Stop': the point is to observe the cmdlets' own behaviour, including whether they
# terminate on their own. Individual probes set their own preference deliberately.
$ErrorActionPreference = 'Continue'

function Write-Section($text) {
    Write-Host ''
    Write-Host "=== $text ===" -ForegroundColor Cyan
}

function Get-ExceptionChain($exception) {
    # The typed catch matches on the exception's own type and its base types, so the whole
    # inner chain is worth seeing - a service exception wrapped in something else behaves
    # very differently from the same exception thrown directly.
    $chain = @()
    $current = $exception
    $guard = 0
    while ($current -and $guard -lt 10) {
        $chain += $current.GetType().FullName
        $current = $current.InnerException
        $guard++
    }
    return $chain
}

function Get-AwsServiceException($exception) {
    # Walk the inner chain for the AWS SDK's own exception - the one carrying ErrorCode. Matched
    # by SHAPE, not by type name: the SDK assembly and namespace differ between the monolithic
    # v4 module and AWS.Tools v5, and this script has to give comparable answers on both.
    $current = $exception
    $guard = 0
    while ($current -and $guard -lt 10) {
        if ($current.PSObject.Properties['ErrorCode'] -and $current.GetType().FullName -like 'Amazon.*') {
            return $current
        }
        $current = $current.InnerException
        $guard++
    }
    return $null
}

# --- Environment ------------------------------------------------------------------------------
Write-Section '0. Environment'
Write-Host "PSVersion : $($PSVersionTable.PSVersion)  ($($PSVersionTable.PSEdition))"
Write-Host "Host exe  : $((Get-Process -Id $PID).Path)"

if ($UseAwsTools) {
    # Must happen before ANY AWS cmdlet is called, or auto-loading will already have bound the
    # names to whichever family it found first and this run would silently measure that one.
    # AWS.Tools.Common carries Set-DefaultAWSRegion and Set-AWSCredential; CloudFormation carries
    # the three cmdlets under test.
    foreach ($needed in 'AWS.Tools.Common', 'AWS.Tools.CloudFormation') {
        try {
            Import-Module $needed -ErrorAction Stop
        } catch {
            Write-Host "Could not import ${needed}: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ''
            # "But I installed it" is the usual reaction, and the usual cause is that it was
            # installed somewhere this process cannot see: -Scope CurrentUser puts it under the
            # INSTALLING user's profile, not the agent service account's, and the pwsh module
            # path (Documents\PowerShell) is never read by Windows PowerShell 5.1 at all. So
            # report the identity, the search path, and where copies actually are on disk.
            Write-Host "Running as   : $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)" -ForegroundColor Yellow
            Write-Host 'PSModulePath (only these directories are searched):' -ForegroundColor Yellow
            $env:PSModulePath -split ';' | Where-Object { $_ } | ForEach-Object { Write-Host "   $_" }

            Write-Host 'AWS.Tools copies found on disk:' -ForegroundColor Yellow
            $roots = @(
                (Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules')          # 5.1 AllUsers
                (Join-Path $env:ProgramFiles 'PowerShell\Modules')                 # pwsh AllUsers
                (Join-Path $env:ProgramFiles 'PowerShell\7\Modules')
                "$env:SystemRoot\system32\config\systemprofile\Documents\WindowsPowerShell\Modules"
                "$env:SystemRoot\SysWOW64\config\systemprofile\Documents\WindowsPowerShell\Modules"
            )
            # Every user profile, to catch an install done under an interactive logon while the
            # agent service runs as somebody else.
            Get-ChildItem "$env:SystemDrive\Users" -Directory -ErrorAction Ignore | ForEach-Object {
                $roots += (Join-Path $_.FullName 'Documents\WindowsPowerShell\Modules')
                $roots += (Join-Path $_.FullName 'Documents\PowerShell\Modules')
            }
            $found = $false
            foreach ($root in ($roots | Select-Object -Unique)) {
                $hit = Get-ChildItem (Join-Path $root 'AWS.Tools.*') -Directory -ErrorAction Ignore
                foreach ($h in $hit) {
                    $found = $true
                    $onPath = ($env:PSModulePath -split ';') -contains $root
                    # Documents\PowerShell is the pwsh-only path - visible to pwsh 7, invisible
                    # to the 5.1 that this task always runs under.
                    $note = if ($onPath) { 'on PSModulePath' }
                            elseif ($root -like '*\Documents\PowerShell\Modules') { 'PWSH-ONLY PATH - 5.1 cannot see this' }
                            else { 'NOT on this process PSModulePath' }
                    Write-Host "   $($h.FullName)  [$note]"
                }
            }
            if (-not $found) {
                Write-Host '   None anywhere - they were never installed on this machine.'
            }
            Write-Host ''
            Write-Host 'Install with -Scope AllUsers so both shells and every account see them:' -ForegroundColor Yellow
            Write-Host "   Install-Module AWS.Tools.Common,AWS.Tools.CloudFormation -Scope AllUsers -Force" -ForegroundColor Yellow
            Write-Host 'Or drop -UseAwsTools to measure the monolithic module instead.' -ForegroundColor Yellow
            exit 1
        }
    }
    Write-Host 'Modules   : AWS.Tools.* imported EXPLICITLY (-UseAwsTools)'
} else {
    Write-Host 'Modules   : resolved by AUTO-LOADING, exactly as aws_stack_provision.ps1 does'
}

foreach ($cmdletName in 'Get-CFNStack', 'Test-CFNStack', 'Get-CFNStackSummary') {
    $cmd = Get-Command $cmdletName -ErrorAction Ignore
    if ($cmd) {
        Write-Host ("{0,-22} -> {1} {2}" -f $cmdletName, $cmd.ModuleName, $cmd.Module.Version)
    } else {
        Write-Host "$cmdletName -> NOT FOUND. Install the AWS modules before running this." -ForegroundColor Red
        exit 1
    }
}

Set-DefaultAWSRegion -Region $Region -Scope Script
Write-Host "Region    : $Region"

if ($ProfileName) {
    Set-AWSCredential -ProfileName $ProfileName -Scope Script
    Write-Host "Profile   : $ProfileName"
}

# --- Credential preflight ----------------------------------------------------------------------
# This has to come first and has to be separate. A credentials or region failure can surface as
# its own exception, and if that were mistaken for 'stack not found' the whole test would report
# a confident, wrong answer. Get-CFNStackSummary lists stacks without naming one, so it cannot
# fail with not-found - if it throws here, the problem is auth or connectivity, not the probe.
Write-Section '1. Credential preflight (must pass, or every result below is meaningless)'
$allStacks = $null
try {
    # ListStacks reports deleted stacks for 90 days, and Get-CFNStack on one of those throws
    # not-found - which would silently turn test 2 into a second copy of test 1. Keep the
    # unfiltered list too: the deleted entries are the specimens test 4c needs.
    $everyStack = @(Get-CFNStackSummary -ErrorAction Stop)
    $allStacks = @($everyStack | Where-Object { $_.StackStatus -notlike 'DELETE_*' })
    # For 4c the name must be genuinely free. This pipeline deletes and recreates stacks under
    # the SAME name, so a DELETE_COMPLETE summary very often has a live stack sharing its name -
    # and testing that name would just re-measure the live one and report a meaningless $true.
    $liveNames = @($allStacks | ForEach-Object { $_.StackName })
    $deletedStacks = @($everyStack |
                       Where-Object { "$($_.StackStatus)" -eq 'DELETE_COMPLETE' -and
                                      $liveNames -notcontains $_.StackName })
    Write-Host "Credentials OK. $($allStacks.Count) live stack summaries readable in $Region." -ForegroundColor Green
} catch {
    Write-Host 'Could not list stacks - credentials, region or connectivity are wrong.' -ForegroundColor Red
    Write-Host "  $($_.Exception.GetType().FullName): $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Fix that first; a not-found probe cannot be distinguished from an auth failure.' -ForegroundColor Red

    # NOTE THE TYPE ABOVE. AWS raises InvalidOperationException for "no credentials" as well as
    # for "no such stack", which is why this preflight exists as a separate, named step. The
    # typed catch in aws_stack_provision.ps1 (lines 194 and 317) cannot tell the two apart: with
    # broken credentials it concludes the stack is absent and calls New-CFNStack.
    Write-Host ''
    Write-Host 'Credential sources visible from HERE:' -ForegroundColor Yellow
    $profiles = @(Get-AWSCredential -ListProfileDetail -ErrorAction Ignore)
    if ($profiles) {
        $profiles | ForEach-Object { Write-Host "  profile: $($_.ProfileName)  ($($_.StoreTypeName))" }
        Write-Host '  Re-run with -ProfileName <name>.' -ForegroundColor Yellow
    } else {
        Write-Host '  No stored credential profiles for this user.'
    }
    foreach ($v in 'AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_SESSION_TOKEN', 'AWS_PROFILE', 'AWS_DEFAULT_REGION') {
        $val = [Environment]::GetEnvironmentVariable($v)
        if ($val) {
            # Masked - never print a secret into a build log or a pasted transcript.
            $shown = if ($v -like '*SECRET*' -or $v -like '*TOKEN*' -or $v -like '*KEY_ID*') {
                "set, $($val.Length) chars"
            } else { $val }
            Write-Host "  env ${v}: $shown"
        }
    }
    Write-Host ''
    Write-Host 'On an agent, an interactive logon has no credentials of its own - the release' -ForegroundColor Yellow
    Write-Host 'pipeline supplies them. Either pass -ProfileName, or run this as a step in the' -ForegroundColor Yellow
    Write-Host 'pipeline itself, which is the more faithful test.' -ForegroundColor Yellow
    exit 1
}

# A name that cannot exist. Random suffix so a real stack can never collide with it, and the
# prefix makes it obvious in CloudTrail that this was a deliberate probe.
$missingStack = "zz-probe-does-not-exist-$([guid]::NewGuid().ToString('N').Substring(0,12))"
Write-Host "Missing-stack probe name: $missingStack"

# --- Test 1: Get-CFNStack on a missing stack -----------------------------------------------------
Write-Section '2. Get-CFNStack on a MISSING stack (drives catch [System.InvalidOperationException])'

$test1Results = @()
foreach ($eap in 'Continue', 'Stop') {
    # 'Continue' is what aws_stack_provision.ps1 actually runs under (its line 14).
    $label = "ErrorActionPreference = $eap"
    $caughtTyped = $false
    $caughtAtAll = $false
    $exceptionType = $null
    $chain = @()
    $errorId = $null
    $returned = $null

    & {
        $ErrorActionPreference = $eap
        try {
            $script:returned = Get-CFNStack -StackName $missingStack
            # Reached only if the cmdlet did NOT terminate.
        }
        catch [System.InvalidOperationException] {
            $script:caughtTyped = $true
            $script:caughtAtAll = $true
            $script:exceptionType = $_.Exception.GetType().FullName
            $script:chain = Get-ExceptionChain $_.Exception
            $script:errorId = $_.FullyQualifiedErrorId
        }
        catch {
            $script:caughtAtAll = $true
            $script:exceptionType = $_.Exception.GetType().FullName
            $script:chain = Get-ExceptionChain $_.Exception
            $script:errorId = $_.FullyQualifiedErrorId
        }
    }

    Write-Host ''
    Write-Host "  --- $label ---"
    if (-not $caughtAtAll) {
        # Non-terminating: try/catch never fires, execution falls straight through.
        Write-Host '    Terminating?                     : NO - try/catch did NOT fire' -ForegroundColor Red
        Write-Host "    Returned                         : $(if ($null -eq $returned) { '$null' } else { $returned.GetType().Name })"
        if ($Error.Count) {
            Write-Host "    Error stream                     : $($Error[0].Exception.GetType().FullName)"
        }
    } else {
        Write-Host '    Terminating?                     : YES'
        Write-Host "    Exception type                   : $exceptionType"
        Write-Host "    Inner chain                      : $($chain -join ' -> ')"
        Write-Host "    FullyQualifiedErrorId            : $errorId"
        $colour = if ($caughtTyped) { 'Green' } else { 'Red' }
        Write-Host "    catch [InvalidOperationException]: $(if ($caughtTyped) { 'MATCHES' } else { 'DOES NOT MATCH' })" -ForegroundColor $colour
    }

    $test1Results += [pscustomobject]@{
        Preference  = $eap
        Terminating = $caughtAtAll
        TypedCatch  = $caughtTyped
        Type        = $exceptionType
    }
}

# --- Test 2: StackStatus.Value on an existing stack ------------------------------------------------
Write-Section '3. (Get-CFNStack).StackStatus.Value on an EXISTING stack'

$stackForStatus = $ExistingStackName
if (-not $stackForStatus) {
    if ($allStacks.Count) {
        $stackForStatus = $allStacks[0].StackName
        Write-Host "No -ExistingStackName given; using the first stack found: $stackForStatus"
    } else {
        Write-Host 'SKIPPED - no stacks in this account/region. Re-run with -ExistingStackName.' -ForegroundColor Yellow
    }
}

$statusVerdict = 'SKIPPED'
if ($stackForStatus) {
    try {
        $stack = Get-CFNStack -StackName $stackForStatus -ErrorAction Stop
        $statusProperty = $stack.StackStatus
        Write-Host "  Stack                 : $stackForStatus"
        Write-Host "  StackStatus type      : $($statusProperty.GetType().FullName)"
        Write-Host "  StackStatus (ToString): $statusProperty"

        # The script reads .Value. On a ConstantClass that is the string; on a plain string
        # there is no .Value and the expression silently yields $null.
        $hasValue = $null -ne $statusProperty.PSObject.Properties['Value']
        $valueRead = $statusProperty.Value
        Write-Host "  Has a .Value property : $hasValue"
        Write-Host "  .Value reads as       : $(if ($null -eq $valueRead) { '$null  <-- script comparisons will NEVER match' } else { $valueRead })"

        if ($null -eq $valueRead) {
            $statusVerdict = 'BROKEN - .StackStatus.Value is $null; use .StackStatus directly'
            Write-Host "  RESULT: .Value is null - lines 52/182/306 must drop '.Value'" -ForegroundColor Red
        } else {
            $statusVerdict = 'OK - .StackStatus.Value still yields the status string'
            Write-Host '  RESULT: .Value still works.' -ForegroundColor Green
        }
    } catch {
        $statusVerdict = "ERROR - $($_.Exception.GetType().Name)"
        Write-Host "  Could not read $stackForStatus : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# --- Test 3: Test-CFNStack on a missing stack --------------------------------------------------------
Write-Section '4. Test-CFNStack -Status DELETE_IN_PROGRESS on a MISSING stack (remove_cfn_stack loop)'

$testCfnVerdict = $null
try {
    $ErrorActionPreference = 'Stop'
    $testResult = Test-CFNStack -StackName $missingStack -Status 'DELETE_IN_PROGRESS'
    $testCfnVerdict = "RETURNED $testResult"
    if ($testResult -eq $false) {
        Write-Host '  Returned $false - the remove_cfn_stack wait loop exits correctly.' -ForegroundColor Green
    } else {
        Write-Host "  Returned '$testResult' for a stack that does not exist - loop would not exit." -ForegroundColor Red
    }
} catch {
    $testCfnVerdict = "THREW $($_.Exception.GetType().FullName)"
    Write-Host "  THREW instead of returning: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "    $($_.Exception.Message)"
    Write-Host '  remove_cfn_stack (line 74) would abort rather than complete.' -ForegroundColor Red
} finally {
    $ErrorActionPreference = 'Continue'
}

# --- Test 4: discriminating "no such stack" from every other failure --------------------------------
Write-Section '5. Telling "no such stack" apart from a credentials/permissions/network failure'

# 4a. Does the missing-stack exception carry an AWS ErrorCode?
# A service-side "does not exist" is an AmazonCloudFormationException with ErrorCode
# 'ValidationError'. A client-side credentials failure never reaches the service, so it has no
# Amazon exception in its chain at all - which makes the presence of ErrorCode a discriminator
# where the .NET exception type is not.
$missingErrorCode = 'NONE'
$missingHttpStatus = 'n/a'
try {
    $ErrorActionPreference = 'Stop'
    Get-CFNStack -StackName $missingStack | Out-Null
} catch {
    $svc = Get-AwsServiceException $_.Exception
    if ($svc) {
        $missingErrorCode = $svc.ErrorCode
        if ($svc.PSObject.Properties['StatusCode']) { $missingHttpStatus = $svc.StatusCode }
        Write-Host "  AWS exception         : $($svc.GetType().FullName)"
        Write-Host "  ErrorCode             : $missingErrorCode" -ForegroundColor Green
        Write-Host "  HTTP status           : $missingHttpStatus"
        Write-Host "  Message               : $($svc.Message)"
    } else {
        Write-Host '  No Amazon service exception in the chain - the call never reached AWS.' -ForegroundColor Red
        Write-Host "  Outer message         : $($_.Exception.Message)"
    }
} finally {
    $ErrorActionPreference = 'Continue'
}

# 4b. Test-CFNStack with NO -Status: an existence check by RETURN VALUE rather than by exception.
# This is the candidate replacement for the try/catch at lines 194 and 317. It has to be right in
# BOTH directions, and the existing-stack case matters most: the stack this account has right now
# is in ROLLBACK_COMPLETE, and if Test-CFNStack treats "exists but unhealthy" as $false the
# rewrite would delete-and-recreate where the current code merely recreates.
Write-Host ''
$existsMissing = 'n/a'
$existsPresent = 'n/a'
try {
    $ErrorActionPreference = 'Stop'
    $existsMissing = Test-CFNStack -StackName $missingStack
    Write-Host "  Test-CFNStack (no -Status), MISSING  stack -> $existsMissing"
} catch {
    $existsMissing = "THREW $($_.Exception.GetType().Name)"
    Write-Host "  Test-CFNStack (no -Status), MISSING  stack -> $existsMissing" -ForegroundColor Red
} finally {
    $ErrorActionPreference = 'Continue'
}

if ($stackForStatus) {
    try {
        $ErrorActionPreference = 'Stop'
        $existsPresent = Test-CFNStack -StackName $stackForStatus
        $colour = if ($existsPresent) { 'Green' } else { 'Red' }
        Write-Host "  Test-CFNStack (no -Status), EXISTING stack -> $existsPresent  ($stackForStatus, $statusProperty)" -ForegroundColor $colour
        if (-not $existsPresent) {
            Write-Host '    NOTE: $false for a stack that exists - Test-CFNStack is filtering on' -ForegroundColor Red
            Write-Host '    status, so it cannot be used as a bare existence check.' -ForegroundColor Red
        }
    } catch {
        $existsPresent = "THREW $($_.Exception.GetType().Name)"
        Write-Host "  Test-CFNStack (no -Status), EXISTING stack -> $existsPresent" -ForegroundColor Red
    } finally {
        $ErrorActionPreference = 'Continue'
    }
}

# 4c. The edge that decides whether 4b is actually safe: a stack that HAS been deleted, looked
# up BY NAME. CloudFormation keeps deleted stacks visible to ListStacks for 90 days but refuses
# DescribeStacks on them by name, so the answer depends entirely on which API Test-CFNStack uses
# underneath - and 4b only measured a name that never existed at all. This matters because
# aws_stack_provision.ps1 deletes a stack and then immediately re-checks the same name: if
# Test-CFNStack reports a DELETE_COMPLETE stack as $true, a rewrite built on it would declare a
# successful delete a failure, and would also send an existing-stack path at a stack that
# Get-CFNStack cannot read.
Write-Host ''
$deletedByName = 'NO DELETE_COMPLETE STACK AVAILABLE TO TEST'
if ($deletedStacks.Count) {
    # Guaranteed by the filter in the preflight to have no live stack sharing its name.
    $deletedName = $deletedStacks[0].StackName
    try {
        $ErrorActionPreference = 'Stop'
        $deletedResult = Test-CFNStack -StackName $deletedName
        $deletedByName = "$deletedResult"
        $colour = if ($deletedResult) { 'Red' } else { 'Green' }
        Write-Host "  Test-CFNStack (no -Status), DELETED  stack by name -> $deletedResult  ($deletedName)" -ForegroundColor $colour
        if ($deletedResult) {
            Write-Host '    UNSAFE: a deleted stack reports as existing, so Test-CFNStack cannot' -ForegroundColor Red
            Write-Host '    replace the post-delete verification.' -ForegroundColor Red
        }
    } catch {
        $deletedByName = "THREW $($_.Exception.GetType().Name)"
        Write-Host "  Test-CFNStack (no -Status), DELETED  stack by name -> $deletedByName  ($deletedName)" -ForegroundColor Red
    } finally {
        $ErrorActionPreference = 'Continue'
    }
} else {
    Write-Host "  $deletedByName" -ForegroundColor Yellow
    Write-Host '    (none in the last 90 days in this region - re-run after a delete.)'
}

# 4d. Opt-in: prove a credentials failure looks different. Run in a CHILD process so the bogus
# keys cannot leak into this session and contaminate every test above.
$badCredVerdict = 'NOT TESTED (pass -TestBadCredentials)'
if ($TestBadCredentials) {
    Write-Host ''
    Write-Host '  --- with deliberately invalid credentials (child process) ---'
    # The child must resolve the same family as its parent, or the two halves of this run would
    # be measuring different modules.
    $childImport = if ($UseAwsTools) { 'Import-Module AWS.Tools.Common, AWS.Tools.CloudFormation' } else { '' }
    # AWS's own documented example key pair, so nobody reading a build log mistakes it for real.
    $childScript = @"
`$ErrorActionPreference = 'Stop'
foreach (`$v in 'AWS_ACCESS_KEY_ID','AWS_SECRET_ACCESS_KEY','AWS_SESSION_TOKEN','AWS_PROFILE') {
    Remove-Item "env:`$v" -ErrorAction Ignore
}
$childImport
Set-DefaultAWSRegion -Region '$Region' -Scope Script
Set-AWSCredential -AccessKey 'AKIAIOSFODNN7EXAMPLE' ``
                  -SecretKey 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY' -Scope Script
foreach (`$probe in 'Get-CFNStack','Test-CFNStack') {
    try {
        & `$probe -StackName '$missingStack' | Out-Null
        Write-Output "`$probe|NO EXCEPTION|"
    } catch {
        `$svc = `$_.Exception
        `$code = ''
        `$guard = 0
        while (`$svc -and `$guard -lt 10) {
            if (`$svc.PSObject.Properties['ErrorCode'] -and `$svc.GetType().FullName -like 'Amazon.*') {
                `$code = `$svc.ErrorCode; break
            }
            `$svc = `$svc.InnerException; `$guard++
        }
        Write-Output "`$probe|`$(`$_.Exception.GetType().FullName)|`$code"
    }
}
"@
    $childLines = @(& (Get-Process -Id $PID).Path -NoProfile -Command $childScript 2>&1)
    foreach ($line in $childLines) {
        $text = "$line"
        if ($text -match '^\S+\|') {
            $parts = $text -split '\|'
            $codeShown = if ($parts[2]) { $parts[2] } else { '(no AWS ErrorCode - never reached AWS)' }
            Write-Host ("    {0,-14} {1}  ErrorCode={2}" -f $parts[0], $parts[1], $codeShown)
        }
    }
    # The headline: same .NET type as a missing stack, different (or absent) ErrorCode.
    $badCredVerdict = ($childLines | Where-Object { "$_" -match '^Get-CFNStack\|' }) -join ''
    if (-not $badCredVerdict) { $badCredVerdict = 'child process produced no parsable result' }
}

# --- Verdict ------------------------------------------------------------------------------------
Write-Section '6. VERDICT (diff these lines between the old and new module sets)'
$awsModule = (Get-Command Get-CFNStack).Module
$resolution = if ($UseAwsTools) { 'explicit import' } else { 'auto-load' }
Write-Host "MODULE          : $($awsModule.Name) $($awsModule.Version)  [PS $($PSVersionTable.PSVersion) $($PSVersionTable.PSEdition), $resolution]"
foreach ($r in $test1Results) {
    Write-Host ("GET-CFNSTACK    : EAP={0,-8} terminating={1,-5} typedCatchMatches={2,-5} type={3}" -f `
        $r.Preference, $r.Terminating, $r.TypedCatch, $r.Type)
}
Write-Host "STACKSTATUS     : $statusVerdict"
Write-Host "TEST-CFNSTACK   : $testCfnVerdict"
Write-Host "MISSING ERRCODE : $missingErrorCode  (HTTP $missingHttpStatus)"
Write-Host "EXISTS-CHECK    : Test-CFNStack no -Status -> missing=$existsMissing existing=$existsPresent deleted-by-name=$deletedByName"
Write-Host "BAD CREDENTIALS : $badCredVerdict"

$continueRow = $test1Results | Where-Object { $_.Preference -eq 'Continue' }
Write-Host ''
if ($continueRow.Terminating -and $continueRow.TypedCatch) {
    Write-Host "OVERALL: catch [System.InvalidOperationException] STILL WORKS under this module set." -ForegroundColor Green
} else {
    Write-Host "OVERALL: catch [System.InvalidOperationException] IS BROKEN under this module set." -ForegroundColor Red
    Write-Host '         aws_stack_provision.ps1 lines 194 and 317 must be rewritten to catch' -ForegroundColor Red
    Write-Host "         $($continueRow.Type) instead (or to test for the stack without relying on an exception)." -ForegroundColor Red
}
