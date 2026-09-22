## Powershell script for provisioning AWS stack for DB Regeression Test.

param (
[parameter(Mandatory=$true)]    [string] $lansa_version,
[parameter(Mandatory=$false)]   [string] $clone_lansa_version, ## lansa version tag that would be used to create clone stack.
[parameter(Mandatory=$false)]   [switch] $create_vm_only
)

if ( [string]::IsNullOrWhiteSpace( $clone_lansa_version))
{
   $clone_lansa_version = $lansa_version
}

$ErrorActionPreference = 'Continue'

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
   $RetryCount = 120
   while (($NULL -EQ (Get-EC2PasswordData -InstanceId $INSTANCE_ID -PemFile $env:tmp\KeyPair.pem) ) -and ($RetryCount -gt 0) )
   {
      Start-Sleep -Seconds 20
      $RetryCount -= 1
      Write-Host "Waiting to fetch the VM password"
   }
    return $RetryCount
}

function show_cfn_failure_reason
{
   Param
   (
      [Parameter(Mandatory=$true)] [String]$STACK_ID
   )
   # A stack status such as ROLLBACK_IN_PROGRESS says that the stack failed but never why. The
   # reason lives in the stack events, and by the time anyone reads the build log the next run
   # has usually deleted the stack - at which point it can only be reached by its ID, not by its
   # name. So log the ID as well, and dump the events here while they are still cheap to get.
   Write-Host "Stack ID: $STACK_ID"
   Write-Host "Failed CloudFormation events (earliest first - the FIRST one is the root cause;"
   Write-Host "everything after it is usually just the rollback tidying up):"
   try
   {
      $FAILED_EVENTS = @(Get-CFNStackEvent -StackName $STACK_ID -ErrorAction Stop |
                         Where-Object { $_.ResourceStatus -like "*FAILED*" } |
                         Sort-Object Timestamp)
      if ( $FAILED_EVENTS.Count -eq 0 )
      {
         Write-Host "   None reported yet - the rollback may still be in progress."
      }
      foreach ( $CFN_EVENT in $FAILED_EVENTS )
      {
         Write-Host ("   {0:HH:mm:ss} {1} ({2}) {3}" -f $CFN_EVENT.Timestamp, $CFN_EVENT.LogicalResourceId, $CFN_EVENT.ResourceType, $CFN_EVENT.ResourceStatus)
         Write-Host "      $($CFN_EVENT.ResourceStatusReason)"
      }
   }
   catch
   {
      # Diagnostics must never replace the real failure - swallow anything that goes wrong here
      # so the caller's throw is still what surfaces.
      Write-Host "   Could not read stack events: $($_.Exception.Message)"
   }
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
      # Keep the whole stack, not just the status: StackId is needed to read the events back
      # after the stack has been deleted.
      $CFN_STACK = Get-CFNStack -StackName $STACK_NAME
      $CFN_STACK_STATUS = ($CFN_STACK.StackStatus).Value
      if ( $CFN_STACK_STATUS -eq "ROLLBACK_COMPLETE" -or $CFN_STACK_STATUS -eq "CREATE_FAILED" -or $CFN_STACK_STATUS -eq "DELETE_COMPLETE" -or $CFN_STACK_STATUS -eq "DELETE_FAILED" -or $CFN_STACK_STATUS -eq "ROLLBACK_FAILED" -or $CFN_STACK_STATUS -eq "ROLLBACK_IN_PROGRESS" -or $CFN_STACK_STATUS -eq "UPDATE_FAILED" -or $CFN_STACK_STATUS -eq "UPDATE_ROLLBACK_FAILED" -or $CFN_STACK_STATUS -eq "UPDATE_ROLLBACK_IN_PROGRESS" -or $CFN_STACK_STATUS -eq "IMPORT_ROLLBACK_FAILED" ) {
         show_cfn_failure_reason $CFN_STACK.StackId
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

   $DB_COUNT = (@(Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$DB_IDENTIFIER})).Count

   if ($DB_COUNT -eq 1)
   {
      Write-Host "RDS $DB_IDENTIFIER already exists"
      $DB_STATUS = (Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$DB_IDENTIFIER}).DBInstanceStatus
      $DB_ARN = (Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$DB_IDENTIFIER}).DBInstanceArn

      if ($DB_STATUS -eq "stopped")
      {
         # Remove any scheduler tag that may be keeping the instance stopped
         Remove-RDSTagFromResource -ResourceName $DB_ARN -TagKey "Schedule" -Force

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
      $STACK_NAME = "DB-Regression-$($FULL_DATABASE_TYPE)-RDS-" + $lansa_version
      try
      {
         $SNAPSHOT_COUNT = (@((Get-RDSDBSnapshot -DBSnapshotIdentifier $SNAPSHOT_IDENTIFIER -SnapshotType manual).DBSnapshotArn)).count
         if ($SNAPSHOT_COUNT -eq 1)
         {
            Write-Host "Found 1 snapshot for identifier $SNAPSHOT_IDENTIFIER"
            
            # Existence is decided by RETURN VALUE, not by an exception. This used to be a
            # 'catch [System.InvalidOperationException]' around Get-CFNStack, which was unsafe:
            # AWS raises that same exception for absent credentials, denied permissions and
            # connectivity failures, so any of those was read as "the stack is not there" and
            # answered with New-CFNStack. Measured on an agent under AWSPowerShell 4.1.554,
            # Test-CFNStack returns $true for a stack in ANY status (ROLLBACK_COMPLETE included)
            # and $false both for a name that never existed and for one whose stack has been
            # deleted - so it answers the question the old catch was only approximating, and a
            # credentials failure now stops the run instead of creating a duplicate stack.
            if ( Test-CFNStack -StackName $STACK_NAME )
            {
               $EXISTING_CFN_STACK_STATUS = ((Get-CFNStack -StackName $STACK_NAME).StackStatus).Value
               Write-Host "CFN Stack $STACK_NAME exists and is in $EXISTING_CFN_STACK_STATUS state"
               $RETRY_COUNT = remove_cfn_stack $STACK_NAME
               if ( $RETRY_COUNT -le 0 )
               {
                  throw "Timeout: 1 hour expired waiting to Delete CFN Stack $STACK_NAME"
               }
               if ( Test-CFNStack -StackName $STACK_NAME )
               {
                  throw "CFN Stack still exists. It failed to delete"
               }
               Write-Host "$STACK_NAME has been deleted."
            }

            Write-Host "Creating $STACK_NAME stack"
            $SNAPSHOT_IDENTIFIER_ARN =  (Get-RDSDBSnapshot -DBSnapshotIdentifier $SNAPSHOT_IDENTIFIER -SnapshotType manual).DBSnapshotArn
            New-CFNStack -StackName $STACK_NAME -TemplateBody $TEMPLATE_BODY -Parameter @(@{ParameterKey="LANSAVERSION";ParameterValue=$lansa_version}, @{ParameterKey="SNAPSHOTARN"; ParameterValue=$SNAPSHOT_IDENTIFIER_ARN}) -Tag @(@{Key="LansaVersion"; Value=$lansa_version}) | Out-Default | Write-Host

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

$RUNNING_INSTANCE_COUNT = 0
$RUNNING_INSTANCES = Get-EC2Instance -Filter @{ Name="tag:LansaVersion"; Values=$lansa_version }, @{Name="instance-state-name"; Values="running"}
if ( $RUNNING_INSTANCES){
   $RUNNING_INSTANCES.Instances | Out-Default | Write-Host
   $RUNNING_INSTANCE_COUNT = $RUNNING_INSTANCES.instances.count
}

$STOPPED_INSTANCE_COUNT = 0
$STOPPED_INSTANCES = Get-EC2Instance -Filter @{ Name="tag:LansaVersion"; Values=$lansa_version }, @{Name="instance-state-name"; Values="stopped"}
if ( $STOPPED_INSTANCES){
   $STOPPED_INSTANCES.Instances | Out-Default | Write-Host
   $STOPPED_INSTANCE_COUNT = $STOPPED_INSTANCES.Instances.Count
}

$EXISTING_INSTANCE_COUNT = $RUNNING_INSTANCE_COUNT + $STOPPED_INSTANCE_COUNT

if ($EXISTING_INSTANCE_COUNT -eq 1 )
{
   Write-Host "Found 1 VM with Lansa Version tag = $lansa_version"
   Write-Host "Checking the VM Status"
   $INSTANCE_ID = ((Get-EC2Instance -Filter @{ Name="tag:LansaVersion"; Values=$lansa_version }, @{Name="instance-state-name"; Values="running", "stopped"}).Instances).InstanceId
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
      Write-Host "Found 1 AMI with Lansa version tag = $clone_lansa_version"
      $AMI_ID = (Get-EC2Image -Filter @{ Name="tag:LansaVersion"; Values=$clone_lansa_version }).ImageId
      $STACK_NAME = "DB-Regression-VM-" + $lansa_version
      # Existence by return value rather than by exception - see the equivalent block in the
      # RDS branch above for why the old typed catch was unsafe.
      if ( Test-CFNStack -StackName $STACK_NAME )
      {
         $EXISTING_CFN_STACK_STATUS = ((Get-CFNStack -StackName $STACK_NAME).StackStatus).Value
         Write-Host "CFN Stack with stack name = $STACK_NAME exists and is in $EXISTING_CFN_STACK_STATUS state"
         $RETRY_COUNT = remove_cfn_stack $STACK_NAME
         if ( $RETRY_COUNT -le 0 )
         {
            throw "Timeout: 30 minutes expired waiting to Delete CFN Stack $STACK_NAME"
         }
         if ( Test-CFNStack -StackName $STACK_NAME )
         {
            throw "CFN Stack still exists. It failed to delete"
         }
         Write-Host "CFN Stack $STACK_NAME has been deleted."
      }

      Write-Host "Creating $STACK_NAME stack"
      New-CFNStack -StackName $STACK_NAME -TemplateBody $vm_template -Parameter @(@{ParameterKey="AMIID";ParameterValue=$AMI_ID}, @{ParameterKey="LANSAVERSION"; ParameterValue=$lansa_version}) -Tag @{Key="LansaVersion"; Value=$lansa_version}

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

if (-not $create_vm_only) {
   #******************************************************************************
   # Create Databases
   #******************************************************************************

   provision_database "ora"
   provision_database "mysql"
}