param (
    # [parameter(Mandatory=$true)]
    # [string]$dbname,

    [parameter(Mandatory=$true)]
    [string]$servername,

    [parameter(Mandatory=$true)]
    [string]$sourceserver,

    [string] $sourceversion

)
#-------------------#-----------------------#
#Pipeline parameters
$server = $servername
$sourceServerName = $sourceserver
$tagversion = $sourceversion

#-------------------#-----------------------#
$subscription = "739c4e86-bd75-4910-8d6e-d7eb23ab94f3"
$tenant = "17e16064-c148-4c9b-9892-bb00e9589aa5"
#-------------------#-----------------------#
#aws secrets
$username = Get-SECSecretValue -SecretId azuresql-username -Select SecretString | ConvertFrom-Json | Select -ExpandProperty username

$password = Get-SECSecretValue -SecretId azuresql-username -Select SecretString | ConvertFrom-Json | Select -ExpandProperty password

$spappid = Get-SECSecretValue -SecretId "password/ServicePrincipalAzure" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty UID
$sppassword = Get-SECSecretValue -SecretId "password/ServicePrincipalAzure" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty PWD

#-------------------#-----------------------#
"##vso[task.setvariable variable=username]$username"
"##vso[task.setvariable variable=password]$password"
"##vso[task.setvariable variable=username]$spappid"
"##vso[task.setvariable variable=username]$sppassword"

#--------------------#----------------------#
#Connect to Azure
$SecureStringPwd = $sppassword | ConvertTo-SecureString -AsPlainText -Force
$pscredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $spappid, $SecureStringPwd
Connect-AzureRmAccount -ServicePrincipal -Credential $pscredential -SubscriptionId $subscription -Tenant $tenant
Set-AzContext -Tenant $tenant -SubscriptionId $subscription
Write-Host "Connected to Azure cloud"

#--------------------#------------------------#
#Azure sql server creation
#$sqlserver = Get-AzResource -ResourceName $servername -ResourceType 'Microsoft.Sql/servers' -ResourceGroupName dbregressiontest -ErrorAction SilentlyContinue
$sqlserver = Get-AzSqlServer -ResourceGroupName dbregressiontest
$Sqlservercmd = Get-AzSqlDatabase -ResourceGroupName dbregressiontest -ServerName $server
$dbname = $Sqlservercmd.DatabaseName
$db = "test"
#-------------------#-----------------------#
$azureparam = @{
	"sqlServername" = $server
	"adminUsername" = $username
	"adminPassword" = $password
	"location" = "eastus"
	"serverTags" = $tagversion
}
#Validating the Azure Sql Server Exist or not
Write-Host "Validating the Azure Sql Server Exist or not"

if($sqlserver.ServerName -eq $server) {
	Write-Host "SQL Server exist $server. Checking Database Exist or not"
	for($i=0; $i -lt $dbname.Length; $i++) 
	{ 
		if($dbname[$i] -contains "test") {
		Write-Host "Found Database. Restore not needed"
	} else {
		Write-Host "Not found the Database $db, Restoring.."
		New-AzSqlDatabaseCopy -ResourceGroupName dbregressiontest -ServerName $sourceServerName -DatabaseName $db -CopyResourceGroupName dbregressiontest -CopyServerName $server -CopyDatabaseName $db
		}
	}
}
else {
	Write-Host "Creating New Azure SQL server.."
    New-AzResourceGroupDeployment -ResourceGroupName dbregressiontest -TemplateFile "$(Build.StagingDirectory)/Template/azure/sqlserver.json" -TemplateParameterObject $azureparam
    Write-Host "Created the SQL server, Now Restoring the Database $db"
    New-AzSqlDatabaseCopy -ResourceGroupName dbregressiontest -ServerName $sourceServerName -DatabaseName $db -CopyResourceGroupName dbregressiontest -CopyServerName $server -CopyDatabaseName $db
}

#-------------------------#------------------------#
#Adding the the firewall rule to sql server


#To get the vm current IP
$ThisIp = (Invoke-RestMethod https://api.ipify.org?format=json).ip

#Dynamic IP`s 
New-AzSqlServerFirewallRule -ResourceGroupName $resourcegroup -ServerName $server -StartIpAddress $ThisIp -EndIpAddress $ThisIp -FirewallRuleName $ThisIp
#-------------------#-----------------------#