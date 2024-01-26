$sql_username = Get-SECSecretValue -SecretId "password/DBRegressionTest/MSSQLS" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty UID
$sql_password = Get-SECSecretValue -SecretId "password/DBRegressionTest/MSSQLS" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty PWD #| ConvertTo-SecureString -AsPlainText -Force

$DSNNames = (Get-OdbcDsn).Name
$lansaVersion = "150060"
$database = $lansaVersion

    # AZURESQL

    if ($DSNNames -contains "AZURESQL" -and (Get-OdbcDsn -Name "AZURESQL").Platform -eq "32-bit"){

        $sqlserver = "db-regression-" + $lansaVersion + ".database.windows.net"
    }

    if ($DSNNames -contains "AZURESQL" -and (Get-OdbcDsn -Name "AZURESQL").Platform -eq "64-bit"){

        $sqlserver = "db-regression-" + $lansaVersion + ".database.windows.net"
    }

SQLCMD.exe -S $sqlserver -d $database -U $sql_username -P $sql_password -i sqlazure-performance-statistics-literal.sql
SQLCMD.exe -S $sqlserver -d $database -U $sql_username -P $sql_password -i sqlazure-performance-statistics-bind.sql
