
--IF OBJECT_ID('Sales.tI_Order_Rollup','TR') IS NOT NULL
--BEGIN
--      DROP TRIGGER [Sales].[tU_OrderLines_Rollup];
--END;
--GO

/****** Object:  Trigger [tU_OrderLines_Rollup]  ******/
create or alter trigger [Sales].[tU_OrderLines_Rollup] on [Sales].[OrderLines]
  FOR UPDATE
  as
begin
  declare  @numrows int,
           @nullcnt int,
           @validcnt int,
           @insbillID int,
           @errno   int,
           @errmsg  varchar(255)

  select @numrows = @@rowcount

    IF @numrows = 0 
        RETURN;

    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN
			DECLARE @messageData XML
			
			SELECT
				OrderID
			INTO 
				#orders 
			FROM
				(
				SELECT OrderID, Quantity, UnitPrice, TaxRate FROM inserted
				EXCEPT
				SELECT OrderID, Quantity, UnitPrice, TaxRate FROM deleted
			) ChangedData;


			IF EXISTS(SELECT 1 FROM #orders)
			BEGIN
				SELECT @messageData =
					( 
					  SELECT DISTINCT
						OrderID
					  FROM
						#orders
					  FOR XML PATH('row'), ROOT('data')
					);
			
				IF DATALENGTH(@messageData) > 0	
				BEGIN
					EXECUTE [Application].[SB_SendIntermediateMessages] N'OrderRollupService', 
						N'OrderRollupContract', 
						N'OrderIDMsg',
						@messageData;
				END

				--DECLARE @InitDlgHandle UNIQUEIDENTIFIER
											
				--BEGIN DIALOG @InitDlgHandle
				--	FROM SERVICE [MonologueSenderService]
				--	TO SERVICE N'OrderRollupService', 'CURRENT DATABASE'
				--	ON CONTRACT [OrderRollupContract]
				--	WITH ENCRYPTION = OFF;

				--SEND ON CONVERSATION @InitDlgHandle
				--	MESSAGE TYPE [OrderIDMsg]
				--	(@messageData);		
			END
        END;
    END TRY
    BEGIN CATCH
	    DECLARE @ErrorMessage NVARCHAR(4000);
		DECLARE @ErrorSeverity INT;
		DECLARE @ErrorState INT;

		SELECT @ErrorMessage = ERROR_MESSAGE(),
			   @ErrorSeverity = ERROR_SEVERITY(),
			   @ErrorState = ERROR_STATE();

		-- Use RAISERROR inside the CATCH block to return 
		-- error information about the original error that 
		-- caused execution to jump to the CATCH block.
		RAISERROR (@ErrorMessage, -- Message text.
				   @ErrorSeverity, -- Severity.
				   @ErrorState -- State.
				   );

        -- Rollback any active or uncommittable transactions before
        -- inserting information in the ErrorLog
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END

    END CATCH;
END;
GO