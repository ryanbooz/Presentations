/*
  Create a simple rollup table that will utilize the Sales.Order and Sales.OrderDetail data.

  With the data aggregated by customer, stockItem, month and year, we can import other fact tables
  from the database to do filtering and charting in Power BI.

  Again, this is a quick demo.  :-)!

*/
CREATE TABLE [Sales].[SalesRollup] (
	CustomerID INT FOREIGN KEY REFERENCES Sales.[Customers]([CustomerID]) NOT NULL,
	StockItemID INT FOREIGN KEY REFERENCES [Warehouse].[StockItems]([StockItemID]) NOT NULL,
	SalesMonth INT NOT NULL,
	SalesYear INT NOT NULL,
	Quantity INT,
	TotalItemSale MONEY
);

/*
  Add a clustered index.  I'm doing it here simply because the data will be inserted
  in the same order based on the next statement.
*/
ALTER TABLE [Sales].[SalesRollup] ADD CONSTRAINT PKC_Year_Month_CustomerID PRIMARY KEY CLUSTERED ([SalesYear],[SalesMonth],[CustomerID], [StockItemID]);

/*
  This simple script will "seed" the database with the current data in Sales.order.
*/

INSERT INTO [Sales].[SalesRollup] 
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


