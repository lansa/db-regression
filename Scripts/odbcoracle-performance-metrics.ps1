$sql_username = Get-SECSecretValue -SecretId "password/DBRegressionTest/MYSQL" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty UID
$sql_password = Get-SECSecretValue -SecretId "password/DBRegressionTest/MYSQL" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty PWD #| ConvertTo-SecureString -AsPlainText -Force

sqlplus -s -NOLOGINTIME $sql_username/$sql_password@ora19cdb @odbcoracle-performance-metrics-literal.sql
sqlplus -s -NOLOGINTIME $sql_username/$sql_password@ora19cdb @odbcoracle-performance-metrics-bind.sql
