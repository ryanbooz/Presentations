/*
 * A numeric series, stepping by 1
 */
SELECT * FROM generate_series(1,5);

/*
 * A numeric series, stepping by 2
 */
SELECT * from generate_series(0,10,2.5);

/*
 * A numeric series, stepping by 2
 */
SELECT * from generate_series(10,0,-2);

/*
 * A timestamp series with 1 hour interval
 * 
 * 25 rows total (not 24) because we start and end
 * at the top of the hour. So, beginning/ending 
 * inclusive **IF** the interval would include the
 * last hour
 */
SELECT * from generate_series(
	'2021-01-01',
    '2021-01-02', INTERVAL '1 hour'
  );
  

/*
 * A timestamp series with 1 hour, 25 minutes
 * 
 * 17 rows and there is no final timestamp on
 * the ending date (because the next step would
 * be past the ending date)
 */
SELECT * from generate_series(
	'2021-01-01',
    '2021-01-02', INTERVAL '1 hour 25 minutes'
  );
  
 
/*
 * Adding a new column to the set
 */
SELECT 'Hello FOSDEM!' as myStr, * FROM generate_series(1,5);


/*
 * We can also add value data from functions
 */
SELECT random()*100 as CPU, * FROM generate_series(1,5);


/*
 * Remember, generate_series is a Set Returning Function,
 * so the data that is returned can be joined like any normal
 * table.
 * 
 * This does an implicit CROSS JOIN of a 10 row and 2 row table = 20 rows
 */
SELECT * from generate_series(1,10) a, generate_series(1,2) b;


/*
 * Now we can combine everything we've learned into a larger statement
 * with data that begins to look just a little bit more real.
 * 
 * 48 rows
 */
SELECT time, device_id, random()*100 as cpu_usage 
FROM generate_series(
	'2021-01-01 00:00:00',
    '2021-01-01 11:00:00',
    INTERVAL '1 hour'
  ) as time, 
generate_series(1,4) device_id;


/*
 *  Create a data starting at a point in the past,
 *  ending at the current timestamp
 * 
 * 17672 rows
 */
SELECT time, device_id, random()*100 as cpu_usage 
FROM generate_series(
	now() - INTERVAL '6 months',
    now(),
    INTERVAL '1 hour'
   ) as time, 
generate_series(1,4) device_id;


/*
 * End on a specific timestamp, starting some period
 * in the past from that ending timestamp
 * 
 * 4.3 million rows!!
 */
SELECT time, device_id, random()*100 as cpu_usage 
FROM generate_series(
	'2021-08-01 00:00:00'::timestamptz - INTERVAL '6 months',
    '2021-08-01 00:00:00'::timestamptz,
    INTERVAL '1 hour'
  ) as time, 
generate_series(1,1000) device_id;


SELECT count(*) FROM (SELECT time, device_id, random()*100 as cpu_usage 
FROM generate_series(
	'2021-08-01 00:00:00'::timestamptz - INTERVAL '6 months',
    '2021-08-01 00:00:00'::timestamptz,
    INTERVAL '1 hour'
  ) as time, 
generate_series(1,1000) device_id)a;

/*
 **********************************************
 * Part 2: Making the sample data look/feel more real
 **********************************************
 */

/*
 * Formula for formatting numeric values
 * 
 * random() - always produces a value between zero and one
 * 
 * To produce a value between min/max:
 * 
 * value = random() * (max-min) + min 
 */
SELECT
  time,
  device_id,
  round((random()* (100-3) + 3)::NUMERIC, 4) AS cpu,
  floor(random()* (83-28) + 28)::INTEGER AS tempc
FROM 
	generate_series(now() - interval '1 hour', now(), interval '1 minute') AS time, 
	generate_series(1,10,1) AS device_id;



/*
 * Function to create a random numeric value between two numbers
 * 
 * NOTICE: We are using the type of 'numeric' in this function in order
 * to visually return values that look like integers (no decimals) and 
 * floats (with decimals). However, if inserted into a table, the assumption
 * is that the appropriate column type is used. The `numeric` type is often
 * not the correct or most efficient type for storing numbers in a table.
 */
CREATE OR REPLACE FUNCTION random_between(min_val numeric, max_val numeric, round_to int=0) 
   RETURNS numeric AS
$$
 DECLARE
 	value NUMERIC = random()* (min_val - max_val) + max_val;
BEGIN
   IF round_to = 0 THEN 
	 RETURN floor(value);
   ELSE 
   	 RETURN round(value,round_to);
   END IF;
END
$$ language 'plpgsql';


/*
 * Isn't that nice and clean?
 */
SELECT
  time,
  device_id,
  random_between(3,100, 4) AS cpu,
  random_between(28,83) AS temperature_c
FROM 
	generate_series(now() - interval '1 hour', now(), interval '1 minute') AS time, 
	generate_series(1,10,1) AS device_id;
	

/*
 * What about text data?
 */
