$TargetSystems = @(
    'C:\Program Files (x86)\AZURESQL\X_WIN95\X_LANSA\x_wbp\',
    'C:\Program Files (x86)\MySQL\X_WIN95\X_LANSA\x_wbp\',
    'C:\Program Files (x86)\ORACLE\X_WIN95\X_LANSA\x_wbp\',
    'C:\Program Files (x86)\SQLANYWHERE\X_WIN95\X_LANSA\x_wbp\'
)
$ExecuteFiles = @(
# 'vti0049.dll',
# 'vi0049d.dll',
# 'vi0049b.dll',
# 'vti0049b.dll',
# 'vi0049c.dll',
# 'vi0049a.dll'
)
$TableFiles =@(
#  'vtli0049.dll'
)

$ScriptFiles = @(
    # '*.sql',
    # '*.ps1'
)

$LANSAPCFiles = @(
    'LIIS.DLL',
    'LANSA.EXE'
)

$LANSAXFiles = @(
    'x_pdfms.dll',
    'lxpprbld.exe',
    'lxptbbld.exe',
    'lxpcobld.exe'
)

$SourceSystem = 'C:\Program Files (x86)\LANSA\X_WIN95\X_LANSA\x_wbp\'
$SourceLANSARoot = "$SourceSystem..\..\..\"

foreach ($TargetSystem in $TargetSystems) {
    $TargetLANSARoot = "$TargetSystem..\..\..\"
    foreach ($ExecuteFile in $ExecuteFiles) {
        Write-Host "$($SourceSystem)execute\$ExecuteFile  to $($TargetSystem)execute\$ExecuteFile"
        Copy-Item "$($SourceSystem)execute\$ExecuteFile"  "$($TargetSystem)execute\$ExecuteFile"
    }
    foreach ($TableFile in $TableFiles) {
        Write-Host "$($SourceSystem)DEVWBPLIBF\execute\$TableFile to $($TargetSystem)DEVWBPLIBF\execute\$TableFile"
        Copy-Item "$($SourceSystem)DEVWBPLIBF\execute\$TableFile"  "$($TargetSystem)DEVWBPLIBF\execute\$TableFile"
    }
    foreach ($ScriptFile in $ScriptFiles) {
        Write-Host "$($SourceSystem)..\..\..\lansa\versioncontrol\scripts\$ScriptFile to $($TargetSystem)..\..\..\lansa\versioncontrol\scripts"
        Copy-Item "$($SourceSystem)..\..\..\lansa\versioncontrol\scripts\$ScriptFile"  "$($TargetSystem)..\..\..\lansa\versioncontrol\scripts"
    }
    foreach ($LANSAPCFile in $LANSAPCFiles) {
        Write-Host "$($SourceLANSARoot)lansa\$LANSAPCFile  to $($TargetLANSARoot)lansa\$LANSAPCFile"
        Copy-Item "$($SourceLANSARoot)lansa\$LANSAPCFile"  "$($TargetLANSARoot)lansa\$LANSAPCFile"
    }
    foreach ($LANSAXFile in $LANSAXFiles) {
        Write-Host "$($SourceLANSARoot)x_win95\x_lansa\execute\$LANSAXFile  to $($TargetLANSARoot)x_win95\x_lansa\execute\$LANSAXFile"
        Copy-Item "$($SourceLANSARoot)x_win95\x_lansa\execute\$LANSAXFile"  "$($TargetLANSARoot)x_win95\x_lansa\execute\$LANSAXFile"

        if (Test-Path( "$($SourceLANSARoot)x_win64\x_lansa\execute\$LANSAXFile") ) {
            Write-Host "$($SourceLANSARoot)x_win64\x_lansa\execute\$LANSAXFile  to $($TargetLANSARoot)x_win64\x_lansa\execute\$LANSAXFile"
            Copy-Item "$($SourceLANSARoot)x_win64\x_lansa\execute\$LANSAXFile"  "$($TargetLANSARoot)x_win64\x_lansa\execute\$LANSAXFile"
        }
    }
}