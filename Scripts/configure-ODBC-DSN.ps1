param (
    [parameter(Mandatory=$true)]
    [string] $lansaVersion
)

$DSNNames = (Get-OdbcDsn).Name

try {
    # AZURESQL

    if ($DSNNames -contains "AZURESQL" -and (Get-OdbcDsn -Name "AZURESQL").Platform -eq "32-bit"){

        $sqlserver = "db-regression-" + $lansaVersion + ".database.windows.net"

        Write-Host("Updating Server name as $sqlserver and database name as $lansaVersion for AZURESQL 32-bit")

        Set-OdbcDsn -Name "AZURESQL" -DsnType "System" -Platform "32-bit" -SetPropertyValue @("Server=$sqlserver", "Database=$lansaVersion") | Out-Default | Write-Host
    }

    if ($DSNNames -contains "AZURESQL" -and (Get-OdbcDsn -Name "AZURESQL").Platform -eq "64-bit"){

        $sqlserver = "db-regression-" + $lansaVersion + ".database.windows.net"

        Write-Host("Updating Server name as $sqlserver and database name as $lansaVersion for AZURESQL 64-bit")

        Set-OdbcDsn -Name "AZURESQL" -DsnType "System" -Platform "64-bit" -SetPropertyValue @("Server=$sqlserver", "Database=$lansaVersion") | Out-Default | Write-Host
    }

    # Oracle

    $TNSNamesPath = "C:\oracle\tnsnames.ora"
    if (Test-Path $TNSNamesPath){
        $Content = Get-Content $TNSNamesPath
        $oraServer = "ora" + $lansaVersion + ".cnyed5gpqwey.us-east-1.rds.amazonaws.com"

        Write-Host("Updating HOST name for Oracle in $TNSNamesPath to $oraServer")

        $FoundTNSName = $false
        foreach ($string in (Get-Content $TNSNamesPath))
        {
            Write-Host( "First locate the ora19cdb TNS name")
            if($string.Contains("ora19cdb")){
                $FoundTNSName = $true
            }

            if($FoundTNSName -and $string.Contains("(ADDRESS=(PROTOCOL=TCP)(HOST=")){
                $newString = "            (ADDRESS=(PROTOCOL=TCP)(HOST=ora" + $lansaVersion + ".cnyed5gpqwey.us-east-1.rds.amazonaws.com)(PORT=1521))"
                $Content = $Content.replace($string,$newString)
                Write-Host("Replaced $string with")
                Write-Host("$newString")
                break
            }
        }
        $Content | Set-Content -Path $TNSNamesPath
    }


    # MYSQL

    if ($DSNNames -contains "MYSQL" -and (Get-OdbcDsn -Name "MYSQL").Platform -eq "32-bit"){

        $mysqlServer = "mysql" + $lansaVersion + ".cnyed5gpqwey.us-east-1.rds.amazonaws.com"

        Write-Host("Updating Server name as $mysqlServer and database name as $lansaVersion for MYSQL 32-bit")

        $temp = Get-OdbcDsn -Name "MYSQL"
        Remove-OdbcDsn -Name "MYSQL" -DsnType "System" -Platform "32-bit" | Out-Default | Write-Host
        Add-OdbcDsn -Name "MYSQL" -DriverName $temp.DriverName -Platform $temp.Platform -DsnType $temp.DsnType -SetPropertyValue @("Server=$mysqlServer", "PORT=$temp.Attribute.PORT", "Database=$lansaVersion") | Out-Default | Write-Host

    }

    if ($DSNNames -contains "MYSQL" -and (Get-OdbcDsn -Name "MYSQL").Platform -eq "64-bit"){

        $mysqlServer = "mysql" + $lansaVersion + ".cnyed5gpqwey.us-east-1.rds.amazonaws.com"

        Write-Host("Updating Server name as $mysqlServer and database name as $lansaVersion for MYSQL 64-bit")

        $temp = Get-OdbcDsn -Name "MYSQL" -Platform "64-bit"
        Remove-OdbcDsn -Name "MYSQL" -DsnType "System" -Platform "64-bit" | Out-Default | Write-Host
        Add-OdbcDsn -Name "MYSQL" -DriverName $temp.DriverName -Platform $temp.Platform -DsnType $temp.DsnType -SetPropertyValue @("Server=$mysqlServer", "PORT=$temp.Attribute.PORT", "Database=$lansaVersion") | Out-Default | Write-Host

    }
} catch {
    $_ | Out-Default | Write-Host
}