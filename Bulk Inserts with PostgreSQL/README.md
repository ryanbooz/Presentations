# Bulk Inserts with PostgreSQL
These are the files and scripts I use in the demos when giving this presentation. 

To reproduce the demos in your environment,
do the following.

### Prepare the database
Choose a PostgreSQL database (either existing or a new one) and
run the `demo_prep.sql` file on it.

Executing this script will:
 - create the two tables used in the scripts: `bulk_data` and `bulk_test`
 - create two functions for generating random numbers and text
 - INSERT ~1 million rows of data into the `bulk_data` table using `generate_series()` and the two functions

### SQL Demo
The `demo.sql` file demonstrates three different methods for take data from a source (`bulk_data` in this case) and inserting rows in bulk to a destination (`bulk_test`).

Each anonymous code block (also called DO blocks) demonstrates a different method. Run them one at a time.

### Python Demo
The Python script, `batch_save.py`, currently relies on the older `psycopg2` package. Depending on your platform, you may need to PIP install the binary package. To prepare the data and script for testing:

 1. Unzip the `bulk_test.zip` file and put the resulting `bulk_test.csv` file into the same folder as the Python script.
 2. Update the connection info at the top of the script.
 3. Uncomment the method that you want to test at the bottom of the file. As shipped, the `multi_valued_insert` method is the one that will execute.

Of the four methods, they should essentially go slowest to fastest in order. The `single_insert` method will be very slow, potentially tens of minutes depending on your system. `multi_valued_insert` and `insert_arrays` should be somewhat equivalent, however, the array version with this much data is a bit slower. This method could be optimized further, but is enough to demonstrate how to use arrays to insert bulk data. Finally, the `copy_from_csv` method is the fastest, utilizing `copy_from` functionality of the protocol, provided by psycopg2.


