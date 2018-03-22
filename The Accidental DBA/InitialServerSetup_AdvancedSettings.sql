USE master
GO

/*
  Default to 8 as that is the maximum recommended by Microsoft

  https://support.microsoft.com/en-us/help/2806535/recommendations-and-guidelines-for-the-max-degree-of-parallelism-confi

*/
DECLARE @maxDegOfParallelism VARCHAR(1) = '8';
DECLARE @numberOfProcessors INT;

/*
  Get the number of cores and set the value based on that.  
*/
SELECT @numberOfProcessors = COUNT(*) FROM sys.dm_os_schedulers WHERE scheduler_id < 255; 

IF(@numberOfProcessors <= 4)
BEGIN 
	SET @maxDegOfParallelism = '2';
END
ELSE IF(@numberOfProcessors > 4 AND @numberOfProcessors <= 6)
BEGIN 
	SET @maxDegOfParallelism = '4';
END
ELSE IF(@numberOfProcessors > 6 AND @numberOfProcessors <=8)
BEGIN
	SET @maxDegOfParallelism = '6';
END

-- Show advanced settings so that we can update them via code
EXEC sp_configure 'show advanced option', '1';
RECONFIGURE

-- If you workload is generally OLTP/single use plans,
-- this can prevent some potential cache bloat
EXEC sp_configure 'optimize for ad hoc workloads', '1';
RECONFIGURE

-- 50 is a recommended starting point. Examine cached
-- plans or Query Store to pinpoint more in your environment
EXEC sp_configure 'cost threshold for parallelism', '50';
RECONFIGURE

-- If you are setting TRACE flags through a startup SPROC
-- this is necessary
EXEC sp_configure 'scan for startup procs', '1';
RECONFIGURE

-- Set the max degree of parallelism based on calculation above
EXEC sp_configure 'max degree of parallelism', @maxDegOfParallelism;
RECONFIGURE

-- Turn off advanced options for consistency
EXEC sp_configure 'show advanced option', '0';
RECONFIGURE

