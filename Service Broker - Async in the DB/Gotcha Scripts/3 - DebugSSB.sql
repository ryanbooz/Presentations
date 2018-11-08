
RAISERROR ('Did you mean to run the whole thing?', 20, 1) WITH LOG;
GO

/*

	Shut off queue activation. This allows messages to accumulate
	in the queue so that you can run your activated procedures
	manually.

*/
ALTER QUEUE OrderRollupQueue WITH ACTIVATION (STATUS = OFF)
ALTER QUEUE MonologueSenderQueue WITH ACTIVATION (STATUS = OFF)
--ALTER QUEUE IntermediateMessageQueue WITH ACTIVATION (STATUS = OFF)
GO

/*
	If the queue got disabled because of a poisen message, you will
	need to enable it again before you can receive messages from it.

	If you are just debugging a process, this shouldn't be needed.
*/
ALTER QUEUE OrderRollupQueue WITH STATUS = ON

/*

	See what's in the queue. This allows you to see what message is going to
	process next, presumably the one that is giving you an error.

*/
SELECT *, CAST(message_body AS XML) FROM MonologueSenderQueue WITH (NOLOCK) ORDER BY queuing_order
SELECT *,CAST(message_body AS xml) FROM OrderRollupQueue WITH (NOLOCK) ORDER BY queuing_order

--SELECT *,CAST(message_body AS xml) FROM IntermediateMessageQueue WITH (NOLOCK) ORDER BY queuing_order

--exec [Application].[SBActivated_IntermediateMessageQueue]

/*
	Proess the messages one at a time

	Select from the queue(s) again to check progress
*/
EXEC [Application].[SBActivated_OrderRollupQueue]

/*
	Sometimes, you might just have to clean these out.

	You can do anything you need to in the receive part, but
	the ultimate goal is to clean out the queue and evaluate
	what to do with these messages.

	Quick hint: Sometimes you might just need to save the messages
	to a temp table to reprocess and then add them back to the queue.

*/
DECLARE @handle UNIQUEIDENTIFIER;
--WHILE (SELECT COUNT(*) FROM [OrderRollupQueue]) > 0
BEGIN
	RECEIVE TOP (1) @handle = conversation_handle FROM [OrderRollupQueue];
	END CONVERSATION @handle
END

/*
	Remember that you have to acknowledge the close of the conversation

	Because the Monologue queue does nothing but close the conversation
	and/or create an entry in the error log, this can wait until you re-enable
	the activation on the queue.
*/
EXEC [Application].[SBActivated_MonologueSenderQueue]

/*
	If you have an error logging table setup, you can check to see if your
	processing is logging the errors you expect.
*/
SELECT * FROM [Application].[SBErrorLog]


/*
	When you're all done, set the queues to be activated again
*/
ALTER QUEUE OrderRollupQueue WITH ACTIVATION (STATUS = ON, MAX_QUEUE_READERS = 1)
ALTER QUEUE MonologueSenderQueue WITH ACTIVATION (STATUS = ON, MAX_QUEUE_READERS = 1)
GO


/*


SELECT * FROM sys.[transmission_queue]

SELECT * FROM sys.[conversation_endpoints] WITH (NOLOCK)

SELECT * FROM sys.services

*/

