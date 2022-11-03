param (
	[parameter(Mandatory=$true)]
	[string] $lansa_version
)

$storage_key = (Get-AzStorageAccountKey -ResourceGroupName "dbregressiontest" -StorageAccountName "stagingdpuseast").Value[0]
$storage_url = "https://stagingdpuseast.blob.core.windows.net/azuresqlbackup"
$storage_uri = "$storage_url/$lansa_version/$lansa_version.bacpac"
$sql_username = Get-SECSecretValue -SecretId "password/DBRegressionTest/SQLAZURE" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty UID
$sql_password = Get-SECSecretValue -SecretId "password/DBRegressionTest/SQLAZURE" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty PWD | ConvertTo-SecureString -AsPlainText -Force

"##vso[task.setvariable variable=username]$sql_username"
"##vso[task.setvariable variable=password]$sql_password"

$export = New-AzSqlDatabaseExport -ResourceGroupName dbregressiontest -ServerName "db-regression-$lansa_version" -DatabaseName $lansa_version -StorageKeyType "StorageAccessKey" -StorageKey $storage_key -StorageUri $storage_uri -AdministratorLogin $sql_username -AdministratorLoginPassword $sql_password

$exportStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $export.OperationStatusLink
[Console]::Write("Exporting")
while ($exportStatus.Status -eq "InProgress")
{
    Start-Sleep -s 10
    $exportStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $export.OperationStatusLink
    [Console]::Write(".")
}
[Console]::WriteLine("")
$exportStatus