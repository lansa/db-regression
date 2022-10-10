Set-AWSCredentials -AccessKey AKIA3JDVQNWWHFSBKU55 -SecretKey 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 -StoreAs myAWScredentials
#Set-AWSCredentials myAWScredentials

$server = 'dbregressiontest.database.windows.net'
$backupPath = 'C:\Program Files (x86)\AZURESQL'
$s3bucket = 'lansa-us-east-1/db-regression-test/backups/150050/'
$region = 'us-east-1'

$databases = Invoke-Sqlcmd -ServerInstance $server -Username "lansa" -Password "Pcxuser@122robg" -Query "SELECT [name]
FROM master.dbo.sysdatabases where [name]='test'"

foreach ($database in $databases)
{
    $timestamp = get-date -format MMddyyyyHHmmss
    $fileName =  "$($database.name)-$timestamp.bak"
    $filePath = Join-Path $backupPath $fileName
    $zipfilepath = Join-Path $backupPath $zipfileName

    Backup-SqlDatabase -ServerInstance $server -Database $database.name -BackupFile $filePath
    Write-Zip -path $filePath -OutputPath $zipfilepath

    Write-S3Object -BucketName $s3Bucket -StoredCredentials myAWScredentials  -File $zipfilePath -Region $region
}