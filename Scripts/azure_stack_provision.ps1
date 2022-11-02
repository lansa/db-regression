param (
	[parameter(Mandatory=$true)]
	[string] $lansa_version,

	[parameter(Mandatory=$false)]
	[AllowEmptyString()]
	[string] $clone_lansa_version, ## lansa version that would be used to create clone stack.

#############As AWS and Azure not working from same script expecting the below values from another script"aws_secret_manager" or pipeline
	[parameter(Mandatory=$true)]
	[string]$sql_username,

	[parameter(Mandatory=$true)]
	[string]$sql_password
)

#####Server Name############
$sql_server = "db-regression-$lansa_version" #only accepting lower case

#######################Retriving Azure Resources using Tags ##################### 
$db = "test"
$azure_tags = (Get-AzResource -Tag @{ "LansaVersion"=$lansa_version}).Name
##############Checking the clone version####################
if ( [string]::IsNullOrWhiteSpace( $clone_lansa_version) ) {
	$clone_lansa_version = $db
 }
###############Geting the sourceserver name##################
$sourceserver = (Get-AzResource -Tag @{ "LansaVersion"=$clone_lansa_version}).Name
#-------------------#-----------------------#
############Template path###############################
$azure_stack_scriptpath = $MyInvocation.MyCommand.Path
$stack_script = Split-Path $azure_stack_scriptpath
$git_repo_root = Get-Item $stack_script\..\Template\azure
Write-Host "New_location - $git_repo_root"
#####################ARM Template Params#################
$azure_template_param = @{
	"sqlServername" = $sql_server
	"adminUsername" = $sql_username
	"adminPassword" = $sql_password
	"location" = "eastus"
	"serverTags" = $lansa_version
}
#Validating the Azure Sql Server Exist or not
Write-Host "Checking Azure SQL Server with lansa version $lansa_version Exist or Not."
if($azure_tags.count -eq 1){
    Write-Host "SQL Server with lansa version exist $lansa_version. Checking Database Exist or Not."
	$Sqlserver_dbname = Get-AzSqlDatabase -ResourceGroupName dbregressiontest -ServerName $sql_server
	$db_name = $Sqlserver_dbname.DatabaseName
    if ($db_name -contains $lansa_version) {
        Write-Host "Found Database $lansa_version. Restore not needed."
    } else {
        Write-Host "Not found the Database $lansa_version, checking for source server."
        if ($sourceserver.count -eq 1) {
            Write-Host "Source server found $sourceserver, Restoring..."
		    New-AzSqlDatabaseCopy -ResourceGroupName dbregressiontest -ServerName $sourceserver -DatabaseName $clone_lansa_version -CopyResourceGroupName dbregressiontest -CopyServerName $sql_server -CopyDatabaseName $lansa_version | Out-Default | Write-Host
        }else {
            throw "Found more than 1 Azure sql server with the Lansa Version tag = $clone_lansa_version"
        }
    }
}
else {
    Write-Host "Creating New Azure SQL server as no server found with lansa version $lansa_version ..."
    New-AzResourceGroupDeployment -ResourceGroupName dbregressiontest -TemplateFile "$git_repo_root/sqlserver.json" -TemplateParameterObject $azure_template_param
    Write-Host "Created the SQL server, Now Restoring the Database using $clone_lansa_version to $lansa_version..."
    if($sourceserver.count -eq 1){
        Write-Host "Source server found $sourceserver, Restoring..."
		New-AzSqlDatabaseCopy -ResourceGroupName dbregressiontest -ServerName $sourceserver -DatabaseName $clone_lansa_version -CopyResourceGroupName dbregressiontest -CopyServerName $sql_server -CopyDatabaseName $lansa_version | Out-Default | Write-Host
    }
    else {
        throw "Found more than 1 Azure sql server with the Lansa Version tag = $clone_lansa_version"
    }
}

#-------------------------#------------------------#
#Adding the the firewall rule to sql server


#To get the vm current IP
#$ThisIp = (Invoke-RestMethod https://api.ipify.org?format=json).ip

#Dynamic IP`s 
#New-AzSqlServerFirewallRule -ResourceGroupName dbregressiontest -ServerName $sql_server -StartIpAddress $ThisIp -EndIpAddress $ThisIp -FirewallRuleName "Current_aws_vm_IP-$ThisIp" | Out-Default | Write-Host
#-------------------#-----------------------#