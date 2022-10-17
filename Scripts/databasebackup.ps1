#To be taken from pipeline need to change when pipeline values created 

param (
    [parameter(Mandatory=$true)]
    [string]$lansaversion,

    [parameter(Mandatory=$true)]
    [string]$dbname,

    [parameter(Mandatory=$true)]
    [string]$Rgroup,

    [parameter(Mandatory=$true)]
    [string]$location,

    [parameter(Mandatory=$true)]
    [string]$path,

    [parameter(Mandatory=$true)]
    [string]$databasestype,

    [parameter(Mandatory=$true)]
    [string]$servername

    # [parameter(Mandatory=$true)]
    # [int]$ip1,

    # [parameter(Mandatory=$true)]
    # [int]$ip2

)
Set-AWSCredentials myAWScredentials

$server = $servername
$backupPath = $path
$s3bucket = 'lansa-us-east-1/db-regression-test/backups'
$databasebackup = $s3bucket/$lansaversion/$databasestype
$region = $location
$resourcegroup = $Rgroup

#$firewallrulename = $rulename
#$currentrules = Get-AzSqlServerFirewallRule -ResourceGroupName $resourcegroup -ServerName $server -FirewallRuleName $firewallrulename
#$serverip = $ip1, $ip2

$ThisIp = (Invoke-RestMethod https://api.ipify.org?format=json).ip
$databases = Invoke-Sqlcmd -ServerInstance $server -Username $user -Password $password -Query "SELECT [name]
FROM master.dbo.sysdatabases where [name]='$dbname'"


#Print parameters

Write-Host "server:         $server"
Write-Host "backup path:    $databasebackup"
Write-Host "region:         $region"
Write-Host "lansa version:  $lansaversion"


# Set firewall rules for server`s Static Ip`s ( Can be uncommented if required)
# foreach ($ip in $serverip)
# {
#     $rule = $currentRules | Where ($_.StartIpAddress -eq $ip)
#     If (!$rule ) 
#     {
#         New-AzureRmSqlServerFirewallRule -ServerName $server -FirewallRuleName $firewallrulename[$1] -StartIpAddress $ip -EndIpAddress $ip
#     }
#     else {
#         Set-AzSqlServerFirewallRule -ServerName $server -FirewallRuleName $firewallrulename[$i] -StartIpAddress $ip -EndIpAddress $ip
#     }
#     $i++
# }

#Dynamic IP`s 
New-AzureRmSqlServerFirewallRule -ResourceGroupName $resourcegroup -ServerName $server -StartIpAddress $ThisIp -EndIpAddress $ThisIp -FirewallRuleName "Current VM IP"

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