CREATE QUEUE [IntermediateMessageQueue] WITH
		 STATUS = ON,
		 RETENTION = OFF,
		 ACTIVATION ( PROCEDURE_NAME = [dbo].[SBActivated_IntermediateMessageQueue],
					  MAX_QUEUE_READERS = 10,
					  EXECUTE AS OWNER,
					  STATUS = OFF
					  ),
	     POISON_MESSAGE_HANDLING (STATUS = ON)  ON [PRIMARY] 
GO

/*
  Getting a little fancy and creating a message type so that we can respond
  to a specific kind of message.
*/
CREATE MESSAGE TYPE [IntermediateMessage] VALIDATION = WELL_FORMED_XML;
GO

/*
  If you have a message type, the contract makes sure everyone is sending the
  correct type of message to the queue
*/
CREATE CONTRACT [IntermediateMessageContract] ([IntermediateMessage] SENT BY ANY);
GO

/*
  Minimally we need a service on a queue.  Messages are sent to a queue through
  a service (remember, they're the "traffic cop")
*/
CREATE SERVICE [IntermediateMessageService] ON QUEUE [IntermediateMessageQueue] ([IntermediateMessageContract])
GO

