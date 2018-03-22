use master
GO

-- If the stored procedure doesn't exist, create a stub
-- SQL 2016 and above could use 'CREATE OR ALTER', but this is 
-- backwards compatible 
-- For more details: https://www.softwareandbooz.com/drop-create-vs-create-alter-in-sql-server/
IF OBJECT_ID('usp_StartupTraceFlagsOn', 'P') IS NULL
	EXEC ('CREATE PROC usp_StartupTraceFlagsOn AS SELECT ''stub version, to be replaced''') 
GO

ALTER PROC usp_StartupTraceFlagsOn
AS
BEGIN
	--DBCC TRACEON (1117, -1); -- file group growth happens at the same time and with the same time, specifically tempdb.  not used for us at this time.
	DBCC TRACEON (1118, -1); -- enable currency enhancements for the tempdb database. http://support.microsoft.com/default.aspx?scid=kb;en-us;328551
	--DBCC TRACEON (1204, 1222); -- capture deadlocks in the SQL Server Error Logs, two different ways
	DBCC TRACEON (3226, -1); -- stop logging successful backup informational messages in the SQL Server Error Logs
	--DBCC TRACEON (4199, -1); -- enable query optimizer fixes http://support.microsoft.com/kb/974006
	DBCC TRACEON (2371, -1); -- update statistics more frequently than the 20% threshold for larger tables
END

GRANT EXECUTE TO PUBLIC

-- Set the stored proc to run at SQL Server start-up
exec sp_procoption N'usp_StartupTraceFlagsOn', 'startup', 'on';

-- Execute the stored procedure once so that the settings
-- takes effect now. If the server restarts, the PROC is now
-- set to run on startup.
EXEC usp_StartupTraceFlagsOn;

-- Output the settings now that the PROC has been run
DBCC TRACESTATUS(-1);
