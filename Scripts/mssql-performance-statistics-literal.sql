-- Execute query to see the performance statistics with literal query.
-- This is required each time a new VM is created because the HOSTNAME changes.
-- Note: Variables cannot be used in DDL statments.
-- Instead, a string needs to be constructed containing the DDL and into which the variable may be concatenated.
-- Then the string is executed as an SQL script.
-- To aid debugging the script to be executed is first printed
USE [LANSA]
DECLARE @rowCount INT = 1;
DECLARE @l_description varchar(1000);
DECLARE @l_start DATETIME2 = GETDATE();
DECLARE @sstr nvarchar(500);

WHILE @rowCount <= 1000
BEGIN
    
    set @sstr = 'DECLARE l_rc CURSOR FOR
    SELECT [F157033K1]
    FROM [VWBPLIBF].[VTLPerformanceStats]
    WHERE [F157033K2] ='+ CAST(@rowCount AS VARCHAR(4));

	EXECUTE sp_executesql @sstr;
    OPEN l_rc;	
    FETCH NEXT FROM l_rc INTO @l_description;
    CLOSE l_rc;
    DEALLOCATE l_rc;
    set @rowCount = @rowCount + 1;
END

PRINT CONVERT(VARCHAR, DATEDIFF(MILLISECOND, @l_start, GETDATE())) + ' MilliSeconds...';


 