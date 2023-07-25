<#
.SYNOPSIS

Runs the database regression test

An overview of these tests may be found here: https://www.evernote.com/l/AA1k-ryIaDRLVp6stZIM-eNQvEf1uY4Lyw8/

IMPORTANT:" To be run in a new instance created from the baked image, NOT while creating the image itself.

.EXAMPLE
When originally written, started by only importing to the Primary environment, which needed to be followed by manual compiles:
.\db-test.ps1 -PrimaryOnly $true
Now the tests in are in git and the git repo just needs to be setup. And then compiles can be run through this script for
all environments and also run the tests (default is to run the tests):
.\db-test.ps1 -Compile $true
Then a second run to import and compile the Secondary environments with testing driven from the Primary environment:
.\db-test.ps1
And when there is only a runtime change, you just want to run the tests:
.\db-test.ps1 -Import $false -Compile $false
And to re-compile because there has been a code generation change:
.\db-test.ps1 -Import $false
#>

param (
    [string] $Partition = 'WBP',
    # "C:\Program Files (x86)\SQLAnywhere"
    # "C:\Program Files (x86)\Oracle"
    [string[]] $SecondaryRoots = @("C:\Program Files (x86)\AzureSQL"),
    [boolean] $Import = $false,
    [boolean] $Compile = $false,
    [boolean] $Test = $true,
    [boolean] $Primary = $true,
    [boolean] $Secondary = $false,
    [boolean] $Bit32 = $true,
    [boolean] $Bit64 = $false,
    [switch] $SkipGitReset
)
# Write-Host "Map drives to LPC network"
# & 'C:\ssh\ServerMappings.bat'

$script:ExitCode = 0
$FullReportFile = "Verifier_Test_Report.txt"
$SummaryFile = "Verifier_Test_Summary.txt"
$TotalSummaryFile = "Verifier_Total_Summary.txt"
$global:TotalErrors = 0
$global:TotalMissingTests = 0
function Import{
    param (
        [Parameter(Mandatory=$true)]
        [string] $LansaRoot,
        [Parameter(Mandatory=$true)]
        [string] $ImportFolder,
        [Parameter(Mandatory=$true)]
        [string] $ImportLog
    )

    # DEVF X_DEVFLAG_IMPORT_CHANGE_FILE_LIB_TO_PARTDTALIB | X_DEVFLAG_IMPORT_ALLOW_NAME_CHANGES | X_DEVFLAG_IMPORT_FORCE_NAME_CHANGES
    # 2 + 16 + 4096
    [String[]] $StdArguments = @(  "PROC=*LIMPORT", "INST=NO", "QUET=Y", "MODE=B", "ALSC=NO", "BPQS=Y", "LOCK=NO", "PART=$Partition", "LANG=ENG", "DEVF=4114")

    $x_err = (Join-Path -Path $lansaRoot -ChildPath 'tmp\x_err.log')
    Remove-Item $x_err -Force -ErrorAction SilentlyContinue | Out-Default | Write-Host

    $installer_file = Join-Path $LansaRoot 'x_win95\x_lansa\execute\x_run.exe'

    $Arguments = $StdArguments + @("EXPR=""$ImportFolder""", "EXPM=""$ImportLog""")

    Write-Host "$(Log-Date) Arguments $Arguments"
    $p = Start-Process -FilePath $installer_file -ArgumentList $Arguments -Wait -PassThru

    if ( $p.ExitCode -ne 0 ) {
        $ErrorMessage = "$(Log-Date) Import returned error code $($p.ExitCode)."
        Write-Host $ErrorMessage
        throw
    }

    if ( (Test-Path -Path $x_err) )
    {
        $ErrorMessage = "$(Log-Date) $x_err exists and indicates an import error has occurred."
        Write-Host $ErrorMessage
        throw
    }
}

function New-Tuple {
    Param(
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [ValidateCount(2,20)]
        [array]$Values
    )

    Process {
        $types = ($Values | ForEach-Object { $_.GetType().Name }) -join ','
        New-Object "Tuple[$types]" $Values
    }
}

