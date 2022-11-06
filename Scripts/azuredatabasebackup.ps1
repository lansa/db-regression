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

$waitDelay = 10
while (($export | Get-AzSqlDatabaseImportExportStatus).Status -eq 'InProgress') {
    ($export | Get-AzSqlDatabaseImportExportStatus).StatusMessage
    Start-Sleep $waitDelay
}
# Output results
$result = $export | Get-AzSqlDatabaseImportExportStatus
$result | Out-Default | Write-Host
if ($result.Status -eq 'Succeeded') {
    Write-Host "Database Deployed"
}else{
    Write-Host "Database did not deploy '$($result.Status)'-'$($result.ErrorMessage)'"
    Throw $result.ErrorMessage
} 