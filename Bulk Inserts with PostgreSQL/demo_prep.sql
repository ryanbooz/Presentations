/*
 * Create a table to hold our fake, bulk data.
 * 
 * This will be the "source" table for our testing
 */
DROP TABLE IF EXISTS bulk_data;

CREATE TABLE bulk_data (
	time timestamptz,
	device_id int,
	val1 int,
	val2 int,
	val3 int,
	val4 int,
	val5 float8,
	val6 float8,
	val7 float8,
	val8 TEXT,
	val9 text
);

/*
 * These functions allow us to create random values and text for the generated data
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


CREATE OR REPLACE FUNCTION random_text(min_val INT=0, max_val INT=50) 
   RETURNS text AS
$$
DECLARE 
	word_length NUMERIC  = floor(random() * (max_val-min_val) + min_val)::INTEGER;
	random_word TEXT = '';
BEGIN
	-- only if the word length we get has a remainder after being divided by 5. This gives
	-- some randomness to when words are produced or not. Adjust for your tastes.
	SELECT * INTO random_word FROM (
		WITH symbols(characters) AS (VALUES ('ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789 '))
		SELECT string_agg(substr(characters, (random() * length(characters) + 1) :: INTEGER, 1), ''), 'g1' AS idx
		FROM symbols
		JOIN generate_series(1,word_length) AS word(chr_idx) on 1 = 1 -- word length
		group by idx) a;
	RETURN random_word;
END
$$ LANGUAGE 'plpgsql';


/*
 * Insert data into our source table. Adjust the generate_series parameters to 
 * increase or decrease the number of rows. Increasing rows will take longer
 * to generate.
 * 
 * These value should create ~1 million rows.
 */
INSERT INTO bulk_data 
SELECT time, device_id, 
	random_between(1,100) val1,
	random_between(1,1000) val2,
	random_between(1,10000) val3,
	random_between(1,100000) val4,
	random_between(0,100,2) val5,
	random_between(0,100,5) val6,
	random_between(0,10000,7) val7,
	random_text(1,25) val8,
	random_text(1,50) val9
  FROM 
		generate_series('2021-01-01', '2021-01-02',INTERVAL '5 minute') time,
		generate_series(1,3500) device_id


		
		
/*
 * Create a copy of the original table with a new name.
 * 
 * This will receive our data for each test.
 */		
CREATE TABLE bulk_test (
	time timestamptz,
	device_id int,
	val1 int,
	val2 int,
	val3 int,
	val4 int,
	val5 float8,
	val6 float8,
	val7 float8,
	val8 TEXT,
	val9 text
);
