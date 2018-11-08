DECLARE @messageData XML

SELECT @messageData =
	( 
	SELECT DISTINCT
	'badorder' as OrderID
	FOR XML PATH('row'), ROOT('data')
	)


DECLARE @InitDlgHandle UNIQUEIDENTIFIER
											
BEGIN DIALOG @InitDlgHandle
	FROM SERVICE [MonologueSenderService]
	TO SERVICE N'OrderRollupService', 'CURRENT DATABASE'
	ON CONTRACT [OrderRollupContract]
	WITH ENCRYPTION = OFF;

SEND ON CONVERSATION @InitDlgHandle
	MESSAGE TYPE [OrderIDMsg]
	(@messageData);		


Select * from sys.service_queues


