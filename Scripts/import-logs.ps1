#########powershell script to upload log files into s3 bucket###########

#s3Bucket path to save the log files
param (
    [string] $version,
    [string] $ReleaseId
)
$Lansaversion = $version
$PipelineReleaseId = $ReleaseId
$s3BasePath = 'lansa-us-east-1/db-regression-test/logs' 
$region = 'us-east-1'
 
#Total Summary for all Dbs
$totalSummaryFile = 'C:\Program Files (x86)\LANSA\Verifier_Total_Summary.txt'
$totalSummaryPath = Join-Path $Lansaversion $PipelineReleaseId
$totalSummaryKey = $totalSummaryPath + '/Verifier_Total_Summary.txt'
Write-S3Object -BucketName $s3BasePath -Key $totalSummaryKey -Content $totalSummaryFile 


################################ list of databases ################################################################
$databases = New-Object -TypeName 'System.Collections.ArrayList';
 #$databases.Add("SQL Server")
 $databases.Add("AZURESQL")
 $databases.Add("Oracle")
 $databases.Add("MySQL")
 $databases.Add("SQLANYWHERE")


############################### writing log files from source to s3 ################################################

$RootPath = 'C:\Program Files (x86)'

#compiled log files

#CompiledObjects.txt
$compiledObjectspath = 'x_win95\x_lansa\X_WBP\Compile\DBTEST\CompiledObjects.txt'
foreach ($database in $databases)
{
    
    $databaseRootPath = Join-Path $RootPath $database
	$compiledObjectsfile = Join-Path $databaseRootPath $compiledObjectspath
    $key = $totalSummaryPath + '/' + $database + '/CompiledObjects.txt'
    Write-S3Object -BucketName $s3BasePath -Key $key -Content $compiledObjectsfile -Region $region
}

#FailedObjects.txt
$failedObjectsPath = 'x_win95\x_lansa\X_WBP\Compile\DBTEST\FailedObjects.txt'
foreach ($database in $databases)
{
    
    $databaseRootPath = Join-Path $RootPath $database
	$failedObjectsFile = Join-Path $databaseRootPath $failedObjectsPath
    $key = $totalSummaryPath + '/' + $database + '/FailedObjects.txt'
    Write-S3Object -BucketName $s3BasePath -Key $key -Content $failedObjectsfile -Region $region
}

#Result.txt
$resultPath = 'x_win95\x_lansa\X_WBP\Compile\DBTEST\Result.txt'
foreach ($database in $databases)
{
    
    $databaseRootPath = Join-Path $RootPath $database
	$resultfile = Join-Path $databaseRootPath $resultPath
    $key = $totalSummaryPath + '/' + $database + '/Result.txt'
    Write-S3Object -BucketName $s3BasePath -Key $key -Content $resultfile -Region $region
}


$build = ''
$compiled = ''

#test log files
$xErrLog = '\tmp\x_err.log'
foreach ($database in $databases)
{
    
    $databaseRootPath = Join-Path $RootPath $database
	$xErrLogfile = Join-Path $databaseRootPath $xErrLogPath
    $key = $totalSummaryPath + '/' + $database + '/x_err.log'
    Write-S3Object -BucketName $s3BasePath -Key $key -Content $xErrLogfile -Region $region
}

#Verifier_Test_Report.txt
$verifierTestReport  = 'Verifier_Test_Report.txt'
foreach ($database in $databases)
{
    
    $databaseRootPath = Join-Path $RootPath $database
	$verifierTestReportFile = Join-Path $databaseRootPath $verifierTestReport
    $key = $totalSummaryPath + '/' + $database + '/Verifier_Test_Report.txt'
    Write-S3Object -BucketName $s3BasePath -Key $key -Content $verifierTestReportFile -Region $region
}


#Verifier_Test_Summary.txt
$verifierTestSummary = 'Verifier_Test_Summary.txt'
foreach ($database in $databases)
{
    
    $databaseRootPath = Join-Path $RootPath $database
	$verifierTestSummaryFile = Join-Path $databaseRootPath $verifierTestSummary
    $key = $totalSummaryPath + '/' + $database + '/Verifier_Test_Summary.txt'
    Write-S3Object -BucketName $s3BasePath -Key $key -Content $verifierTestSummaryFile -Region $region
}
 

  
 
 

