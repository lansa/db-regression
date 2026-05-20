$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$secret = Get-SECSecretValue `
    -SecretId "password/DBRegressionTest/MYSQL" `
    -Select SecretString | ConvertFrom-Json

$sql_username = $secret.UID
$sql_password = $secret.PWD #| ConvertTo-SecureString -AsPlainText -Force

$odbc = Get-OdbcDsn -Name "MYSQL" -Platform "32-bit" | Select-Object -ExpandProperty Attribute

$mysqlExe = "C:\Program Files\mysql\MySQL Workbench 8.0 CE\mysql.exe"
$defaultsFile = Join-Path $env:TEMP "mysql-dbreg-$PID.ini"

try {
    #create mysql configuration file for database connection
    $content = @"
[client]
database=$($odbc.database)
user=$sql_username
password=$sql_password
host=$($odbc.server)
"@

    Set-Content -Path $defaultsFile -Value $content -Encoding ASCII -NoNewline

    # in lansa estrict access to the current user where possible - montana
    & icacls $defaultsFile /inheritance:r /grant:r "$env:USERNAME:(R,W)" | Out-Default | Write-Host

    #execute the performance statistics for both bind and literal
    Get-Content mysql-performance-metrics-literal.sql | & $mysqlExe --defaults-extra-file=$defaultsFile --skip-column-names
    Get-Content mysql-performance-metrics-bind.sql | & $mysqlExe --defaults-extra-file=$defaultsFile --skip-column-names
}
finally {
    #remove the configuration file
    Remove-Item $defaultsFile -Force -ErrorAction SilentlyContinue
}
