$ErrorActionPreference = 'Stop'

Set-DefaultAWSRegion -Region 'us-east-1' -Scope Script

$aws_stack_script_path = $MyInvocation.MyCommand.Path
$stack_script = Split-Path $aws_stack_script_path
$DvdDir = "C:\LanDvdCut-Trunk"

$InstallSettingsPassword = Get-SECSecretValue -SecretId "password/DBRegressionTest/VLInstallSettings" -Select SecretString | ConvertFrom-Json | Select -ExpandProperty PWD

$installer_file = "$DvdDir\Setup\FileTransfer.exe"

[string[]] $TargetDB = @("MSSQLS", "MYSQL", "SQLANYWHERE", "ODBCORACLE", "SQLAZURE")

try {
    foreach ($System in $TargetDB ){
        $SettingsFile = "$stack_script\$($System)-Settings.cfg"
        Write-Host "Settings File: $SettingsFile"
        Write-Host "Password: $InstallSettingsPassword"
        &$installer_file """$InstallSettingsPassword""" """$SettingsFile""" """E""" | Out-Default | Write-Host
        if ($LASTEXITCODE -ne 0) {
            throw
        }
        Write-Host "Successfully installed $System system"
    }
} catch {
    $_ | Out-Default | Write-Host
    Write-Host "Error $LASTEXITCODE installing $System. Check log files in $($ENV:TEMP)"
    throw    
}
Write-Host "Finished Installs successfully"