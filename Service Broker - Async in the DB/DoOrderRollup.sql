IF OBJECT_ID('dbo.DoOrderRollup','P') IS NOT NULL
	DROP PROCEDURE dbo.DoOrderRollup
GO

CREATE PROCEDURE dbo.DoOrderRollup @id INT
AS
BEGIN
	SET NOCOUNT ON

	/* Declare variables for later in the process.  These are used by the differential queries */

	--DECLARE @ownerID INT = COALESCE((SELECT @ids.value('(/row/ownerID)[1]', 'INT')),NULL);

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

	MERGE dbo.[SalesRollup] AS TARGET
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
	--			OUTPUT $action, Inserted.*, [Deleted].*;

	DROP TABLE [#tempSalesRollup];

	SET NOCOUNT OFF;
END;
GO