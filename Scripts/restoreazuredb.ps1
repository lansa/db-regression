param (
    [parameter(Mandatory=$true)]
    [string]$dbname,

    [parameter(Mandatory=$true)]
    [string]$Rgroup,

    [parameter(Mandatory=$true)]
    [string]$servername,

    [parameter(Mandatory=$true)]
    [string]$sourceserver

)

#Pipeline parameters
$resourcegroup    = $Rgroup
$sourceServerName = $sourceserver
$targetServerName = $servername
$database         = $dbname

#Database copy from old azure sql server to new
New-AzSqlDatabaseCopy -ResourceGroupName $resourcegroup -ServerName $sourceServerName -DatabaseName $database -CopyResourceGroupName $resourcegroup -CopyServerName $targetServerName -CopyDatabaseName $database 
