$sql_username = Get-SECSecretValue -SecretId "password/DBRegressionTest/MYSQL" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty UID
$sql_password = Get-SECSecretValue -SecretId "password/DBRegressionTest/MYSQL" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty PWD #| ConvertTo-SecureString -AsPlainText -Force

$ODBC = Get-OdbcDsn -Name "MYSQL" -Platform "32-bit" | Select-Object -Expandproperty Attribute

#remove if configuration file is exists
$filecsv = "my.ini.lansa"
if (Test-Path $filecsv) {
        Remove-Item $filecsv -Force
    }

#create mysql configuration file for database connection
New-Item $filecsv -ItemType File -Value ("[client]" + [Environment]::NewLine) | Out-Null
Add-Content $filecsv ("database="+ $ODBC.database)
Add-Content $filecsv ("user=" + $sql_username)
Add-Content $filecsv ("password=" + $sql_password)
Add-Content $filecsv ("host="+ $ODBC.server)

#execute the performance statistics for both bind and literal
get-content mysql-performance-metrics-literal.sql | & "C:\Program Files\mysql\MySQL Workbench 8.0 CE\mysql.exe" --defaults-file=my.ini.lansa --skip-column-names
get-content mysql-performance-metrics-bind.sql | & "C:\Program Files\mysql\MySQL Workbench 8.0 CE\mysql.exe" --defaults-file=my.ini.lansa --skip-column-names

#remove the configuration file 
if (Test-Path $filecsv) {
        Remove-Item $filecsv -Force
    }