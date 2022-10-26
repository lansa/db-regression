# dbTypes is containing database type names which will be coming from pipeline
param (
    [parameter(Mandatory=$true)]
    [string[]] $dbTypes
)

# HashTable mapping database type name with LU Names
$DB_LU_Map = @{
    DB2ISERIES = "LANSA01_DEVPGMLIB"
    MSSQLS = "TestPrimaryMSSQLS"
    SQLAZURE = "TestSecondaryAZUR"
    SQLANYWHERE = "TestSecondarySQLA"
    MYSQL = "TestSecondaryMySQ"
    ODBCORACLE = "TestSecondaryORA"
}

# VerifierConnectionPath is variable containing path of Verifier_Connection.dat file
$VerifierConnectionPath = "C:\Program Files (x86)\Lansa\Verifier_Connection.dat"
$Content = [System.IO.File]::ReadAllLines($VerifierConnectionPath)

# Making sure every dbType is having semicolon
Write-Host("Adding semicolon if not present with any db type in $VerifierConnectionPath")

foreach ($string in (Get-Content $VerifierConnectionPath))
{
    if($string.Substring(0, 1) -ne ";"){
        $newString = ";" + $string
        $Content = $Content -replace $string,$newString
    }
    $Content | Set-Content -Path $VerifierConnectionPath
}


Write-Host("Configuring... $VerifierConnectionPath")

#Iterarting over db types to remove the semicolon from particular line from verifier_connection.dat file
foreach($db in $dbTypes){

    if($DB_LU_Map.ContainsKey($db)){

        foreach ($string in (Get-Content $VerifierConnectionPath))
        {
            if($string.Contains($DB_LU_Map[$db])){
                Write-Host("Enabling SuperServer test for $db")
                #Here we are removing the semicolon
                $Content = $Content -replace $string,$string.Substring(1)
            }
        }

        $Content | Set-Content -Path $VerifierConnectionPath
    }
}