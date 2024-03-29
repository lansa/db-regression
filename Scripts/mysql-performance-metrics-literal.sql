-- Execute query to see the performance statistics using literal variables.

USE `LANSA`;
DROP procedure IF EXISTS `LANSA`.`sp_mysql_performanceStatistics_literal`;
;

DELIMITER $$
USE `LANSA`$$
CREATE  PROCEDURE `sp_mysql_performanceStatistics_literal`()
BEGIN

declare rowCount int;
DECLARE l_description VARCHAR(1000);
DECLARE l_start varchar(50);
DECLARE l_sqlQuery VARCHAR(1024);

SET  @rowCount = 1;
SET l_start = now(3);
WHILE @rowCount <= 1000 Do
	BEGIN		  
        SET @l_sqlQuery =CONCAT('SELECT F157033K1 INTO @l_description FROM LANSA.VWBPLIBF_VTLI0049 Where F157033K2=', @rowCount,' limit 1');
        PREPARE statement FROM @l_sqlQuery;
        EXECUTE statement;
		DEALLOCATE PREPARE statement;
         
        SET @rowCount = @rowCount + 1;
	END;
END WHILE;

SELECT concat('MYSQL, Literal, ' , TRUNCATE(TIMESTAMPDIFF(microsecond, l_start, now(3))/1000,0)) as Elapsedtime;
END$$

DELIMITER ;
;

CALL sp_mysql_performanceStatistics_literal();