## Powershell script for

param (
[parameter(Mandatory=$true)]    [string] $lansa_version,
[parameter(Mandatory=$false)]   [string] $tag_lansa_version ## lansa version that would be used to tag cloned stack

)

Write-Host "Searching for VM with Lansa Version tag = $lansa_version"

$EXISTING_INSTANCE_COUNT = (((Get-EC2Instance -Filter @{ Name="tag:LansaVersion"; Values=$lansa_version }).Instances).InstanceId).count

if ($EXISTING_INSTANCE_COUNT -eq 1 ){
  
	Write-Host "VM with Lansa Version tag = $lansa_version exist"
	Write-Host "Checking VM Status"
	$INSTANCE_ID = ((Get-EC2Instance -Filter @{ Name="tag:LansaVersion"; Values=$lansa_version }).Instances).InstanceId
	$INSTANCE_STATE = (((Get-EC2InstanceStatus -IncludeAllInstance $true -InstanceId $INSTANCE_ID).InstanceState).Name).Value

  	if ($INSTANCE_STATE -eq "running"){
		Write-Host "VM is already in running state"}

	elseif ($INSTANCE_STATE -eq "stopped"){
     		Write-Host "VM is in stopped state"
     		Write-Host "Starting the VM"
     		$INSTANCE_ID = ((Get-EC2Instance -Filter @{ Name="tag:LansaVersion"; Values=$lansa_version }).Instances).InstanceId
     		$NEW_STATUS = (((Start-EC2Instance -InstanceID $INSTANCE_ID).CurrentState).Name).Value

     		Write-Host "Current status of VM is $NEW_STATUS"}

  	else{
     		Write-Host "VM is neither Running nor stopped"
     		Write-Host "VM status is $INSTANCE_STATE"}  
}
elseif ($EXISTING_INSTANCE_COUNT -eq 0){
  	Write-Host "No Exisiting VM with Lansa Version tag = $lansa_version found"
  	$NO_OF_AMIS = (Get-EC2Image -Filter @{ Name="tag:LansaVersion"; Values=$lansa_version } | Select-Object ImageId | Measure-Object | Select-Object Count).count
  	if ($NO_OF_AMIS -eq 1){
    		Write-Host "Found 1 AMI with Lansa vesion tag = $lansa_version"
    		$AMI_ID = (Get-EC2Image -Filter @{ Name="tag:LansaVersion"; Values=$lansa_version }).ImageId

    		#New-CNFStack -StackName "DB-Regression- + $lansa_version" .........................
		$PHYSICAL_INSTANCE_ID = ((Get-CFNStackResource -StackName "DB-Regression- + $lansa_version" -LogicalResourceId INSTANCE).PhysicalResourceId)		        
		( Get-SECSecretValue -SecretId privatekey/AzureDevOps).SecretString > $env:tmp\key.pem
		$RetryCount = 15
		while ( ((Get-EC2PasswordData -InstanceId $PHYSICAL_INSTANCE_ID -PemFile $env:tmp\key.pem) -eq $null ) -and ($RetryCount -gt 0) ){
			Start-Sleep -Seconds 120
      			$RetryCount -= 1 
                        Write-Host "Waiting to fetch VM password"}
                  
		if ( $RetryCount -le 0 ) {
        		throw "Timeout: 30 minutes expired waiting to fetch VM password"}
    		Write-Host "Able to fetch the VM password"}
                   

  	elseif ($NO_OF_AMIS -eq 0){
    		Write-Host "Did not find any AMI with the lansa version tag = $lansa_version"}
  	else{
    		Write-Host "Found more than 1 AMI with the lansa version tag = $lansa_version"}
}
else{
  	Write-Host "Found more than 1 VM with the Lansa Version tag = $lansa_version"}


###########################################################################
##
## Checking Oracle database for required lansa version
##
###########################################################################

Write-Host "Searching for Oracle RDS with Lansa Version tag = $lansa_version"

$ORACLE_DB_IDENTIFIER = "ora" + $lansa_version
$ORACLE_DB_COUNT = (Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$ORACLE_DB_IDENTIFIER}).count

