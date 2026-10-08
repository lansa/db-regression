<#
.SYNOPSIS

Restarts SQL Server

.EXAMPLE
#>

$MyInvocation.MyCommand.Path
$StartDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Use the default instance if installed, otherwise fall back to a named instance (e.g. SQLEXPRESS)
$ServerInstance = $env:computername
if (-not (Get-Service -Name "MSSQLSERVER" -ErrorAction SilentlyContinue)) {
    $named = Get-Service -Name 'MSSQL$*' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($named) {
        $ServerInstance = "$env:computername\$($named.Name.Substring(6))"
    }
}
Write-Host "Using SQL Server instance: $ServerInstance"

Invoke-Sqlcmd -ServerInstance $ServerInstance -Database lansa -InputFile "$StartDir\mssql-add-pcxuser2.sql" -verbose | write-Host

# Restart SQL Server

$svc=Get-Service
$i=1
foreach($service in $svc)
{
if ($svc[$i].name -eq "MSSQLSERVER" -or
    $svc[$i].name -like 'MSSQL$*' -or
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