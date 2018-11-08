# Workload Driver for Order Insertion in WideWorldImporters

This application simulates an order insertion workload for the WideWorldImporters sample database.

### Contents

[About this sample](#about-this-sample)<br/>
[Before you begin](#before-you-begin)<br/>
[Running the sample](#run-this-sample)<br/>
[Sample details](#sample-details)<br/>
[Disclaimers](#disclaimers)<br/>
[Related links](#related-links)<br/>


<a name=about-this-sample></a>

## About this sample

<!-- Delete the ones that don't apply -->
1. **Applies to:** SQL Server 2016 (or higher), Azure SQL Database
1. **Key features:** Core database features
1. **Workload:** OLTP
1. **Programming Language:** C#
1. **Authors:** Greg Low, Jos de Bruijn
1. **Update history:** 25 May 2016 - initial revision

<a name=before-you-begin></a>

## Before you begin

To run this sample, you need the following prerequisites.

**Software prerequisites:**

<!-- Examples -->
1. SQL Server 2016 (or higher) or Azure SQL Database.
2. Visual Studio 2015.
3. The WideWorldImporters database.

<a name=run-this-sample></a>

## Running the sample

1. Open the solution file MultithreadedOrderInsertWorkload.sln in Visual Studio.

2. Build the solution.

3. Run the app.

## Sample details

This application is used to provide an intensive order entry workload for the WideWorldImporters database. When started it displays the following:

![Alt text](/media/wide-world-importers-order-insert-app.png "WideWorldImporters Order Insert Workload Simulation")

Ensure that the connection string is set appropriately. It is save when the program is edited. If you ever need to set it back to the default value, open the program, clear the string, and exit the program. When you restart the program, the connection string will have been returned to the default value.

The program uses the selected number of threads to concurrently call the `Website.InsertCustomerOrder` stored procedure.

When inserts are occurring, click the button to stop but allow time for the system to respond and stop. It may take a few seconds to respond, particularly if a larger number of threads is being used.


<a name=disclaimers></a>

## Disclaimers
The code included in this sample is not intended to be used for production purposes.

<a name=related-links></a>