if ($ORACLE_DB_COUNT -eq 1){

  	Write-Host "Oracle RDS with Lansa Version tag = $lansa_version already exist"
  	$ORACLE_DB_STATUS = (Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$ORACLE_DB_IDENTIFIER}).DBInstanceStatus
  	$ORACLE_DB_ARN = (Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$ORACLE_DB_IDENTIFIER}).DBInstanceArn

  	if ($ORACLE_DB_STATUS -eq "available"){
    		Write-Host "Oracle RDS is in $ORACLE_DB_STATUS state and its ARN is $ORACLE_DB_ARN"}

  	elseif ($ORACLE_DB_STATUS -eq "stopped"){

		Write-Host "Oracle RDS is in $ORACLE_DB_STATUS state and its ARN is $ORACLE_DB_ARN"
    		Start-RDSDBInstance -DBInstanceIdentifier $ORACLE_DB_IDENTIFIER
    		Write-Host "Waiting for Oracle RDS to be in Available state"
    
    		$RetryCount = 15

    		while ( ((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$ORACLE_DB_IDENTIFIER}).DBInstanceStatus -ne "available") -and ($RetryCount -gt 0)){

      			Start-Sleep -Seconds 120
      			$RetryCount -= 1 
      			if ( ((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$ORACLE_DB_IDENTIFIER}).DBInstanceStatus -eq "starting") -or ((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$ORACLE_DB_IDENTIFIER}).DBInstanceStatus -eq "backing-up")  ) {

         			Write-Host "Oracle RDS is getting started"}}

		if ( $RetryCount -le 0 ) {
        		throw "Timeout: 30 minutes expired waiting for RDS to be in availabe state" }
    		Write-Host "Oracle RDS is in Available state"}

  	else{
    		throw "Oracle Database is in $ORACLE_DB_STATUS state"}}

elseif ($ORACLE_DB_COUNT -eq 0){
   	Write-Host "No existing oracle database exist with required lansa version"
   	$ORACLE_SNAPSHOT_COUNT = ((Get-RDSDBSnapshot -DBInstanceIdentifier $ORACLE_DB_IDENTIFIER).DBSnapshotArn).count
   	if ($ORACLE_SNAPSHOT_COUNT -eq 1){
     		Write-Host "Found 1 snapshot for database identifier $ORACLE_DB_IDENTIFIER"
     		#New-CNFStack ......................................................

     		$RetryCount = 15
     		while ( ((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$ORACLE_DB_IDENTIFIER}).DBInstanceStatus -ne "available") -and ($RetryCount -gt 0)){

      			Start-Sleep -Seconds 120
      			$RetryCount -= 1
      			if ( ((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$ORACLE_DB_IDENTIFIER}).DBInstanceStatus -eq "starting") -or ((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$ORACLE_DB_IDENTIFIER}).DBInstanceStatus -eq "backing-up")  ) {

         			Write-Host "Oracle RDS is getting started"}}

     		if ( $RetryCount -le 0 ) {
        		throw "Timeout: 30 minutes expired waiting for RDS to be in availabe state" }}

   	elseif ($ORACLE_SNAPSHOT_COUNT -eq 0){
     		throw "Found 0 snapshot for database identifier $ORACLE_DB_IDENTIFIER"}
   	else{
     		throw "Found more than 1 snapshot for database identifier $ORACLE_DB_IDENTIFIER"}}

else{
   throw "More than 1 Oracle RDS with Lansa Version tag = $lansa_version lready exist"}


#########################################################################################
##
## Checking MYSQL database for required lansa version
##
#########################################################################################


Write-Host "Searching for MYSQL RDS with Lansa Version tag = $lansa_version"

$MYSQL_DB_IDENTIFIER = "mysql" + $lansa_version
$MYSQL_DB_COUNT = (Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$MYSQL_DB_IDENTIFIER}).count

if ($MYSQL_DB_COUNT -eq 1){

  	Write-Host "MYSQL RDS with Lansa version tag = $lansa_version already exist"
  	$MYSQL_DB_STATUS = (Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$MYSQL_DB_IDENTIFIER}).DBInstanceStatus
  	$MYSQL_DB_ARN = (Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$MYSQL_DB_IDENTIFIER}).DBInstanceArn

  	if ($MYSQL_DB_STATUS -eq "available"){
    		Write-Host "MYSQL RDS is in $MYSQL_DB_STATUS state and its ARN is $MYSQL_DB_ARN"}
  
  	elseif ($MYSQL_DB_STATUS -eq "stopped"){

    		Write-Host "MYSQL RDS is in $MYSQL_DB_STATUS state and its ARN is $MYSQL_DB_ARN"
    		Start-RDSDBInstance -DBInstanceIdentifier $MYSQL_DB_IDENTIFIER
    		Write-Host "Waiting for MYSQL RDS to be in Available state"
    		$RetryCount = 15
    		while ( ((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$MYSQL_DB_IDENTIFIER}).DBInstanceStatus -ne "available") -and ($RetryCount -gt 0)) {

      			Start-Sleep -Seconds 120
      			$RetryCount -= 1
      			if ( ((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$MYSQL_DB_IDENTIFIER}).DBInstanceStatus -eq "starting") -or ((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$MYSQL_DB_IDENTIFIER}).DBInstanceStatus -eq "backing-up")  ) {

         			Write-Host "MYSQL RDS is getting started"}}

    		if ( $RetryCount -le 0 ) {
       			throw "Timeout: 30 minutes expired waiting for MYSQL RDS to be in availabe state" }
    		Write-Host "MYSQL RDS with Lansa Version tag = $lansa_version is in Available state"}


  	else{
    		throw "MYSQL RDS in $MYSQL_DB_STATUS state"}}


