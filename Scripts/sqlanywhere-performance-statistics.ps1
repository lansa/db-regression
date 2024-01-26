$sql_username = Get-SECSecretValue -SecretId "password/DBRegressionTest/MSSQLS" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty UID
$sql_password = Get-SECSecretValue -SecretId "password/DBRegressionTest/MSSQLS" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty PWD #| ConvertTo-SecureString -AsPlainText -Force

dbisql -c "UID=$sql_username;PWD=$sql_password;DSN=SQLANYWHERE" -onerror exit -nogui "sqlanywhere-performance-statistics-literal.sql"
dbisql -c "UID=$sql_username;PWD=$sql_password;DSN=SQLANYWHERE" -onerror exit -nogui "sqlanywhere-performance-statistics-bind.sql"
