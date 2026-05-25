[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $AzureSqlServer,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $ResourceGroupName = "dbregressiontest",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $SubscriptionId = "739c4e86-bd75-4910-8d6e-d7eb23ab94f3",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $TenantId = "17e16064-c148-4c9b-9892-bb00e9589aa5",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $SecretId = "password/ServicePrincipalAzure"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-PublicIPAddress {
    # Prefer EC2 instance metadata (IMDSv2) - we are on AWS, this is the authoritative source
    try {
        $token = Invoke-RestMethod `
            -Uri "http://169.254.169.254/latest/api/token" `
            -Method PUT `
            -Headers @{ "X-aws-ec2-metadata-token-ttl-seconds" = "60" } `
            -TimeoutSec 5

        $ip = Invoke-RestMethod `
            -Uri "http://169.254.169.254/latest/meta-data/public-ipv4" `
            -Headers @{ "X-aws-ec2-metadata-token" = $token } `
            -TimeoutSec 5

        return $ip.Trim()
    } catch {
        Write-Host "EC2 metadata unavailable, falling back to external IP service..."
    }

    # Fallback - external service. The metadata path above has been flaky in the past.
    try {
        $response = Invoke-WebRequest -Uri "https://myexternalip.com/raw" -UseBasicParsing -TimeoutSec 10
        return $response.Content.Trim()
    } catch {
        throw "Could not determine public IP via EC2 metadata or external service: $_"
    }
}

function ConvertTo-IPv4UInt32 {
    param([string] $IpString)
    $bytes = [System.Net.IPAddress]::Parse($IpString).GetAddressBytes()
    [Array]::Reverse($bytes)
    return [BitConverter]::ToUInt32($bytes, 0)
}

function Find-CoveringFirewallRule {
    param(
        [string] $IpAddress,
        [object[]] $Rules
    )

    if (-not $Rules) { return $null }

    $target = ConvertTo-IPv4UInt32 $IpAddress
    foreach ($rule in $Rules) {
        $start = ConvertTo-IPv4UInt32 $rule.StartIpAddress
        $end = ConvertTo-IPv4UInt32 $rule.EndIpAddress
        if ($target -ge $start -and $target -le $end) {
            return $rule
        }
    }
    return $null
}

$connected = $false

try {
    Write-Host "Retrieving Azure service principal from AWS Secrets Manager..."
    $secret = Get-SECSecretValue -SecretId $SecretId -Select SecretString | ConvertFrom-Json
    $appId = $secret.UID
    $appSecret = ConvertTo-SecureString -String $secret.PWD -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential -ArgumentList $appId, $appSecret

    Write-Host "Connecting to Azure (tenant $TenantId, subscription $SubscriptionId)..."
    Connect-AzAccount `
        -ServicePrincipal `
        -Credential $credential `
        -SubscriptionId $SubscriptionId `
        -Tenant $TenantId | Out-Null
    $connected = $true

    Write-Host "Retrieving the public IP address of this VM..."
    $publicIp = Get-PublicIPAddress
    # At times the EC2 IP address retrieved has been null - guard explicitly
    if (-not $publicIp) {
        throw "Could not determine public IP for $env:COMPUTERNAME"
    }
    Write-Host "Public IP: $publicIp"

    Write-Host "Fetching existing firewall rules for $AzureSqlServer..."
    $existingRules = @(Get-AzSqlServerFirewallRule `
            -ResourceGroupName $ResourceGroupName `
            -ServerName $AzureSqlServer)

    # check ranges, not just single-IP rules - a CIDR-style range that already covers us means we are done
    $coveringRule = Find-CoveringFirewallRule -IpAddress $publicIp -Rules $existingRules
    if ($coveringRule) {
        Write-Host "IP $publicIp already covered by firewall rule '$($coveringRule.FirewallRuleName)'."
        return
    }

    # reuse one rule per host to avoid accumulating stale entries (Azure SQL caps at 128 server-level rules)
    $ruleName = "auto-$env:COMPUTERNAME"
    $existing = $existingRules | Where-Object { $_.FirewallRuleName -eq $ruleName }

    if ($existing) {
        Write-Host "Updating existing rule '$ruleName' -> $publicIp..."
        Set-AzSqlServerFirewallRule `
            -ResourceGroupName $ResourceGroupName `
            -ServerName $AzureSqlServer `
            -FirewallRuleName $ruleName `
            -StartIpAddress $publicIp `
            -EndIpAddress $publicIp | Out-Null
    } else {
        Write-Host "Creating new firewall rule '$ruleName' for $publicIp..."
        New-AzSqlServerFirewallRule `
            -ResourceGroupName $ResourceGroupName `
            -ServerName $AzureSqlServer `
            -FirewallRuleName $ruleName `
            -StartIpAddress $publicIp `
            -EndIpAddress $publicIp | Out-Null
    }

    Write-Host "Done."
} finally {
    if ($connected) {
        Disconnect-AzAccount | Out-Null
    }
}
