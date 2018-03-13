USE master
GO

/*
  Default to 8 as that is the maximum recommended by Microsoft
*/
DECLARE @maxDegOfParallelism VARCHAR(1) = '8';
DECLARE @numberOfProcessors INT;

/*
  Get the number of cores and set the value based on that.
*/
SELECT @numberOfProcessors = COUNT(*) FROM sys.dm_os_schedulers WHERE scheduler_id < 255; 

IF(@numberOfProcessors > 4 AND @numberOfProcessors <= 6)
BEGIN 
	SET @maxDegOfParallelism = '4';
END
ELSE IF(@numberOfProcessors > 6 AND @numberOfProcessors <=8)
BEGIN
	SET @maxDegOfParallelism = '6';
END

EXEC sp_configure 'show advanced option', '1';
RECONFIGURE

EXEC sp_configure 'optimize for ad hoc workloads', '1';
RECONFIGURE

EXEC sp_configure 'cost threshold for parallelism', '50';
RECONFIGURE

EXEC sp_configure 'scan for startup procs', '1';
RECONFIGURE

EXEC sp_configure 'max degree of parallelism', @maxDegOfParallelism;
RECONFIGURE

EXEC sp_configure


--EXEC sp_configure 'show advanced option', '0';
--RECONFIGURE

