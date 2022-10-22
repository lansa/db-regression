<#
.SYNOPSIS

Creates a Service Principal

An overview of this process is here: https://www.techtarget.com/searchwindowsserver/tutorial/Using-PowerShell-for-Azure-service-principal-authentication

.EXAMPLE
#>

Param(
    [Parameter(mandatory)]
    [string] $ServicePrincipal
)

$myApp = New-AzADApplication -DisplayName $ServicePrincipal
$azureAppId = $myApp.AppID
#$azureAppId = (Get-AzADApplication -DisplayName 'DBRegressionTestAppForServicePrincipal').AppId.ToString()

$sp = New-AzADServicePrincipal -ApplicationId $azureAppId
#$sp = Get-AzADServicePrincipal -ApplicationId $azureAppId

New-AzRoleAssignment -RoleDefinitionName Contributor -ApplicationId $sp.AppId

$NewCredential = New-AzureADApplicationPasswordCredential -ObjectId $sp.AppId
$NewCredential