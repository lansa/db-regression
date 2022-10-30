## Powershell script for provisioning AWS stack

param (
[parameter(Mandatory=$true)]    [string] $lansa_version,
[parameter(Mandatory=$false)]   [string] $clone_lansa_version ## lansa version that would be used to create clone stack.

)

if ( [string]::IsNullOrWhiteSpace( $clone_lansa_version) )
{
   $clone_lansa_version = $lansa_version
}

#$MYSQL_RDS_CFN_TEMPLATE_URL = "https://lansa-us-east-1.s3.amazonaws.com/db-regression-test/cloudformation_template/mysql_rds.cfn.template.yml"
#$ORACLE_RDS_CFN_TEMPLATE_URL = "https://lansa-us-east-1.s3.amazonaws.com/db-regression-test/cloudformation_template/oracle_rds.cfn.template.yml"
#$VM_CFN_TEMPLATE_URL = "https://lansa-us-east-1.s3.amazonaws.com/db-regression-test/cloudformation_template/vm.cfn.template.yml"

$aws_stack_script_path = $MyInvocation.MyCommand.Path
$stack_script = Split-Path $aws_stack_script_path
$git_repo_root = Get-Item $stack_script\..\Templates\aws

$vm_template = Get-Content -Path $git_repo_root\vm.cfn.template.yaml -Raw
$oracle_rds_template = Get-Content -Path $git_repo_root\oracle_rds.cfn.template.yaml -Raw
$mysql_rds_template = Get-Content -Path $git_repo_root\mysql_rds.cfn.template.yaml -Raw


function fetch_vm_password
{
   Param
   (
      [Parameter(Mandatory=$true)] [String]$INSTANCE_ID
   )
   Write-Host "Trying to fetch the VM Password"
   (Get-SECSecretValue -SecretId privatekey/AzureDevOps).SecretString > $env:tmp\key.pem
   $RetryCount = 10
   while ( ((Get-EC2PasswordData -InstanceId $INSTANCE_ID) -eq $null ) -and ($RetryCount -gt 0) )
   {
      Start-Sleep -Seconds 120
      $RetryCount -= 1
      Write-Host "Waiting to fetch the VM password"
   }
    return $RetryCount
}

function cfn_stack_status
{
   Param
   (
      [Parameter(Mandatory=$true)] [String]$STACK_NAME
   )
   $CFN_STACK_STATUS = ((Get-CFNStack -StackName $STACK_NAME).StackStatus).Value
   Write-Host $CFN_STACK_STATUS
   $RetryCount = 15
   while (($CFN_STACK_STATUS -ne "CREATE_COMPLETE") -and ($RetryCount -gt 0) )
   {
      Start-Sleep -Seconds 120
      $RetryCount -= 1
      Write-Host "Waiting for CFN $STACK_NAME stack to be in CREATE_COMPLETE state"
      $CFN_STACK_STATUS = ((Get-CFNStack -StackName $STACK_NAME).StackStatus).Value
      Write-Host $CFN_STACK_STATUS

   }
   return $RetryCount
}

function remove_cfn_stack
{
   Param
   (
      [Parameter(Mandatory=$true)] [String]$STACK_NAME
   )

   $RetryCount = 15
   Remove-CFNStack -StackName $STACK_NAME -Force
   while (((Test-CFNStack -StackName $STACK_NAME -Status "DELETE_IN_PROGRESS") -eq $true )  -and ($RetryCount -gt 0) )
   {
      Write-Host "Waiting for deletion of existing CFN stack $STACK_NAME"
      Start-Sleep -Seconds 120
      $RetryCount -= 1
   }
   return $RetryCount
}

Write-Host "Searching for VM with Lansa Version tag = $lansa_version"

$EXISTING_INSTANCE_COUNT = (((Get-EC2Instance -Filter @{ Name="tag:LansaVersion"; Values=$lansa_version }).Instances).InstanceId).count