elseif ($MYSQL_DB_COUNT -eq 0){
   	Write-Host "No existing MYSQL RDS with Lansa version tag = $lansa_version exist"
   	$MYSQL_SNAPSHOT_COUNT = ((Get-RDSDBSnapshot -DBInstanceIdentifier $MYSQL_DB_IDENTIFIER).DBSnapshotArn).count
   	if ($MYSQL_SNAPSHOT_COUNT -eq 1){
     		Write-Host "Found 1 snapshot for database identifier $MYSQL_DB_IDENTIFIER"

		## Creating new MYSQL RDS resource
     		#New-CNFStack -StackName .........................

		## Validating if newly provisioned MYSQL RDS is in available state
     		$RetryCount = 15
     		while ( ((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$MYSQL_DB_IDENTIFIER}).DBInstanceStatus -ne "available") -and ($RetryCount -gt 0)){

       			Start-Sleep -Seconds 120
       			$RetryCount -= 1 
       			if ( ((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$MYSQL_DB_IDENTIFIER}).DBInstanceStatus -eq "starting") -or ((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$MYSQL_DB_IDENTIFIER}).DBInstanceStatus -eq "backing-up")  ) {

          			Write-Host "RDS is getting started"}}

       		if ( $RetryCount -le 0 ) {
          		throw "Timeout: 30 minutes expired waiting for MYSQL RDS to be in availabe state" }}

   	elseif ($MYSQL_SNAPSHOT_COUNT -eq 0){
     		throw "Found 0 snapshot for database identifier $MYSQL_DB_IDENTIFIER"}
   	else{
     		throw "Found more than 1 snapshot for database identifier $MYSQL_DB_IDENTIFIER"}}

else{
   	throw "More than 1 MYSQL RDS with lansa version tag = $lansa_version already exist"}

############################################################################################################################################################

## Provisiong VM from Source Lansa Version tagged AMI and tagging it with Tag Lansa Version

