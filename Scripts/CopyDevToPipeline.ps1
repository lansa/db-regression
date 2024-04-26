param (
    [string] $SourceRoot = "C:\dev\work\"
)

[string[]] $TargetRoots = @('C:\Program Files (x86)\lansa\', 'C:\Program Files (x86)\sqlanywhere\', 'C:\Program Files (x86)\mysql\', 'C:\Program Files (x86)\oracle\', 'C:\Program Files (x86)\azuresql\')

iisreset /Stop
Write-Host "Copy debug build of Web Server to IIS"
robocopy "$($SourceRoot)X_WIN95\X_LANSA\wpi\build\Debug" "$($SourceRoot)WebServer\IISPlugin\lansaweb"  *.dll /s /w:2
robocopy "$($SourceRoot)X_WIN95\X_LANSA\wpi\build\x64\Debug" "$($SourceRoot)WebServer\IISPlugin\lansaweb64"  *.dll /s /w:2
    
Write-Host "Copy from $SourceRoot to All Pipeline systems"

foreach ($root in $TargetRoots ){
    Write-Host "Stop the listener"

    & "$($Root)connect64\lcolist" -sstop
    robocopy "$($SourceRoot)lansa" "$Root\lansa" *.dll *.exe *.bnd /w:2
    # robocopy "$($SourceRoot)lansa\connect" "$Root\lansa\connect" *.dll *.exe /s /w:2
    # robocopy "$($SourceRoot)lansa\connect64" "$Root\lansa\connect64" *.dll *.exe /s /w:2
    # robocopy "$($SourceRoot)lansa\integrator" "$Root\lansa\integrator" *.jar *.dll *.exe *.gif *.htm *.html *.xml *.hhc /s /w:2
    # robocopy "$($SourceRoot)lansa\integrator\java" "$Root\lansa\integrator\java" *.* /s /w:2
    # robocopy "$($SourceRoot)lansa\open" "$Root\lansa\open" *.dll *.exe /s /w:2
    # robocopy "$($SourceRoot)lansa\WebUtilities" "$Root\lansa\WebUtilities" *.dll *.exe /s /w:2

    Write-Host "Copying '$($SourceRoot)x_win95\x_lansa\execute'"
    robocopy "$($SourceRoot)x_win95\x_lansa\execute" "$Root\x_win95\x_lansa\execute" *.dll *.exe *.bnd *.s /w:2
    robocopy "$($SourceRoot)x_win95\x_lansa\source" "$Root\x_win95\x_lansa\source" *.h *.s /w:2
    robocopy "$($SourceRoot)x_win95\x_lansa\web\tsp" "$Root\x_win95\x_lansa\web\tsp" *.xsl /w:2

    Write-Host "Remove all W32 vlweb versions that are not in Source system and update the rest. (/mir - mirror)"
    # Remove-Item "$Root\x_win95\x_lansa\web\vl\lansa*" -recurse -force -ErrorAction 'SilentlyContinue'
    # Remove-Item "$Root\x_win95\x_lansa\web\vl\vlweb.dat" -ErrorAction 'SilentlyContinue'
    robocopy "$($SourceRoot)x_win95\x_lansa\web\vl" "$Root\x_win95\x_lansa\web\vl"  *.* /xf compile.cmd /xd source minifier symbols* /s /w:2 /mir

    Write-Host "Copying "$($SourceRoot)x_win64\x_lansa\execute""
    robocopy "$($SourceRoot)x_win64\x_lansa\execute" "$Root\x_win64\x_lansa\execute" *.dll *.exe *.bnd /w:2
    robocopy "$($SourceRoot)x_win64\x_lansa\web\tsp" "$Root\x_win64\x_lansa\web\tsp" *.xsl /w:2

    Write-Host "Remove all x64 vlweb versions that are not in Source system and update the rest. (/mir - mirror)"
    # Remove-Item "$Root\x_win64\x_lansa\web\vl\lansa*" -recurse -force -ErrorAction 'SilentlyContinue'
    # Remove-Item "$Root\x_win64\x_lansa\web\vl\vlweb.dat" -ErrorAction 'SilentlyContinue'
    robocopy "$($SourceRoot)x_win64\x_lansa\web\vl" "$Root\x_win64\x_lansa\web\vl"  *.* /xf compile.cmd /xd source minifier symbols* /s /w:2 /mir
    
    Write-Host "Copy WebServer"
    robocopy "$($SourceRoot)WebServer\IISPlugin" "$($Root)WebServer\IISPlugin"  *.dll /s /w:2
    
    Write-Host "Start the Listener"
    & "$($Root)connect64\lcolist" -sstart
}
IISRESET /START