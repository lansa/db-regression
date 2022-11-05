﻿param (
    [parameter(Mandatory=$true)]
    [string] $lansaVersion
)

$DSNNames = (Get-OdbcDsn).Name


# AZURESQL

if($DSNNames -contains "AZURESQL" -and (Get-OdbcDsn -Name "AZURESQL").Platform -eq "32-bit"){

    $sqlserver = "db-regression-" + $lansaVersion + ".database.windows.net" 

    Write-Host("Updating Server name as $sqlserver and database name as $lansaVersion for AZURESQL")
    
    Set-OdbcDsn -Name "AZURESQL" -DsnType "System" -Platform "32-bit" -SetPropertyValue @("Server=$sqlserver", "Database=$lansaVersion")

}


# Oracle

if($DSNNames -contains "ora19cdb" -and (Get-OdbcDsn -Name "ora19cdb").Platform -eq "32-bit"){

    $TNSNamesPath = "C:\oracle\instantclient_21_6\network\admin\tnsnames.ora"
    $Content = Get-Content $TNSNamesPath
    $oraServer = "ora" + $lansaVersion + ".cnyed5gpqwey.us-east-1.rds.amazonaws.com"

    Write-Host("Updating HOST name for Oracle in $TNSNamesPath to $oraServer")


    foreach ($string in (Get-Content $TNSNamesPath))
    {
        if($string.Contains("(ADDRESS=(PROTOCOL=TCP)(HOST=")){

            $newString = "            (ADDRESS=(PROTOCOL=TCP)(HOST=ora" + $lansaVersion + ".cnyed5gpqwey.us-east-1.rds.amazonaws.com)(PORT=1521))"
            $Content = $Content.replace($string,$newString)
            
        }
    }
    $Content | Set-Content -Path $TNSNamesPath
}


# MYSQL

if($DSNNames -contains "MYSQL" -and (Get-OdbcDsn -Name "MYSQL").Platform -eq "32-bit"){

    $mysqlServer = "mysql" + $lansaVersion + ".cnyed5gpqwey.us-east-1.rds.amazonaws.com"

    Write-Host("Updating Server name as $mysqlServer and database name as $lansaVersion for MYSQL")
    
    $temp = Get-OdbcDsn -Name "MYSQL"
    Remove-OdbcDsn -Name "MYSQL" -DsnType "System" -Platform "32-bit"
    Add-OdbcDsn -Name "MYSQL" -DriverName $temp.DriverName -Platform $temp.Platform -DsnType $temp.DsnType -SetPropertyValue @("Server=$mysqlServer", "PORT=$temp.Attribute.PORT", "Database=$lansaVersion")

}