# Service Broker - Async in the DB #

## Sample Scripts ##

### Pre-requisits ##

During the presentation I chose to run these scripts on the new WideWorldImporters database provided by Microsoft.  Technically, the first two scripts will work on any database of your choosing as there is nothing specific to that WWI datbase that is required.

The third script, however, does require this database and some additional setup:

* [WideWorldImporters database](https://github.com/Microsoft/sql-server-samples/releases/download/wide-world-importers-v1.0/WideWorldImporters-Standard.bak) - This is specifically a link to the "Standard" version which should work on every version of SQL 2016.

* [Order Insert Application](https://github.com/Microsoft/sql-server-samples/tree/master/samples/databases/wide-world-importers/workload-drivers/order-insert) - This is a simple "workload" application (EXE) that the SQL Server team provides with the WideWorldImporters database to simulate load by inserting (many) orders.  Using this free application, you can connect to the database and insert order to see your Service Broker application work in "real-time"!

* Power BI - As part of the presentation I showed a simple dashboard in Power BI that utilized the "real-time" rollup data from the database. The PBIX file is provided as a separate download and can be opened and connected

## Demo Scripts ##

1. SSB-Demo1.sql

    This initial demo script runs through the process of creating a very simple Service Broker application that can send and receive messages "by hand".  No activation or automation is included.  This should help you understand the basic nature of the messaging architecture.

    No specific database is needed for this application.  The queries at the end will remove everything that is added as part of running through the script.

2. SSB-Demo2.sql

    This script builds on the first and assumes that you ran the "clean up" from the first script.  It creates most of the same queues, but does the work through stored procedures.  Near the end of the script, we turn on activation so that your messages are now processed by the target and initiator queue automatically.

    No specific database is required for this script either.  There is a section at the end of the script to clean up again.

3. SSB-Demo3.sql

   This is the culmination of the presentation and attempts to show a very simple Service Broker application that receives messages from a trigger, processes data "automatically", which can then be consumed by another application - Power BI in this case.

   Additional setup is needed and the WideWorldImporters database (referenced above) is required for this sample to work.

   After restoring a copy of WideWorldImporters, execute these scripts in order to prepare the database for this demo to work.
    

   **WWI-Demo-Prep.sql** - This script creates a new table and then populates it with whatever data is currently in Sales.Orders and Sales.OrderDetails.  See comments in the file.
   
   **tI_Order_Rollup.sql** - This trigger will fire every time a new order is created for a customer.  It is in this trigger that we save the OrderID in an XML document which is placed on the queue.  Another SPROC takes that message off of the queue and passes the OrderID to a procedure that will do the rollup of this order.

   **DoOrderRollup.sql** - This stored procedure simply receives and OrderID from the activated SPROC and does the rollup.  It uses a MERGE statement to either insert a new row if it doesn't exist or udpate one if it is there (if a user modifies an order or orders more of the same item for that month).