if ($EXISTING_INSTANCE_COUNT -eq 1 )
{
   Write-Host "Found 1 VM with Lansa Version tag = $lansa_version"
   Write-Host "Checking the VM Status"
   $INSTANCE_ID = ((Get-EC2Instance -Filter @{ Name="tag:LansaVersion"; Values=$lansa_version }).Instances).InstanceId
   $INSTANCE_STATE = (((Get-EC2InstanceStatus -IncludeAllInstance $true -InstanceId $INSTANCE_ID).InstanceState).Name).Value

   if ($INSTANCE_STATE -eq "running")
   {
      Write-Host "VM is already in running state"
      $RETRY_COUNT = fetch_vm_password $INSTANCE_ID
      if ( $RETRY_COUNT -le 0 )
      {
         throw "Timeout: 20 minutes expired in waiting to fetch the VM password"
      }

      Write-Host "Able to fetch the VM password"

   }

   elseif ($INSTANCE_STATE -eq "stopped")
   {
      Write-Host "VM is in stopped state"
      Write-Host "Starting the VM"
      $NEW_STATUS = (((Start-EC2Instance -InstanceID $INSTANCE_ID).CurrentState).Name).Value
      $RETRY_COUNT = fetch_vm_password $INSTANCE_ID
      if ( $RETRY_COUNT -le 0)
      {
         throw "Timeout: 20 minutes expired in waiting to fetch the VM password"
      }

      Write-Host "Able to fetch the VM password"
      Write-Host "Current state of VM is $NEW_STATUS"
   }

   else
   {
      Write-Host "VM is neither in Running State nor in Stopped State"
      throw "VM state is $INSTANCE_STATE"
   }
}

elseif ($EXISTING_INSTANCE_COUNT -eq 0){
   Write-Host "No Exisiting VM found with Lansa Version tag = $lansa_version"
   $NO_OF_AMIS = (Get-EC2Image -Filter @{ Name="tag:LansaVersion"; Values=$clone_lansa_version } | Select-Object ImageId | Measure-Object | Select-Object Count).count
   if ($NO_OF_AMIS -eq 1)
   {
      Write-Host "Found 1 AMI with Lansa vesion tag = $clone_lansa_version"
      $AMI_ID = (Get-EC2Image -Filter @{ Name="tag:LansaVersion"; Values=$clone_lansa_version }).ImageId
      $STACK_NAME = "DB-Regression-VM-" + $lansa_version
      try
      {
         $EXISTING_CFN_STACK_STATUS = ((Get-CFNStack -StackName $STACK_NAME).StackStatus).Value
         Write-Host "CFN Stack with stack name = $STACK_NAME exist and is in $EXISTING_CFN_STACK_STATUS state"
         $RETRY_COUNT = remove_cfn_stack $STACK_NAME
         if ( $RETRY_COUNT -le 0 )
         {
            throw "Timeout: 30 minutes expired waiting to Delete CFN Stack $STACK_NAME"
         }

         Get-CFNStack -StackName $STACK_NAME
      }
      catch [System.InvalidOperationException]
      {
         New-CFNStack -StackName $STACK_NAME -TemplateBody $vm_template -Parameter @{ParameterKey="AMIID";ParameterValue=$AMI_ID} -Tag @{Key="LansaVersion"; Value=$lansa_version}
      }

      $RETRY_COUNT = cfn_stack_status $STACK_NAME
      if ( $RETRY_COUNT -le 0 )
      {
         throw "Timeout: 30 minutes expired waiting for CFN stack to be in CREATE_COMPLETE state"
      }
      Write-Host "CFN Stack $STACK_NAME is in CREATE_COMPLETE State"
      $PHYSICAL_INSTANCE_ID = ((Get-CFNStackResource -StackName $STACK_NAME -LogicalResourceId INSTANCE).PhysicalResourceId)
      Write-Host "Trying to fetch VM Password"
      $RETRY_COUNT = fetch_vm_password $PHYSICAL_INSTANCE_ID
      if ( $RETRY_COUNT -le 0 )
      {
         throw "Timeout: 20 minutes expired waiting to fetch VM password"
      }

      Write-Host "Able to fetch the VM password"
   }


   elseif ($NO_OF_AMIS -eq 0)
   {
      throw "Did not find any AMI with the lansa version tag = $clone_lansa_version"
   }

   else
   {
      throw "Found more than 1 AMI with the lansa version tag = $clone_lansa_version"
   }
}

