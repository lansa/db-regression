# This script uses the PowerShellSend-SSMCommand API to run db-test.ps1

param (
    [Parameter(Mandatory = $true)]
    [string]
    $LansaVersion,

    [Parameter(Mandatory = $false)]
    [boolean]
    $Test = $true,
    
    [Parameter(Mandatory = $false)]
    [boolean]
    $Compile = $false,

    [Parameter(Mandatory = $true)]
    [string]
    $OutputS3BucketName,

    [Parameter(Mandatory = $true)]
    [string]
    $OutputS3KeyPrefix
)


# if (($Test -eq "true") -or ($Test -eq "True")) {
#     $bool_Test = $true
# } else {
#     $bool_Test = $false
# }

# if (($Compile -eq "true") -or ($Compile -eq "True")) {
#     $bool_Compile = $true
# } else {
#     $bool_Compile = $false
# }

$runPSCommandID = (Send-SSMCommand `
        -DocumentName "AWS-RunPowerShellScript" `
        -Comment "Running db-test.ps1 on DB-Regression-VM-$LansaVersion" `
        -Parameter @{'commands'=@(' & "C:\Program Files (x86)\Lansa\LANSA\VersionControl\Scripts\db-test.ps1" -Compile $Compile -Test $Test ')} `
        -Target @(@{Key="tag:aws:cloudformation:stack-name"; Values = "DB-Regression-VM-$LansaVersion"}, @{Key="tag:LansaVersion"; Values = $LansaVersion}) `
        -OutputS3BucketName $OutputS3BucketName `
        -OutputS3KeyPrefix $OutputS3KeyPrefix).CommandId


while ($true) {
    if ((Get-SSMCommand -CommandId $runPSCommandID).Status -eq "Success") {
            Write-Host "Execution complete. The logs can be found here: $OutputS3BucketName/$OutputS3KeyPrefix/$runPSCommandID" # When the Status of the Get-SSMCommand is "Success", the while loop terminates
            break
        } else { # While the status isn't "Success"...
            Start-Sleep 20 # Checking every 20 seconds, if the status changes to "Success", 
            Write-Host "Please wait, db-test.ps1 execution is in progress." # and if not, writing to host that message.
        }
}
