param (
    [Parameter(Mandatory = $true)]
    [string]
    $dbtype,

    [Parameter(Mandatory = $true)]
    [string]
    $compile,

    [Parameter(Mandatory = $true)]
    [string]
    $test,

    [Parameter(Mandatory = $true)]
    [string]
    $OutputS3BucketName,

    [Parameter(Mandatory = $true)]
    [string]
    $OutputS3KeyPrefix,

    [Parameter(Mandatory = $true)]
    [string]
    $LansaVersion
)


# Setting the compile and test variables to use 1s and 0s; The target scripts seems to be accepting that.
if ($compile -eq "true") { $compile = 1} else { $compile = 0 }
if ($test -eq "true") { $test = 1} else { $test = 0 }

# Mapping of databases to appropriate path
$DatabaseType_SystemRootPath = @{
    "AZURESQL" = "C:\Program Files (x86)\AZURESQL";
    "MSSQLS" = "C:\Program Files (x86)\LANSA";
    "ORACLE" = "C:\Program Files (x86)\ORACLE";
    "SQLANYWHERE" = "C:\Program Files (x86)\SQLANYWHERE";
    "MYSQL" = "C:\Program Files (x86)\MySQL"
}

$root_directory = $DatabaseType_SystemRootPath[$dbtype]

$instance_id = ((Get-EC2Instance -Filter @( `
                                    @{Name = "tag:LansaVersion"; Values=$LansaVersion}, `
                                    @{Name= "tag:aws:cloudformation:stack-name"; Values="DB-Regression-VM-$LansaVersion"}) `
                                    ).Instances `
                                ).InstanceId `

$runPSCommandID = (Send-SSMCommand `
        -DocumentName "AWS-RunPowerShellScript" `
        -Comment "Running db-test.ps1 for $dbtype" `
        -Parameter @{'commands' = @("& '$root_directory\LANSA\VersionControl\Scripts\db-test.ps1' -Compile $compile -Test $test")} `
        -Target @(@{Key="tag:aws:cloudformation:stack-name"; Values = "DB-Regression-VM-$LansaVersion"}, @{Key="tag:LansaVersion"; Values = "$LansaVersion"}) `
        -OutputS3BucketName $OutputS3BucketName `
        -OutputS3KeyPrefix $OutputS3KeyPrefix/$dbtype).CommandId

# Function to read the logs generated by running the scripts (from the S3 bucket) and printing it out to the Azure DevOps console
function writings3logs {

    # This will download the AWS Systems Manager log file(s) locally at the location specified on the "Folder" flag ($root_directory)
    Read-S3Object -BucketName $(OutputS3BucketName) `
        -KeyPrefix "$(OutputS3KeyPrefix)/$dbtype/$runPSCommandID/$instance_id/awsrunPowerShellScript/0.awsrunPowerShellScript" `
        -Folder "$root_directory\LANSA\VersionControl\Scripts\s3_logs"

    # This will get all types of logs (expected types: stderr, for failure and stdout if successful) and print them to the Azure DevOps console
    Get-ChildItem "$root_directory\LANSA\VersionControl\Scripts\s3_logs" | ForEach-Object {
        $content = Get-Content -Raw $_.FullName
        Write-Host "`n###################### - Displaying logs for: $($_.Name) - ######################`n"
        Write-Host $content
        Write-Host "`n###################### - END - ######################`n"
    }
}

# The timeout logic in case the script doesn't run; it will halt the execution right away if status is "Failed"
$RetryCount = 90		
while(((Get-SSMCommand -CommandId $runPSCommandID).Status -ne "Success") -and ($RetryCount -gt 0)) {

    Write-Host "Please wait. db-test.ps1 execution for $dbtype is in progress. The logs will be displayed soon.`n"

    Start-Sleep 20 # Checking every 20 seconds

    $RetryCount -= 1
    
    if(((Get-SSMCommand -CommandId $runPSCommandID).Status).Value -eq "Failed") {

        writings3logs # This is a function
        throw "db-test.ps1 execution for $dbtype has failed!"
    }
}

# The actual halting of execution when timeout occures
if($RetryCount -le 0) {
    writings3logs # This is a function
    throw "Timeout: 30 minutes expired waiting for the script to start."
}


Write-Host "Execution complete. The logs can also be found here: $(OutputS3BucketName)/$(OutputS3KeyPrefix)/$dbtype/$runPSCommandID/"

writings3logs # This is a function
