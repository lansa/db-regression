## Powershell script for

param (
    [string] $lansa_version
)


$EXISTING_INSTANCE_COUNT = (((Get-EC2Instance -Filter @{ Name="tag:LansaVersion"; Values=$lansa_version }).Instances).InstanceId).count

if ($EXISTING_INSTANCE_COUNT -eq 1 ){
  echo "VM with same lansa Version tag exist"
  echo "Checking VM Status"
  $INSTANCE_ID = ((Get-EC2Instance -Filter @{ Name="tag:LansaVersion"; Values=$lansa_version }).Instances).InstanceId
  $INSTANCE_STATE = (((Get-EC2InstanceStatus -IncludeAllInstance $true -InstanceId $INSTANCE_ID).InstanceState).Name).Value

  if ($INSTANCE_STATE -eq "running"){
     echo "VM is already in running state"}
  elseif ($INSTANCE_STATE -eq "stopped"){
     echo "VM is in stopped state"
     echo "Starting the VM"
     $INSTANCE_ID = ((Get-EC2Instance -Filter @{ Name="tag:LansaVersion"; Values=$lansa_version }).Instances).InstanceId
     Start-Sleep -Seconds 60
     $NEW_STATUS = (((Start-EC2Instance -InstanceID $INSTANCE_ID).CurrentState).Name).Value
     echo "Current status of VM is $NEW_STATUS"}
  else{
     echo "VM is neither Running nor stopped"
     echo "VM status is $INSTANCE_STATE"}  }

elseif ($EXISTING_INSTANCE_COUNT -eq 0){
  echo "No Exisiting VM found for this lansa version"
  $NO_OF_AMIS = (Get-EC2Image -Filter @{ Name="tag:LansaVersion"; Values=$lansa_version } | Select-Object ImageId | Measure-Object | Select-Object Count).count
  if ($NO_OF_AMIS -eq 1){
    echo "Found 1 AMI with this version tag"
    $AMI_ID = (Get-EC2Image -Filter @{ Name="tag:LansaVersion"; Values=$lansa_version }).ImageId
    echo $AMI_ID
    New-CNFStack -StackName .........................}
  elseif ($NO_OF_AMIS -eq 0){
    echo "Did not find any AMI with this tag"}
  else{
    echo "Found more than 1 AMI with this version tag"}}

else{
  echo "Found more than 1 VM with same value of LAnsa Version tag"}

## Checking Oracle database for required lansa version

$ORACLE_DB_IDENTIFIER = "ora" + $lansa_version
$ORACLE_DB_COUNT = (Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$ORACLE_DB_IDENTIFIER}).count

if ($ORACLE_DB_COUNT -eq 1){
  echo "Oracle DB with required lansa version tag already exist"
  $ORACLE_DB_STATUS = (Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$ORACLE_DB_IDENTIFIER}).DBInstanceStatus
  $ORACLE_DB_ARN = (Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$ORACLE_DB_IDENTIFIER}).DBInstanceArn
  if ($ORACLE_DB_STATUS -eq "available"){
    echo "Oracle Database is in $ORACLE_DB_STATUS state and its ARN is $ORACLE_DB_ARN"}
  elseif ($ORACLE_DB_STATUS -eq "stopped"){
    echo "Oracle Database is in $ORACLE_DB_STATUS state and its ARN is $ORACLE_DB_ARN"}
  else{
    echo "Oracle Database is in $ORACLE_DB_STATUS state"}}

elseif ($ORACLE_DB_COUNT -eq 0){
   echo "No existing oracle database exist with required lansa version"
   $ORACLE_SNAPSHOT_COUNT = ((Get-RDSDBSnapshot -DBInstanceIdentifier $ORACLE_DB_IDENTIFIER).DBSnapshotArn).count
   if ($ORACLE_SNAPSHOT_COUNT -eq 1){
     echo "Found 1 snapshot for database identifier $ORACLE_DB_IDENTIFIER"}
   elseif ($ORACLE_SNAPSHOT_COUNT -eq 0){
     echo "Found 0 snapshot for database identifier $ORACLE_DB_IDENTIFIER"}
   else{
     echo "Found more than 1 snapshot for database identifier $ORACLE_DB_IDENTIFIER"}}

else{
   echo "More than 1 Oracle DB with required lansa version tag already exist"} 
    
## Checking MYSQL database for required lansa version


$MYSQL_DB_IDENTIFIER = "mysql" + $lansa_version
$MYSQL_DB_COUNT = (Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$MYSQL_DB_IDENTIFIER}).count

if ($MYSQL_DB_COUNT -eq 1){
  echo "MYSQL DB with required lansa version tag already exist"
  $MYSQL_DB_STATUS = (Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$MYSQL_DB_IDENTIFIER}).DBInstanceStatus
  $MYSQL_DB_ARN = (Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$MYSQL_DB_IDENTIFIER}).DBInstanceArn
  if ($MYSQL_DB_STATUS -eq "available"){
    echo "MYSQL Database is in $MYSQL_DB_STATUS state and its ARN is $MYSQL_DB_ARN"}
  elseif ($MYSQL_DB_STATUS -eq "stopped"){
    echo "MYSQL Database is in $MYSQL_DB_STATUS state and its ARN is $MYSQL_DB_ARN"}  
  else{
    echo "MYSQL Database in $MYSQL_DB_STATUS state"}}


elseif ($MYSQL_DB_COUNT -eq 0){
   echo "No existing MYSQL database exist with required lansa version"
   $MYSQL_SNAPSHOT_COUNT = ((Get-RDSDBSnapshot -DBInstanceIdentifier $MYSQL_DB_IDENTIFIER).DBSnapshotArn).count
   if ($MYSQL_SNAPSHOT_COUNT -eq 1){
     echo "Found 1 snapshot for database identifier $MYSQL_DB_IDENTIFIER"}
   elseif ($MYSQL_SNAPSHOT_COUNT -eq 0){
     echo "Found 0 snapshot for database identifier $MYSQL_DB_IDENTIFIER"}
   else{
     echo "Found more than 1 snapshot for database identifier $MYSQL_DB_IDENTIFIER"}}

else{
   echo "More than 1 MYSQL DB with required lansa version tag already exist"}
