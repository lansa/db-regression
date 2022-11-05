## Powershell script to create RDS snapshot of exisiting Oracle and MYSQL Database for DB Regeression Test.

param (
[parameter(Mandatory=$true)]    [string] $lansa_version
)

$MYSQL_DB_IDENTIFIER = "mysql" + $lansa_version
$MYSQL_DB_SNAPSHOT_IDENTIFIER = "mysql" + $lansa_version
Write-Host "Finding MYSQL RDS snapshot with Lansa version tag = $lansa_version"
Write-Host "If Snapshot does not exist the exception System.InvalidOperationException will be thrown. This is an expected state."
try 
{
   $MYSQL_SNAPSHOT_COUNT = ((Get-RDSDBSnapshot -DBSnapshotIdentifier $MYSQL_DB_SNAPSHOT_IDENTIFIER -SnapshotType manual).DBSnapshotArn).count
   if ($MYSQL_SNAPSHOT_COUNT -eq 1)
   {
      Write-Host "Found 1 snapshot for lansa version tag = $lansa_version"
   }
   else
   {
      throw "Found more than 1 snapshot with lansa version tag = $lansa_version"
   }
}
catch [System.InvalidOperationException]
{
   Write-Host "Creating Snapshot for $MYSQL_DB_IDENTIFIER"
   New-RDSDBSnapshot -DBSnapshotIdentifier $MYSQL_DB_SNAPSHOT_IDENTIFIER -DBInstanceIdentifier $MYSQL_DB_IDENTIFIER -Tag @{Key="LansaVersion"; Value=$lansa_version}
   Write-Host "Waiting for MYSQL snapshot to be in available state"
   $RetryCount = 60
   while ( (((Get-RDSDBSnapshot -DBSnapshotIdentifier $MYSQL_DB_SNAPSHOT_IDENTIFIER).Status) -ne "available") -and ($RetryCount -gt 0))
   {
      Start-Sleep -Seconds 20
      $RetryCount -= 1
      Write-Host "Waiting for MYSQL snapshot to be in available state"
   }
   if ( $RetryCount -le 0 )
   {
      throw "Timeout: 20 minutes expired waiting for MYSQLRDS snapshot to be in availabe state"
   }
   Write-Host "MYSQL snapshot is in Available state"
}

$ORACLE_DB_IDENTIFIER = "ora" + $lansa_version
$ORACLE_DB_SNAPSHOT_IDENTIFIER = "ora" + $lansa_version
Write-Host "Finding ORACLE RDS snapshot with Lansa version tag = $lansa_version"
Write-Host "If Snapshot does not exist the exception System.InvalidOperationException will be thrown. This is an expected state."

try
{
   $ORACLE_SNAPSHOT_COUNT = ((Get-RDSDBSnapshot -DBSnapshotIdentifier $ORACLE_DB_SNAPSHOT_IDENTIFIER -SnapshotType manual).DBSnapshotArn).count
   if ($ORACLE_SNAPSHOT_COUNT -eq 1)
   {
      Write-Host "Found 1 snapshot for lansa version tag = $lansa_version"
   }
   else
   {
      Write-Host "Found more than 1 snapshot for lansa version tag = $lansa_version"
   }
}
catch [System.InvalidOperationException]
{
   Write-Host "Creating Snapshot for $ORACLE_DB_IDENTIFIER"
   New-RDSDBSnapshot -DBSnapshotIdentifier $ORACLE_DB_SNAPSHOT_IDENTIFIER -DBInstanceIdentifier $ORACLE_DB_IDENTIFIER  -Tag @{Key="LansaVersion"; Value=$lansa_version}
   Write-Host "Waiting for ORACLE snapshot to be in available state"
   $RetryCount = 60
   while ( (((Get-RDSDBSnapshot -DBSnapshotIdentifier $ORACLE_DB_SNAPSHOT_IDENTIFIER).Status) -ne "available") -and ($RetryCount -gt 0))
   {
      Start-Sleep -Seconds 20
      $RetryCount -= 1
      Write-Host "Waiting for ORACLE snapshot to be in available state"
   }
   if ( $RetryCount -le 0 )
   {
      throw "Timeout: 20 minutes expired waiting for ORACLE RDS snapshot to be in availabe state"
   }
   Write-Host "ORACLE snapshot is in Available state"
}
