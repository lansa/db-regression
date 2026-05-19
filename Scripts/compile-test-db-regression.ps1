param (
    [Parameter(Mandatory = $true)]
    [ValidateSet("AZURESQL", "MSSQLS", "ORACLE", "SQLANYWHERE", "MYSQL")]
    [string] $dbtype,

    [Parameter(Mandatory = $true)]
    [bool] $compile,

    [Parameter(Mandatory = $true)]
    [bool] $test,

    [Parameter(Mandatory = $true)]
    [string] $OutputS3BucketName,

    [Parameter(Mandatory = $true)]
    [string] $OutputS3KeyPrefix,

    [Parameter(Mandatory = $true)]
    [string] $LansaVersion,

    [Parameter(Mandatory = $false)]
    [string] $AwsRegion = "us-east-1"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$compileFlag = if ($compile) { 1 } else { 0 }
$testFlag = if ($test) { 1 } else { 0 }

& "$PSScriptRoot\run-aws-send-ssmcommand.ps1" `
    -scriptName "db-test.ps1" `
    -scriptParameters "-Compile $compileFlag -Test $testFlag" `
    -comment "Running db-test.ps1" `
    -dbtype $dbtype `
    -OutputS3BucketName $OutputS3BucketName `
    -OutputS3KeyPrefix $OutputS3KeyPrefix `
    -LansaVersion $LansaVersion `
    -AwsRegion $AwsRegion
