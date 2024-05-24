--DROP TABLE payment2;

SELECT to_char(payment_date,'YY-MM') AS payment_month, count(*)
FROM payment
GROUP BY 1
ORDER BY 1 desc;

CREATE TABLE public.payment2 (
	payment_id int4 DEFAULT nextval('payment_payment_id_seq'::regclass) NOT NULL,
	customer_id int4 NOT NULL,
	rental_id int4 NOT NULL,
	amount numeric(5, 2) NOT NULL,
	payment_date timestamptz NOT NULL,
	CONSTRAINT payment2_pkey PRIMARY KEY (payment_date,payment_id)
)
PARTITION BY RANGE (payment_date);


/*
 * Create relevant table partitions
 * 
 * In reality, you don't want to do this manually. Either use
 * a script that runs periodically to do this, or use an
 * extention like pg_partman to automate this.
 */

CREATE TABLE payment2_y2024m01 PARTITION OF payment2
	FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE payment2_y2024m02 PARTITION OF payment2
	FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

CREATE TABLE payment2_y2024m03 PARTITION OF payment2
	FOR VALUES FROM ('2024-03-01') TO ('2024-04-01');

CREATE TABLE payment2_y2024m04 PARTITION OF payment2
	FOR VALUES FROM ('2024-04-01') TO ('2024-05-01');

CREATE TABLE payment2_y2024m05 PARTITION OF payment2
	FOR VALUES FROM ('2024-05-01') TO ('2024-06-01');


INSERT INTO payment2
	SELECT * FROM payment WHERE payment_date >= '2024-01-01';

/*
 * Partition exclusion
 */
EXPLAIN ANALYZE 
SELECT avg(amount) FROM payment WHERE payment_date > '2024-03-19';

EXPLAIN ANALYZE 
SELECT avg(amount) FROM payment2 WHERE payment_date > '2024-03-19';

EXPLAIN ANALYZE 
SELECT avg(amount) FROM payment2 WHERE payment_date > now()-'1 months'::interval;


/*
 * Data Retention
 */
DROP TABLE payment2_y2024m01;

EXPLAIN ANALYZE 
SELECT avg(amount) FROM payment2 WHERE payment_date > '2024-01-01';

ALTER TABLE payment2 DETACH PARTITION payment2_y2024m02;

/*
 * Attaching a partition must have
 */
ALTER TABLE payment2 ATTACH PARTITION payment2_y2024m02
	FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

/*
 * Index creattion
 */
CREATE INDEX payment2_rental_id_idx ON public.payment2 USING btree (rental_id);
CREATE INDEX payment2_payment_date_customer_id_idx 
	ON public.payment2 USING btree (payment_date,customer_id);

/*
 * Modifying a partitioned table
 */
ALTER TABLE payment2_y2024m03 ADD COLUMN status text;

ALTER TABLE payment2 ADD COLUMN status TEXT;

