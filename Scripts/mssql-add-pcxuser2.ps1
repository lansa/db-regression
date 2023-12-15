<#
.SYNOPSIS

Restarts SQL Server

.EXAMPLE
#>

$MyInvocation.MyCommand.Path
$StartDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Invoke-Sqlcmd -ServerInstance $env:computername -Database lansa -InputFile "$StartDir\mssql-add-pcxuser2.sql" -verbose | write-Host

# Restart SQL Server

$svc=Get-Service
$i=1
foreach($service in $svc)
{
if ($svc[$i].name -eq "MSSQLSERVER" -or
    $svc[$i].name -eq "SQLServerReportingServices" -or
    $svc[$i].name -eq "MsDtsServer150" )
    {
        if($svc[$i].status -eq "Stopped")
        {
            Write-Host ( "Starting $($svc[$i].Name)")
            start-service -name $svc[$i].Name -PassThru | Out-Default | Write-Host
        }
        if($svc[$i].status -eq "Running")
        {    
            Write-Host ( "Restarting $($svc[$i].Name)")
            stop-service -name $svc[$i].Name -Force -PassThru | Out-Default | Write-Host
            start-service -name $svc[$i].Name -PassThru | Out-Default | Write-Host
        }
        }
$i++
}
Write-Output " "
Write-Output "SQL Services Successfully restarted."