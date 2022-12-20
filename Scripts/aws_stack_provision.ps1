## Powershell script for provisioning AWS stack for DB Regeression Test.

param (
[parameter(Mandatory=$true)]    [string] $lansa_version,
[parameter(Mandatory=$false)]   [string] $clone_lansa_version ## lansa version tag that would be used to create clone stack.
)

if ( [string]::IsNullOrWhiteSpace( $clone_lansa_version))
{
   $clone_lansa_version = $lansa_version
}

$aws_stack_script_path = $MyInvocation.MyCommand.Path
$stack_script = Split-Path $aws_stack_script_path
$git_repo_root = Get-Item $stack_script\..\Templates\aws

$vm_template = Get-Content -Path $git_repo_root\vm.cfn.template.yaml -Raw

Set-DefaultAWSRegion -Region 'us-east-1' -Scope Script

function fetch_vm_password
{
   Param
   (
      [Parameter(Mandatory=$true)] [String]$INSTANCE_ID
   )
   Write-Host "Trying to fetch the VM Password"
   (Get-SECSecretValue -SecretId privatekey/AzureDevOps).SecretString > $env:tmp\KeyPair.pem
   $RetryCount = 60
   while (($NULL -EQ (Get-EC2PasswordData -InstanceId $INSTANCE_ID -PemFile $env:tmp\KeyPair.pem) ) -and ($RetryCount -gt 0) )
   {
      Start-Sleep -Seconds 20
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
   Write-Host "Checking CFN stack $STACK_NAME status"
   $RetryCount = 180
   do
   {
      $CFN_STACK_STATUS = ((Get-CFNStack -StackName $STACK_NAME).StackStatus).Value
      if ( $CFN_STACK_STATUS -eq "ROLLBACK_COMPLETE" -or $CFN_STACK_STATUS -eq "CREATE_FAILED" -or $CFN_STACK_STATUS -eq "DELETE_COMPLETE" -or $CFN_STACK_STATUS -eq "DELETE_FAILED" -or $CFN_STACK_STATUS -eq "ROLLBACK_FAILED" -or $CFN_STACK_STATUS -eq "ROLLBACK_IN_PROGRESS" -or $CFN_STACK_STATUS -eq "UPDATE_FAILED" -or $CFN_STACK_STATUS -eq "UPDATE_ROLLBACK_FAILED" -or $CFN_STACK_STATUS -eq "UPDATE_ROLLBACK_IN_PROGRESS" -or $CFN_STACK_STATUS -eq "IMPORT_ROLLBACK_FAILED" ) {
         throw "CFN $STACK_NAME stack is in the invalid state '$CFN_STACK_STATUS' state"
      }
      if ($CFN_STACK_STATUS -ne "CREATE_COMPLETE") {
         Start-Sleep -Seconds 20
         $RetryCount -= 1
         Write-Host "CFN $STACK_NAME stack is in $CFN_STACK_STATUS status. Waiting for CREATE_COMPLETE state"
      }
   } while (($CFN_STACK_STATUS -ne "CREATE_COMPLETE") -and ($RetryCount -gt 0) )
   return $RetryCount
}

function remove_cfn_stack
{
   Param
   (
      [Parameter(Mandatory=$true)] [String]$STACK_NAME
   )
   Write-Host "Deleting exisitng CFN stack $STACK_NAME"
   $RetryCount = 90
   Remove-CFNStack -StackName $STACK_NAME -Force
   while (((Test-CFNStack -StackName $STACK_NAME -Status "DELETE_IN_PROGRESS") -eq $true )  -and ($RetryCount -gt 0) )
   {
      Write-Host "Waiting for deletion of existing CFN stack $STACK_NAME"
      Start-Sleep -Seconds 20
      $RetryCount -= 1
   }
   return $RetryCount
}

function check_rds_status
{
   Param
   (
      [Parameter(Mandatory=$true)] [String]$DB_ID
   )
   Write-Host "Checking RDS status for $DB_ID and waiting for it to be ready."
   $RetryCount = 90
   do {
      $global:InstanceStatus = (Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$DB_ID}).DBInstanceStatus

      if ( ($global:InstanceStatus -eq "Deleting") -or ($global:InstanceStatus -eq "Failed") -or ($global:InstanceStatus -eq "Inaccessible-encryption-credentials") -or ($global:InstanceStatus -eq "Inaccessible-encryption-credentials-recoverable")-or ($global:InstanceStatus -eq "Incompatible-network") -or ($global:InstanceStatus -eq "Incompatible-option-group") -or ($global:InstanceStatus -eq "Incompatible-parameters") -or ($global:InstanceStatus -eq "Incompatible-restore") -or ($global:InstanceStatus -eq "Insufficient-capacity") -or ($global:InstanceStatus -eq "Restore-error") -or ($global:InstanceStatus -eq "Storage-full") -or ($global:InstanceStatus -eq "Stopping") -or ($global:InstanceStatus -eq "Stopped") )
      {
        throw "RDS $DB_ID is in the invalid state '$($global:InstanceStatus)'. Aborting"
      }
      if ( ($global:InstanceStatus -ne "Available") ) {
        Write-Host "RDS $DB_ID is in $($global:InstanceStatus) status. Waiting for it to be available"
        Start-Sleep -Seconds 20
        $RetryCount -= 1
      }
   } while ( ($global:InstanceStatus -ne "available") -and ($RetryCount -gt 0))
   if ($global:InstanceStatus -eq "available") {
      Write-Host "RDS $DB_ID is in Available state"
   }
   return $RetryCount
}

