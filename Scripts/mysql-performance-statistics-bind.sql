-- Execute query to see the performance statistics using bind variables.

USE `LANSA`;
DROP procedure IF EXISTS `LANSA`.`sp_mysql_performanceStatistics_bind`;
;

DELIMITER $$
USE `LANSA`$$
CREATE  PROCEDURE `sp_mysql_performanceStatistics_bind`()
BEGIN

declare rowCount int;
DECLARE l_description VARCHAR(1000);
DECLARE l_start varchar(50);
DECLARE l_sqlQuery VARCHAR(1024);

SET  @rowCount = 1;
SET l_start = now(3);
WHILE @rowCount <= 1000 Do
	BEGIN
		SELECT F157033K1 INTO @l_description FROM LANSA.VWBPLIBF_VTLI0049 Where F157033K2 = @rowCount LIMIT 1; 
        SET  @rowCount = @rowCount+1;
	END;
END WHILE;

SELECT concat('MYSQL, Bind, ' , TRUNCATE(TIMESTAMPDIFF(microsecond, l_start, now(3))/1000,0)) as Elapsedtime;
END$$

DELIMITER ;
;

CALL sp_mysql_performanceStatistics_bind();