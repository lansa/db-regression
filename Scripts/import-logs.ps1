
#########powershell script to upload log files into s3 bucket###########

#s3Bucket path to save the log files
param (
    [Parameter(Mandatory=$true)]
    [string] $Lansaversion,
    [Parameter(Mandatory=$true)]
    [string] $PipelineReleaseId,
    [Parameter(Mandatory=$true)]
    [string[]] $databaseTypes
)

$s3BasePath = 'lansa-us-east-1/db-regression-test/logs' 
$region = 'us-east-1'

$s3BaseKey =  $Lansaversion +'/'+ $PipelineReleaseId


# Mapping the database to root folder
# Here DB2ISERIES and MSSQLS are not included as DB2ISERIES is not mapped to any root path and MSSQLS is mapped to LANSA which is included by default
$DB_ROOT_Map = @{

    SQLAZURE = "AZURESQL"
    SQLANYWHERE = "SQLANYWHERE"
    MYSQL = "MYSQL"
    ODBCORACLE = "ORACLE"
}
$databases = New-Object -TypeName 'System.Collections.ArrayList';
Write-Host('list of databases:') 
Write-Host('--------------------------------------------------------------')
foreach ($db in $databaseTypes)
{
    
    if($db -ne 'DB2ISERIES'){
        $databases.Add($DB_ROOT_Map[$db])
    }     
    Write-Host($db) 
}
Write-Host('--------------------------------------------------------------')
$databases.Add('LANSA')


Write-Host('------------------ Saving log files from source to s3 ------------------')
$RootPath = 'C:\Program Files (x86)'


try{   
    Write-Host('#DbTest results')
    foreach ($database in $databases)
    {
        $databaseRootPath = Join-Path $RootPath $database
        $dbTest = 'x_win95\x_lansa\X_WBP\Compile\DBTEST'
        $dbTestParent = Join-Path $databaseRootPath $dbTest
        $dbTestFiles = Get-ChildItem $dbTestParent -Filter *.txt
        $rootKey=''
        if($database -eq 'Lansa'){
            $rootKey = $s3BaseKey  + '/MSSQLS' + '/DBTEST' 
        }
        else{
                $rootKey = $s3BaseKey + '/' + $database + '/DBTEST' 
        }
        foreach ($f in $dbTestFiles){
            $file = $f.FullName
            $key = Join-Path $rootKey $f
            Write-Host('Root: ' + $database)
            Write-Host('Log File: ' + $file)
            Write-Host('Key: ' + $key)
            Write-S3Object -BucketName $s3BasePath -Key $key -File $file | Out-Default | Write-Host
        }
    }
}
catch{
    Write-Host "Message: [$($_.Exception.Message)]" -ForegroundColor Yellow
}
Write-Host('--------------------------------------------------------------')


try{
    Write-Host('#test log files')
    Write-Host('#x_err.log')
    Write-Host('--------------------------------------------------------------')
    $xErrLogPath = '\tmp\x_err.log'
    foreach ($database in $databases)
    {
        $databaseRootPath = Join-Path $RootPath $database
        $xErrLogfile = Join-Path $databaseRootPath $xErrLogPath
        $key=''
        if($database -eq 'Lansa'){
            $key = $s3BaseKey  + '/MSSQLS/x_err.log'
        }
        else{
                $key = $s3BaseKey + '/' + $database + 'tmp/x_err.log'
        }
        Write-Host(' Root: ' + $database)
        Write-Host('Log File: ' + $xErrLogfile)
        Write-Host('Key: ' + $key)
        Write-S3Object -BucketName $s3BasePath -Key $key -File $xErrLogfile -Region $region | Out-Default | Write-Host
    }
}
catch{
    Write-Host "Message: [$($_.Exception.Message)]" -ForegroundColor Yellow
}
Write-Host('--------------------------------------------------------------')