function provision_database
{
   Param
   (
      [Parameter(Mandatory=$true)] [String]$DatabaseType
   )

   $DB_IDENTIFIER = $DatabaseType + $lansa_version
   $SNAPSHOT_IDENTIFIER = $DatabaseType + $clone_lansa_version

   Write-Host
   Write-Host "Searching for RDS $DB_IDENTIFIER"

   switch ($DatabaseType) {
      "ora"   {
         $FULL_DATABASE_TYPE = "ORACLE"
         $TEMPLATE_BODY = Get-Content -Path $git_repo_root\oracle_rds.cfn.template.yaml -Raw
       }
      "mysql" {
         $FULL_DATABASE_TYPE = "MYSQL"
         $TEMPLATE_BODY = Get-Content -Path $git_repo_root\mysql_rds.cfn.template.yaml -Raw
      }
   }

   $DB_COUNT = (Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$DB_IDENTIFIER}).count

   if ($DB_COUNT -eq 1)
   {
      Write-Host "RDS $DB_IDENTIFIER already exists"
      $DB_STATUS = (Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$DB_IDENTIFIER}).DBInstanceStatus

      if ($DB_STATUS -eq "stopped")
      {
         Start-RDSDBInstance -DBInstanceIdentifier $DB_IDENTIFIER | Out-Default | Write-Host
         Write-Host "Waiting for RDS $DB_IDENTIFIER to be in Available state"

         $RETRY_COUNT = check_rds_status $DB_IDENTIFIER
         if ( $RETRY_COUNT -le 0 )
         {
            throw "Timeout: 30 minutes expired waiting for RDS $DB_IDENTIFIER to be in available state. Current state is $($global:InstanceStatus)"
         }
      }
      elseif ($DB_STATUS -ne "available")
      {
            # If the database has been created external to this script then it might still be being created.
            # Or maybe the script was cancelled but the database is still being created and this script has been run again.
            # So handle it like a stopped database.
            $RETRY_COUNT = check_rds_status $DB_IDENTIFIER
            if ( $RETRY_COUNT -le 0 )
            {
               throw "Timeout: 30 minutes expired waiting for RDS $DB_IDENTIFIER to be in available state. Current state is $($global:InstanceStatus)"
            }
      }
   }
   elseif ($DB_COUNT -eq 0)
   {
      Write-Host "RDS $DB_IDENTIFIER does not exist"
      try
      {
         $SNAPSHOT_COUNT = ((Get-RDSDBSnapshot -DBSnapshotIdentifier $SNAPSHOT_IDENTIFIER -SnapshotType manual).DBSnapshotArn).count
         if ($SNAPSHOT_COUNT -eq 1)
         {
            Write-Host "Found 1 snapshot for identifier $SNAPSHOT_IDENTIFIER"
            $STACK_NAME = "DB-Regression-$($FULL_DATABASE_TYPE)-RDS-" + $lansa_version
            try
            {
               Write-Host "If Stack $STACK_NAME does not exist the exception System.InvalidOperationException will be thrown. This is the expected state"
               $EXISTING_CFN_STACK_STATUS = ((Get-CFNStack -StackName $STACK_NAME).StackStatus).Value
               Write-Host "CFN Stack $STACK_NAME exists and is in $EXISTING_CFN_STACK_STATUS state"
               $RETRY_COUNT = remove_cfn_stack $STACK_NAME
               if ( $RETRY_COUNT -le 0 )
               {
                  throw "Timeout: 1 hour expired waiting to Delete CFN Stack $STACK_NAME"
               }
               Write-Host "$STACK_NAME should by now have been deleted."
               Write-Host "If Stack $STACK_NAME does not exist the exception System.InvalidOperationException will be thrown. This is the expected state"
               Get-CFNStack -StackName $STACK_NAME | Out-Default | Write-Host
               throw "CFN Stack still exists. It failed to delete"
            }
            catch [System.InvalidOperationException]
            {
               Write-Host "Creating $STACK_NAME stack"
               $SNAPSHOT_IDENTIFIER_ARN =  (Get-RDSDBSnapshot -DBSnapshotIdentifier $SNAPSHOT_IDENTIFIER -SnapshotType manual).DBSnapshotArn
               New-CFNStack -StackName $STACK_NAME -TemplateBody $TEMPLATE_BODY -Parameter @(@{ParameterKey="LANSAVERSION";ParameterValue=$lansa_version}, @{ParameterKey="SNAPSHOTARN"; ParameterValue=$SNAPSHOT_IDENTIFIER_ARN}) -Tag @(@{Key="LansaVersion"; Value=$lansa_version}, @{Key="RDS_KEEP_STOPPED"; Value='YES'}) | Out-Default | Write-Host
            }

            $RETRY_COUNT = cfn_stack_status $STACK_NAME
            if ( $RETRY_COUNT -le 0 )
            {
               throw "Timeout: 1 hour expired waiting for CFN stack to be CREATE_COMPLETE state"
            }
            Write-Host "CFN Stack $STACK_NAME is in CREATE_COMPLETE State"

            $RETRY_COUNT = check_rds_status $DB_IDENTIFIER
            if ($RETRY_COUNT -le 0)
            {
               throw "Timeout: 30 minutes expired waiting for RDS $DB_IDENTIFIER to be in available state. Current state is $($global:InstanceStatus)"
            }
         }
         else
         {
            throw "Found none or more than 1 snapshot for database identifier $SNAPSHOT_IDENTIFIER"
         }
      }
      catch
      {
         $_ | Out-Default | Write-Host
         throw "Error creating stack $STACK_NAME"
      }
   }
   else
   {
      throw "More than 1 RDS $DatabaseType with lansa version tag = $lansa_version already exists"
   }
   # If execution gets here it must be available
   $DB_ARN = (Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$DB_IDENTIFIER}).DBInstanceArn
   Write-Host "RDS $DB_IDENTIFIER is available and its ARN is $DB_ARN"
}

