$sql_username = Get-SECSecretValue -SecretId "password/DBRegressionTest/SQLAZURE" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty UID

$sql_password = Get-SECSecretValue -SecretId "password/DBRegressionTest/SQLAZURE" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty PWD #| ConvertTo-SecureString -AsPlainText -Force



#$azusername = Get-SECSecretValue -SecretId azuresql-username -Select SecretString | ConvertFrom-Json | Select -ExpandProperty username
#$azpassword = Get-SECSecretValue -SecretId azuresql-username -Select SecretString | ConvertFrom-Json | Select -ExpandProperty password | ConvertTo-SecureString -AsPlainText -Force

"##vso[task.setvariable variable=username]$sql_username"
"##vso[task.setvariable variable=password]$sql_password"