else
{
   throw "Found more than 1 VM with the Lansa Version tag = $lansa_version"
}


###########################################################################
##
## Oracle RDS
##
###########################################################################

function check_oracle_rds_status
{
   Param
   (
      [Parameter(Mandatory=$true)] [String]$ORACLE_DB_ID
   )
   $RetryCount = 15
   while ( ((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$ORACLE_DB_ID}).DBInstanceStatus -ne "available") -and ($RetryCount -gt 0))
   {
      Start-Sleep -Seconds 120
      $RetryCount -= 1
      if ( ((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$ORACLE_DB_ID}).DBInstanceStatus -eq "starting") -or ((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$ORACLE_DB_ID}).DBInstanceStatus -eq "backing-up")  )
      {
         Write-Host "Oracle RDS is getting started"
      }
   }
   return $RetryCount
}



Write-Host "Searching for Oracle RDS with Lansa Version tag = $lansa_version"

$ORACLE_DB_IDENTIFIER = "ora" + $lansa_version
$ORACLE_SNAPSHOT_IDENTIFIER = "ora" + $clone_lansa_version
$ORACLE_DB_COUNT = (Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$ORACLE_DB_IDENTIFIER}).count

if ($ORACLE_DB_COUNT -eq 1)
{

   Write-Host "Found 1 Oracle RDS with Lansa Version tag = $lansa_version"
   $ORACLE_DB_STATUS = (Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$ORACLE_DB_IDENTIFIER}).DBInstanceStatus
   $ORACLE_DB_ARN = (Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$ORACLE_DB_IDENTIFIER}).DBInstanceArn

   if ($ORACLE_DB_STATUS -eq "available")
   {
      Write-Host "Oracle RDS is in $ORACLE_DB_STATUS state and its ARN is $ORACLE_DB_ARN"
   }

   elseif ($ORACLE_DB_STATUS -eq "stopped")
   {
      Write-Host "Oracle RDS is in $ORACLE_DB_STATUS state and its ARN is $ORACLE_DB_ARN"
      Start-RDSDBInstance -DBInstanceIdentifier $ORACLE_DB_IDENTIFIER
      Write-Host "Waiting for Oracle RDS to be in Available state"

      $RETRY_COUNT = check_oracle_rds_status $ORACLE_DB_IDENTIFIER
      if ( $RETRY_COUNT -le 0 )
      {
         throw "Timeout: 30 minutes expired waiting for RDS to be in availabe state"
      }
      Write-Host "Oracle RDS is in Available state"}

   else
   {
      throw "Oracle Database is in $ORACLE_DB_STATUS state"
   }
}