Write-Host('#Verifier_Test_Report.txt')
Write-Host('--------------------------------------------------------------')
try{
    $verifierTestReport  = 'Verifier_Test_Report.txt'
    foreach ($database in $databases)
    {
        $databaseRootPath = Join-Path $RootPath $database
        $verifierTestReportFile = Join-Path $databaseRootPath $verifierTestReport
        $key=''
        if($database -eq 'Lansa'){
            $key = $s3BaseKey  + '/MSSQLS/Verifier_Test_Report.txt'
        }
        else{
                $key = $s3BaseKey + '/' + $database + '/Verifier_Test_Report.txt'
        }
        Write-Host('Root: ' + $database)
        Write-Host('Log File: ' + $verifierTestReportFile)
        Write-Host('Key: ' + $key)
        Write-S3Object -BucketName $s3BasePath -Key $key -File $verifierTestReportFile -Region $region | Out-Default | Write-Host
        
    }
}
catch{
    Write-Host "Message: [$($_.Exception.Message)]" -ForegroundColor Yellow
}
Write-Host('--------------------------------------------------------------')



try{   
    Write-Host('#Verifier_Test_Summary.txt')
    Write-Host('--------------------------------------------------------------')
    $verifierTestSummary = 'Verifier_Test_Summary.txt'
    foreach ($database in $databases)
    {
        $databaseRootPath = Join-Path $RootPath $database
        $verifierTestSummaryFile = Join-Path $databaseRootPath $verifierTestSummary
        $key=''
        if($database -eq 'Lansa'){
            $key = $s3BaseKey  + '/MSSQLS/Verifier_Test_Summary.txt'
        }
        else{
                $key = $s3BaseKey + '/' + $database + '/Verifier_Test_Summary.txt'
        }
        Write-Host('Root: ' + $database)
        Write-Host('Log File: ' + $verifierTestSummaryFile)
        Write-Host('Key: ' + $key)
        Write-S3Object -BucketName $s3BasePath -Key $key -File $verifierTestSummaryFile -Region $region | Out-Default | Write-Host
    }
}
catch{
    Write-Host "Message: [$($_.Exception.Message)]" -ForegroundColor Yellow
}
Write-Host('--------------------------------------------------------------')


try{   
    Write-Host('#Detailed compile results')
    foreach ($database in $databases)
    {
        $databaseRootPath = Join-Path $RootPath $database
        $detailedResult = 'lansa/lansa/' + $database
        $detailedResultParent = Join-Path $databaseRootPath $detailedResult
        $detailedResultFiles = Get-ChildItem $detailedResultParent -Filter *.txt
        $rootKey=''
        if($database -eq 'Lansa'){
            $rootKey = $s3BaseKey  + '/MSSQLS' + '/CompileDetails'
        }
        else{
                $rootKey = $s3BaseKey + '/' + $database + '/CompileDetails'
        }
        foreach ($f in $detailedResultFiles){
            $file = $f.FullName
            $key = Join-Path $rootKey $f
            Write-Host('Root: ' + $database)
            Write-Host('Log File: ' + $file)
            Write-Host('Key: ' + $key)
            Write-S3Object -BucketName $s3BasePath -Key $key -File $file | Out-Default | Write-Host
        }
    }
}
catch{
    Write-Host "Message: [$($_.Exception.Message)]" -ForegroundColor Yellow
}
Write-Host('--------------------------------------------------------------')
    



try{
    Write-Host('#Total Summary for all Dbs')
    Write-Host('--------------------------------------------------------------')
    $totalSummaryFile='C:\Program Files (x86)\Lansa\Verifier_Total_Summary.txt'
    $totalSummaryKey= $s3BaseKey + '/MSSQLS/Verifier_Total_Summary.txt'

    Write-Host('Log File: ' + $totalSummaryFile)
    Write-Host('Key: ' + $totalSummaryKey)
    Write-S3Object -BucketName $s3BasePath -Key $totalSummaryKey -File $totalSummaryFile | Out-Default | Write-Host
    
}
catch{
    Write-Host "Message: [$($_.Exception.Message)]" -ForegroundColor Yellow
}
Write-Host('--------------------------------------------------------------')
  
 
 

