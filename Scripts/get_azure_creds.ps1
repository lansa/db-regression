$sql_username = Get-SECSecretValue -SecretId "password/DBRegressionTest/SQLAZURE" -Select SecretString | ConvertFrom-Json | Select-Object -ExpandProperty UID

$sql_password = Get-SECSecretValue -SecretId "password/DBRegressionTest/SQLAZURE" -Select SecretString | ConvertFrom-Json | Select-Object -ExpandProperty PWD | ConvertTo-SecureString -AsPlainText -Force


"##vso[task.setvariable variable=username]$sql_username"
"##vso[task.setvariable variable=password;issecret=true]$sql_password"