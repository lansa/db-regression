-- Execute query to see the performance statistics using bind variables.
   
BEGIN
    DECLARE rowCount INT = 1;
    DECLARE l_description varchar(1000);
    DECLARE l_start DATETIME = GETDATE();  
    
    SET rowCount =1;   
   
  WHILE rowCount <= 1000 Loop
     
	BEGIN
		DECLARE l_rc Cursor FOR SELECT F157033K1 into l_description FROM VWBPLIBF.VTLI0049 Where F157033K2 = rowCount;
		open l_rc;
		fetch l_rc into l_description;
		close l_rc;
	END;
  
    set rowCount = rowCount + 1;
  END LOOP;

  MESSAGE 'SQLANYWHERE, Bind, ' + convert(varchar(50), DATEDIFF(ms, l_start, GETDATE())) + ', milliseconds' TYPE INFO TO CLIENT;
END