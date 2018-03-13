USE [WideWorldImporters]
GO

RAISERROR ('Did you mean to run the whole thing?', 20, 1) WITH LOG;
GO

/*
  Let's setup our first SSB conversation.
*/

/*

 This is the initiator queue. When using SSB as a pure monolog queue, somebody
 needs to be responsible for closing out the conversations and handling any errors
*/
CREATE QUEUE [MonologSenderQueue]
GO

/*
  Minimally we need a service on a queue.  Messages are sent to a queue through
  a service (remember, they're the "traffic cop")
*/
CREATE SERVICE [MonologSenderService] ON QUEUE [MonologSenderQueue]
GO

/*
  Our first target queue
*/
CREATE QUEUE [HelloWorldQueue] 
GO

/*
  Getting a little fancy and creating a message type so that we can respond
  to a specific kind of message.
*/
CREATE MESSAGE TYPE [HelloWorldMsg] VALIDATION = NONE;
GO

/*
  If you have a message type, the contract makes sure everyone is sending the
  correct type of message to the queue
*/
CREATE CONTRACT [HelloWorldContract] ([HelloWorldMsg] SENT BY INITIATOR);
GO

/*
  Again, everyone needs their traffic cop
*/
CREATE SERVICE [HelloWorldService] ON QUEUE [HelloWorldQueue] ([HelloWorldContract])
GO


/*
  Let's send the first message!
*/
DECLARE @InitDlgHandle UNIQUEIDENTIFIER
											
BEGIN DIALOG @InitDlgHandle
	FROM SERVICE [MonologSenderService]
	TO SERVICE N'HelloWorldService', 'CURRENT DATABASE'
	ON CONTRACT [HelloWorldContract]
	WITH ENCRYPTION = OFF;

SEND ON CONVERSATION @InitDlgHandle
	MESSAGE TYPE [HelloWorldMsg]
	('Hello World!')

/*
  Now see the fruit of our messaging labor!

  HUH?
*/
SELECT * FROM HelloWorldQueue WITH (NOLOCK)
SELECT * FROM MonologSenderQueue WITH (NOLOCK)

/*
  Conversation_endpoints shows
*/
SELECT * FROM sys.[conversation_endpoints] WITH (NOLOCK)
SELECT * FROM sys.[transmission_queue]

/*
  If the aboce message didn't send and we see an error in the transmission queue, 
  then that means that Service Broker hasn't been enabled
*/
ALTER DATABASE [WideWorldImporters] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
ALTER DATABASE [WideWorldImporters] SET ENABLE_BROKER
ALTER DATABASE [WideWorldImporters] SET MULTI_USER

/*
  That's more like it!

*/
SELECT * FROM HelloWorldQueue WITH (NOLOCK)
SELECT * FROM MonologSenderQueue WITH (NOLOCK)

SELECT * FROM sys.[conversation_endpoints] WITH (NOLOCK)
SELECT * FROM sys.[transmission_queue]

/*
  Now we take the message off of the queue and do something with it.

  Once we've done all of our work, we either respond with a message back
  to the initiator OR we close the conversation.

  At some point we MUST close the conversation
*/

DECLARE @conversation_handle UNIQUEIDENTIFIER;
DECLARE @message_body VARBINARY(max);
DECLARE @message_type_name sysname;

-- Put this in a transaction. If something fails it can be returned to the queue.
BEGIN TRANSACTION;
	waitfor (                
        RECEIVE TOP(1) 
            @conversation_handle = conversation_handle,
            @message_body = message_body,
            @message_type_name = message_type_name
            FROM HelloWorldQueue
    ), TIMEOUT 5000;

	IF (@conversation_handle IS NOT NULL)
	BEGIN
		DECLARE @msg VARCHAR(250);
		IF (@message_type_name = N'HelloWorldMsg')
		BEGIN
			-- SELECT the message back out to return
			SELECT @msg = CAST(@message_body AS VARCHAR(250));
			PRINT @msg;
		END

		END CONVERSATION @conversation_handle;

	END
COMMIT;


/*
  Check progress.  Note that the STATE has changed on the conversation
*/
SELECT * FROM HelloWorldQueue WITH (NOLOCK)
SELECT * FROM MonologSenderQueue WITH (NOLOCK)
SELECT * FROM sys.[conversation_endpoints] WITH (NOLOCK)


/*
  And now we finish up the conversation from the sender side.

  Same process, receive the message, do something based on the type(s) and 
  eventually close the conversation.
*/
DECLARE @conversation_handle UNIQUEIDENTIFIER;
DECLARE @message_body VARBINARY(max);
DECLARE @message_type_name sysname;

-- Put this in a transaction. If something fails it can be returned to the queue.
BEGIN TRANSACTION;
	waitfor (                
        RECEIVE TOP(1) 
            @conversation_handle = conversation_handle,
            @message_body = message_body,
            @message_type_name = message_type_name
            FROM MonologSenderQueue
    ), TIMEOUT 5000;

	IF (@conversation_handle IS NOT NULL)
	BEGIN
		IF (@message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog')
		BEGIN
			END CONVERSATION @conversation_handle;
		END
	END
COMMIT;

/*
  Check progress.  Note that the STATE has changed on the conversation again
*/
SELECT * FROM HelloWorldQueue WITH (NOLOCK)
SELECT * FROM MonologSenderQueue WITH (NOLOCK)
SELECT * FROM sys.[conversation_endpoints] WITH (NOLOCK)



/*
  Clean everything up for next demo

  Drop everything to get recreated
*/

/* 
    The first part of this script allows it to be Idempotent, simply removing objects if they
    currently exist and then adding the pieces back in.  If the objects are not there, we
    simply create the services and start the Queues rolling.

*/
IF EXISTS (SELECT * FROM sys.services WHERE name = N'MonologSenderService')
     DROP SERVICE [MonologSenderService];

/* 
    The Intermeditate Queue is for processing Trigger messages that may contain many rows
    from the action on a table.  It then parses those rows into separate messages for another 
    Queue to processes
*/
IF EXISTS (SELECT * FROM sys.services WHERE name = N'HelloWorldService')
     DROP SERVICE [HelloWorldService];

IF EXISTS (SELECT * FROM sys.service_contracts WHERE name = N'HelloWorldContract')
     DROP CONTRACT [HelloWorldContract];

IF EXISTS (SELECT * FROM sys.service_message_types WHERE name = N'HelloWorldMsg') 
	DROP MESSAGE TYPE [HelloWorldMsg];


IF EXISTS (SELECT * FROM sys.service_queues WHERE name = N'MonologSenderQueue')
     DROP QUEUE [MonologSenderQueue];

IF EXISTS (SELECT * FROM sys.service_queues WHERE name = N'HelloWorldQueue')
     DROP QUEUE [HelloWorldQueue];
