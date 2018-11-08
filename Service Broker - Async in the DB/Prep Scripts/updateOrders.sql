update sales.orderlines set quantity=quantity+1000 where orderID in
	(
		select top 100 OL.orderID from sales.orderlines OL
		inner join sales.orders O on ol.orderID = O.orderID
		where o.OrderDate > DATEADD(day,-10,getdate())
		and StockItemID=164
	)

