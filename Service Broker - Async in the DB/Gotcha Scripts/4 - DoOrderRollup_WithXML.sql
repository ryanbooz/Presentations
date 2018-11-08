CREATE OR ALTER PROCEDURE Sales.DoOrderRollup @message XML
AS
BEGIN
	SET NOCOUNT ON

	BEGIN TRY

		IF(@@TRANCOUNT > 0)
		BEGIN
			SAVE TRANSACTION SavePoint1;
		END
		
		DECLARE @id INT = COALESCE((SELECT @message.value('(//row/OrderID)[1]', 'INT')),NULL);
	
		CREATE TABLE #tempSalesRollup (
			CustomerID INT FOREIGN KEY REFERENCES Sales.[Customers]([CustomerID]) NOT NULL,
			StockItemID INT FOREIGN KEY REFERENCES [Warehouse].[StockItems]([StockItemID]) NOT NULL,
			SalesMonth INT NOT NULL,
			SalesYear INT NOT NULL,
			Quantity INT,
			TotalItemSale MONEY
		);

		INSERT INTO #tempsalesRollup 
		SELECT C.[CustomerID], si.[StockItemID], 
		MONTH(O.[OrderDate]) AS [month], YEAR(O.[OrderDate]) AS [Year], 
			SUM(OL.[Quantity]) Quantity, SUM(OL.[Quantity] * OL.[UnitPrice] + (OL.[Quantity] * OL.[UnitPrice])*([OL].[TaxRate]/100)) as TotalItemSale 
			FROM [Warehouse].[StockItems] SI
			INNER JOIN [Sales].[orderLines] OL ON OL.[StockItemID] = [SI].[StockItemID]
			INNER JOIN sales.orders O ON O.[OrderID] = OL.[OrderID]
			INNER JOIN [Sales].[Customers] C ON [C].[CustomerID] = O.[CustomerID]
			WHERE O.orderID = @id
			GROUP BY C.[CustomerID], [SI].[StockItemID], SI.[StockItemName], 
			YEAR(O.[OrderDate]), MONTH(O.[OrderDate])
			ORDER BY Year, month, [C].[CustomerID], [SI].[StockItemID]

		ALTER TABLE [#tempSalesRollup] ADD CONSTRAINT PKC_Year_Month_CustomerID PRIMARY KEY CLUSTERED ([SalesYear],[SalesMonth],[CustomerID], [StockItemID]);

		MERGE Sales.[SalesRollup] AS TARGET
					USING (SELECT * FROM [#tempSalesRollup]) AS SOURCE
					ON TARGET.[SalesYear] = SOURCE.[SalesYear]
						AND TARGET.[SalesMonth] = SOURCE.[SalesMonth]
						AND TARGET.[CustomerID] = SOURCE.[CustomerID]
						AND TARGET.[StockItemID] = SOURCE.[StockItemID]
					WHEN MATCHED
						THEN UPDATE SET 
						[TARGET].[Quantity] = TARGET.[Quantity] + SOURCE.[Quantity],
						[TARGET].[TotalItemSale] = TARGET.[TotalItemSale] + SOURCE.[TotalItemSale]
					WHEN NOT MATCHED
						THEN INSERT VALUES
							(
							 SOURCE.[CustomerID],
							 SOURCE.[StockItemID],
							 SOURCE.[SalesMonth],
							 SOURCE.[SalesYear],
							 SOURCE.[Quantity],
							 SOURCE.[TotalItemSale]
							);

		DROP TABLE [#tempSalesRollup];

	END TRY
	BEGIN CATCH

			DECLARE
			@ErrorSeverity  int,
			@ErrorState   int,
			@ErrorMessage nvarchar(2048),
			@XACT_STATE   int;

			SELECT
			@ErrorSeverity  = ERROR_SEVERITY(),
			@ErrorState   = ERROR_STATE(),
			@ErrorMessage = ERROR_MESSAGE(),
			@XACT_STATE   = XACT_STATE();

		-- Check XACT_STATE() 

			IF (@XACT_STATE = -1)
		-- Transaction is doomed **
			BEGIN 
				ROLLBACK TRAN;
			END
                
			IF (@XACT_STATE = 1)
		-- Transaction is commited to rollback to the save point
			BEGIN
				ROLLBACK TRANSACTION SavePoint1;
			END

		-- Re-raise the error.
			RAISERROR (
			@ErrorMessage,
			@ErrorSeverity,
			@ErrorState );   

	END CATCH
	SET NOCOUNT OFF;
END;
GO