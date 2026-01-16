-- ============================================================
-- PATHOLOGICAL QUERY EXAMPLES
-- Queries that demonstrate common query planner problems
-- ============================================================

-- Pattern 1: EXTERNAL MERGE/SORT OPERATION:
-- Look for:
--    - "external merge   Disk: size_in_kb"
--    - when multiple workers are involved, divide total

-- SET work_mem = '48MB';

EXPLAIN (ANALYZE,buffers)
SELECT r.rental_id, r.customer_id, r.store_id, r.inventory_id,
       p.amount, p.payment_date, c.full_name, c.email
FROM bluebox.rental r
JOIN bluebox.payment p ON p.rental_id = r.rental_id
JOIN bluebox.customer c ON c.customer_id = r.customer_id
WHERE r.store_id <= 20
   OR c.store_id >= 100 AND c.store_id <= 105
ORDER BY p.amount DESC, r.customer_id, p.payment_date;

-- FINDING THESE QUERIES
--  - look in auto_explain plans
--      "Sort Method: external merge  Disk: 30936kB"
--      "Worker 0:  Sort Method: external merge  Disk: 30032kB"
--      "Worker 1:  Sort Method: external merge  Disk: 29760kB"
--  - examine pg_stat_statements for consisten "temp" offenders 
/*
  SELECT 
    queryid,
    calls,
    round(mean_exec_time::numeric, 0) as mean_ms,
    temp_blks_written / NULLIF(calls, 0) as temp_blks_per_call,
    pg_size_pretty((temp_blks_written / NULLIF(calls, 0)) * 8192::bigint) 
        as temp_per_call,
    left(query, 60) as query_preview
   FROM pg_stat_statements
   WHERE temp_blks_written > 1000  -- At least 8MB spilled
   ORDER BY temp_blks_per_call DESC NULLS LAST
   LIMIT 10;
*/


-- ============================================================
-- PATTERN 2: WRONG INDEX DUE TO ORDER BY
-- 
-- The planner chooses an index to satisfy ORDER BY, but that
-- index requires scanning many rows and filtering them out.
-- A better plan would filter first, then sort the small result.
-- 
-- Fix: Add "+0" to the ORDER BY column to disable index usage
-- ============================================================

-- SLOW VERSION: Uses rental_pkey to avoid sort, but scans 67K+ rows
-- Execution: ~33ms, Buffers: ~4,700
EXPLAIN (ANALYZE, BUFFERS)
SELECT r.rental_id, r.rental_period, r.customer_id, c.full_name
FROM bluebox.rental r
JOIN bluebox.customer c ON r.customer_id = c.customer_id
WHERE r.store_id = 50
  AND lower(r.rental_period) > '2025-01-01'
ORDER BY r.rental_id DESC
LIMIT 100;

-- FAST VERSION: Uses store_id and date indexes, sorts small result in memory
-- Execution: ~20ms, Buffers: ~1,000
-- The "+0" prevents the planner from using rental_pkey for ordering
EXPLAIN (ANALYZE, BUFFERS)
SELECT r.rental_id, r.rental_period, r.customer_id, c.full_name
FROM bluebox.rental r
JOIN bluebox.customer c ON r.customer_id = c.customer_id
WHERE r.store_id = 50
  AND lower(r.rental_period) > '2025-01-01'
ORDER BY r.rental_id + 0 DESC  -- "+0" disables index-for-ORDER-BY
LIMIT 100;

-- WHY IT WORKS:
-- Original: Scans rental_pkey backwards, filters 66K+ rows to find 100 matches
-- Fixed: BitmapAnd on store_id + date indexes, gets ~3K rows, quicksorts in memory
-- Result: 5x fewer buffer reads, 37% faster




-- ============================================================
-- PATTERN 3: INEFFICIENT NESTED LOOP (Correlated Subquery)
-- 
-- A correlated subquery in the WHERE clause forces the planner
-- to re-execute the subquery for every row in the outer query.
-- This causes repeated scans of the same tables.
-- 
-- Fix: Use a MATERIALIZED CTE to compute the result once
-- ============================================================

-- SLOW VERSION: Correlated subquery re-runs for each customer
-- Execution: ~5,300ms, Buffers: ~5.7M
-- The subquery scans the customer table 219 times!
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.customer_id, c.full_name, c.store_id, customer_rentals.cnt
FROM bluebox.customer c
JOIN (
    SELECT customer_id, count(*) as cnt
    FROM bluebox.rental
    GROUP BY customer_id
) customer_rentals ON c.customer_id = customer_rentals.customer_id
WHERE customer_rentals.cnt > (
    -- This subquery runs once PER ROW in the outer query!
    SELECT avg(cnt) FROM (
        SELECT count(*) as cnt
        FROM bluebox.rental r2
        JOIN bluebox.customer c2 ON r2.customer_id = c2.customer_id
        WHERE c2.store_id = c.store_id  -- Correlation: references outer query
        GROUP BY r2.customer_id
    ) store_avg
)
LIMIT 100;

-- FAST VERSION: Compute aggregates once using MATERIALIZED CTEs
-- Execution: ~1,400ms, Buffers: ~100K
EXPLAIN (ANALYZE, BUFFERS)
WITH customer_rental_counts AS MATERIALIZED (
    -- Compute rental counts per customer ONCE
    SELECT customer_id, count(*) as cnt
    FROM bluebox.rental
    GROUP BY customer_id
),
store_averages AS MATERIALIZED (
    -- Compute average rentals per store ONCE
    SELECT c.store_id, avg(crc.cnt) as avg_rentals
    FROM bluebox.customer c
    JOIN customer_rental_counts crc ON c.customer_id = crc.customer_id
    GROUP BY c.store_id
)
SELECT c.customer_id, c.full_name, c.store_id, crc.cnt
FROM bluebox.customer c
JOIN customer_rental_counts crc ON c.customer_id = crc.customer_id
JOIN store_averages sa ON c.store_id = sa.store_id
WHERE crc.cnt > sa.avg_rentals
LIMIT 100;

-- WHY IT WORKS:
-- Original: SubPlan executes 219 times, each scanning 186K customers
-- Fixed: CTEs compute each aggregate exactly once, then join
-- Result: 56x fewer buffer reads, 4x faster


-- ============================================================
-- SUMMARY: IDENTIFYING THESE PATTERNS IN EXPLAIN OUTPUT
-- ============================================================

-- EXTERNAL MERGE/SORT OPERATION:
-- Look for:
--   - "External" operations in the plan
--   - The amount of disk logged is the amount of additional
--     disk needed. Start by adding this to work_mem and then adjust
--   - Consider setting this per connection for specific queries
--   - For regular jobs that might benefit from an increased setting,
--     (like nightly batch processing), consider running as a specific
--     role and giving that role more work_mem by default through
--     ALTER ROLE...

-- WRONG INDEX DUE TO ORDER BY:
-- Look for:
--   - Index Scan on a primary key or sort column
--   - "Filter:" with high "Rows Removed by Filter"
--   - The index doesn't match the WHERE clause columns

-- INEFFICIENT NESTED LOOP:
-- Look for:
--   - "SubPlan" with high "loops=" count
--   - Same table being scanned repeatedly inside the loop
--   - Massive buffer counts relative to actual rows returned
--   - Correlation: subquery references columns from outer query




