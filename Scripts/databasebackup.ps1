#To be taken from pipeline need to change when pipeline values created 

param (
    [parameter(Mandatory=$true)]
    [string]$lansaversion,

    [parameter(Mandatory=$true)]
    [string]$dbname,

    [parameter(Mandatory=$true)]
    [string]$location,

    [parameter(Mandatory=$true)]
    [string]$path,

    [parameter(Mandatory=$true)]
    [string]$databasestype,

    [parameter(Mandatory=$true)]
    [string]$servername
)
Set-AWSCredentials myAWScredentials

$server = $servername
$backupPath = $path
$s3bucket = 'lansa-us-east-1/db-regression-test/backups'
$databasebackup = $s3bucket/$lansaversion/$databasestype
$region = $location

#$firewallrulename = $rulename
#$currentrules = Get-AzSqlServerFirewallRule -ResourceGroupName $resourcegroup -ServerName $server -FirewallRuleName $firewallrulename
#$serverip = $ip1, $ip2

$databases = Invoke-Sqlcmd -ServerInstance $server -Username $user -Password $password -Query "SELECT [name]
FROM master.dbo.sysdatabases where [name]='$dbname'"


#Print parameters

Write-Host "server:         $server"
Write-Host "backup path:    $databasebackup"
Write-Host "region:         $region"
Write-Host "lansa version:  $lansaversion"


#Database backup
foreach ($database in $databases)
{
    $timestamp = get-date -format MMddyyyyHHmmss
    $fileName =  "$($database.name)-$timestamp.bak"
    $filePath = Join-Path $backupPath $fileName
    $zipfilepath = Join-Path $backupPath $zipfileName

    Backup-SqlDatabase -ServerInstance $server -Database $database.name -BackupFile $filePath
    Write-Zip -path $filePath -OutputPath $zipfilepath

    Write-S3Object -BucketName $databasebackup -StoredCredentials myAWScredentials  -File $zipfilePath -Region $region
}