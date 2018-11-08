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
					--DECLARE @OrderID INT = COALESCE((SELECT @message_body.value('(//row/OrderID)[1]', 'INT')),NULL);
					--PRINT @OrderID;
					EXEC Sales.DoOrderRollup @message_body;
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