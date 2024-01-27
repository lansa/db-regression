$sql_username = Get-SECSecretValue -SecretId "password/DBRegressionTest/MSSQLS" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty UID
$sql_password = Get-SECSecretValue -SecretId "password/DBRegressionTest/MSSQLS" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty PWD #| ConvertTo-SecureString -AsPlainText -Force

$ODBC = Get-OdbcDsn -Name "AZURESQL" -Platform "32-bit" | Select-Object -Expandproperty Attribute
$sqlserver = $ODBC.server
$database = $ODBC.database 

SQLCMD.exe -S $sqlserver -d $database -U $sql_username -P $sql_password -i sqlazure-performance-statistics-literal.sql
SQLCMD.exe -S $sqlserver -d $database -U $sql_username -P $sql_password -i sqlazure-performance-statistics-bind.sql