function Test{
    param (
        [Parameter(Mandatory=$true)]
        [string] $LansaRoot,
        [Parameter(Mandatory=$true)]
        [string] $Process,
        [Parameter(Mandatory=$true)]
        [string] $Function,
        [Parameter(Mandatory=$false)]
        [switch] $Bit64
    )

    # DEVF X_DEVFLAG_IMPORT_CHANGE_FILE_LIB_TO_PARTDTALIB | X_DEVFLAG_IMPORT_ALLOW_NAME_CHANGES | X_DEVFLAG_IMPORT_FORCE_NAME_CHANGES
    # 2 + 16 + 4096
    [String[]] $StdArguments = @(  "PROC=$Process", "INST=NO", "QUET=Y", "MODE=B", "ALSC=NO", "BPQS=Y", "LOCK=NO", "PART=$Partition", "LANG=ENG")

    $x_err = (Join-Path -Path $lansaRoot -ChildPath 'tmp\x_err.log')
    Remove-Item $x_err -Force -ErrorAction SilentlyContinue | Out-Default | Write-Host

    $Platform = 'x_win95'
    if ( $Bit64 ) {
        $Platform = 'x_win64'
    }
    $installer_file = Join-Path $LansaRoot "$Platform\x_lansa\execute\x_run.exe"

    $Arguments = $StdArguments

    Write-Host "$(Log-Date) $installer_file $Arguments"
    $p = Start-Process -FilePath $installer_file -ArgumentList $Arguments -Wait -PassThru

    if ( $p.ExitCode -ne 0 ) {
        $ErrorCount++
        $ErrorMessage = "$(Log-Date) Test $Process returned error code $($p.ExitCode)."
        Write-Host $ErrorMessage
        Add-Content -Path (Join-Path $LansaRoot $SummaryFile) -Value $ErrorMessage
        $global:TotalErrors++
    }

    if ( (Test-Path -Path $x_err) )
    {
        $ErrorMessage = "$(Log-Date) Test $Process, $x_err exists and indicates a test error has occurred."
        Write-Host $ErrorMessage
        Get-Content $x_err | Add-Content -Path (Join-Path $LansaRoot $SummaryFile)
        $global:TotalErrors++
    }
}

function Compile{
    param (
        [Parameter(Mandatory=$true)]
        [string] $LansaRoot,
        [Parameter(Mandatory=$false)]
        [string] $List
    )

    $x_err = (Join-Path -Path $lansaRoot -ChildPath 'tmp\x_err.log')
    Remove-Item $x_err -Force -ErrorAction SilentlyContinue | Out-Default | Write-Host

    if ( $List -eq '') {
        [String[]] $StdArguments = @(  "/PARTITION=$Partition", "/VCONLY=YES", "/OBJECTS=ALL",  "/EXCLUDE=VT_CVLEX", "/BUILDID=DBTEST")
    } else {
        [String[]] $StdArguments = @(  "/PARTITION=$Partition", "/PROJECT=$List", "/VCONLY=YES", "/OBJECTS=ALL",  "/EXCLUDE=VT_CVLEX", "/BUILDID=DBTEST")
    }

    $installer_file = Join-Path $LansaRoot 'lansa\compile.cmd'

    $Arguments = $StdArguments

    Write-Host "$(Log-Date) Arguments $Arguments"

    &$installer_file $StdArguments
    Write-Host ("$(Log-Date) LastExitCode = $LastExitCode")
    if ( $LASTEXITCODE -ne 0 ){
        if ( (Test-Path -Path $x_err) )
        {
            $ErrorMessage = "$(Log-Date) Compile $Arguments, $x_err exists and indicates a test error has occurred."
            Write-Host $ErrorMessage
            Get-Content $x_err | Add-Content -Path (Join-Path $LansaRoot $SummaryFile)
            $global:TotalErrors++
        }
        throw "$(Log-Date) Compile returned error code $LASTEXITCODE."
    }
}

