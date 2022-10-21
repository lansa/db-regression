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
    echo "Found 1 AMI"
    $AMI_ID = (Get-EC2Image -Filter @{ Name="tag:LansaVersion"; Values=$lansa_version }).ImageId
    echo $AMI_ID
    New-CNFStack -StackName .........................}
  elseif ($NO_OF_AMIS -eq 0){
    echo "Did not find any AMI with this tag"}
  else{
    echo "Found more than 1 tag for this version"}}

else{
  echo "Found more than 1 VM with same value of LAnsa Version tag"}
