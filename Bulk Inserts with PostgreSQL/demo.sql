/*
 * Bulk_data is the source data of ~1 million rows
 * with 11 total columns.
 * 
 * It was pre-generated to avoid memory contention of 
 * generating data each time.
 */
SELECT * FROM bulk_data LIMIT 10;

SELECT count(*) FROM bulk_data;


/*
 * INSERT data with multi-valued INSERT statement.
 * 
 * In this case, we'll insert in blocks of 500 rows/values 
 * because otherwise the memory needed to create the string
 * becomes the limitation.
 */ 
DO
$$
DECLARE
	exec_start timestamptz;
	string_start timestamptz;
	total_string_time int = 0;
	total_exec_time int = 0;
	SQL TEXT;
	row_val record;
	counter int = 0;
	batch_size int = 500;
BEGIN
	TRUNCATE bulk_test;
	string_start := clock_timestamp();
	SQL := 'INSERT INTO bulk_test VALUES ';

	FOR row_val IN SELECT time, device_id, 
		val1,
		val2,
		val3,
		val4,
		val5,
		val6,
		val7,
		val8,
		val9
	FROM
		bulk_data 
	LOOP
		counter := counter + 1;
		SQL := SQL || FORMAT('(%1$L,%2$s,%3$s,%4$s,%5$s,%6$s,%7$s,%8$s,%9$s,%10$L,%11$L),', 
							row_val.time, row_val.device_id, row_val.val1, row_val.val2,
							row_val.val3,row_val.val4,row_val.val5,row_val.val6,row_val.val7,
							row_val.val8,row_val.val9);
	
		IF counter = batch_size THEN
			total_string_time := total_string_time + (1000 * (extract(epoch FROM clock_timestamp() - string_start)));
			
			exec_start := clock_timestamp();
			EXECUTE rtrim(SQL,',');
			
			total_exec_time := total_exec_time + (1000 * (extract(epoch FROM clock_timestamp() - exec_start)));

		counter = 0;
			string_start := clock_timestamp();
			SQL := 'INSERT INTO bulk_test VALUES ';
		
			
		END IF;
	END LOOP;

	
	IF counter > 0 THEN 
		exec_start := clock_timestamp();
			EXECUTE rtrim(SQL,',');
			--COMMIT;
			total_exec_time := total_exec_time + (1000 * (extract(epoch FROM clock_timestamp() - exec_start)));
	END IF;

	RAISE NOTICE 'Total String generation time in ms = %' , total_string_time;
	RAISE NOTICE 'Total Execution time in ms = %' , total_exec_time;


END;
$$


/*
 * Now try the same thing with Arrays
 */
TRUNCATE bulk_test;
SELECT count(*) FROM bulk_test;

DO
$$
DECLARE
	exec_start timestamptz;
	select_start timestamptz;
	total_select_time int = 0;
	total_exec_time int = 0;
	SQL TEXT;
	counter int = 0;
	row_limit int = 10000;
	row_offset int = 0;
	array_size int = 10000;
	t timestamptz[]; -- = NULL;
	d int[]; --= NULL;
	v1 int[];
	v2 int[];
	v3 int[];
	v4 int[];
	v5 float8[];
	v6 float8[];
	v7 float8[];
	v8 text[];
	v9 text[];
	do_loop bool = TRUE;
BEGIN
	TRUNCATE bulk_test;
	SQL := 'INSERT INTO bulk_test SELECT * FROM unnest($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) a(a,b,v1,v2,v3,v4,v5,v6,v7,v8,v9) ON CONFLICT DO nothing;';

	WHILE do_loop loop

		select_start := clock_timestamp();
		SELECT array_agg(time), array_agg(device_id), 
			array_agg(val1),
			array_agg(val2),
			array_agg(val3),
			array_agg(val4),
			array_agg(val5),
			array_agg(val6),
			array_agg(val7),
			array_agg(val8),
			array_agg(val9)
		INTO t,d,v1,v2,v3,v4,v5,v6,v7,v8,v9
		FROM
			(SELECT * FROM bulk_data
				ORDER BY time, device_id
				LIMIT row_limit OFFSET row_offset) a;
			
		total_select_time := total_select_time + (1000 * (extract(epoch FROM clock_timestamp() - select_start)));

		IF array_length(t,1) > 0 THEN
			exec_start := clock_timestamp();
			EXECUTE SQL USING t,d,v1,v2,v3,v4,v5,v6,v7,v8,v9;
			total_exec_time := total_exec_time + (1000 * (extract(epoch FROM clock_timestamp() - exec_start)));
			row_offset = row_offset+row_limit;
		ELSE
			do_loop = FALSE;
		END IF;

	END LOOP;
	--
	RAISE NOTICE 'Total SELECT time in ms = %' , total_select_time;
	RAISE NOTICE 'Total Execution time in ms = %' , total_exec_time;
END;
$$


/*
 * Create the CSV file from the source table. Adjust the path
 * below depending on your server/Docker/laptop setup.
 */
COPY bulk_data TO '/tmp/bulk_test.csv' CSV HEADER;


/*
 * Now using COPY. Remember, it's very fast
 * but also a failure stops it from completing.
 * 
 * Adjust the path to the file to match above
 */
DO
$$
DECLARE
	exec_start timestamptz;
BEGIN
	TRUNCATE bulk_test;
	exec_start := clock_timestamp();

	COPY bulk_test FROM '/tmp/bulk_test.csv' CSV HEADER;
	
	RAISE NOTICE 'Execution time in ms = %' , 1000 * (extract(epoch FROM clock_timestamp() - exec_start));

	
END;
$$

/*
 * Set the test table to UNLOGGED and then
 * try the COPY statement again.
 * 
 * ***REMEMBER***: Set the table back to LOGGED
 * under most normal circumstances.
 */
ALTER TABLE bulk_test SET UNLOGGED;


