$sql_username = Get-SECSecretValue -SecretId "password/DBRegressionTest/MSSQLS" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty UID
$sql_password = Get-SECSecretValue -SecretId "password/DBRegressionTest/MSSQLS" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty PWD #| ConvertTo-SecureString -AsPlainText -Force

$ODBC = Get-OdbcDsn -Name "AZURESQL" -Platform "32-bit" | Select-Object -Expandproperty Attribute

SQLCMD.exe -S $ODBC.server -d $ODBC.database -U $sql_username -P $sql_password -i sqlazure-performance-metrics-literal.sql
SQLCMD.exe -S $ODBC.server -d $ODBC.database -U $sql_username -P $sql_password -i sqlazure-performance-metrics-bind.sql
