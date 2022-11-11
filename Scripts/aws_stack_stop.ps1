## Powershell script to stop the exisiting AWS stack.

param (
    [parameter(Mandatory=$true)]    [string] $lansa_version
)

$INSTANCE_ID = ((Get-EC2Instance -Filter @(@{Name="tag:LansaVersion"; Values=$lansa_version}, @{Name= "tag:aws:cloudformation:stack-name"; Values="DB-Regression-VM-$lansa_version"})).Instances).InstanceId

$ORACLE_DB_INSTANCE_IDENTIFIER = "ora" + $lansa_version

$MYSQL_DB_INSTANCE_IDENTIFIER = "mysql" + $lansa_version


Write-Host "Stopping the VM"
Stop-EC2Instance -InstanceId $INSTANCE_ID -Force
$RetryCount = 30
while (( (((Get-EC2InstanceStatus -IncludeAllInstance $true -InstanceId $INSTANCE_ID).InstanceState).Name).Value -ne "stopped" )  -and ($RetryCount -gt 0) )
{
    Write-Host "Waiting for stopping the VM"
    Start-Sleep -Seconds 20
    $RetryCount -= 1
}
if ($RetryCount -le 0) {
    Write-Host "##[error] Timeout: 10 minutes expired in waiting for VM with instance id $INSTANCE_ID to be stopped"
} else {
    Write-Host "VM is in stopped state"
}


Write-Host "Stopping the ORACLE RDS"
Stop-RDSDBInstance -DBInstanceIdentifier $ORACLE_DB_INSTANCE_IDENTIFIER -Force
$RetryCount = 60
while (((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$ORACLE_DB_INSTANCE_IDENTIFIER}).DBInstanceStatus -ne "stopped" )  -and ($RetryCount -gt 0) ){
    Write-Host "Waiting for stopping the Oracle RDS"
    Start-Sleep -Seconds 20
    $RetryCount -= 1
}

if ($RetryCount -le 0){
    Write-Host "##[error] Timeout: 20 minutes expired in waiting for ORACLE RDS $ORACLE_DB_INSTANCE_IDENTIFIER to be stopped"
} else {
    Write-Host "Oracle RDS is in stopped state"
}


Write-Host "Stopping the MYSQL RDS"
Stop-RDSDBInstance -DBInstanceIdentifier $MYSQL_DB_INSTANCE_IDENTIFIER -Force
$RetryCount = 60
while (((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$MYSQL_DB_INSTANCE_IDENTIFIER}).DBInstanceStatus -ne "stopped" )  -and ($RetryCount -gt 0) )
{
    Write-Host "Waiting for stopping the MYSQL RDS"
    Start-Sleep -Seconds 20
    $RetryCount -= 1
}
if ($RetryCount -le 0) {
    Write-Host "##[error] Timeout: 20 minutes expired in waiting for MYSQL RDS $MYSQL_DB_INSTANCE_IDENTIFIER to be stopped"
} else {
    Write-Host "MYSQL RDS is in stopped state"
}