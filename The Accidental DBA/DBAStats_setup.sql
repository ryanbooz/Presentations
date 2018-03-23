USE master
GO

/*********************************************************************************************
DBAStats_setup.sql
(C) 2018, Ryan Booz

Feedback: mailto:ryan@softwareandbooz.com

Purpose:
This script is part of a DB checklist, creating a consistent database on each managed server
to collect data as we see fit to help with troubleshooting and over system performance. In
it's current form, the script does three things:

  1. Create the DBA_Stats database if it doesn't exist
  2. Create two tables for holding output from sp_WhoIsActive from Adam Machanic
  3. Creates two stored procedures in the DBA_Stats database to facilitate alerting of
     long running queries

These three pieces could be split out into separate scripts.

Portions of the initial script were created following tutorials from Kendra Little and
Tara Kizer. A complete rundown of this particular solution can be found at:

https://www.softwareandbooz.com/long-running-query-alerts-with-sp_whoisactive/

*********************************************************************************************/


SET NOCOUNT ON;
DECLARE @retention int = 7, 
		@destination_table VARCHAR(100) = 'WhoIsActiveLogging', 
		@longrunning_table VARCHAR(100) = 'LongRunningQueries', 
		@destination_database sysname = 'DBA_stats', 
		@schema VARCHAR(max), 
		@dynSQL NVARCHAR(4000), 
		@createSQL NVARCHAR(500),
		@alterSQL NVARCHAR(2000),
		@parameters NVARCHAR(500),
		@exists bit;

SET @destination_table = @destination_database + '.dbo.' + @destination_table;
SET @longrunning_table = @destination_database + '.dbo.' + @longrunning_table;


If(DB_ID(@destination_database) IS NULL)
BEGIN;
	PRINT 'Creating stats database: ' + @destination_database;
	SET @createSQL = N'CREATE DATABASE ' + @destination_database + '; ALTER DATABASE ' + @destination_database + ' SET RECOVERY SIMPLE;';
	EXEC(@createSQL);
END;

-- Create the main logging table to capture periodic runs of sp_WhoIsActive output
-- Set it to simple recovery. We will be deleting out of it every few days
IF OBJECT_ID(@destination_table) IS NULL
BEGIN;
	PRINT 'Creating periodic logging table: ' + @destination_table;
	-- This returns the schema for the table to store data only.
	EXEC sp_WhoIsActive  @get_transaction_info = 1,  @get_outer_command = 1,  @get_plans = 1,  @format_output=0, @return_schema = 1,  @schema = @schema OUTPUT;
	SET @schema = REPLACE(@schema, '<table_name>', @destination_table);  
	EXEC(@schema);

  --create index on collection_time
	SET @dynSQL = 'CREATE CLUSTERED INDEX CX_Collection_Time ON ' + @destination_table + '(collection_time ASC)';
	EXEC (@dynSQL);
END;

--create the long-running query table
IF OBJECT_ID(@longrunning_table) IS NULL
BEGIN;

  PRINT 'Creating long-running queries table: ' + @longrunning_table;
  -- Createing the same table, this time for storing long-running query information
  EXEC sp_WhoIsActive  @get_transaction_info = 1,  @get_outer_command = 1,  @get_plans = 1,  @format_output=0, @return_schema = 1,  @schema = @schema OUTPUT;
  SET @schema = REPLACE(@schema, '<table_name>', @longrunning_table);  
  EXEC(@schema);

  -- Add additional columns to the table to assist in email tracking and
  -- a unique primary key aside from the session_id which can obviously
  -- be reused
  SET @alterSQL = N'
	ALTER TABLE '+ @longrunning_table + ' ADD
		id INT IDENTITY CONSTRAINT PKC_ID PRIMARY KEY CLUSTERED,
		email_sent BIT  CONSTRAINT DF_email_sent DEFAULT 0,
		email_time DATETIME NULL,
		email2_sent BIT CONSTRAINT DF_email2_sent DEFAULT 0,
		email2_time DATETIME NULL;
		

	CREATE NONCLUSTERED INDEX IX_SessionID_LoginName_DatabaseName_StartTime ON '+ @longrunning_table +' (session_id, login_name, database_name,start_time);
	';

  EXEC(@alterSQL);
