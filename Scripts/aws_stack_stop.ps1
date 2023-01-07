## Powershell script to stop the exisiting AWS stack.

param (
    [parameter(Mandatory=$true)]    [string] $lansa_version
)

Set-DefaultAWSRegion -Region 'us-east-1' -Scope Script

$INSTANCE_ID = ((Get-EC2Instance -Filter @(@{Name="tag:LansaVersion"; Values=$lansa_version}, @{Name= "tag:aws:cloudformation:stack-name"; Values="DB-Regression-VM-$lansa_version"})).Instances).InstanceId

$ORACLE_DB_INSTANCE_IDENTIFIER = "ora" + $lansa_version

$MYSQL_DB_INSTANCE_IDENTIFIER = "mysql" + $lansa_version


Write-Host "Stopping the VM"
try {
   Stop-EC2Instance -InstanceId $INSTANCE_ID -Force
   $RetryCount = 30
   while (( (((Get-EC2InstanceStatus -IncludeAllInstance $true -InstanceId $INSTANCE_ID).InstanceState).Name).Value -ne "stopped" )  -and ($RetryCount -gt 0) )
   {
      Write-Host "Waiting for the VM to stop"
      Start-Sleep -Seconds 20
      $RetryCount -= 1
   }
   if ($RetryCount -le 0) {
      Write-Host "##[error] Timeout: 10 minutes expired in waiting for VM with instance id $INSTANCE_ID to be stopped"
   } else {
      Write-Host "VM is in stopped state"
   }
} catch {
   Write-Host "VM is already in stopped state or can't be found"
}

Write-Host "Stopping the ORACLE RDS"
try {
   Stop-RDSDBInstance -DBInstanceIdentifier $ORACLE_DB_INSTANCE_IDENTIFIER -Force
   $RetryCount = 60
   while (((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$ORACLE_DB_INSTANCE_IDENTIFIER}).DBInstanceStatus -ne "stopped" )  -and ($RetryCount -gt 0) ){
      Write-Host "Waiting for the Oracle RDS to stop..."
      Start-Sleep -Seconds 20
      $RetryCount -= 1
   }

   if ($RetryCount -le 0){
      Write-Host "##[error] Timeout: 20 minutes expired in waiting for ORACLE RDS $ORACLE_DB_INSTANCE_IDENTIFIER to be stopped"
   } else {
      Write-Host "Oracle RDS is in stopped state"
   }
} catch {
   Write-Host "Oracle RDS is already in stopped state or can't be found"
}

Write-Host "Stopping the MYSQL RDS"
try {
   Stop-RDSDBInstance -DBInstanceIdentifier $MYSQL_DB_INSTANCE_IDENTIFIER -Force
   $RetryCount = 60
   while (((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$MYSQL_DB_INSTANCE_IDENTIFIER}).DBInstanceStatus -ne "stopped" )  -and ($RetryCount -gt 0) )
   {
      Write-Host "Waiting for the MYSQL RDS to stop..."
      Start-Sleep -Seconds 20
      $RetryCount -= 1
   }
   if ($RetryCount -le 0) {
      Write-Host "##[error] Timeout: 20 minutes expired in waiting for MYSQL RDS $MYSQL_DB_INSTANCE_IDENTIFIER to be stopped"
   } else {
      Write-Host "MYSQL RDS is in stopped state"
   }
} catch {
   Write-Host "MYSQL RDS is already in stopped state or can't be found"
}