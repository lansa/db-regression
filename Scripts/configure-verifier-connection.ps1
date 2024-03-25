param (
    [parameter(Mandatory=$false)]
    [string[]] $dbTypes
)
$ErrorActionPreference = "Stop"

try {

    Write-Host(" Modifying Verifier_Connection.dat file")

    $DB_LU_Map = @{
        DB2ISERIES = "LANSA01_P50PGMLIB"
        MSSQLS = "TestPrimaryMSSQLS"
        SQLAZURE = "TestSecondaryAZUR"
        SQLANYWHERE = "TestSecondarySQLA"
        MYSQL = "TestSecondaryMySQ"
        ODBCORACLE = "TestSecondaryORA"
    }

    $VerifierConnectionPath = "C:\Program Files (x86)\Lansa\Verifier_Connection.dat"
    $Content = [System.IO.File]::ReadAllLines($VerifierConnectionPath)


    Write-Host("Adding semicolon if not present with any db type in $VerifierConnectionPath")

    foreach ($string in (Get-Content $VerifierConnectionPath))
    {
        Write-Host("String being searched is '$string'")
        if($string.Length -gt 0 -and $string.Substring(0, 1) -ne ";"){
            $newString = ";" + $string
            $Content = $Content -replace $string,$newString
        }
        $Content | Set-Content -Path $VerifierConnectionPath
    }


    Write-Host("Configuring... $VerifierConnectionPath")

    Write-Host("Iterating over db types to remove the semicolon from matching lines in $VerifierConnectionPath")
    foreach($db in $dbTypes){

        if($DB_LU_Map.ContainsKey($db)){

            foreach ($string in (Get-Content $VerifierConnectionPath))
            {
                if($string.Contains($DB_LU_Map[$db])){
                    Write-Host("Enabling SuperServer test for $db by removing the semicolon")
                    $Content = $Content -replace $string,$string.Substring(1)
                }
            }

            $Content | Set-Content -Path $VerifierConnectionPath
        }
    }

    Write-Host("Final state of $VerifierConnectionPath")
    Get-Content $VerifierConnectionPath | Write-Host

    Write-Host("Ensuring 64 bit configured the same as 32 bit")
    $Configuration_Paths = @(
        'C:\Program Files (x86)\Lansa',
        'C:\Program Files (x86)\AZURESQL',
        'C:\Program Files (x86)\ORACLE',
        'C:\Program Files (x86)\SQLANYWHERE'
    )
    foreach ($Path in $Configuration_Paths) {
        $SourcePath = [IO.PATH]::Combine( $Path, 'x_win95\x_lansa\x_lansa.pro')
        $TargetPath = [IO.PATH]::Combine( $Path, 'x_win64\x_lansa\x_lansa.pro')
        Write-Host("Copy from $SourcePath to $TargetPath")
        Copy-Item $SourcePath $TargetPath -Force | Write-Host
    }
} catch {
    $_ | Out-Default | Write-Host
    throw
}