elseif ($ORACLE_DB_COUNT -eq 0)
{
   Write-Host "No existing oracle database exist with lansa version tag = $lansa_version"
   $ORACLE_SNAPSHOT_COUNT = ((Get-RDSDBSnapshot -DBInstanceIdentifier $ORACLE_SNAPSHOT_IDENTIFIER -SnapshotType manual).DBSnapshotArn).count
   if ($ORACLE_SNAPSHOT_COUNT -eq 1)
   {
      Write-Host "Found 1 snapshot for database identifier $ORACLE_SNAPSHOT_IDENTIFIER"
      $STACK_NAME = "DB-Regression-ORACLE-RDS-" + $lansa_version
      try
      {
         $EXISTING_CFN_STACK_STATUS = ((Get-CFNStack -StackName $STACK_NAME).StackStatus).Value
         Write-Host "CFN Stack with stack name = $STACK_NAME exist and is in $EXISTING_CFN_STACK_STATUS state"
         $RETRY_COUNT = remove_cfn_stack $STACK_NAME
         if ( $RETRY_COUNT -le 0 )
         {
            throw "Timeout: 30 minutes expired waiting to Delete CFN Stack $STACK_NAME"
         }

         Get-CFNStack -StackName $STACK_NAME

      }
      catch [System.InvalidOperationException]
      {
      $ORACLE_SNAPSHOT_IDENTIFIER_ARN =  (Get-RDSDBSnapshot -DBInstanceIdentifier $ORACLE_SNAPSHOT_IDENTIFIER -SnapshotType manual).DBSnapshotArn
      New-CFNStack -StackName $STACK_NAME -TemplateBody $oracle_rds_template -Parameter @(@{ParameterKey="LANSAVERSION";ParameterValue=$lansa_version}, @{ParameterKey="ORACLESNAPSHOTARN"; ParameterValue=$ORACLE_SNAPSHOT_IDENTIFIER_ARN}) -Tag @{Key="LansaVersion"; Value=$lansa_version}
      }

      $RETRY_COUNT = cfn_stack_status $STACK_NAME
      if ( $RETRY_COUNT -le 0 )
      {
         throw "Timeout: 30 minutes expired waiting for CFN stack to be in CREATE_COMPLETE state"
      }
      Write-Host "CFN Stack $STACK_NAME is in CREATE_COMPLETE State"
      $RETRY_COUNT = check_oracle_rds_status $ORACLE_SNAPSHOT_IDENTIFIER
      if ( $RETRY_COUNT -le 0 )
      {
         throw "Timeout: 30 minutes expired waiting for RDS to be in availabe state"
      }
      Write-Host "Oracle RDS is in Available state"
   }

   elseif ($ORACLE_SNAPSHOT_COUNT -eq 0)
   {
      throw "Found 0 snapshot for database identifier $ORACLE_SNAPSHOT_IDENTIFIER"
   }

   else
   {
      throw "Found more than 1 snapshot for database identifier $ORACLE_SNAPSHOT_IDENTIFIER"
   }
}

else
{
   throw "More than 1 Oracle RDS with Lansa Version tag = $lansa_version exist"
}

#########################################################################################
##
## MYSQL RDS
##
#########################################################################################

function check_mysql_rds_status
{
   Param
   (
      [Parameter(Mandatory=$true)] [String]$MYSQL_DB_ID
   )
   $RetryCount = 15
   while ( ((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$MYSQL_DB_ID}).DBInstanceStatus -ne "available") -and ($RetryCount -gt 0))
   {
      Start-Sleep -Seconds 120
      $RetryCount -= 1
      if ( ((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$MYSQL_DB_ID}).DBInstanceStatus -eq "starting") -or ((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$ORACLE_DB_ID}).DBInstanceStatus -eq "backing-up")  )
      {
         Write-Host "MYSQL RDS is getting started"
      }
   }
   return $RetryCount
}

Write-Host "Searching for MYSQL RDS with Lansa Version tag = $lansa_version"

$MYSQL_DB_IDENTIFIER = "mysql" + $lansa_version
$MYSQL_SNAPSHOT_IDENTIFIER = "mysql" + $clone_lansa_version
$MYSQL_DB_COUNT = (Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$MYSQL_DB_IDENTIFIER}).count

