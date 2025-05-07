--CREATE DATABASE obrc;

CREATE UNLOGGED TABLE obrc
(
  station_name VARCHAR(26),
  measurement  NUMERIC(3,1)
);

ALTER TABLE obrc SET (parallel_workers=16);

-- this took ~5.5 minutes in a single table
COPY obrc(station_name, measurement)
 FROM '/tmp/measurements.txt'
 WITH
 (
  FORMAT CSV,
  DELIMITER ';'
 );

SELECT * FROM obrc LIMIT 20;

-- This will take a very long time to complete
SELECT count(*) FROM obrc;

ANALYZE obrc;

-- If ANALYZE is up to date
SELECT reltuples::numeric as count
FROM pg_class
WHERE relname='obrc';

EXPLAIN analyze
SELECT
  station_name,
  MIN(measurement) AS min_measurement,
  ROUND(AVG(measurement),1) AS mean_measurement,
  MAX(measurement) AS max_measurement
 FROM obrc
 GROUP BY station_name
 ORDER BY station_name;


EXPLAIN analyze
SELECT
  '{' ||
    STRING_AGG(station_name || '=' || min_measurement || '/' || mean_measurement || '/' || max_measurement, ', ' ORDER BY station_name) ||
  '}' AS result
 FROM
  (SELECT station_name,
          MIN(measurement) AS min_measurement,
          ROUND(AVG(measurement), 1) AS mean_measurement,
          MAX(measurement) AS max_measurement
    FROM obrc
     GROUP BY station_name
  );

-- partitioned by station name
CREATE UNLOGGED TABLE obrc_partitioned
(
  station_name VARCHAR(26),
  measurement  NUMERIC(3,1)
) PARTITION BY hash(station_name);

TRUNCATE obrc_partitioned;

CREATE UNLOGGED TABLE obrc_p0
PARTITION OF obrc_partitioned 
FOR VALUES WITH (modulus 10, remainder 0);

CREATE UNLOGGED TABLE obrc_p1
PARTITION OF obrc_partitioned 
FOR VALUES WITH (modulus 10, remainder 1);

CREATE UNLOGGED TABLE obrc_p2
PARTITION OF obrc_partitioned 
FOR VALUES WITH (modulus 10, remainder 2);

CREATE UNLOGGED TABLE obrc_p3
PARTITION OF obrc_partitioned 
FOR VALUES WITH (modulus 10, remainder 3);

CREATE UNLOGGED TABLE obrc_p4
PARTITION OF obrc_partitioned 
FOR VALUES WITH (modulus 10, remainder 4);

CREATE UNLOGGED TABLE obrc_p5
PARTITION OF obrc_partitioned 
FOR VALUES WITH (modulus 10, remainder 5);

CREATE UNLOGGED TABLE obrc_p6
PARTITION OF obrc_partitioned 
FOR VALUES WITH (modulus 10, remainder 6);

CREATE UNLOGGED TABLE obrc_p7
PARTITION OF obrc_partitioned 
FOR VALUES WITH (modulus 10, remainder 7);

CREATE UNLOGGED TABLE obrc_p8
PARTITION OF obrc_partitioned 
FOR VALUES WITH (modulus 10, remainder 8);

CREATE UNLOGGED TABLE obrc_p9
PARTITION OF obrc_partitioned 
FOR VALUES WITH (modulus 10, remainder 9);

-- This doesn't make a difference because COPY is 
-- single threaded
COPY obrc_partitioned(station_name, measurement)
 FROM '/tmp/measurements.txt'
 WITH
 (
  FORMAT CSV,
  DELIMITER ';'
 );

EXPLAIN analyze
SELECT
  station_name,
  MIN(measurement) AS min_measurement,
  ROUND(AVG(measurement),1) AS mean_measurement,
  MAX(measurement) AS max_measurement
 FROM obrc_partitioned
 GROUP BY station_name
 ORDER BY station_name;


