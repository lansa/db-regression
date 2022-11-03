Param(
    [Parameter(mandatory)]
    [ValidateSet('SP','LPC','LPC-DP','LPC-AsDP','LPC-AsBake','LANSAInc', 'KeyVault' )]
    [string] $CloudAccount,

    # Parameter help description
    [Parameter(Mandatory=$false)]
    [string]
    $CloudSecret
)

switch ( $CloudAccount ) {
    {$_ -eq 'LPC-MSDN'} {
        $TenantName = 'DefaultDirectory'
        $Tenant = '17e16064-c148-4c9b-9892-bb00e9589aa5'
        $Subscription = 'edff5157-5735-4ceb-af94-526e2c235e80'
        $User = 'robert@lansacloudlansacom.onmicrosoft.com'
    }
    {$_ -eq 'LPC-DP'} {
        $TenantName = 'DefaultDirectory'
        $Tenant = '17e16064-c148-4c9b-9892-bb00e9589aa5'
        $Subscription = '739c4e86-bd75-4910-8d6e-d7eb23ab94f3'
        $User = 'robert@lansacloudlansacom.onmicrosoft.com'
    }
    {$_ -eq 'LANSAInc'} {
        $TenantName = 'LANSA Inc'
        $Tenant = '3a9638cf-42dc-4c21-95b5-c691e47eef65'
        $Subscription = 'b837dfa9-fc6c-4a44-ae38-94964ea035a3'
        $User = 'rob.goodridge@lansa.com.au'
    }
    {$_ -eq 'KeyVault'} {
        $TenantName = 'LANSA Inc'
        $Tenant = '3a9638cf-42dc-4c21-95b5-c691e47eef65'
        $Subscription = 'ffe7f8f1-c8cb-425c-ad93-bbd52cffe4ed'
        $User = 'rob.goodridge@lansa.com.au'
    }
    {$_ -eq 'LPC-AsDP'} {
        $TenantName = 'DefaultDirectory'
        $Tenant = '17e16064-c148-4c9b-9892-bb00e9589aa5'
        $Subscription = '739c4e86-bd75-4910-8d6e-d7eb23ab94f3'
        $User = 'robAsDP@lansacloudlansacom.onmicrosoft.com'
    }
    {$_ -eq 'LPC-AsBake'} {
        $TenantName = 'DefaultDirectory'
        $Tenant = '17e16064-c148-4c9b-9892-bb00e9589aa5'
        $Subscription = '739c4e86-bd75-4910-8d6e-d7eb23ab94f3'
        $User = 'robAsBake@lansacloudlansacom.onmicrosoft.com'
    }
    # Service Principals, requires a password to be passed in
    {$_ -eq 'SP'} {
        $TenantName = 'DefaultDirectory'
        $Tenant = '17e16064-c148-4c9b-9892-bb00e9589aa5'
        $Subscription = '739c4e86-bd75-4910-8d6e-d7eb23ab94f3'
        $User = '43fa6ab3-abff-42c3-b90f-7cf9887434c0'
    }
}

Write-Host( "Connecting $CloudAccount using User $user to Tenant $TenantName & subscription $subscription")

#Connect-AzAccount -SubscriptionId edff5157-5735-4ceb-af94-526e2c235e80
#Connect-AzAccount -SubscriptionId ffe7f8f1-c8cb-425c-ad93-bbd52cffe4ed
Clear-AzContext -Force

if ( $CloudSecret ) {
    $secPassword = ConvertTo-SecureString -AsPlainText -Force -String $CloudSecret 
    $Credential = (New-Object System.Management.Automation.PSCredential $User, $secPassword)
    Connect-AzAccount -ServicePrincipal -SubscriptionId $subscription -TenantId $tenant -Credential $Credential
} else {
    #$Credential = Get-Credential -UserName $user -Message "Enter password for $user"
    Connect-AzAccount

}

Set-AzContext -Tenant $Tenant -SubscriptionId $Subscription