if ($MYSQL_DB_COUNT -eq 1)
{
   Write-Host "MYSQL RDS with Lansa version tag = $lansa_version already exist"
   $MYSQL_DB_STATUS = (Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$MYSQL_DB_IDENTIFIER}).DBInstanceStatus
   $MYSQL_DB_ARN = (Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$MYSQL_DB_IDENTIFIER}).DBInstanceArn

   if ($MYSQL_DB_STATUS -eq "available")
   {
      Write-Host "MYSQL RDS is in $MYSQL_DB_STATUS state and its ARN is $MYSQL_DB_ARN"
   }

   elseif ($MYSQL_DB_STATUS -eq "stopped")
   {
      Write-Host "MYSQL RDS is in $MYSQL_DB_STATUS state and its ARN is $MYSQL_DB_ARN"
      Start-RDSDBInstance -DBInstanceIdentifier $MYSQL_DB_IDENTIFIER
      Write-Host "Waiting for MYSQL RDS to be in Available state"

      $RETRY_COUNT = check_mysql_rds_status $MYSQL_DB_IDENTIFIER
      if ( $RETRY_COUNT -le 0 )
      {
         throw "Timeout: 30 minutes expired waiting for MYSQL RDS to be in availabe state"
      }
      Write-Host "MYSQL RDS with Lansa Version tag = $lansa_version is in Available state"
   }
   else
   {
      throw "MYSQL RDS in $MYSQL_DB_STATUS state"
   }
}

elseif ($MYSQL_DB_COUNT -eq 0)
{
   Write-Host "No existing MYSQL RDS with Lansa version tag = $lansa_version exist"
   $MYSQL_SNAPSHOT_COUNT = ((Get-RDSDBSnapshot -DBInstanceIdentifier $MYSQL_SNAPSHOT_IDENTIFIER -SnapshotType manual).DBSnapshotArn).count
   if ($MYSQL_SNAPSHOT_COUNT -eq 1)
   {
      Write-Host "Found 1 snapshot for identifier $MYSQL_SNAPSHOT_IDENTIFIER"
      $STACK_NAME = "DB-Regression-MYSQL-RDS-" + $lansa_version
      try
      {
         $EXISTING_CFN_STACK_STATUS = ((Get-CFNStack -StackName $STACK_NAME).StackStatus).Value
         Write-Host "CFN Stack with stack name = $STACK_NAME exist and is in $EXISTING_CFN_STACK_STATUS state"
         $RETRY_COUNT = remove_cfn_stack $STACK_NAME
         if ( $RETRY_COUNT -le 0 )
         {
            throw "Timeout: 30 minutes expired waiting to Delete CFN Stack $STACK_NAME"
         }

         Get-CFNStack -StackName $STACK_NAME
      }
      catch [System.InvalidOperationException]
      {
      $MYSQL_SNAPSHOT_IDENTIFIER_ARN =  (Get-RDSDBSnapshot -DBInstanceIdentifier $MYSQL_SNAPSHOT_IDENTIFIER -SnapshotType manual).DBSnapshotArn
      New-CFNStack -StackName $STACK_NAME -TemplateBody $mysql_rds_template -Parameter @(@{ParameterKey="LANSAVERSION";ParameterValue=$lansa_version}, @{ParameterKey="MYSQLSNAPSHOTARN"; ParameterValue=$MYSQL_SNAPSHOT_IDENTIFIER_ARN}) -Tag @{Key="LansaVersion"; Value=$lansa_version}
      }

      $RETRY_COUNT = cfn_stack_status $STACK_NAME
      if ( $RETRY_COUNT -le 0 )
      {
         throw "Timeout: 30 minutes expired waiting for CFN stack to be CREATE_COMPLETE state"
      }
      Write-Host "CFN Stack $STACK_NAME is in CREATE_COMPLETE State"

      $RETRY_COUNT = check_mysql_rds_status $MYSQL_SNAPSHOT_IDENTIFIER
      if ($RETRY_COUNT -le 0)
      {
         throw "Timeout: 30 minutes expired waiting for MYSQL RDS to be in availabe state"
      }
      Write-Host "MYSQL RDS is in Available State"
   }

   elseif ($MYSQL_SNAPSHOT_COUNT -eq 0)
   {
      throw "Found 0 snapshot for database identifier $MYSQL_SNAPSHOT_IDENTIFIER"
   }

   else
   {
      throw "Found more than 1 snapshot for database identifier $MYSQL_SNAPSHOT_IDENTIFIER"
   }
}

else
{
   throw "More than 1 MYSQL RDS with lansa version tag = $lansa_version already exist"
}
