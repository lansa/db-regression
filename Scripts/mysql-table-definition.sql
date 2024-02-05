USE `LANSA`;

CREATE TABLE `VTLI0036D`(
	`V_ID` int NOT NULL,
	`V_NAME` nvarchar(50) NULL,
	`V_SURNAME` char(10) NULL,
	`V_LASTNAME` nchar(10) NULL,
	`V_DATE` datetime(3) NULL,
	`V_SALARY` Double NULL,
	`V_ACTIVE` Tinyint NULL,
	`V_DESC` Longtext NULL,
	`V_TAG` Char(36) NULL,
	`V_TIME` time(6) NULL,
	`V_RAWDATA` binary(50) NULL,
	`V_DATA` varchar(50) NULL,
	`V_CODE` numeric(18, 0) NULL,
	`V_XML` Longtext NULL,
 CONSTRAINT `PK_VTLI0036D` PRIMARY KEY 
(
	`V_ID` ASC
) 
) ;

