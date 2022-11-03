param (
    [parameter(Mandatory=$true)]
    [string] $lansaVersion
)

$DSNNames = (Get-OdbcDsn).Name

# AZURESQL

Write-Host("Updating Server name and database name for AZURESQL")

if($DSNNames -contains "AZURESQL" -and (Get-OdbcDsn -Name "AZURESQL").Platform -eq "32-bit"){
    $sqlserver = "db-regression-" + $lansaVersion + ".database.windows.net" 
    Set-OdbcDsn -Name "AZURESQL" -DsnType "System" -Platform "32-bit" -SetPropertyValue @("Server=$sqlserver", "Database=$lansaVersion")
}

# Oracle

Write-Host("Updating Server name for Oracle")

if($DSNNames -contains "ora19cdb" -and (Get-OdbcDsn -Name "ora19cdb").Platform -eq "32-bit"){
    $oraServer = "ora" + $lansaVersion
    Set-OdbcDsn -Name "ora19cdb" -DsnType "System" -Platform "32-bit" -SetPropertyValue "ServerName=$oraServer"
}

# MYSQL

Write-Host("Updating Server name and database name for MYSQL")

if($DSNNames -contains "MYSQL" -and (Get-OdbcDsn -Name "MYSQL").Platform -eq "32-bit"){
    $mysqlServer = "mysql" + $lansaVersion + ".cnyed5gpqwey.us-east-1.rds.amazonaws.com"
    $temp = Get-OdbcDsn -Name "MYSQL"
    Remove-OdbcDsn -Name "MYSQL" -DsnType "System" -Platform "32-bit"
    Add-OdbcDsn -Name "MYSQL" -DriverName $temp.DriverName -Platform $temp.Platform -DsnType $temp.DsnType -SetPropertyValue @("Server=$mysqlServer", "PORT=$temp.Attribute.PORT", "Database=$lansaVersion")
}