function Remove-Logs{
    param (
        [Parameter(Mandatory=$true)]
        [string] $LansaRoot
    )
    $dbTestParent = Join-Path $LansaRoot 'x_win95\x_lansa\X_WBP\Compile\DBTEST'
    if ( Test-Path -Path $dbTestParent ) {
        Write-Host "$(Log-Date) Removing all files in $dbTestParent"
        Get-ChildItem -Path $dbTestParent | Out-Default | Write-Host
        Get-ChildItem -Path $dbTestParent | ForEach-Object {$_.Delete()} | Out-Default | Write-Host
    }

    $detailedResult = 'lansa/lansa/' + $database
    $detailedResultParent = Join-Path $LansaRoot $detailedResult
    if ( Test-Path -Path $detailedResultParent ) {
        Write-Host "$(Log-Date) Removing all files in $detailedResultParent"
        Get-ChildItem -Path $dbTestParent | Out-Default | Write-Host
        Get-ChildItem -Path $dbTestParent | ForEach-Object {$_.Delete()} | Out-Default | Write-Host
    }

    Remove-Item -Path (Join-Path $LansaRoot $TotalSummaryFile) -ErrorAction SilentlyContinue
    Remove-Item -Path (Join-Path $LansaRoot $FullReportFile) -ErrorAction SilentlyContinue
    Remove-Item -Path (Join-Path $LansaRoot $SummaryFile) -ErrorAction SilentlyContinue

}

# =============================================================================
# Main program
# =============================================================================

$ErrorActionPreference = "Stop"

