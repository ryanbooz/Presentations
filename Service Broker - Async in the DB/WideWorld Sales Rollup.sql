SELECT * FROM sales.orders WHERE orderDate > '2017-01-01'

SELECT * FROM sales.[OrderLines] WHERE orderID >= 73596
SELECT * FROM sales.[Invoices]
SELECT * FROM sales.invoicelines

SELECT * FROM [Warehouse].[StockItems]
SELECT * FROM [Warehouse].[StockItemStockGroups]


SELECT si.[StockItemID], SI.[StockItemName], MONTH(inv.[InvoiceDate]) AS [month], YEAR(inv.[InvoiceDate]) AS [Year], 
	SUM(il.[ExtendedPrice]) FROM [Warehouse].[StockItems] SI
	INNER JOIN [Sales].[InvoiceLines] IL ON [IL].[StockItemID] = [SI].[StockItemID]
	INNER JOIN sales.[Invoices] INV ON [INV].[InvoiceID] = [IL].[InvoiceID]
	GROUP BY [SI].[StockItemID], SI.[StockItemName],YEAR(inv.[InvoiceDate]), MONTH(inv.[InvoiceDate])
	ORDER BY Year, month, [SI].[StockItemID]

SELECT C.[CustomerName], si.[StockItemID], SI.[StockItemName], MONTH(inv.[InvoiceDate]) AS [month], YEAR(inv.[InvoiceDate]) AS [Year], 
	SUM(il.[Quantity]) Quantity, SUM(il.[ExtendedPrice]) TotalItemSale FROM [Warehouse].[StockItems] SI
	INNER JOIN [Sales].[InvoiceLines] IL ON [IL].[StockItemID] = [SI].[StockItemID]
	INNER JOIN sales.[Invoices] INV ON [INV].[InvoiceID] = [IL].[InvoiceID]
	INNER JOIN [Sales].[Customers] C ON [C].[CustomerID] = [INV].[CustomerID]
	GROUP BY C.[CustomerName], [SI].[StockItemID], SI.[StockItemName],YEAR(inv.[InvoiceDate]), MONTH(inv.[InvoiceDate])
	ORDER BY [C].CustomerNAme, Year, month, [SI].[StockItemID]


SELECT si.[StockItemID], SI.[StockItemName], MONTH(O.[OrderDate]) AS [month], YEAR(O.[OrderDate]) AS [Year], 
	SUM(OL.[Quantity] * OL.[UnitPrice]) Total FROM [Warehouse].[StockItems] SI
	INNER JOIN [Sales].[orderLines] OL ON OL.[StockItemID] = [SI].[StockItemID]
	INNER JOIN sales.[orders] O ON O.[OrderID] = OL.[OrderID]
	GROUP BY [SI].[StockItemID], SI.[StockItemName],YEAR(O.[OrderDate]), MONTH(O.[OrderDate])
	ORDER BY Year, month, [SI].[StockItemID]

INSERT INTO dbo.salesRollup 
SELECT C.[CustomerID], si.[StockItemID], 
MONTH(O.[OrderDate]) AS [month], YEAR(O.[OrderDate]) AS [Year], 
	SUM(OL.[Quantity]) Quantity, SUM(OL.[Quantity] * OL.[UnitPrice] + (OL.[Quantity] * OL.[UnitPrice])*([OL].[TaxRate]/100)) as TotalItemSale 
	FROM [Warehouse].[StockItems] SI
	INNER JOIN [Sales].[orderLines] OL ON OL.[StockItemID] = [SI].[StockItemID]
	INNER JOIN sales.orders O ON O.[OrderID] = OL.[OrderID]
	INNER JOIN [Sales].[Customers] C ON [C].[CustomerID] = O.[CustomerID]
	--WHERE O.[LastEditedWhen]> '2017-06-02 00:52:20'
	GROUP BY C.[CustomerID], [SI].[StockItemID], SI.[StockItemName], 
	YEAR(O.[OrderDate]), MONTH(O.[OrderDate])
	ORDER BY Year, month, [C].[CustomerID], [SI].[StockItemID]


CREATE TABLE dbo.SalesRollup (
	CustomerID INT FOREIGN KEY REFERENCES Sales.[Customers]([CustomerID]) NOT NULL,
	StockItemID INT FOREIGN KEY REFERENCES [Warehouse].[StockItems]([StockItemID]) NOT NULL,
	SalesMonth INT NOT NULL,
	SalesYear INT NOT NULL,
	Quantity INT,
	TotalItemSale MONEY
);

ALTER TABLE dbo.SalesRollup ADD CONSTRAINT PKC_Year_Month_CustomerID PRIMARY KEY CLUSTERED ([SalesYear],[SalesMonth],[CustomerID], [StockItemID]);

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
	WHERE O.orderID = 74080
	GROUP BY C.[CustomerID], [SI].[StockItemID], SI.[StockItemName], 
	YEAR(O.[OrderDate]), MONTH(O.[OrderDate])
	ORDER BY Year, month, [C].[CustomerID], [SI].[StockItemID]

ALTER TABLE [#tempSalesRollup] ADD CONSTRAINT PKC_Year_Month_CustomerID PRIMARY KEY CLUSTERED ([SalesYear],[SalesMonth],[CustomerID], [StockItemID]);

SELECT * FROM [#tempSalesRollup]

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
