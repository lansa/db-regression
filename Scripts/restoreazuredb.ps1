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
#aws secrets
$username = Get-SECSecretValue -SecretId azuresql-username -Select SecretString | ConvertFrom-Json | Select -ExpandProperty username

$password = Get-SECSecretValue -SecretId azuresql-username -Select SecretString | ConvertFrom-Json | Select -ExpandProperty password

$SecureStringPwd = Get-SECSecretValue -SecretId azuresql -Select SecretString | ConvertFrom-Json | Select -ExpandProperty secret

"##vso[task.setvariable variable=username]$username"
"##vso[task.setvariable variable=password]$password"
"##vso[task.setvariable variable=password]$SecureStringPwd"

#--------------------#----------------------#
#Connect to Azure
$pscredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList f51da9b8-7040-499e-a8c4-93e05e1bb5e5, $SecureStringPwd
Connect-AzureRmAccount -ServicePrincipal -Credential $pscredential -Tenant 17e16064-c148-4c9b-9892-bb00e9589aa5

#Azure sql server
#$sqlserver = Get-AzResource -ResourceName $servername -ResourceType 'Microsoft.Sql/servers' -ResourceGroupName dbregressiontest -ErrorAction SilentlyContinue
$sqlserver = Get-AzSqlServer -ResourceGroupName dbregressiontest
$Sqlservercmd = Get-AzSqlDatabase -ResourceGroupName dbregressiontest -ServerName $servername

if($servername -eq $sqlserver.ServerName){
    Write-Host "Server does not exist"
    Write-Host "Creating new server'$servername'"
    New-AzureRmResourceGroupDeployment -ResourceGroupName dbregressiontest -TemplateFile "C:\Users\tarun.s\Desktop\Accolite\Lansa\tarun-repo\db-regression\Template\azure\sqlserver.json" -TemplateParameterFile "C:\Users\tarun.s\Desktop\Accolite\Lansa\tarun-repo\db-regression\Template\azure\azuresqlserver.parameters.json"
}
else 
{
    Write-Host "Server exit"
}

if ($Sqlservercmd.DatabaseName -eq $database)
{
    Write-Host "Database exist.. Skipping Restore"
}
else {
    New-AzSqlDatabaseCopy -ResourceGroupName dbregressiontest -ServerName $sourceServerName -DatabaseName $database -CopyResourceGroupName dbregressiontest -CopyServerName $server -CopyDatabaseName $database
}

#Pipeline parameters
$server = $servername
$resourcegroup    = $Rgroup
$sourceServerName = $sourceserver
$database         = $dbname

#To get the vm current IP
$ThisIp = (Invoke-RestMethod https://api.ipify.org?format=json).ip


if ($null -eq $sourceversion){
    $sourceversion == $lansaversion
}

#Print parameters

Write-Host "server:            $server"
Write-Host "lansa version:     $lansaversion"
Write-Host "database name:     $database"
Write-Host "targetServerName:  $targetServerName"
Write-Host "Version: $sourceversion"


#Dynamic IP`s 
New-AzureRmSqlServerFirewallRule -ResourceGroupName $resourcegroup -ServerName $server -StartIpAddress $ThisIp -EndIpAddress $ThisIp -FirewallRuleName $ThisIp

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