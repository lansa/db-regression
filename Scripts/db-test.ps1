<#
.SYNOPSIS

Runs the database regression test

An overview of these tests may be found here: https://www.evernote.com/l/AA1k-ryIaDRLVp6stZIM-eNQvEf1uY4Lyw8/

IMPORTANT:" To be run in a new instance created from the baked image, NOT while creating the image itself.

.EXAMPLE
Typically starts by only importing to the Primary environment, which needs to be followed by manual compiles:
db-test.ps1 -PrimaryOnly $true
Then a second run to import and compile the Secondary environments with testing driven from the Primary environment:
db-test.ps1
And when there is only a runtime change, you just want to run the tests:
db-test.ps1 -Import $false -Compile $false
And to re-compile because there has been a code generation change:
db-test.ps1 -Import $false
#>

param (
    [string] $Partition = 'WBP',
    [boolean] $Import = $true,
    [boolean] $Compile = $true,
    [boolean] $Test = $true,
    [boolean] $PrimaryOnly = $false
)
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
        $ExitCode = $p.ExitCode
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

function Test{
    param (
        [Parameter(Mandatory=$true)]
        [string] $LansaRoot,
        [Parameter(Mandatory=$true)]
        [string] $Process,
        [Parameter(Mandatory=$true)]
        [string] $Function
    )

    # DEVF X_DEVFLAG_IMPORT_CHANGE_FILE_LIB_TO_PARTDTALIB | X_DEVFLAG_IMPORT_ALLOW_NAME_CHANGES | X_DEVFLAG_IMPORT_FORCE_NAME_CHANGES
    # 2 + 16 + 4096
    [String[]] $StdArguments = @(  "PROC=$Process", "INST=NO", "QUET=Y", "MODE=B", "ALSC=NO", "BPQS=Y", "LOCK=NO", "PART=$Partition", "LANG=ENG")

    $x_err = (Join-Path -Path $lansaRoot -ChildPath 'tmp\x_err.log')
    Remove-Item $x_err -Force -ErrorAction SilentlyContinue | Out-Default | Write-Host

    $installer_file = Join-Path $LansaRoot 'x_win95\x_lansa\execute\x_run.exe'

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
        [Parameter(Mandatory=$true)]
        [string] $List
    )

    [String[]] $StdArguments = @(  "/PARTITION=$Partition", "/PROJECT=$List", "/VCONLY=NO", "/OBJECTS=ALL")

    $installer_file = Join-Path $LansaRoot 'lansa\compile.cmd'

    $Arguments = $StdArguments

    Write-Host "$(Log-Date) Arguments $Arguments"

    &$installer_file $StdArguments
    Write-Host ("$(Log-Date) LastExitCode = $LastExitCode")
    if ( $LASTEXITCODE -ne 0 ){
        throw "$(Log-Date) Compile returned error code $LASTEXITCODE."
    }
}

# =============================================================================
# Main program
# =============================================================================

