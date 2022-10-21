
# dbTypes is containing database type names which will be coming from pipeline
param (
    [string[]] $dbTypes
)


# using this as dummy here for testing, we can remove this line in the final script
$dbArray = 'MSSQLS','MYSQL'


# this line will also be removed
$dbTypes = $dbArray


# HashTable mapping database type name with LU Names
$DB_LU_Map = @{
    DB21SERIES = 'LANSA01_DEVPGMLIB'
    MSSQLS = 'TestPrimaryMSSQLS'
    SQLAZURE = 'TestSecondaryAZUR'
    SQLANYWHERE = 'TestSecondarySQLA'
    MYSQL = 'TestSecondaryMySQ'
    ODBCORACLE = 'TestSecondaryORA'
}


#Iterarting over db types to remove the semicolon from particular line from verifier_connection.dat file
foreach($db in $dbTypes){

    if($DB_LU_Map.ContainsKey($db)){

        $Path = 'C:\Program Files (x86)\Lansa\Verifier_Connection.dat'
        $Content = [System.IO.File]::ReadAllLines($Path)

        foreach ($string in (Get-Content 'C:\Program Files (x86)\Lansa\Verifier_Connection.dat'))
        {
            if($string.Contains($DB_LU_Map[$db])){
                Write-Host("Changes made in $db")
                #Here we are removing the semicolon
                $Content = $Content -replace $string,$string.Substring(1)
            }
        }

        $Content | Set-Content -Path $Path
    }
}

# DB test script 
$DbTestScript = 'C:\Program Files (x86)\AZURESQL\LANSA\VersionControl\Scripts\db-test.ps1'

#Running the script here
&  "$DbTestScript" -compile $true -test $true