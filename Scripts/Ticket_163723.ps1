
param (
    [string] $dbType,
    [string] $username 
)

$databaseType = $dbType
$User = $username

<#
$file_data = Get-Content -Path "C:\Program Files (x86)\Lansa\Verifier_Connection.dat" -Encoding Byte -Raw
#>

$file_data = Get-Content "C:\Program Files (x86)\Lansa\Verifier_Connection.dat"

echo($file_data)

<#
foreach($line in [System.IO.File]::ReadLines("C:\Program Files (x86)\Lansa\Verifier_Connection.dat"))
{
    Write-Output $line
}
#>


$DbTestScript = "C:\Program Files (x86)\AZURESQL\LANSA\VersionControl\Scripts\db-test.ps1"


if($file_data -eq $databaseType){
    echo("Database Type is correct")
    &  "$DbTestScript" -compile $true -test $true
}


<#
$DbTestScript = "C:\Program Files (x86)\AZURESQL\LANSA\VersionControl\Scripts\db-test.ps1"

&  "$DbTestScript" -compile $true -test $true
#>

#Start-Process powershell db-test.ps1 -compile $true -test $false



# Invoke-Item (start powershell ((Split-Path $MyInvocation.InvocationName) + "\db-test.ps1"))