try {
    Push-Location
	Write-Host $MyInvocation.MyCommand.Path
    $script:IncludeDir = Join-Path 'c:\lansa' 'scripts'
    $script:IncludeDir
    . "$script:IncludeDir\dot-CommonTools.ps1"

    $PrimaryPath = split-Path (split-path (split-path (Split-Path -Parent $MyInvocation.MyCommand.Path)))
    $Database = split-path $PrimaryPath -leaf

    [System.Collections.ArrayList]$RootList = @()
    if ( $Primary ) {
        Write-Host( "$(Log-Date) PrimaryPath: $PrimaryPath")
        $RootList.Add( $PrimaryPath )
    }

    if ( $Secondary ) {
        Write-Host( "$(Log-Date) List of Secondary environments to be compiled/tested:")
        $SecondaryRoots
        Write-Host

        foreach ($root in $SecondaryRoots ){
            if ( Test-Path $root ) {
                $RootList.Add( $root ) | Out-Null
            } else {
                Write-Host ( "$(Log-Date) $root does not exist" )
            }
        }
    }

    Write-Host( "$(Log-Date) List of ALL environments to be compiled/tested:")
    $RootList
    Write-Host

    # if ($Import) {
    #     $ImportBasePath = "\\$syd6\ccs\tests\Test-Materials"
    #     Write-Host( "$(Log-Date) Check if directory $ImportBasePath exists")
    #     if (-not (Test-Path -Path $ImportBasePath) ) {
    #         Write-Host "$(Log-Date) $ImportBasePath does not exist"
    #         throw
    #     }
    # }

    # All may be false when testing the summary logging code.
    if ( $Import -or $Compile -or $Test) {
        # Delete Old Log Files
        # Always remove Primary Logs
        Remove-Logs $PrimaryPath
        foreach ($Root in $RootList ){
            Remove-Logs $Root

            Add-Content -Path (Join-Path $Root $SummaryFile) -Value $Root

            Write-Host( "$(Log-Date) Remove any residue from running previous tests..." )

            Set-Location (Join-Path $Root "LANSA\VersionControl")
            if ( -not $SkipGitReset ){
                git reset --hard HEAD
            } else {
                Write-Host("Skipping Git Reset")
            }
        }
    }

    # if ( $Import ) {
    #     foreach ($Root in $RootList ){
    #         Set-Location $Root
    #         Write-Host( "$(Log-Date) Working directory is $($pwd.Path)" )

    #         $lansatempdir = Join-Path $root "tmp"

    #         Write-Host( "$(Log-Date) Check if this current directory is a Visual LANSA Root Directory")
    #         $BuildFile = Join-Path $root 'build.dat'
    #         if (-not (Test-Path -Path $BuildFile) ) {
    #             Write-Host "$(Log-Date) Current directory must be a Visual LANSA IDE root directory"
    #             throw
    #         }

    #         Write-Host ("$(Log-Date) Importing Base Test Cases")
    #         Write-Host ("$(Log-Date) Importing BIF Fields")
    #         Import $Root (Join-Path $ImportBasePath "BIF Field") (Join-Path $lansatempdir 'BIFField.log')

    #         Write-Host ("$(Log-Date) Importing VT_CVL and its Functions")
    #         Import $Root (Join-Path $ImportBasePath "VT_CVL") (Join-Path $lansatempdir 'VT_CVL.log')

    #         Write-Host ("$(Log-Date) Importing CVL_R")
    #         Import $Root (Join-Path $ImportBasePath "CVL_R - Re-usable Parts") (Join-Path $lansatempdir 'CVL_R.log')

            # Write-Host ("$(Log-Date) Copy UserLists for compiling")
            # # UserLists are yml files in the git repo which are loaded into the correct location for the IDE when either
            # # the IDE is run or compile.cmd is run (which does a VCS get)

            # # UserLists are in the git repo root directory called UserLists
            # # Needs to be copied to <Root>\LANSA\<Current User\LX_NodeName>\UserLists\<Partition>
            # # That is <Root>\LANSA\LANSA\UserLists\WBP
            # $TestPath = Join-Path $Root "LANSA\lansa\UserLists"
            # if ( -not (Test-Path $TestPath) ) { New-Item $TestPath -Type Directory}
            # $TestPath = Join-Path $TestPath $Partition
            # if ( -not (Test-Path $TestPath) ) { New-Item $TestPath -Type Directory}
            # Copy-Item (Join-Path $ImportBasePath "UserLists\*") $TestPath

    #         $CCSImports = @("\\$syd6\CCS\Tests\157000-157999\157033",
    #                         "\\$syd6\CCS\Tests\156000-156999\156118",
    #                         "\\$syd6\CCS\Tests\159000-159999\159821",
    #                         "\\$syd6\CCS\Tests\157000-157999\157722",
    #                         "\\$syd6\CCS\Tests\160000-160999\160466",
    #                         "\\$syd6\CCS\Tests\156000-156999\156710",
    #                         "\\$syd6\CCS\Tests\161000-161999\161348",
    #                         "\\$syd6\CCS\Tests\159000-159999\159434",
    #                         "\\$syd6\CCS\Tests\159000-159999\159585",
    #                         "\\$syd6\CCS\Tests\158000-158999\158011",
    #                         "\\$syd6\CCS\Tests\159000-159999\159138",
    #                         "\\$syd6\CCS\Tests\159000-159999\159138\User Provided File",
    #                         "\\$syd6\CCS\Tests\160000-160999\160553")
    #         foreach ($CCSImport in $CCSImports) {
    #             $CCSNumber = Split-path $CCSImport -Leaf
    #             Write-Host ("$(Log-Date) Importing $CCSNumber to $Root")
    #             Import $Root $CCSImport (Join-Path $lansatempdir "$CCSNumber.log")
    #             Write-Host ("$(Log-Date) ************************************************************")
    #         }
    #     }
    # }

    if ( $Compile ) {
        Write-Host "$(Log-Date) Compile all the Tests"

        foreach ($Root in $RootList ){
            Write-Host ("$(Log-Date) Compiling all objects under VCS Control in $Root")

            Compile $Root

            Write-Host ("$(Log-Date) ************************************************************")
        }
    }

    if ( $Test ){
        if ( -not $Compile ) {
            Write-Host "$(Log-Date) Compile Tests that must be compiled each time its tested"

            foreach ($Root in $RootList ){
                Write-Host ("$(Log-Date) Compiling $CompileItem for $Root")
                Compile $Root 'L157726'
                Write-Host ("$(Log-Date) ************************************************************")
            }
        }

        [System.Collections.ArrayList]$TestList = @()
        $TestList.Add( $(New-Tuple "VT157033", "V57033A") ) | Out-Null
        $TestList.Add( $(New-Tuple "VT156118", "V56118A") ) | Out-Null
        $TestList.Add( $(New-Tuple "VT159821", "V59821A") ) | Out-Null
        $TestList.Add( $(New-Tuple "VT157722", "V57722A") ) | Out-Null
        $TestList.Add( $(New-Tuple "VT160466", "V60466A") ) | Out-Null
        $TestList.Add( $(New-Tuple "VT156710", "V56710A") ) | Out-Null
        $TestList.Add( $(New-Tuple "VT161348", "V61348A") ) | Out-Null
        $TestList.Add( $(New-Tuple "VT157726", "V57726A") ) | Out-Null
        $TestList.Add( $(New-Tuple "VT159434", "V59434A") ) | Out-Null
        $TestList.Add( $(New-Tuple "VT159585", "V59585A") ) | Out-Null
        $TestList.Add( $(New-Tuple "VT158011", "V58011A") ) | Out-Null
        $TestList.Add( $(New-Tuple "VT159138", "V59138A") ) | Out-Null
        $TestList.Add( $(New-Tuple "VT160553", "V60553A") ) | Out-Null
        $TestList.Add( $(New-Tuple "VT986925", "V86925A") ) | Out-Null

        Write-Host( "$(Log-Date) Run tests in EVERY environment." )
        Write-Host( "$(Log-Date) Only the Primary environment is configured to run IBM i and SuperServer tests" )
        foreach ($Root in $RootList ){
            Write-Host ("$(Log-Date) Testing $Root")
            foreach ($TestItem in $TestList ) {
                Write-Host ("$(Log-Date) Testing $Root $($TestItem.Item1) $($TestItem.Item2)")
                if ( $Bit32 ) {
                    Test $Root $TestItem.Item1 $TestItem.Item2
                }

                if ( $Bit64 ) {
                    # 157726 and 158011 are not setup for 64 testing, though they could be.
                    # The rest are defects that should get fixed.
                    If ( -not ( $TestItem.Item1 -eq 'VT157726' -or $TestItem.Item1 -eq 'VT158011' `
                    -or $TestItem.Item1 -eq 'VT156118' ) ) {
                        Test $Root $TestItem.Item1 $TestItem.Item2 -Bit64
                    } else {
                        Write-Host( "Skipping 64 bit test" )
                    }
                }
            }
        }
    }

    Write-Host "$(Log-Date) Import, Compile and/or test completed without an exception being raised. Success/Failure reports below..."
} catch {
    $_
    # To show inner exception...
    Write-Host "$(Log-Date) Exception caught: $($_.Exception)"

    # Show other details if they exist
    If ($_.Exception.Response) {
        $response = ($_.Exception.Response ).ToString().Trim();
        Write-Host ("$(Log-Date) Exception.Response $response")
    }
    If ($_.Exception.Response.StatusCode.value__) {
        $htmlResponseCode = ($_.Exception.Response.StatusCode.value__ ).ToString().Trim();
        Write-Host ("$(Log-Date) ResponseCode $htmlResponseCode")
    }
    If  ($_.Exception.Message) {
        $exceptionMessage = ($_.Exception.Message).ToString().Trim()
        Write-Host ("$(Log-Date) Exception.Message $exceptionMessage")
    }
    If  ($_.ErrorDetails.Message) {
        $exceptionDescription = ($_.ErrorDetails.Message).ToString().Trim()
        Write-Host ("$(Log-Date) ErrorDetails.Message $exceptionDescription")
    }

    $global:TotalErrors++
    cmd /c exit -1    #Set $LASTEXITCODE
} finally {
    Write-Host

    if ( $Test -or $Compile -or ((-not $Test) -and (-not $Import) -and (-not $Compile)) ) {
        # Search for errors in Verifier_Test_Report.txt
        Add-Content -Path (Join-Path $PrimaryPath $TotalSummaryFile) -Value "Total Summary File"
        Add-Content -Path (Join-Path $PrimaryPath $TotalSummaryFile) -Value "=================="
        foreach ($Root in $RootList ){
            if ( Test-Path (Join-Path $Root $FullReportFile)) {
                $Select = Select-String -Path (Join-Path $Root $FullReportFile) -Pattern "Completed with <ER>" -SimpleMatch
                $Measure = $Select |  Measure-Object -Line
                if ( $Measure ) {
                    $global:TotalErrors += $Measure.Lines
                    Add-Content -Path  (Join-Path $Root $SummaryFile) -Value $Select
                    Add-Content -Path  (Join-Path $Root $SummaryFile) -Value "Completed with $($Measure.Lines) testing errors"
                } else {
                    Add-Content -Path  (Join-Path $Root $SummaryFile) -Value "Completed with 0 testing errors"
                }

                $OtherErrors = @(
                    "*** Unable to connect to <LU Name>",
                    "Error:"
                    "*** Failure"
                )
                foreach ($OtherError in $OtherErrors ){
                    $Select = Select-String -Path (Join-Path $Root $FullReportFile) -Pattern "$OtherError" -SimpleMatch
                    $Measure = $Select |  Measure-Object -Line
                    if ( $Measure -and $Measure.Lines -gt 0 ) {
                        $global:TotalErrors += $Measure.Lines
                        # $lines = $Select | Select-Object -ExpandProperty line
                        Add-Content -Path  (Join-Path $Root $SummaryFile) -Value $Select
                        Add-Content -Path  (Join-Path $Root $SummaryFile) -Value "$($Measure.Lines) $OtherError"
                    }
                }

                if ( $root -eq $PrimaryPath ){
                    $OtherWarnings = @(
                        "*** <Missing Test Case>",
                        "Missing test platform IBMI",
                        "Missing test database type DB2ISERIES",
                        "Missing test database type SQLANYWHERE",
                        "Missing test database type MSSQLS",
                        "Missing test database type MYSQL"
                    )
                    foreach ($Warning in $OtherWarnings ){
                        $Select = Select-String -Path (Join-Path $Root $FullReportFile) -Pattern "$Warning" -SimpleMatch
                        $Measure = $Select |  Measure-Object -Line
                        if ( $Measure -and $Measure.Lines -gt 0 ) {
                            $TotalMissingTests += $Measure.Lines
                            Add-Content -Path  (Join-Path $Root $SummaryFile) -Value $Select
                            Add-Content -Path  (Join-Path $Root $SummaryFile) -Value "$($Measure.Lines) $Warning"
                        }
                    }
                }
            } else {
                Add-Content -Path  (Join-Path $Root $SummaryFile) -Value "$(Join-Path $Root $FullReportFile) Does not exist"
            }
            # Append this Environments summary file to a sumary of summaries file
            Get-Content -Path (Join-Path $Root $SummaryFile) | Add-Content -Path (Join-Path $PrimaryPath $TotalSummaryFile)
            Add-Content -Path (Join-Path $PrimaryPath $TotalSummaryFile) -Value "************************************************************"
        }
        Add-Content -Path (Join-Path $PrimaryPath $TotalSummaryFile) -Value "`n"
        Add-Content -Path (Join-Path $PrimaryPath $TotalSummaryFile) -Value "Total errors $global:TotalErrors"
        if ( $TotalMissingTests -gt 0 ){
            Add-Content -Path (Join-Path $PrimaryPath $TotalSummaryFile) -Value "Total missing tests $TotalMissingTests"
        }

        # Display the summary of summaries file
        Get-Content -Path (Join-Path $PrimaryPath $TotalSummaryFile)

        if ( $global:TotalErrors -gt 0) {
            throw "There have been $global:TotalErrors errors"
        }
    }

    Pop-Location
}