$sql_username = Get-SECSecretValue -SecretId "password/DBRegressionTest/MSSQLS" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty UID
$sql_password = Get-SECSecretValue -SecretId "password/DBRegressionTest/MSSQLS" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty PWD #| ConvertTo-SecureString -AsPlainText -Force

SQLCMD.exe -S Localhost -d LANSA -U $sql_username -P $sql_password -i mssql-performance-statistics-literal.sql
SQLCMD.exe -S Localhost -d LANSA -U $sql_username -P $sql_password -i mssql-performance-statistics-bind.sql
