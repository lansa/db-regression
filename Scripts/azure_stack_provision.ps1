param (
	[parameter(Mandatory=$true)]
	[string] $lansa_version,

	[string] $clone_lansa_version, ## lansa version that would be used to create clone stack.

    [parameter(Mandatory=$true)]
    [string]$sourceserver, ## To clone the DB from existing SQL server
#############As AWS and Azure not working from same script expecting the below values from another script"aws_secret_manager" or pipeline
	[parameter(Mandatory=$true)]
	[string]$sql_username,

	[parameter(Mandatory=$true)]
	[string]$sql_password
)



##############Checking the clone version####################
if ( [string]::IsNullOrWhiteSpace( $clone_lansa_version) ) {
	$clone_lansa_version = $lansa_version
 }

 #####Parameters############
$sql_server = "db-regression-$clone_lansa_version" #only accepting lower case
$subscription = "739c4e86-bd75-4910-8d6e-d7eb23ab94f3"
$tenant = "17e16064-c148-4c9b-9892-bb00e9589aa5"
###################################Unblock#####If########Needed####################################
#Not needed as we are
#$spappid = Get-SECSecretValue -SecretId "password/ServicePrincipalAzure" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty UID
#$sppassword = Get-SECSecretValue -SecretId "password/ServicePrincipalAzure" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty PWD | ConvertTo-SecureString -AsPlainText -Force

#--------------------#----------------------#

#Connect to Azure
#Install-Module Az -AllowClobber

###################################Unblock#####If########Needed####################################
# $pscredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $spappid, $sppassword
# Connect-AzAccount -ServicePrincipal -Credential $pscredential -SubscriptionId $subscription -Tenant $tenant
# Set-AzContext -Tenant $tenant -SubscriptionId $subscription
# Write-Host "Connected to Azure cloud.."

#--------------------#------------------------#

#Azure sql server creation
#$sqlserver = Get-AzResource -ResourceName $servername -ResourceType 'Microsoft.Sql/servers' -ResourceGroupName dbregressiontest -ErrorAction SilentlyContinue

#$sql_servers = Get-AzSqlServer -ResourceGroupName dbregressiontest
#######################Retriving Azure Databases##################### 
$db = "test"
$azure_tags = (Get-AzResource -Tag @{ "LansaVersion"=$clone_lansa_version}).Name
#-------------------#-----------------------#
#####################ARM Template Params#################
$azure_template_param = @{
	"sqlServername" = $sql_server
	"adminUsername" = $sql_username
	"adminPassword" = $sql_password
	"location" = "eastus"
	"serverTags" = $clone_lansa_version
}
#Validating the Azure Sql Server Exist or not
Write-Host "Checking Azure SQL Server with lansa version $clone_lansa_version exist or not..."

if($azure_tags -ge 1) {
	Write-Host "SQL Server with lansa version exist $clone_lansa_version. Checking Database Exist or not"
	$Sqlserver_dbname = Get-AzSqlDatabase -ResourceGroupName dbregressiontest -ServerName $sql_server
	$db_name = $Sqlserver_dbname.DatabaseName
	if ($db_name -contains $db) 
	{ 
		Write-Host "Found Database $db. Restore not needed.."
	} 
	else{
		Write-Host "Not found the Database $db, Restoring.."
		New-AzSqlDatabaseCopy -ResourceGroupName dbregressiontest -ServerName $sourceserver -DatabaseName $db -CopyResourceGroupName dbregressiontest -CopyServerName $sql_server -CopyDatabaseName $db
		}
}
else {
	Write-Host "Creating New Azure SQL server and it does not exist with lansa version $clone_lansa_version .."
    New-AzResourceGroupDeployment -ResourceGroupName dbregressiontest -TemplateFile "$(Build.StagingDirectory)/Template/azure/sqlserver.json" -TemplateParameterObject $azure_template_param
    Write-Host "Created the SQL server, Now Restoring the Database $db"
    New-AzSqlDatabaseCopy -ResourceGroupName dbregressiontest -ServerName $sourceserver -DatabaseName $db -CopyResourceGroupName dbregressiontest -CopyServerName $sql_server -CopyDatabaseName $db
}

#-------------------------#------------------------#
#Adding the the firewall rule to sql server


#To get the vm current IP
$ThisIp = (Invoke-RestMethod https://api.ipify.org?format=json).ip

#Dynamic IP`s 
New-AzSqlServerFirewallRule -ResourceGroupName dbregressiontest -ServerName $sql_server -StartIpAddress $ThisIp -EndIpAddress $ThisIp -FirewallRuleName "Current_aws_vm_IP-$ThisIp"
#-------------------#-----------------------#