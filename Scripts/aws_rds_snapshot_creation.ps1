i## Powershell script to create RDS snapshot of exisiting Oracle and MYSQL Database for DB Regeression Test.

param (
[parameter(Mandatory=$true)]    [string] $lansa_version
)

$MYSQL_DB_IDENTIFIER = "mysql + $lansa_version"
$MYSQL_DB_SNAPSHOT_IDENTIFIER = "mysql + $lansa_version" 
Write-Host "Finding MYSQL RDS snapshot with Lansa version tag = $lansa_version exist"
$MYSQL_SNAPSHOT_COUNT = ((Get-RDSDBSnapshot -DBInstanceIdentifier $MYSQL_DB_IDENTIFIER -SnapshotType manual).DBSnapshotArn).count
if ($MYSQL_SNAPSHOT_COUNT -eq 1)
{
   Write-Host "Found 1 snapshot for database identifier $MYSQL_SNAPSHOT_IDENTIFIER"
}  
elseif ($MYSQL_SNAPSHOT_COUNT -eq 0)
{
   Write-Host "Creating Snapshot for $MYSQL_DB_IDENTIFIER"
   New-RDSDBSnapshot -DBSnapshotIdentifier $MYSQL_DB_SNAPSHOT_IDENTIFIER -DBInstanceIdentifier $MYSQL_DB_IDENTIFIER  @{Key="LansaVersion"; Value=$lansa_version} 
   Write-Host "Waiting for MYSQL snapshot to be in available state"
   $RetryCount = 10
   while ( ((Get-RDSDBSnapshot -DBInstanceIdentifier $MYSQL_DB_IDENTIFIER).Status) -ne "available") -and ($RetryCount -gt 0))}
   {
      Start-Sleep -Seconds 120
      $RetryCount -= 1
	  Write-Host "Waiting for MYSQLsnapshot to be in available state"
   }
   if ( $RetryCount -le 0 )
      {
         Write-Host "Timeout: 20 minutes expired waiting for MYSQLRDS snapshot to be in availabe state"
      }
      Write-Host "MYSQL snapshot is in Available state"
}
else
{
  throw "Found more than 1 snapshot for database identifier $MYSQL_DB_IDENTIFIER"
}

$ORACLE_DB_IDENTIFIER = "ora + $lansa_version"
$ORACLE_DB_SNAPSHOT_IDENTIFIER = "ora + $lansa_version" 
Write-Host "Finding ORACLE RDS snapshot with Lansa version tag = $lansa_version exist"
$ORACLE_SNAPSHOT_COUNT = ((Get-RDSDBSnapshot -DBInstanceIdentifier $ORACLE_DB_IDENTIFIER -SnapshotType manual).DBSnapshotArn).count
if ($ORACLE_SNAPSHOT_COUNT -eq 1)
{
   Write-Host "Found 1 snapshot for database identifier $MYSQL_SNAPSHOT_IDENTIFIER"
}  
elseif ($ORACLE_SNAPSHOT_COUNT -eq 0)
{
   Write-Host "Creating Snapshot for $MYSQL_DB_IDENTIFIER"
   New-RDSDBSnapshot -DBSnapshotIdentifier $ORACLE_DB_SNAPSHOT_IDENTIFIER -DBInstanceIdentifier $ORACLE_DB_IDENTIFIER  @{Key="LansaVersion"; Value=$lansa_version} 
   Write-Host "Waiting for ORACLE snapshot to be in available state"
   $RetryCount = 10
   while ( ((Get-RDSDBSnapshot -DBInstanceIdentifier $ORACLE_DB_IDENTIFIER).Status) -ne "available") -and ($RetryCount -gt 0))}
   {
      Start-Sleep -Seconds 120
      $RetryCount -= 1
	  Write-Host "Waiting for ORACLE snapshot to be in available state"
   }
   if ( $RetryCount -le 0 )
      {
         Write-Host "Timeout: 20 minutes expired waiting for ORACLE RDS snapshot to be in availabe state"
      }
      Write-Host "ORACLE snapshot is in Available state"
}
else
{
  throw "Found more than 1 snapshot for database identifier $ORACLE_DB_IDENTIFIER"
}