END;

/*

	Now switch to the newly created database and create two stored procedures in it. The first
	is to allow for HTML formatting of the long running queries if we need to be alerted. The 
	second PROC is what is scheduled to run every minute and check for long-running queries to
	be alerted on.

*/
USE DBA_Stats
GO

IF OBJECT_ID('QueryToHtmlTable','P') IS NULL
	EXEC ('CREATE PROC QueryToHtmlTable AS SELECT ''stub version, to be replaced''') 
GO
/*
 This SPROC is taken from this Stack Overflow answer with minimal modifications
 to add CSS for some basic formatting

 https://stackoverflow.com/a/29708178/9222525

 Description: Turns a query into a formatted HTML table. Useful for emails. 
 Any ORDER BY clause needs to be passed in the separate ORDER BY parameter.
 =============================================
*/
PRINT 'Altering Stored Procedure QueryToHtmlTable';
GO

ALTER PROC QueryToHtmlTable
(
  @query NVARCHAR(MAX), --A query to turn into HTML format. It should not include an ORDER BY clause.
  @orderBy NVARCHAR(MAX) = NULL, --An optional ORDER BY clause. It should contain the words 'ORDER BY'.
  @html NVARCHAR(MAX) = NULL OUTPUT --The HTML output of the procedure.
)
AS
BEGIN   
  SET NOCOUNT ON;

  IF @orderBy IS NULL BEGIN
    SET @orderBy = ''  
  END

  SET @orderBy = REPLACE(@orderBy, '''', '''''');

  DECLARE @htmlQuery NVARCHAR(MAX) = '
    DECLARE @headerRow NVARCHAR(MAX);
    DECLARE @cols NVARCHAR(MAX);    

    SELECT * INTO #tableSQL FROM (' + @query + ') sub;

    SELECT @cols = COALESCE(@cols + '', '''''''', '', '''') + ''['' + name + ''] AS ''''td''''''
    FROM tempdb.sys.columns 
    WHERE object_id = object_id(''tempdb..#tableSQL'')
    ORDER BY column_id;

    SET @cols = ''SET @html = CAST(( SELECT '' + @cols + '' FROM #tableSQL ' + @orderBy + ' FOR XML PATH(''''tr''''), ELEMENTS XSINIL) AS NVARCHAR(max))''    

    EXEC sys.sp_executesql @cols, N''@html NVARCHAR(MAX) OUTPUT'', @html=@html OUTPUT

    SELECT @headerRow = COALESCE(@headerRow + '''', '''') + ''<th>'' + name + ''</th>'' 
    FROM tempdb.sys.columns 
    WHERE object_id = object_id(''tempdb..#tableSQL'')
    ORDER BY column_id;

    SET @headerRow = ''<tr>'' + @headerRow + ''</tr>'';

    SET @html = ''<html>
		<head>
			<style type="text/css">
				table {  
					color: #333;
					font-family: Helvetica, Arial, sans-serif;
					width: 2000px; 
					border-collapse: 
					collapse; border-spacing: 0; 
				}

				td, th {  
					border: 1px solid transparent; /* No more visible border */
					height: 30px; 
				}

				th {  
					background: #DFDFDF;  /* Darken header a bit */
					font-weight: bold;
				}

				td {  
					background: #FAFAFA;
					text-align: center;
				}

				/* Cells in even rows (2,4,6...) are one color */        
				tr:nth-child(even) td { background: #F1F1F1; }   

				/* Cells in odd rows (1,3,5...) are another (excludes header cells)  */        
				tr:nth-child(odd) td { background: #FEFEFE; } 
			</style>
		</head>
		<body>
			<table width="2000" border="1">'' + @headerRow + @html + ''</table>
		</body>
		</html>'';    
    ';

  EXEC sp_executesql @htmlQuery, N'@html NVARCHAR(MAX) OUTPUT', @html=@html OUTPUT;
END;
GO


/*

	This PROC is what checks to see if there are long-running processes (specified as parameters)
	and alerts the given email(s).

*/
IF OBJECT_ID('LongRunningQueriesAlert','P') IS NULL
	EXEC ('CREATE PROC LongRunningQueriesAlert AS SELECT ''stub version, to be replaced''') 
