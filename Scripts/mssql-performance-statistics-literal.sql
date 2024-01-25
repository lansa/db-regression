-- Execute query to see the performance statistics using literal variables.

DECLARE @rowCount INT = 1;
DECLARE @l_description varchar(1000);
DECLARE @l_start DATETIME2 = GETDATE();
DECLARE @sstr nvarchar(500);

WHILE @rowCount <= 1000
BEGIN    
    set @sstr = 'DECLARE l_rc CURSOR FOR
    SELECT [F157033K1]
    FROM [VWBPLIBF].[VTLI0049]
    WHERE [F157033K2] ='+ CAST(@rowCount AS VARCHAR(4));

	EXECUTE sp_executesql @sstr;
    OPEN l_rc;	
    FETCH NEXT FROM l_rc INTO @l_description;
    CLOSE l_rc;
    DEALLOCATE l_rc;
    set @rowCount = @rowCount + 1;
END

PRINT 'SQL Server Literal ' + CONVERT(VARCHAR, DATEDIFF(MILLISECOND, @l_start, GETDATE())) + ' MilliSeconds...';


 