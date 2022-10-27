
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




Write-Host($db)
Write-Host('')
$databases = New-Object -TypeName 'System.Collections.ArrayList';
Write-Host('list of databases:') 
Write-Host('--------------------------------------------------------------')
foreach ($db in $databaseTypes)
{
    if($db -ne 'SQL Server')
    {
        $databases.Add($db)
    }  
    Write-Host($db) 
}
Write-Host('--------------------------------------------------------------')
$databases.Add('Lansa')


Write-Host('------------------ Saving log files from source to s3 ------------------')
$RootPath = 'C:\Program Files (x86)'


try{
    Write-Host('COMPILEDOBJECTS.TXT')
    Write-Host('--------------------------------------------------------------')
    $compiledObjectspath = 'x_win95\x_lansa\X_WBP\Compile\DBTEST\CompiledObjects.txt'
    foreach ($database in $databases)
    {
        $databaseRootPath = Join-Path $RootPath $database    
        $compiledObjectsfile = Join-Path $databaseRootPath $compiledObjectspath
        $key=''
        if($database -eq 'Lansa'){
            $key = $s3BaseKey  + '/MYSQLS/CompiledObjects.txt'
        }
        else{
                $key = $s3BaseKey + '/' + $database + '/CompiledObjects.txt'
        } 
        Write-Host('Root: ' + $database)
        Write-Host('Log File: ' + $compiledObjectsfile)
        Write-Host('Key: ' + $key)
        Write-S3Object -BucketName $s3BasePath -Key $key -File $compiledObjectsfile -Region $region | Out-Default | Write-Host
        
    }
}
catch{
    Write-Host "Message: [$($_.Exception.Message)"] --ForegroundColor Yellow
}
Write-Host('--------------------------------------------------------------')


Write-Host('#FailedObjects.txt')
Write-Host('--------------------------------------------------------------')
try{
    $failedObjectsPath = 'x_win95\x_lansa\X_WBP\Compile\DBTEST\FailedObjects.txt'
    foreach ($database in $databases)
    {
        
        $databaseRootPath = Join-Path $RootPath $database
        $failedObjectsFile = Join-Path $databaseRootPath $failedObjectsPath
        $key=''
        if($database -eq 'Lansa'){
            $key = $s3BaseKey  + '/MYSQLS/FailedObjects.txt'
        }
        else{
                $key = $s3BaseKey + '/' + $database + '/FailedObjects.txt'
        } 
        Write-Host('Root: ' + $database)
        Write-Host('Log File: ' + $failedObjectsfile)
        Write-Host('Key: ' + $key)
        Write-S3Object -BucketName $s3BasePath -Key $key -File $failedObjectsfile -Region $region | Out-Default | Write-Host
    }
}
catch{
    Write-Host "Message: [$($_.Exception.Message)"] --ForegroundColor Yellow
}
Write-Host('--------------------------------------------------------------')

try{
    Write-Host('#Result.txt')
    Write-Host('--------------------------------------------------------------')
    $resultPath = 'x_win95\x_lansa\X_WBP\Compile\DBTEST\Result.txt'
    foreach ($database in $databases)
    {
        $databaseRootPath = Join-Path $RootPath $database
        $resultfile = Join-Path $databaseRootPath $resultPath
        $key=''
        if($database -eq 'Lansa'){
            $key = $s3BaseKey  + '/MYSQLS/Result.txt'
        }
        else{
                $key = $s3BaseKey + '/' + $database + '/Result.txt'
        }
        Write-Host(' Root: ' + $database)
        Write-Host('Log File: ' + $compiledObjectsfile)
        Write-Host('Key: ' + $key)
        Write-S3Object -BucketName $s3BasePath -Key $key -File $resultfile -Region $region | Out-Default | Write-Host
    }
}
catch{
    Write-Host "Message: [$($_.Exception.Message)"] --ForegroundColor Yellow
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
            $key = $s3BaseKey  + '/MYSQLS/x_err.log'
        }
        else{
                $key = $s3BaseKey + '/' + $database + '/x_err.log'
        }
        Write-Host(' Root: ' + $database)
        Write-Host('Log File: ' + $xErrLogfile)
        Write-Host('Key: ' + $key)
        Write-S3Object -BucketName $s3BasePath -Key $key -File $xErrLogfile -Region $region | Out-Default | Write-Host
    }
}
catch{
    Write-Host "Message: [$($_.Exception.Message)"] --ForegroundColor Yellow
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
            $key = $s3BaseKey  + '/MYSQLS/Verifier_Test_Report.txt'
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
    Write-Host "Message: [$($_.Exception.Message)"] --ForegroundColor Yellow
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
            $key = $s3BaseKey  + '/MYSQLS/Verifier_Test_Summary.txt'
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
    Write-Host "Message: [$($_.Exception.Message)"] --ForegroundColor Yellow
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
            $rootKey = $s3BaseKey  + '/MYSQLS/'
        }
        else{
                $rootKey = $s3BaseKey + '/' + $database 
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
    Write-Host "Message: [$($_.Exception.Message)"] --ForegroundColor Yellow
}
Write-Host('--------------------------------------------------------------')
    



try{
    Write-Host('#Total Summary for all Dbs')
    Write-Host('--------------------------------------------------------------')
    $totalSummaryFile='C:\Program Files (x86)\Lansa\Verifier_Total_Summary.txt'
    $totalSummaryKey= $s3BaseKey + '/MYSQLS/Verifier_Total_Summary.txt'

    Write-Host('Log File: ' + $totalSummaryFile)
    Write-Host('Key: ' + $totalSummaryKey)
    Write-S3Object -BucketName $s3BasePath -Key $totalSummaryKey -File $totalSummaryFile | Out-Default | Write-Host
    
}
catch{
    Write-Host "Message: [$($_.Exception.Message)"] --ForegroundColor Yellow
}
Write-Host('--------------------------------------------------------------')
  
 
 