WITH symbols(characters) as (VALUES ('ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789 {}')),
w1 AS (
	SELECT string_agg(substr(characters, (random() * length(characters) + 1) :: INTEGER, 1), '') r_text, 'g1' AS idx
	FROM symbols,
		generate_series(1,10) as word(chr_idx) -- word length
	GROUP BY idx)
SELECT
  time,
  device_id,
  random_between(3,100, 4) AS cpu,
  random_between(28,83) AS temperature_c,
  w1.r_text AS note
FROM w1, generate_series(now() - interval '1 hour', now(), interval '1 minute') AS time, 
	generate_series(1,10,1) AS device_id
ORDER BY 1,2;


/*
 * Create text of varying lengths
 */
CREATE OR REPLACE FUNCTION random_text(min_val INT=0, max_val INT=50) 
   RETURNS text AS
$$
DECLARE 
	word_length NUMERIC  = floor(random() * (max_val-min_val) + min_val)::INTEGER;
	random_word TEXT = '';
BEGIN
	-- only if the word length we get has a remainder after being divided by 5. This gives
	-- some randomness to when words are produced or not. Adjust for your tastes.
	IF(word_length % 5) > 1 THEN
	SELECT * INTO random_word FROM (
		WITH symbols(characters) AS (VALUES ('ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789 '))
		SELECT string_agg(substr(characters, (random() * length(characters) + 1) :: INTEGER, 1), ''), 'g1' AS idx
		FROM symbols
		JOIN generate_series(1,word_length) AS word(chr_idx) on 1 = 1 -- word length
		group by idx) a;
	END IF;
	RETURN random_word;
END
$$ LANGUAGE 'plpgsql';


/*
 * Again, using this function makes it much cleaner 
 * and easier to repeat
 */
SELECT
  time,
  device_id,
  random_between(3,100, 4) AS cpu,
  random_between(28,83) AS temperature_c,
  random_text(2,10) AS note
FROM generate_series(now() - interval '1 hour', now(), interval '1 minute') AS time, 
	generate_series(1,10,1) AS device_id
ORDER BY 1,2;


/*
 * Finally, something like JSON
 */
WITH fake_json AS (
SELECT json_object_agg(key, random_between(1,10)) as json_data
    FROM unnest(array['a', 'b']) as u(key))
  SELECT json_data, generate_series(1,5) FROM fake_json;
  
/*
 * Create the random function
 * 
 * If no values are passed in, it will contain three objects
 * with values between 0 and 10
 */
CREATE OR REPLACE FUNCTION random_json(keys TEXT[]='{"a","b","c"}',min_val NUMERIC = 0, max_val NUMERIC = 10) 
   RETURNS JSON AS
$$
DECLARE 
	random_val NUMERIC  = floor(random() * (max_val-min_val) + min_val)::INTEGER;
	random_json JSON = NULL;
BEGIN
	-- again, this adds some randomness into the results. Remove or modify if this
	-- isn't useful for your situation
	if(random_val % 5) > 1 then
		SELECT * INTO random_json FROM (
			SELECT json_object_agg(key, random_between(min_val,max_val)) as json_data
	    		FROM unnest(keys) as u(key)
		) json_val;
	END IF;
	RETURN random_json;
END
$$ LANGUAGE 'plpgsql';

/*
 * Because of the default values...
 */
SELECT random_json();

/*
 * Join it to a set of generate_series data
 */
SELECT device_id, random_json() FROM generate_series(1,5) device_id;


/*
 * Putting it all together, three different functions joined
 * with a time series set and a device_id set
 */
SELECT
  time,
  device_id,
  random_between(3,100, 4) AS cpu,
  random_between(28,83) AS temperature_c,
  random_text(2,10) AS note,
  random_json(ARRAY['building','rack'],1,20) device_location
FROM generate_series(now() - interval '1 month', now(), interval '1 minute') AS time, 
	generate_series(1,10,1) AS device_id
ORDER BY 1,2;

/*
 * There is one problem with using random() - over time,
 * random still averages back to the center over thousands
 * of samples
 */
WITH test_rows AS (
	SELECT
	  time,
	  device_id,
	  random_between(3,200, 4) AS cpu,
	  random_between(28,83) AS temperature_c,
	  random_text(2,10) AS note,
	  random_json(ARRAY['building','rack'],1,20) device_location
	FROM generate_series(now() - interval '1 hour', now(), interval '1 minute') AS time, 
		generate_series(1,10,1) AS device_id
	ORDER BY 1,2
)
SELECT avg(cpu) avg_cpu, avg(temperature_c) avg_temp FROM test_rows;

/*
 **********************************************
 * Part 3: Using the results to create increasing data
 ********************************************** 
 */

/*
 * row_number() over()
 */
SELECT ts, row_number() over(order by ts) AS rownum
FROM generate_series('2022-01-01','2022-01-05',INTERVAL '1 day') ts;

/*
 * vs. using WITH ORDINALITY
 */
SELECT ts AS time, rownum
FROM generate_series('2022-01-01','2022-01-05',INTERVAL '1 day') WITH ORDINALITY AS t(ts,rownum);

