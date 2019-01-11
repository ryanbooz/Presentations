# Service Broker - Async in the DB #

## Sample Scripts ##

### Pre-requisits ##

During the presentation I chose to run these scripts on the new WideWorldImporters database provided by Microsoft.  Technically, the first two scripts will work on any database of your choosing as there is nothing specific to that WWI datbase that is required.

The third script, however, does require this database and some additional setup:

* [WideWorldImporters database](https://github.com/Microsoft/sql-server-samples/releases/download/wide-world-importers-v1.0/WideWorldImporters-Standard.bak) - This is specifically a link to the "Standard" version which should work on every version of SQL 2016.

* [Order Insert Application](https://github.com/Microsoft/sql-server-samples/tree/master/samples/databases/wide-world-importers/workload-drivers/order-insert) - This is a simple "workload" application (EXE) that the SQL Server team provides with the WideWorldImporters database to simulate load by inserting (many) orders.  Using this free application, you can connect to the database and insert order to see your Service Broker application work in "real-time"!

I've included this in the **order-insert** folder for you in case you cannot find it easily online.

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
    

   These scripts are in the **Prep Scripts** folder:

   **WWI-Demo-Prep.sql** - This script creates a new table and then populates it with whatever data is currently in Sales.Orders and Sales.OrderDetails.  See comments in the file.
   
   **tI_Order_Rollup.sql** - This trigger will fire every time a new order is created for a customer.  It is in this trigger that we save the OrderID in an XML document which is placed on the queue.  Another SPROC takes that message off of the queue and passes the OrderID to a procedure that will do the rollup of this order.

   **DoOrderRollup.sql** - This stored procedure simply receives and OrderID from the activated SPROC and does the rollup.  It uses a MERGE statement to either insert a new row if it doesn't exist or update one if it is there (if a user modifies an order or orders more of the same item for that month).

## Gotcha & Tips Scripts ##

The scripts in the **Gotcha Scripts** folder show examples of scripts relating to the Gotcha and Tips section of the slides. These are T-SQL examples that are helpful in debugging Service Broker apps and solving some problems like error catching and checking.

**ServiceBrokerEnable.sql** - This stored procedure is helpful to have in a database so that when it is created or attached, you can run it as part of your process to make sure Service Broker is enabled correctly. It also shows an example of how to ensure that a system user owns the database (SA in this case) so that the threads which process messages can run as expected.

**bad_order.sql** - This script intentionally puts a bad message on the queue which the activated procedure cannot process correctly.  This causes an activated queue to be disabled after 5 attempts. When this happens, you have to know how to get a queue back into a state that you can retrieve messages to take care of the offending message. 

**DebugSSB.sql** - This script walks through the process of turning off activation on a queue (either because of a bad message or for actual debugging purposes) and then make sure the queue is enabled so that messages can be retrieved again. This is an example of the basic way most people debug Service Broker applications:
* Turn off Activation by setting the status to OFF
* Re-enable the queue if you need to because a poison message turned it off
* Select the messages from the queue so that you can see what they contain and try to determine why the message is causing errors, etc.
* Run the Activated stored procedures manually to take messages off the queue as you modify the process to check progress. This can take at least two forms:
    * There really was an error with the activated stored procedure that didn't know how to deal with the message correctly and your (eventual) changes allow the message to be process correctly now.
    * The message is just bad or causing errors that you cannot accommodate. In this case you either deal with error logging correctly to get the message off of the queue OR you simply start receiving messages off the queue and ending the conversation until the offending messages are gone. It happens. :-)
* When all is said and done, we re-enable the activation on the queues and let the application start doing it's work again.

**DoOrderRollup_WithXML.sql** - After inserting an intentionally bad message and starting to debug the activated stored procedure, this update changes the context of the message so that the inner procedure (the one that's called from within the Activated procedure), correctly ends the transaction and bubbles up the error so that we can log it.

This is just one way to deal with it as I mentioned above. In this case, parsing the XML at a different transaction scope allows us to bubble the error in a way that allows us to log the issue, end the conversation correctly, and then move on.

**SBActivated_OrderRollupQueue.sql** - This is an updated Activated stored procedure that goes with the updated XML variant of the rollup procedure above.  They must be used in tandem. 

