param (
    [Parameter(Mandatory=$true)]
    [string] $azure_sql_server
)
$ErrorActionPreference = "Stop"

try {
    Write-Host( "Getting Azure Service Principle and Secret from AWS Secret Manager")
    $spappid = Get-SECSecretValue -SecretId "password/ServicePrincipalAzure" -Select SecretString | ConvertFrom-Json | Select-Object -ExpandProperty UID
    $sppassword = Get-SECSecretValue -SecretId "password/ServicePrincipalAzure" -Select SecretString | ConvertFrom-Json | Select-Object -ExpandProperty PWD | ConvertTo-SecureString -AsPlainText -Force

    $subscription = "739c4e86-bd75-4910-8d6e-d7eb23ab94f3"
    $tenant = "17e16064-c148-4c9b-9892-bb00e9589aa5"
    $pscredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $spappid, $sppassword
    Connect-AzAccount -ServicePrincipal -Credential $pscredential -SubscriptionId $subscription -Tenant $tenant
    Set-AzContext -Tenant $tenant -SubscriptionId $subscription

    Write-Host "Retrieving the Public IP Address of this VM..."
    $Ip = (Invoke-WebRequest "https://myexternalip.com/raw" -UseBasicParsing)
    Write-Host( $ip.Content)

    # strip CR or LF from string and return Ip Address
    $ip_address_to_whitelist_on_Azure_SQLServer = $Ip.content -replace "`t|`n|`r",""

    Write-Host( "Retrieving all the IP addresses in the Azure SQL Server Firewall Rule, $azure_sql_server" )
    $StartIPAddressList = (Get-AzSqlServerFirewallRule -ResourceGroupName dbregressiontest -ServerName $azure_sql_server).StartIpAddress
    $StartIPAddressList
    
    # At times the EC2 IP address retrieved have been null...
    if ($ip_address_to_whitelist_on_Azure_SQLServer) {

        Write-Host("Ensuring that $ip_address_to_whitelist_on_Azure_SQLServer is in Azure SQL Server firewall")
        # This will execute if the EC2 instance's IP address is NOT in the list of IP addresses of the SQL Server Firewall Rule
        if (!($ip_address_to_whitelist_on_Azure_SQLServer -in $StartIPAddressList)) {

            $current_time = Get-Date -UFormat "%m-%d-%YT%R" # Example: "11-01-2022T14:21" -This will be appended in the Firewall Rule name 

            Write-Host "Updating Azure SQL Server Firewall rule..."
            
            New-AzSqlServerFirewallRule -ResourceGroupName dbregressiontest `
                                            -ServerName $azure_sql_server `
                                            -StartIpAddress $ip_address_to_whitelist_on_Azure_SQLServer `
                                            -EndIpAddress $ip_address_to_whitelist_on_Azure_SQLServer `
                                            -FirewallRuleName "$env:computername-$current_time"
        } else {
            Write-Host "IP address already in Firewall." 
        }
    } else { 
        Write-Host "IP Not found. Please check the parameters, and/or if the machine actually exists." 
        throw
    }

} catch {
    $_ | Out-Default | Write-Host
    throw
}