EXPLAIN analyze
SELECT
  '{' ||
    STRING_AGG(station_name || '=' || min_measurement || '/' || mean_measurement || '/' || max_measurement, ', ' ORDER BY station_name) ||
  '}' AS result
 FROM
  (SELECT station_name,
          MIN(measurement) AS min_measurement,
          ROUND(AVG(measurement), 1) AS mean_measurement,
          MAX(measurement) AS max_measurement
    FROM obrc_partitioned
     GROUP BY station_name
  );

 /*
  * DuckDB
  * Stop Postgres Container
  * 
  * 
  */
 .duckdb/cli/latest/duckdb
 .timer ON
 
 SELECT * FROM READ_CSV_AUTO('/tmp/measurements.txt') LIMIT 5;
 
 CREATE OR REPLACE TABLE measurements AS
        SELECT * FROM READ_CSV('/tmp/measurements.txt', 
        		header=false, 
        		columns= {'station_name':'VARCHAR','measurement':'double'}, 
        		delim=';');
        	
SELECT station_name, 
           MIN(measurement),
           AVG(measurement),
           MAX(measurement)
    FROM measurements 
    GROUP BY station_name
    LIMIT 5;

   
WITH src AS (SELECT station_name, 
                    MIN(measurement) AS min_measurement,
                    CAST(AVG(measurement) AS DECIMAL(8,1)) AS mean_measurement,
                    MAX(measurement) AS max_measurement
            FROM measurements 
            GROUP BY station_name
            LIMIT 5)
    SELECT station_name || '=' || CONCAT_WS('/',min_measurement, mean_measurement, max_measurement)
    FROM src;
 
   
/*
 * Stop Postgres container
 * Start pg_duckdb container
 */
ALTER SYSTEM SET duckdb.max_memory='10GB';
SELECT * FROM pg_available_extensions ORDER BY name;
CREATE EXTENSION pg_duckdb;
truncate obrc;

CREATE UNLOGGED TABLE obrc
(
  station_name VARCHAR(26),
  measurement  NUMERIC(3,1)
);


ALTER TABLE obrc SET (parallel_workers=16);

-- Can still use duckdb functions for reading data
SELECT count(*) FROM read_csv('/tmp/measurements.txt');

-- Not supported yet
INSERT INTO obrc
SELECT * FROM read_csv('/tmp/measurements.txt') r LIMIT 20;

/*
 * COPY DATA IN
 */
-- Works as normal
-- Back of napkind ~20% faster
COPY obrc(station_name, measurement)
 FROM '/tmp/measurements.txt'
 WITH
 (
  FORMAT CSV,
  DELIMITER ';'
 );

SELECT * FROM obrc LIMIT 10;
SELECT count(*) FROM obrc;
/*
 * On my Docker image this didn't have an impact
 * for some reason.
 */
SET duckdb.max_workers_per_postgres_scan=16;
SET duckdb.force_execution=TRUE;
SET duckdb.worker_threads=16;

EXPLAIN --analyze
SELECT
  station_name,
  MIN(measurement) AS min_measurement,
  ROUND(AVG(measurement),1) AS mean_measurement,
  MAX(measurement) AS max_measurement
 FROM obrc
 GROUP BY station_name
 ORDER BY station_name;




/*
 * Stop pg_duckdb container
 * Start pg_mooncake container
 */
CREATE DATABASE obrc;
CREATE EXTENSION pg_mooncake;

CREATE UNLOGGED TABLE obrc
(
  station_name VARCHAR(26),
  measurement  NUMERIC(3,1)
) USING columnstore;

-- not supported
ALTER TABLE obrc SET (parallel_workers=16);


-- Not supported yet
INSERT INTO obrc
SELECT station_name,measurement 
FROM mooncake.read_csv('/tmp/measurements.txt') 
	AS (station_name text, measurement float4) LIMIT 20;


-- Works as normal
-- Back of napkind ~20% faster
COPY obrc(station_name, measurement)
 FROM '/tmp/measurements.txt'
 WITH
 (
  FORMAT CSV,
  DELIMITER ';'
 );

-- This didn't seem to work while COPY was happening.
SELECT * FROM pg_stat_progress_copy;


select pg_size_pretty(pg_total_relation_size('obrc'));
SELECT count(*) FROM obrc;

 
SELECT * FROM obrc LIMIT 10;

--EXPLAIN analyze
SELECT
  station_name,
  MIN(measurement) AS min_measurement,
  ROUND(AVG(measurement),1) AS mean_measurement,
  MAX(measurement) AS max_measurement
 FROM obrc
 GROUP BY station_name
 ORDER BY station_name;

TRUNCATE obrc;

