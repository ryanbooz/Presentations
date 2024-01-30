import os
import time
import csv
import psycopg2
from psycopg2.extras import execute_values
from psycopg2.extras import execute_batch
from pandas import *

conn = psycopg2.connect(dbname="postgres", 
                        host="localhost", 
                        user="postgres", 
                        password="password", 
                        port=5432)


cur = conn.cursor()

cur.execute("TRUNCATE bulk_test;")
batch_count=0
total_rows = 0
filename = 'bulk_test.csv'
function_name = ''

t = time.time()

def single_insert():
    global function_name
    function_name = 'single_insert '
    with open(filename, 'r') as f:
        global batch_count
        reader = csv.reader(f)
        next(reader) # Skip the header row.
        for row in reader:
            batch_count += 1
            if batch_count == 5000:
                conn.commit()
                batch_count = 0

            cur.execute(
            "INSERT INTO bulk_test VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
            row
        )

        conn.commit()

def multi_valued_insert(tname="bulk_test"):
    global function_name
    function_name = 'multi_valued_insert '
    with open(filename, 'r') as f:
        global batch_count
        reader = csv.reader(f)
        sql = "INSERT INTO {} VALUES ".format(tname)
        next(reader) # Skip the header row.
        for row in reader:
            batch_count += 1
            sql += "('{}', {}, {}, {}, {}, {}, {}, {}, {}, '{}', '{}'),".format(*row)

            if batch_count == 10000:
                cur.execute(sql[:-1])
                conn.commit()
                batch_count = 0
                sql = "INSERT INTO {} VALUES ".format(tname)

        conn.commit()


def insert_arrays():
    global function_name
    function_name = 'insert_arrays ' 
    data = read_csv(filename)
    
    # converting column data to list
    date = data['time'].tolist()
    device_id = data['device_id'].tolist()
    val1 = data['val1'].tolist()
    val2 = data['val2'].tolist()
    val3 = data['val3'].tolist()
    val4 = data['val4'].tolist()
    val5 = data['val5'].tolist()
    val6 = data['val6'].tolist()
    val7 = data['val7'].tolist()
    val8 = data['val8'].tolist()
    val9 = data['val9'].tolist()


    i=0
    batch_size=10000
    batch_end=batch_size
    total_length = len(date)
    while batch_end < total_length:
        cur.execute("INSERT INTO bulk_test SELECT * FROM unnest \
                        (%s::timestamptz[],%s::int[],%s::int[],%s::int[],%s::int[],%s::int[],%s::double precision[],%s::double precision[],%s::double precision[],%s::text[],%s::text[]) \
                        a(t,d,v1,v2,v3,v4,v5,v6,v7,v8,v9) ON CONFLICT DO nothing;",
                    (date[i:batch_end],device_id[i:batch_end],val1[i:batch_end],val2[i:batch_end],val3[i:batch_end],val4[i:batch_end],val5[i:batch_end],val6[i:batch_end],val7[i:batch_end],val8[i:batch_end],val9[i:batch_end]))
        i=batch_end
        batch_end+=batch_size
        conn.commit()
    
    if total_length > i:
        cur.execute("INSERT INTO bulk_test SELECT * FROM unnest \
                        (%s::timestamptz[],%s::int[],%s::int[],%s::int[],%s::int[],%s::int[],%s::double precision[],%s::double precision[],%s::double precision[],%s::text[],%s::text[]) \
                        a(t,d,v1,v2,v3,v4,v5,v6,v7,v8,v9) ON CONFLICT DO nothing;",
                    (date[i:],device_id[i:],val1[i:],val2[i:],val3[i:],val4[i:],val5[i:],val6[i:],val7[i:],val8[i:],val9[i:]))
        conn.commit()
    
    conn.commit()


def copy_from_csv():
    global function_name
    function_name = 'copy_from_csv '    
    with open(filename, 'r') as f:
        next(f) # Skip the header row.
        cur.copy_from(f, 'bulk_test', sep=',')



#single_insert()
#multi_valued_insert()
#insert_arrays()
copy_from_csv()

print('{} elapsed time in seconds: {}'.format(function_name, time.time() - t))