if ($tag_lansa_version -ne $null) {

 	$NO_OF_AMIS = (Get-EC2Image -Filter @{ Name="tag:LansaVersion"; Values=$lansa_version } | Select-Object ImageId | Measure-Object | Select-Object Count).count
  	if ($NO_OF_AMIS -eq 1){
    		Write-Host "Found 1 AMI with Lansa vesion tag = $lansa_version"
    		$AMI_ID = (Get-EC2Image -Filter @{ Name="tag:LansaVersion"; Values=$lansa_version }).ImageId

		New-CFNStack -StackName "DB-Regression- + $tag_lansa_version" -RoleARN ......... -TemplateURL https://lansa-us-east-1.s3.amazonaws.com/db-regression-test/cloudformation_template/aws_cloudformation_template_vm.yml -Parameter @(@{ParameterKey="AMI_ID"; ParameterValue=$AMI_ID}, @{ParameterKey="LANSAVERSION"; ParameterValue="$tag_lansa_version"})

		$PHYSICAL_INSTANCE_ID = (Get-CFNStackResource -StackName "DB-Regression- + $tag_lansa_version" -LogicalResourceId INSTANCE).PhysicalResourceId		        
		(Get-SECSecretValue -SecretId privatekey/AzureDevOps).SecretString > $env:tmp\key.pem
		$RetryCount = 15
		while ( ((Get-EC2PasswordData -InstanceId $PHYSICAL_INSTANCE_ID -PemFile $env:tmp\key.pem) -eq $null ) -and ($RetryCount -gt 0) ){
			Start-Sleep -Seconds 120
      			$RetryCount -= 1 
                        Write-Host "Waiting to fetch VM password"}
                  
		if ( $RetryCount -le 0 ) {
        		throw "Timeout: 30 minutes expired waiting to fetch VM password"}
    		Write-Host "Able to fetch the VM password"}
                   

  	elseif ($NO_OF_AMIS -eq 0){
    		Write-Host "Did not find any AMI with the lansa version tag = $lansa_version"}
  	else{
    		Write-Host "Found more than 1 AMI with the lansa version tag = $lansa_version"}

## Provisiong Oracle RDS from Source Lansa Version tagged snapshot and tagging it with Tag Lansa Version

	Write-Host "Searching for Source Oracle RDS snapshot with Lansa Version tag = $lansa_version"
	$SOURCE_ORACLE_DB_IDENTIFIER = "ora" + $lansa_version
	$TAG_ORACLE_DB_IDENTIFIER = "ora" + $tag_lansa_version

  	$ORACLE_SNAPSHOT_COUNT = ((Get-RDSDBSnapshot -DBInstanceIdentifier $SOURCE_ORACLE_DB_IDENTIFIER).DBSnapshotArn).count
   	if ($ORACLE_SNAPSHOT_COUNT -eq 1){
     		Write-Host "Found 1 snapshot for database identifier $SOURCE_ORACLE_DB_IDENTIFIER"
     		Write-Host "Creating Oracle RDS from snapshot tagged with $lansa_version"
     		#New-CNFStack ......................................................

     		$RetryCount = 15
     		while ( ((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$TAG_ORACLE_DB_IDENTIFIER}).DBInstanceStatus -ne "available") -and ($RetryCount -gt 0)){

      			Start-Sleep -Seconds 120
      			$RetryCount -= 1
      			if ( ((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$TAG_ORACLE_DB_IDENTIFIER}).DBInstanceStatus -eq "starting") -or ((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$TAG_ORACLE_DB_IDENTIFIER}).DBInstanceStatus -eq "backing-up")  ) {

         		Write-Host "Oracle RDS is getting started"}}

     		if ( $RetryCount -le 0 ) {
        		throw "Timeout: 30 minutes expired waiting for RDS to be in availabe state" }}

   	elseif ($ORACLE_SNAPSHOT_COUNT -eq 0){
     		throw "Found 0 snapshot with lansa version tag = $lansa_version"}
   	else{
     		throw "Found more than 1 snapshot with lansa version tag = $lansa_version"}


## Provisiong MYSQL RDS from Source Lansa Version tagged snapshot and tagging it with Tag Lansa Version

	Write-Host "Searching for Source MYSQL RDS snapshot with Lansa Version tag = $lansa_version"

	$SOURCE_MYSQL_DB_IDENTIFIER = "mysql" + $lansa_version
	$TAG_MYSQL_DB_IDENTIFIER = "mysql" + $tag_lansa_version
   	$MYSQL_SNAPSHOT_COUNT = ((Get-RDSDBSnapshot -DBInstanceIdentifier $SOURCE_MYSQL_DB_IDENTIFIER).DBSnapshotArn).count
   	if ($MYSQL_SNAPSHOT_COUNT -eq 1){
		Write-Host "Found 1 snapshot for database identifier $SOURCE_MYSQL_DB_IDENTIFIER"
     		Write-Host "Creating MYSQL RDS from snapshot tagged with $lansa_version"
   
		## Creating new MYSQL RDS resource
     		#New-CNFStack -StackName .........................

		## Validating if newly provisioned MYSQL RDS is in available state
     		$RetryCount = 15
     		while ( ((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$TAG_MYSQL_DB_IDENTIFIER}).DBInstanceStatus -ne "available") -and ($RetryCount -gt 0)){

	       		Start-Sleep -Seconds 120
       			$RetryCount -= 1 
       			if ( ((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$TAG_MYSQL_DB_IDENTIFIER}).DBInstanceStatus -eq "starting") -or ((Get-RDSDBInstance -Filter @{Name="db-instance-id"; Values=$TAG_MYSQL_DB_IDENTIFIER}).DBInstanceStatus -eq "backing-up")  ) {

          			Write-Host "RDS is getting started"}}

       		if ( $RetryCount -le 0 ) {
          		throw "Timeout: 30 minutes expired waiting for MYSQL RDS to be in availabe state" }}

   	elseif ($MYSQL_SNAPSHOT_COUNT -eq 0){
     		throw "Found 0 snapshot with lansa version tag = $lansa_version"}
   	else{
     		throw "Found more than 1 snapshot with lansa version tag = $lansa_version"}
}
