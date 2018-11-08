
--IF OBJECT_ID('Sales.tI_Order_Rollup','TR') IS NOT NULL
--BEGIN
--      DROP TRIGGER [Sales].[tI_Order_Rollup];
--END;
--GO

/****** Object:  Trigger [tI_Order_Rollup]  ******/
create or alter trigger [Sales].[tI_Order_Rollup] on Sales.[Orders]
  FOR INSERT
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
			
			SELECT @messageData =
				( 
				  SELECT DISTINCT
					[i].[OrderID]
				  FROM
					inserted i
				  FOR XML PATH('row'), ROOT('data')
				 );
			
			DECLARE @InitDlgHandle UNIQUEIDENTIFIER
											
			BEGIN DIALOG @InitDlgHandle
				FROM SERVICE [MonologueSenderService]
				TO SERVICE N'OrderRollupService', 'CURRENT DATABASE'
				ON CONTRACT [OrderRollupContract]
				WITH ENCRYPTION = OFF;

			SEND ON CONVERSATION @InitDlgHandle
				MESSAGE TYPE [OrderIDMsg]
				(@messageData);		

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