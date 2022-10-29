$sql_username = Get-SECSecretValue -SecretId "password/DBRegressionTest/SQLAZURE" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty UID

$sql_password = Get-SECSecretValue -SecretId "password/DBRegressionTest/SQLAZURE" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty PWD | ConvertTo-SecureString -AsPlainText -Force