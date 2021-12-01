import os
import time
import csv
import psycopg2
from psycopg2.extras import execute_values
from psycopg2.extras import execute_batch
from pandas import *
import numpy as np
import msgpack
import msgpack_numpy as m

conn = psycopg2.connect(database="nft_copy", 
                        host="localhost", 
                        user="postgres", 
                        password="password", 
                        port=5432)


cur = conn.cursor()

cur.execute("TRUNCATE test_insert;")
batch_count=0
total_rows = 0
filename = '725k.csv'
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
            "INSERT INTO test_insert VALUES (%s, %s, %s)",
            row
        )

        conn.commit()

def multi_valued_insert():
    global function_name
    function_name = 'multi_valued_insert '
    with open(filename, 'r') as f:
        global batch_count
        reader = csv.reader(f)
        sql = "INSERT INTO test_insert VALUES "
        next(reader) # Skip the header row.
        for row in reader:
            batch_count += 1
            sql += "('{}', {}, {}),".format(*row)

            if batch_count == 500:
                cur.execute(sql[:-1])
                conn.commit()
                batch_count = 0
                sql = "INSERT INTO test_insert VALUES "

        conn.commit()



def exec_values():
    global function_name
    function_name = 'exec_values '  
    with open(filename, 'r') as f:
        reader = csv.reader(f)
        next(reader) # Skip the header row.
        list_of_rows = list(reader)

        execute_values(cur, "INSERT INTO test_insert VALUES %s", list_of_rows,page_size=1000)

        conn.commit()




def insert_arrays():
    global function_name
    function_name = 'insert_arrays ' 
    data = read_csv(filename)
    
    # converting column data to list
    date = data['time'].tolist()
    tempc = data['tempc'].tolist()
    cpu = data['cpu'].tolist()

    i=0
    batch_size=10000
    batch_end=batch_size
    total_length = len(date)
    while batch_end < total_length:
        cur.execute("INSERT INTO test_insert SELECT * FROM unnest(%s::timestamptz[],%s::int[],%s::double precision[]) a(t,v,s) ON CONFLICT DO nothing;",(date[i:batch_end],tempc[i:batch_end],cpu[i:batch_end]))
        i=batch_end
        batch_end+=batch_size
        #conn.commit()
    
    if total_length > i:
        cur.execute("INSERT INTO test_insert SELECT * FROM unnest(%s::timestamptz[],%s::int[],%s::double precision[]) a(t,v,s) ON CONFLICT DO nothing;",(date[i:],tempc[i:],cpu[i:]))
        #conn.commit()
    
    conn.commit()


def copy_from_csv():
    global function_name
    function_name = 'copy_from_csv '    
    with open(filename, 'r') as f:
        next(f) # Skip the header row.
        cur.copy_from(f, 'test_insert', sep=',')



#single_insert()
#multi_valued_insert()
#exec_values()
#insert_arrays()
copy_from_csv()

print('{} elapsed time in seconds: {}'.format(function_name, time.time() - t))