GO

PRINT 'ALTER Stored Procedure: LongRunningQueriesAlert';
GO

ALTER PROCEDURE [LongRunningQueriesAlert]
	@email_Subject VARCHAR(255) = 'Long-Running Queries on ',
	@low_threshold_min VARCHAR(2) = '5',
	@high_threshold_min VARCHAR(2) = '30',
	@dbmail_profile VARCHAR(128) = 'DB Alerts',
	@email_recipients VARCHAR(500) = 'email@example.com'
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @server_name VARCHAR(255),
			@schema NVARCHAR(4000),
			@dynSQL NVARCHAR(4000),
			@lrq_table VARCHAR(255),
			@html NVARCHAR(MAX),
			@low_threshold_subject VARCHAR(255),
			@high_threshold_subject VARCHAR(255);

	SET @server_name = @@SERVERNAME;
	SET @email_Subject = @email_Subject + @server_name;


	/*
		Setting this to a global temp table so that it's available to the SELECT after it is
		created and we insert data.

		Depending on how long this runs (which should be almost instant) and how often, setting
		this equal to the server name could cause a conflict if two processes run close together.

		We only run this once a minute and tear down the table when we're done, so using the
		server_name to make this temp table unique is acceptable risk for me ATM. Technically the
		server_name isn't even needed.  Adjust as you see fit.

	*/ 
	SET @lrq_table = QUOTENAME('##LongRunningQueries_' + @server_name);

	-- create the logging temp table as we've done previously. First get the schema and create the table
	-- then execute the returned SQL to create the temp table
	IF OBJECT_ID(@lrq_table) IS NULL
	BEGIN;
		EXEC sp_WhoIsActive  @get_transaction_info = 1,
			@get_outer_command = 1,
			@get_plans = 1,  
			@format_output=0, -- Don't format output so that it works in an email
			@return_schema = 1, 
			@schema = @schema OUTPUT;

		SET @schema = REPLACE(@schema, '<table_name>', @lrq_table);  
		EXEC(@schema);
	END;


	-- Run WhoIsActive again and put results into the table
	EXEC sp_WhoIsActive @get_transaction_info = 1,  
		@get_outer_command = 1,  
		@get_plans = 1, 
		@format_output=0, 
		@destination_table = @lrq_table, 
		@not_filter = 'PITTPROCWIN01', @not_filter_type = 'host'; 


	/*
	   Insert any new long-running queries that haven't existed before

	   The WHERE clause below is very specific at the moment and not very flexible.
	   Improvements to what we ignore and how we specify it are needed.

	*/
	SET @dynSQL = N'
		INSERT INTO LongRunningQueries ([session_id], [sql_text], [sql_command], [login_name], [wait_info], [tran_log_writes], [CPU], 
			[tempdb_allocations], [tempdb_current], [blocking_session_id], [reads], [writes], [physical_reads], [query_plan], [used_memory], [status], 
			[tran_start_time], [open_tran_count], [percent_complete], [host_name], [database_name], [program_name], [start_time], [login_time], 
			[request_id], [collection_time])
		SELECT tempLRQ.* FROM ' + @lrq_table + N' tempLRQ
			LEFT JOIN LongRunningQueries LRQ ON
				LRQ.session_id = tempLRQ.session_id
				AND LRQ.login_name = tempLRQ.login_name
				AND LRQ.database_name = tempLRQ.database_name
				AND LRQ.start_time = tempLRQ.start_time 
			WHERE LRQ.session_id IS NULL
			AND tempLRQ.start_time <  DATEADD(MINUTE,-' + @low_threshold_min + N',GETDATE()) 
			AND tempLRQ.database_name NOT in (''master'',''msdb'',''tempdb'',''DBA_Stats'')
			AND tempLRQ.program_name NOT LIKE ''%Service Broker%''
			AND tempLRQ.program_name <> ''SQBCoreService.exe''';

	EXEC(@dynSQL);
        

	/*
		Now send the emails for any new long-running queries
	
		Using the new SPROC, format the output as HTML for the email
	*/
	EXEC QueryToHtmlTable 
			@query = N'SELECT id, LRQ.session_id, LRQ.sql_text,LRQ.blocking_session_id, LRQ.reads, 
						LRQ.writes, LRQ.status, LRQ.host_name, LRQ.database_name, LRQ.program_name,
						LRQ.start_time FROM dbo.LongRunningQueries LRQ
						WHERE LRQ.email_sent = 0' ,       
			@orderBy = N'' ,     
			@html = @html OUTPUT; 

	
	IF(LEN(@html) > 1)
	BEGIN;
		SET @low_threshold_subject = @email_Subject + ' - >' + @low_threshold_min + ' minute(s)';
		
		-- Now send the email
		EXEC msdb.dbo.sp_send_dbmail
		   @profile_name = @dbmail_profile,
		   @recipients = @email_recipients,
		   @subject = @low_threshold_subject,
		   @attach_query_result_as_file = 0,
		   @importance = 'Normal',
		   @body = @html,
		   @body_format='html'

		/* 
			Update the table to specify that all new queries have had a notification sent
		*/
		UPDATE dbo.LongRunningQueries SET email_sent = 1, email_time = GETDATE() WHERE email_sent = 0;
	END;


	/*
	   Now get a list of queries that are still running after the second threshold time has elapsed. 
	   Someone REALLY needs to get on these.
	*/

	-- Reset the variable for reuse
	SET @html = '';

	-- Setting this here because concat in the parameter throws an error
	SET @dynSQL = N'SELECT id, LRQ.session_id, LRQ.sql_text,LRQ.blocking_session_id, LRQ.reads, 
			 			LRQ.writes, LRQ.status, LRQ.host_name, LRQ.database_name, LRQ.program_name,
						LRQ.start_time FROM dbo.LongRunningQueries LRQ
						WHERE LRQ.id in 
							(
							SELECT id FROM dbo.LongRunningQueries LRQ
							INNER JOIN ' + @lrq_table + N' tempLRQ ON LRQ.session_id = tempLRQ.session_id
								AND LRQ.login_name = tempLRQ.login_name
								AND LRQ.database_name = tempLRQ.database_name
								AND LRQ.start_time = tempLRQ.start_time 
							WHERE tempLRQ.start_time < DATEADD(MINUTE,-'+ @high_threshold_min + N',GETDATE())
								AND lrq.email2_sent = 0
							)';

	---- Using the new SPROC, format the output as HTML for the email, 
	EXEC QueryToHtmlTable
			 @query =  @dynSQL,
			@orderBy = N'' ,     
			@html = @html OUTPUT;

	IF(LEN(@html) > 1)
	BEGIN;
		SET @high_threshold_subject = @email_Subject + ' - >' + @high_threshold_min + ' minute(s)';
		---- Now send the email second email
		EXEC msdb.dbo.sp_send_dbmail
		   @profile_name = @dbmail_profile,
		   @recipients = @email_recipients,
		   @subject = @high_threshold_subject,
		   @attach_query_result_as_file = 0,
		   @importance = 'High',
		   @body = @html,
		   @body_format='html'

		/*
		   Update the table to track that a second email has been sent for a query that has
		   been running for an extended period of time
		*/
		UPDATE LongRunningQueries SET email2_sent = 1, email2_time = GETDATE() WHERE id in (select id from #HighThresholdQueries) AND email_sent = 1 AND email2_sent = 0;

	END;


	/*
	  Drop Temporary Tables
	*/
	DROP TABLE #HighThresholdQueries;

	SET @dynSQL = N'DROP TABLE ' + @lrq_table;
	EXEC(@dynSQL);

END;
GO
