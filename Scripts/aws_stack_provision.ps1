## Powershell script for

param (
    [string] $lansa_version
)
#$NO_OF_AMIS = (Get-EC2Image -Filter @{ Name="tag:LansaVersion"; Values="150050" } | Select-Object ImageId | Measure-Object | Select-Object Count).count
$NO_OF_AMIS = (Get-EC2Image -Filter @{ Name="tag:LansaVersion"; Values=$lansa_version } | Select-Object ImageId | Measure-Object | Select-Object Count).count


if ($NO_OF_AMIS -eq 1) {
	echo "Found 1 AMI"
	$AMI_ID = (Get-EC2Image -Filter @{ Name="tag:LansaVersion"; Values="150050" }).ImageId
	echo $AMI_ID }
elseif ($NO_OF_AMIS -eq 0) {
	echo "Did not find any AMI with this tag" }
else {
	echo "Found more than 1 tag for this version" }
