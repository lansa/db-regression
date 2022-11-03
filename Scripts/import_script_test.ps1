param (
	[parameter(Mandatory=$false)]
	[AllowEmptyString()]
	[string] $lansa_version, ## lansa version that would be used to create clone stack.

    [parameter(Mandatory=$true)]
	[string]$sql_username,

	[parameter(Mandatory=$true)]
	[string]$sql_password
)

$azure_sql_password = ConvertTo-SecureString $sql_password -AsPlainText -Force

$storage_key = (Get-AzStorageAccountKey -ResourceGroupName "dbregressiontest" -StorageAccountName "stagingdpuseast").Value[0]
$storage_url = "https://stagingdpuseast.blob.core.windows.net/azuresqlbackup"
$storage_uri = "$storage_url/$lansa_version/$lansa_version.bacpac"
$sql_server = "db-regression-$lansa_version"

$importRequest = New-AzSqlDatabaseImport -ResourceGroupName "dbregressiontest" -ServerName $sql_server -DatabaseName $lansa_version -StorageKeyType "StorageAccessKey" -StorageKey $storage_key -StorageUri $storage_uri -AdministratorLogin $sql_username -AdministratorLoginPassword $azure_sql_password -Edition GeneralPurpose -ServiceObjectiveName GP_S_Gen5_8 -DatabaseMaxSizeBytes 1099511627776
		
#cheacking status
$importStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink

[Console]::Write("Importing")
while ($importStatus.Status -eq "InProgress") {
    $importStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $importRequest.OperationStatusLink
    [Console]::Write(".")
    Start-Sleep -s 10
}

[Console]::WriteLine("")
$importStatus