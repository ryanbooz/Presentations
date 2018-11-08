USE [WideWorldImporters]
GO

RAISERROR ('Did you mean to run the whole thing?', 20, 1) WITH LOG;
GO

/*
	First things first, in a real system, we want to be able to track errors
	as they happen. This gives us a place to see that a message caused a processing
	error somewhere, but allows us to get the message off of the queue.
*/

CREATE TABLE [Application].[SBErrorLog](
	[errorID] [int] IDENTITY(1,1) NOT NULL,
	[errorDate] [datetime] NOT NULL,
	[service_contract_name] [sysname] NOT NULL,
	[errorCode] [int] NOT NULL,
	[errorDescription] [varchar](4000) NULL,
 CONSTRAINT [PKC_SBErrorLog_ErrorID] PRIMARY KEY CLUSTERED 
  (
	[errorID] ASC
  )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [Application].[SBErrorLog] ADD  CONSTRAINT [DF_SBErrorLog_errorDate]  DEFAULT (getdate()) FOR [errorDate]
GO


/*
  Let's create SPROCs to processes these messages instead
*/

/* 
    This is the SPROC that will take one message off of the queue at a time (XML) and 
	pass it to another SPROC to process the staging tables for objects effected by modifying
	this bill in some way.
*/
CREATE OR ALTER PROCEDURE [Application].[SBActivated_OrderRollupQueue]
AS
BEGIN
	SET NOCOUNT ON;
		DECLARE @conversation_handle UNIQUEIDENTIFIER;
		DECLARE @message_body XML;
		DECLARE @message_type_name sysname;

		/*
		  Always put receptions in a Try/Catch. Remember, if there's an error,
		  this gives you a way to clean up
		*/
		BEGIN TRY

		-- Put this in a transaction. If something fails it can be returned to the queue.
		BEGIN TRANSACTION;
			waitfor (                
					RECEIVE TOP(1) 
						@conversation_handle = conversation_handle,
						@message_body = message_body,
						@message_type_name = message_type_name
						FROM OrderRollupQueue
				), TIMEOUT 5000;

			IF (@conversation_handle IS NOT NULL)
			BEGIN
				IF (@message_type_name = N'OrderIDMsg')
				BEGIN
					DECLARE @OrderID INT = COALESCE((SELECT @message_body.value('(//row/OrderID)[1]', 'INT')),NULL);
					--PRINT @OrderID;
					EXEC Sales.DoOrderRollup @OrderID;
				END

				END CONVERSATION @conversation_handle;

			END
			COMMIT;
		END TRY
		BEGIN CATCH

			DECLARE @XACT_STATE INT = XACT_STATE();
			DECLARE @error INT, @message NVARCHAR(3000);
			SELECT @error = ERROR_NUMBER(), @message = @message_type_name + ' | ' + CAST(CAST(@message_body as XML) as varchar(2000)) + ' | ' + ERROR_MESSAGE();
			END CONVERSATION @conversation_handle WITH error = @error DESCRIPTION = @message;
			
			IF (@XACT_STATE = -1)
			BEGIN
				IF (@@TRANCOUNT > 0)
				BEGIN
					ROLLBACK TRANSACTION;
				END;
			END;

			IF (@XACT_STATE = 1)
			BEGIN
				IF (@@TRANCOUNT > 0)
				BEGIN 
					COMMIT TRANSACTION SavePoint1;
				END;
			END		

		END CATCH;

END
GO


/* 
   Create the SPROC that will close out the conversation
   when the target queue ends the conversation
*/
CREATE OR ALTER PROCEDURE [Application].[SBActivated_MonologueSenderQueue]
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE
		@service_contract_name sysname,
		@message_type_name sysname,
		@message_body VARBINARY(max),
		@conversation_handle UNIQUEIDENTIFIER,
		@errorXML XML;

		BEGIN TRY 

		-- Put this in a transaction. If something fails it can be returned to the queue.
		BEGIN TRANSACTION;

			waitfor (                
                RECEIVE TOP(1) 
					@service_contract_name = service_contract_name,
                    @conversation_handle = conversation_handle,
                    @message_body = message_body,
                    @message_type_name = message_type_name
                    FROM MonologueSenderQueue
            ), TIMEOUT 5000;

			IF (@conversation_handle is not null)
			BEGIN

				IF (@message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog')
				BEGIN
					END CONVERSATION @conversation_handle;
				END

				/*
				  If one of the other activated SPROCs returned an error, it will be logged into our table
				  so that we can look at it over time.  

				  The logging table currently has the "event date" in local time as DATETIME.
				*/
				ELSE IF (@message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/Error')
				BEGIN				
					SET @errorXML = CAST(@message_body as XML);
					DECLARE @Code INT, @Description NVARCHAR(3000);
				
					WITH XMLNAMESPACES(N'http://schemas.microsoft.com/SQL/ServiceBroker/Error' AS ns)
					select @Code=(SELECT @errorXML.value('(/ns:Error/ns:Code)[1]','int')),
						@Description=(SELECT @errorXML.value('(/ns:Error/ns:Description)[1]','nvarchar(3000)'));

					INSERT INTO [Application].[SBErrorLog] (service_contract_name, errorCode, errorDescription) VALUES (@service_contract_name, @Code, @Description);

					END CONVERSATION @conversation_handle;

				END
			END;
			-- This goes outside of the BEGIN/END so that even an "empty" transaction can get committed
			COMMIT;
		END TRY
		BEGIN CATCH
			-- If for some reason either of the above failed, log it so that we have the message body with a unique errorCode and then commit (remove) the message from the queue.
			
			--Test whether the transaction is uncommittable.
            if (XACT_STATE()) = -1
            BEGIN
                  rollback transaction;
            END
 
            -- Test wether the transaction is active and valid.
            if (XACT_STATE()) = 1
            BEGIN
				SET @errorXML = CAST(@message_body as XML);
				DECLARE @errorText NVARCHAR(3000) = CAST(@errorXML AS NVARCHAR(3000));

				/*
				  For future reference.  Simple table to store returned error
				*/
				INSERT INTO [Application].[SBErrorLog] (service_contract_name, errorCode, errorDescription) VALUES (@service_contract_name, -999, @errorText);

				/*
				   Because this is a monologue, we end the conversation here anyway, having logged the error above. In the future,
				   this could be extended to do more conversation or creating a better message back to the queue to do more work.
				*/
				END CONVERSATION @conversation_handle;
			    COMMIT;
            END
		END CATCH;
END;
GO



/*

 This is the initiator queue. When using SSB as a pure Monologue queue, somebody
 needs to be responsible for closing out the conversations and handling any errors
*/
CREATE QUEUE [MonologueSenderQueue] WITH
		 STATUS = ON,
		 RETENTION = OFF,
		 ACTIVATION ( PROCEDURE_NAME = [Application].[SBActivated_MonologueSenderQueue],
					  MAX_QUEUE_READERS = 10,
					  EXECUTE AS OWNER,
					  STATUS = OFF
					  ),
	     POISON_MESSAGE_HANDLING (STATUS = ON)  ON [PRIMARY] 
GO

/*
  Minimally we need a service on a queue.  Messages are sent to a queue through
  a service (remember, they're the "traffic cop")
*/
CREATE SERVICE [MonologueSenderService] ON QUEUE [MonologueSenderQueue]
GO

/*
  Our first destination queue
*/
CREATE QUEUE [OrderRollupQueue] WITH 
		STATUS = ON,
		RETENTION = OFF,
		 ACTIVATION ( PROCEDURE_NAME = [Application].[SBActivated_OrderRollupQueue],
					  MAX_QUEUE_READERS = 1,
					  EXECUTE AS OWNER,
					  STATUS = OFF
					  ),

		POISON_MESSAGE_HANDLING (STATUS = ON)  ON [PRIMARY] 
GO

/*
  Getting a little fancy and creating a message type so that we can respond
  to a specific kind of message.
*/
CREATE MESSAGE TYPE [OrderIDMsg] VALIDATION = WELL_FORMED_XML;
GO

/*
  If you have a message type, the contract makes sure everyone is sending the
  correct type of message to the queue
*/
CREATE CONTRACT [OrderRollupContract] ([OrderIDMsg] SENT BY INITIATOR);
GO

/*
  Again, everyone needs their traffic cop
*/
CREATE SERVICE [OrderRollupService] ON QUEUE [OrderRollupQueue] ([OrderRollupContract])
GO

/*
	Check that things are empty.
*/

SELECT *, CAST(message_body AS XML) FROM [OrderRollupQueue] WITH (NOLOCK)
SELECT *, CAST(message_body AS XML) FROM MonologueSenderQueue WITH (NOLOCK)
SELECT * FROM sys.[conversation_endpoints] WITH (NOLOCK)

EXEC [Application].[SBActivated_OrderRollupQueue]

/*

  NOW RUN THE ORDER IMPORTER!  LET'S SEE WHAT HAPPENS!

  select count(*) from sales.orders

*/

/*
  Check the Queues!
*/
SELECT *, CAST(message_body AS XML) FROM [OrderRollupQueue] WITH (NOLOCK)
SELECT *, CAST(message_body AS XML) FROM MonologueSenderQueue WITH (NOLOCK)
SELECT * FROM sys.[conversation_endpoints] WITH (NOLOCK)

EXEC [Application].[SBActivated_OrderRollupQueue]

/*
  Alter the database to set the activation in motion
*/

SELECT COUNT(*) from [Sales].[SalesRollup]

ALTER QUEUE MonologueSenderQueue WITH ACTIVATION (STATUS = ON, MAX_QUEUE_READERS = 1)
ALTER QUEUE OrderRollupQueue WITH ACTIVATION (STATUS = ON, MAX_QUEUE_READERS = 1)

SELECT COUNT(*) from [Sales].[SalesRollup]

/*
  Clean everything up for next demo

  Drop everything to get recreated
*/

/* 
    The first part of this script allows it to be Idempotent, simply removing objects if they
    currently exist and then adding the pieces back in.  If the objects are not there, we
    simply create the services and start the Queues rolling.

*/
IF EXISTS (SELECT * FROM sys.services WHERE name = N'MonologueSenderService')
     DROP SERVICE [MonologueSenderService];

/* 
    The Intermeditate Queue is for processing Trigger messages that may contain many rows
    from the action on a table.  It then parses those rows into separate messages for another 
    Queue to processes
*/
IF EXISTS (SELECT * FROM sys.services WHERE name = N'OrderRollupService')
     DROP SERVICE [OrderRollupService];

IF EXISTS (SELECT * FROM sys.service_contracts WHERE name = N'OrderRollupContract')
     DROP CONTRACT [OrderRollupContract];

IF EXISTS (SELECT * FROM sys.service_message_types WHERE name = N'OrderIDMsg') 
	DROP MESSAGE TYPE [OrderIDMsg];


IF EXISTS (SELECT * FROM sys.service_queues WHERE name = N'MonologueSenderQueue')
     DROP QUEUE [MonologueSenderQueue];

IF EXISTS (SELECT * FROM sys.service_queues WHERE name = N'OrderRollupQueue')
     DROP QUEUE [OrderRollupQueue];

IF OBJECT_ID('Application.SBActivated_MonologueSenderQueue','P') IS NOT NULL
	DROP PROCEDURE [Application].[SBActivated_MonologueSenderQueue]
GO

IF OBJECT_ID('Application.SBActivated_OrderRollupQueue','P') IS NOT NULL
	DROP PROCEDURE [Application].[SBActivated_OrderRollupQueue]
GO