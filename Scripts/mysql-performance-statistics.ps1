$sql_username = Get-SECSecretValue -SecretId "password/DBRegressionTest/MYSQL" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty UID
$sql_password = Get-SECSecretValue -SecretId "password/DBRegressionTest/MYSQL" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty PWD #| ConvertTo-SecureString -AsPlainText -Force

$ODBC = Get-OdbcDsn -Name "MYSQL" -Platform "32-bit" | Select-Object -Expandproperty Attribute
$mysqlServer = $ODBC.server
$database = $ODBC.database 

#remove if configuration file is exists
$filecsv = "my.ini.lansa"
if (Test-Path $filecsv) {
        Remove-Item $filecsv -Force
    }

#create mysql configuration file for database connection
New-Item $filecsv -ItemType File -Value ("[client]" + [Environment]::NewLine) | Out-Null
Add-Content $filecsv ("database="+ $database)
Add-Content $filecsv ("user=" + $sql_username)
Add-Content $filecsv ("password=" + $sql_password)
Add-Content $filecsv ("host="+ $mysqlServer)

#execute the performance statistics for both bind and literal
get-content mysql-performance-statistics-literal.sql | & "C:\Program Files\mysql\MySQL Workbench 8.0 CE\mysql.exe" --defaults-file=my.ini.lansa --skip-column-names
get-content mysql-performance-statistics-bind.sql | & "C:\Program Files\mysql\MySQL Workbench 8.0 CE\mysql.exe" --defaults-file=my.ini.lansa --skip-column-names

#remove the configuration file
$filecsv = "my.ini.lansa"
if (Test-Path $filecsv) {
        Remove-Item $filecsv -Force
    }