#******************************************************************************
# Create VM
#******************************************************************************

Write-Host "Searching for VM with Lansa Version tag = $lansa_version"

$RUNNING_INSTANCE_COUNT = (((Get-EC2Instance -Filter @{ Name="tag:LansaVersion"; Values=$lansa_version }, @{Name="instance-state-name"; Values="running"}).Instances).InstanceId).count

$STOPPED_INSTANCE_COUNT = (((Get-EC2Instance -Filter @{ Name="tag:LansaVersion"; Values=$lansa_version }, @{Name="instance-state-name"; Values="stopped"}).Instances).InstanceId).count

$EXISTING_INSTANCE_COUNT = $RUNNING_INSTANCE_COUNT + $STOPPED_INSTANCE_COUNT

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
   Write-Host "No Existing VM found with Lansa Version tag = $lansa_version"
   $NO_OF_AMIS = (Get-EC2Image -Filter @{ Name="tag:LansaVersion"; Values=$clone_lansa_version } | Select-Object ImageId | Measure-Object | Select-Object Count).count
   if ($NO_OF_AMIS -eq 1)
   {
      Write-Host "Found 1 AMI with Lansa vesion tag = $clone_lansa_version"
      $AMI_ID = (Get-EC2Image -Filter @{ Name="tag:LansaVersion"; Values=$clone_lansa_version }).ImageId
      $STACK_NAME = "DB-Regression-VM-" + $lansa_version
      try
      {
         Write-Host "If Stack does not exist the exception System.InvalidOperationException will be thrown. This is an expected state"
         $EXISTING_CFN_STACK_STATUS = ((Get-CFNStack -StackName $STACK_NAME).StackStatus).Value
         Write-Host "CFN Stack with stack name = $STACK_NAME exist and is in $EXISTING_CFN_STACK_STATUS state"
         $RETRY_COUNT = remove_cfn_stack $STACK_NAME
         if ( $RETRY_COUNT -le 0 )
         {
            throw "Timeout: 30 minutes expired waiting to Delete CFN Stack $STACK_NAME"
         }
         Write-Host "CFN Stack $STACK_NAME should have been deleted. If it has, than the exception System.InvalidOperationException will be thrown. This is an expected state"
         Get-CFNStack -StackName $STACK_NAME
         throw "CFN Stack still exist. It failed to delete"
      }
      catch [System.InvalidOperationException]
      {
         Write-Host "Creating $STACK_NAME stack"
         New-CFNStack -StackName $STACK_NAME -TemplateBody $vm_template -Parameter @(@{ParameterKey="AMIID";ParameterValue=$AMI_ID}, @{ParameterKey="LANSAVERSION"; ParameterValue=$lansa_version}) -Tag @{Key="LansaVersion"; Value=$lansa_version}
      }

      $RETRY_COUNT = cfn_stack_status $STACK_NAME
      if ( $RETRY_COUNT -le 0 )
      {
         throw "Timeout: 30 minutes expired waiting for CFN stack to be in CREATE_COMPLETE state"
      }
      Write-Host "CFN Stack $STACK_NAME is in CREATE_COMPLETE State"
      $PHYSICAL_INSTANCE_ID = ((Get-CFNStackResource -StackName $STACK_NAME -LogicalResourceId INSTANCE).PhysicalResourceId)
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
   throw "Found more than 1 VM with Lansa Version tag = $lansa_version"
}

#******************************************************************************
# Create Databases
#******************************************************************************

provision_database "ora"
provision_database "mysql"