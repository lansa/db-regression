-- Add user PCXUSER2 as db_owner of the LANSA database.
-- This is required each time a new VM is created because the HOSTNAME changes.
-- Note: Variables cannot be used in DDL statments.
-- Instead, a string needs to be constructed containing the DDL and into which the variable may be concatenated.
-- Then the string is executed as an SQL script.
-- To aid debugging the script to be executed is first printed
USE [LANSA]
DECLARE @UserName AS VARCHAR(100)=HOST_NAME() + '\PCXUSER2'
Declare @sstr nvarchar(500)
print @UserName

IF NOT EXISTS
	(SELECT name
	 FROM master.sys.server_principals
	 WHERE name = @UserName)
BEGIN
	set @sstr = 'create login ' + QUOTENAME(@UserName) + ' from windows'
	print @sstr
	Exec sp_executesql @sstr
END
ELSE PRINT QUOTENAME(@UserName) + ' login exists in server ' + HOST_NAME()

set @sstr = 'ALTER SERVER ROLE [sysadmin] ADD MEMBER ' + QUOTENAME(@UserName)
print @sstr
Exec sp_executesql @sstr

IF NOT EXISTS
	(SELECT name
	 FROM sys.database_principals
	 WHERE name = @UserName)
BEGIN
	set @sstr = 'CREATE USER ' + QUOTENAME(@UserName) + ' FOR LOGIN ' + QUOTENAME(@UserName)
	print @sstr
	Exec sp_executesql @sstr
END
ELSE PRINT QUOTENAME(@UserName) + ' user exists in lansa database'


set @sstr = 'ALTER ROLE [db_owner] ADD MEMBER ' + QUOTENAME(@UserName)
print @sstr
Exec sp_executesql @sstr
