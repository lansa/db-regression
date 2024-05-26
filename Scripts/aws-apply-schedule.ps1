## Powershell script to create RDS snapshot of exisiting Oracle and MYSQL Database for DB Regeression Test.

param (
[parameter(Mandatory=$true)] [string] $lansa_version,
[parameter(Mandatory=$false)] [switch] $RemoveSchedule,

[parameter(Mandatory=$false)] 
[ValidateSet('KEEP_STOPPED','RUN_WORKHOURS_AEST','RUN_WORKHOURS_ACST','RUN_ALL_WEEK_ACST','RUN_ALL_WEEK_AEST')]
[string] $SchedulePeriod = "RUN_WORKHOURS_AEST"
)

Set-DefaultAWSRegion -Region 'us-east-1' -Scope Script

try {
   Write-Host "Get all EC2 instances no matter their state"
   $ALL_EC2_INSTANCES = @(Get-EC2Instance -Filter @{ Name="tag:LansaVersion"; Values=$lansa_version })
   $ALL_INSTANCES = $ALL_EC2_INSTANCES.Instances
   $ALL_INSTANCES | Out-Default | Write-Host
   foreach ($INSTANCE in $ALL_INSTANCES ) {
      # $INSTANCE | Out-Default | Write-Host
      if ( $RemoveSchedule ) {
         Write-Host "Removing Schedule tag from $($INSTANCE.InstanceId)"
         Remove-EC2Tag -Resource $INSTANCE.InstanceId -Tag @{ Key = "Schedule"} -Force
      } else {
         Write-Host "Adding Schedule tag $SchedulePeriod to $($INSTANCE.InstanceId)"
         New-EC2Tag -Resource $INSTANCE.InstanceId -Tag @{ Key = "Schedule"; Value = $SchedulePeriod} -Force
      }
   }

   foreach ($DBType in @("ora", "mysql") ) {
      $DB_ARN = "arn:aws:rds:us-east-1:775488040364:db:$($DBType)$($lansa_version)"
      if ( $RemoveSchedule ) {
         Write-Host "Removing Schedule tag from $($DB_ARN)"
         Remove-RDSTagFromResource -ResourceName $DB_ARN -TagKey @("Schedule") -Force
      } else {
         Write-Host "Adding Schedule tag $SchedulePeriod to $($DB_ARN)"
         Add-RDSTagsToResource -ResourceName $DB_ARN -Tag @{ Key = "Schedule"; Value = $SchedulePeriod} -Force
      }
   }

} catch {
   $_ | Out-Default | Write-Host
   throw
}