try {
	Write-Host $MyInvocation.MyCommand.Path
    $script:IncludeDir = Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) )) 'scripts'
    $script:IncludeDir
    . "$script:IncludeDir\dot-CommonTools.ps1"

    $PrimaryPath = "C:\lansa\TestPrimaryMSSQLS"
    $RootList = @(
        $PrimaryPath,
        "C:\lansa\TestSecondaryMySQL",
        "C:\lansa\TestSecondarySQLAnywhere",
        "C:\lansa\TestSecondaryORA"
    )
    # $RootList = @(
    #     $PrimaryPath,
    #     "C:\lansa\TestSecondarySQLAnywhere"
    # )

    $ImportBasePath = '\\syd6\ccs\tests\Test-Materials'
    Write-Host( "$(Log-Date) Check if directory $ImportBasePath exists")
    if (-not (Test-Path -Path $ImportBasePath) ) {
        Write-Host "$(Log-Date) $ImportBasePath does not exist"
        throw
    }

    # Delete Old Log Files
    Remove-Item -Path (Join-Path $PrimaryPath $FullReportFile) -ErrorAction SilentlyContinue
    foreach ($Root in $RootList ){
        Remove-Item -Path (Join-Path $Root $TotalSummaryFile) -ErrorAction SilentlyContinue
        Remove-Item -Path (Join-Path $Root $FullReportFile) -ErrorAction SilentlyContinue
        Remove-Item -Path (Join-Path $Root $SummaryFile) -ErrorAction SilentlyContinue
        Add-Content -Path (Join-Path $Root $SummaryFile) -Value $Root
    }

    if ( $Import ) {
        [boolean] $First = $true
        foreach ($Root in $RootList ){
            if ( $First -and -not $PrimaryOnly) {
                $First = $false
                continue
            }
            if ( -not $First -and $PrimaryOnly) {
                continue
            }
            $First = $false

            Set-Location $Root
            Write-Host( "$(Log-Date) Working directory is $($pwd.Path)" )

            $lansatempdir = Join-Path $root "tmp"

            Write-Host( "$(Log-Date) Check if this current directory is a Visual LANSA Root Directory")
            $BuildFile = Join-Path $root 'build.dat'
            if (-not (Test-Path -Path $BuildFile) ) {
                Write-Host "$(Log-Date) Current directory must be a Visual LANSA IDE root directory"
                throw
            }

            # Write-Host ("$(Log-Date) Importing Base Test Cases")
            # Write-Host ("$(Log-Date) Importing BIF Fields")
            # Import $Root (Join-Path $ImportBasePath "BIF Field") (Join-Path $lansatempdir 'BIFField.log')

            # Write-Host ("$(Log-Date) Importing VT_CVL and its Functions")
            # Import $Root (Join-Path $ImportBasePath "VT_CVL") (Join-Path $lansatempdir 'VT_CVL.log')

            # Write-Host ("$(Log-Date) Importing CVL_R")
            # Import $Root (Join-Path $ImportBasePath "CVL_R - Re-usable Parts") (Join-Path $lansatempdir 'CVL_R.log')

            Write-Host ("$(Log-Date) Copy UserLists for compiling")
            Copy-Item (Join-Path $ImportBasePath "UserLists\*") (Join-Path $Root "lansa\UserLists\$Partition")

            $CCSImports = @("\\syd6\CCS\Tests\157000-157999\157033",
                            "\\syd6\CCS\Tests\156000-156999\156118",
                            "\\syd6\CCS\Tests\159000-159999\159821",
                            "\\syd6\CCS\Tests\157000-157999\157722",
                            "\\syd6\CCS\Tests\160000-160999\160466",
                            "\\syd6\CCS\Tests\156000-156999\156710",
                            "\\syd6\CCS\Tests\161000-161999\161348",
                            "\\syd6\CCS\Tests\159000-159999\159434",
                            "\\syd6\CCS\Tests\159000-159999\159585",
                            "\\syd6\CCS\Tests\158000-158999\158011",
                            "\\syd6\CCS\Tests\159000-159999\159138",
                            "\\syd6\CCS\Tests\159000-159999\159138\User Provided File",
                            "\\syd6\CCS\Tests\160000-160999\160553")
            foreach ($CCSImport in $CCSImports) {
                $CCSNumber = Split-path $CCSImport -Leaf
                Write-Host ("$(Log-Date) Importing $CCSNumber to $Root")
                Import $Root $CCSImport (Join-Path $lansatempdir "$CCSNumber.log")
                Write-Host ("$(Log-Date) ************************************************************")
            }
        }
    }

    if ( $Compile -or $Test) {
        [boolean] $First = $true
        foreach ($Root in $RootList ){
            if ( $First -and -not $PrimaryOnly) {
                $First = $false
                continue
            }
            if ( -not $First -and $PrimaryOnly) {
                continue
            }
            $First = $false

            Set-Location $Root
            Write-Host( "$(Log-Date) Working directory is $($pwd.Path)" )

            $lansatempdir = Join-Path $root "tmp"

            Write-Host "$(Log-Date) Imports that are required every time the test is compiled or tested"

            $CCSCompileImports = @("\\syd6\CCS\Tests\157000-157999\157726")
            foreach ($CCSImport in $CCSCompileImports) {
                $CCSNumber = Split-path $CCSImport -Leaf
                Write-Host ("$(Log-Date) Importing $CCSNumber to $Root")
                Import $Root $CCSImport (Join-Path $lansatempdir "$CCSNumber.log")
                Write-Host ("$(Log-Date) ************************************************************")
            }
        }
    }

    if ( $Compile -and -not $PrimaryOnly) {
        Write-Host "$(Log-Date) Compile all the Secondary Tests"

        foreach ($Root in $RootList ){
            if ( $Root -eq $PrimaryPath) {
                continue
            }

            Write-Host ("$(Log-Date) Compiling $Root")

            $CompileList = @(
                ("L157033"),
                ("L156118"),
                ("L159821"),
                ("L157722"),
                ("L160466"),
                ("L156710"),
                ("L161348"),
                ("L159434"),
                ("L159585"),
                ("L158011"),
                ("L159138"),
                ("L160553")
            )
            foreach ($CompileItem in $CompileList) {
                Write-Host ("$(Log-Date) Compiling $CompileItem for $Root")
                Compile $Root $CompileItem
                Write-Host ("$(Log-Date) ************************************************************")
            }
        }
    }

    if ( $Test ){
        Write-Host "$(Log-Date) Compile Tests that must be compiled each time its tested"

        foreach ($Root in $RootList ){
            if ( $Root -eq $PrimaryPath) {
                continue
            }

            Write-Host ("$(Log-Date) Compiling $CompileItem for $Root")
            Compile $Root 'L157726'
            Write-Host ("$(Log-Date) ************************************************************")
        }

        $TestList = @(
            ("VT157033", "V57033A"),
            ("VT156118", "V56118A"),
            ("VT159821", "V59821A"),
            ("VT157722", "V57722A"),
            ("VT160466", "V60466A"),
            ("VT156710", "V56710A"),
            ("VT161348", "V61348A"),
            ("VT157726", "V57726A"),
            ("VT159434", "V59434A"),
            ("VT159585", "V59585A"),
            ("VT158011", "V58011A"),
            ("VT159138", "V59138A"),
            ("VT160553", "V60553A")
        )

        # Run tests in EVERY environment.
        # Only the Primary environment is configured to run IBM i and SuperServer tests
        foreach ($Root in $RootList ){
            Write-Host ("$(Log-Date) Testing $Root")
            foreach ($TestItem in $TestList ) {
                if ( $TestItem[1] -eq "VT57726A") {
                    # Don't test this test on the Primary because it requires importing and compiling every time,
                    # and compiling is done differently in a non-VCS
                    if ( $Root -eq $PrimaryPath) {
                        continue
                    }

                }
                Test $Root $TestItem[0] $TestItem[1]
            }
        }
    }

    Write-Host "$(Log-Date) Import, Compile and/or test completed successfully"
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
    # Search for errors in Verifier_Test_Report.txt
    Add-Content -Path (Join-Path $PrimaryPath $TotalSummaryFile) -Value "Total Summary File"
    Add-Content -Path (Join-Path $PrimaryPath $TotalSummaryFile) -Value "=================="
    foreach ($Root in $RootList ){
        if ( Test-Path (Join-Path $Root $FullReportFile)) {
            $Measure = Select-String -Path (Join-Path $Root $FullReportFile) -Pattern "Completed with <ER>" -SimpleMatch |  Measure-Object -Line
            if ( $Measure ) {
                $global:TotalErrors += $Measure.Lines
                Add-Content -Path  (Join-Path $Root $SummaryFile) -Value "Completed with $($Measure.Lines) testing errors"
            } else {
                Add-Content -Path  (Join-Path $Root $SummaryFile) -Value "Completed with 0 testing errors"
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
                    $Measure = Select-String -Path (Join-Path $Root $FullReportFile) -Pattern "$Warning" -SimpleMatch |  Measure-Object -Line
                    if ( $Measure -and $Measure.Lines -gt 0 ) {
                        $TotalMissingTests += $Measure.Lines
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
}