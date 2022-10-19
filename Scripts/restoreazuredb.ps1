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
$server = $servername
$resourcegroup    = $Rgroup
$sourceServerName = $sourceserver
$database         = $dbname

#To get the vm current IP
$ThisIp = (Invoke-RestMethod https://api.ipify.org?format=json).ip

#Print parameters

Write-Host "server:            $server"
Write-Host "lansa version:     $lansaversion"
Write-Host "database name:     $database"
Write-Host "targetServerName:  $targetServerName"
#Dynamic IP`s 
New-AzureRmSqlServerFirewallRule -ResourceGroupName $resourcegroup -ServerName $server -StartIpAddress $ThisIp -EndIpAddress $ThisIp -FirewallRuleName "Current VM IP"

#Database copy from old azure sql server to new
New-AzSqlDatabaseCopy -ResourceGroupName $resourcegroup -ServerName $sourceServerName -DatabaseName $database -CopyResourceGroupName $resourcegroup -CopyServerName $server -CopyDatabaseName $database 

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