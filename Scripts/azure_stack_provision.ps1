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

#$azure_sql_password = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $sql_password

#$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sql_password)
#$azure_sql_password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
#$azure_sql_password = $Credentials.GetNetworkCredential().Password
##############Checking the clone version parameter passed or not####################

if ( [string]::IsNullOrWhiteSpace( $clone_lansa_version) ) {
	$clone_lansa_version = $lansa_version
 }

#####Server Name############
$sql_server = "db-regression-$lansa_version" #only accepting lower case

#######################Retriving Azure Resources using Tags ##################### 
#$db = "test"
$azure_tags = (Get-AzResource -Tag @{ "LansaVersion"=$lansa_version}).Name
###############Geting the sourceserver name##################
$sourceserver = (Get-AzResource -Tag @{ "LansaVersion"=$clone_lansa_version}).Name
#-------------------#-----------------------#
###############Import database from storage account if the clone lansa version or lansaVersion server does not exist##################
$storage_key = (Get-AzStorageAccountKey -ResourceGroupName "dbregressiontest" -StorageAccountName "stagingdpuseast").Value[0]
$storage_url = "https://stagingdpuseast.blob.core.windows.net/azuresqlbackup"
$storage_uri = "$storage_url/$clone_lansa_version/$clone_lansa_version.bacpac"

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
            Write-Host "Source server found $sourceserver. Checking for clone lansa version db."
            $sourceserver_dbname = Get-AzSqlDatabase -ResourceGroupName dbregressiontest -ServerName $sourceserver
            $source_db_name = $sourceserver_dbname.DatabaseName

            if($source_db_name -contains $clone_lansa_version){
            Write-Host "database $clone_lansa_version Found, Restoring the DB from Sourceserver..."
		    New-AzSqlDatabaseCopy -ResourceGroupName dbregressiontest -ServerName $sourceserver -DatabaseName $clone_lansa_version -CopyResourceGroupName dbregressiontest -CopyServerName $sql_server -CopyDatabaseName $lansa_version | Out-Default | Write-Host
            }else{
                Write-Host "Sourceserver $sourceserver does not have the db with clone lansa version $clone_lansa_version."
                Write-Host "Importing database from Storage Account..."
                $importRequest = New-AzSqlDatabaseImport -ResourceGroupName "dbregressiontest" -ServerName $sql_server -DatabaseName $lansa_version -StorageKeyType "StorageAccessKey" -StorageKey $storage_key -StorageUri $storage_uri -AdministratorLogin $sql_username -AdministratorLoginPassword $(ConvertTo-SecureString -String $sql_password -AsPlainText -Force) -Edition GeneralPurpose -ServiceObjectiveName GP_S_Gen5_8 -DatabaseMaxSizeBytes 1099511627776
                #cheacking status
                $importStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
                [Console]::Write("Importing")
                while ($importStatus.Status -eq "InProgress") {
                    $importStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
                    [Console]::Write(".")
                    Start-Sleep -s 10
                }
            }
        }elseif($null -eq $sourceserver.count){
            Write-Host "Importing database from Storage Account..."
            $importRequest = New-AzSqlDatabaseImport -ResourceGroupName "dbregressiontest" -ServerName $sql_server -DatabaseName $lansa_version -StorageKeyType "StorageAccessKey" -StorageKey $storage_key -StorageUri $storage_uri -AdministratorLogin $sql_username -AdministratorLoginPassword $(ConvertTo-SecureString -String $sql_password -AsPlainText -Force) -Edition GeneralPurpose -ServiceObjectiveName GP_S_Gen5_8 -DatabaseMaxSizeBytes 1099511627776
            #cheacking status
            $importStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
            [Console]::Write("Importing")
            while ($importStatus.Status -eq "InProgress") {
                $importStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
                [Console]::Write(".")
                Start-Sleep -s 10
            }
        }
        else {
            throw "Found more than 1 Azure sql server with the Lansa Version tag = $clone_lansa_version"
        }
    }
}
else {
    Write-Host "Creating New Azure SQL server as no server found with lansa version $lansa_version ..."
    New-AzResourceGroupDeployment -ResourceGroupName dbregressiontest -TemplateFile "$git_repo_root/sqlserver.json" -TemplateParameterObject $azure_template_param
    Write-Host "Created the SQL server, Now Restoring the Database using $clone_lansa_version to $lansa_version or from Storage Account..."
    if($sourceserver.count -ge 1){
		Write-Host "Source server found $sourceserver. Checking for clone lansa version db else Restore from storage account."
        $sourceserver_dbname = Get-AzSqlDatabase -ResourceGroupName dbregressiontest -ServerName $sourceserver
        $source_db_name = $sourceserver_dbname.DatabaseName
		
		if($source_db_name -contains $clone_lansa_version){
			Write-Host "database $clone_lansa_version Found, Restoring the DB from Sourceserver..."
		    New-AzSqlDatabaseCopy -ResourceGroupName dbregressiontest -ServerName $sourceserver -DatabaseName $clone_lansa_version -CopyResourceGroupName dbregressiontest -CopyServerName $sql_server -CopyDatabaseName $lansa_version | Out-Default | Write-Host
		}else{
				Write-Host "Importing database from Storage Account..."
                $importRequest = New-AzSqlDatabaseImport -ResourceGroupName "dbregressiontest" -ServerName $sql_server -DatabaseName $lansa_version -StorageKeyType "StorageAccessKey" -StorageKey $storage_key -StorageUri $storage_uri -AdministratorLogin $sql_username -AdministratorLoginPassword $(ConvertTo-SecureString -String $sql_password -AsPlainText -Force) -Edition GeneralPurpose -ServiceObjectiveName GP_S_Gen5_8 -DatabaseMaxSizeBytes 1099511627776
                #cheacking status
                $importStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
                [Console]::Write("Importing")
                while ($importStatus.Status -eq "InProgress") {
                    $importStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
                    [Console]::Write(".")
                    Start-Sleep -s 10
                }
		}
	}else {
        throw "Found more than 1 Azure sql server with the Lansa Version tag = $clone_lansa_version"
    }
}