/*
 * -- Monitoring Database --
 * 
 * Remember that pg_stat_statements logs queries for the entire
 * PostgreSQL cluster. To avoid the monitoring queries below
 * showing up as part of your overall monitoring under normal
 * operations, it is advisable to create a separate monitoring
 * database within the cluster and filter that 'dbid' out in the 
 * monitoring queries.
 * 
 */

/*
 * Create a dedicated schema to hold the info
 */
CREATE SCHEMA IF NOT EXISTS statements_history;

/*
 * The snapshots table holds the cluster-wide values
 * each time an overall snapshot is taken. There is
 * no database or user information stored. This allows
 * you to create cluster dashboards for very fast, high-level
 * information on the trending state of the cluster.
 */
CREATE TABLE IF NOT EXISTS statements_history.snapshots (
    created timestamp with time zone NOT NULL,
    calls bigint NOT NULL,
    total_plan_time double precision NOT NULL,
    total_exec_time double precision NOT NULL,
    rows bigint NOT NULL,
    shared_blks_hit bigint NOT NULL,
    shared_blks_read bigint NOT NULL,
    shared_blks_dirtied bigint NOT NULL,
    shared_blks_written bigint NOT NULL,
    local_blks_hit bigint NOT NULL,
    local_blks_read bigint NOT NULL,
    local_blks_dirtied bigint NOT NULL,
    local_blks_written bigint NOT NULL,
    temp_blks_read bigint NOT NULL,
    temp_blks_written bigint NOT NULL,
    blk_read_time double precision NOT NULL,
    blk_write_time double precision NOT NULL,
    wal_records bigint NOT NULL,
    wal_fpi bigint NOT NULL,
    wal_bytes numeric NOT NULL,
    wal_position bigint NOT NULL,
    stats_reset timestamp with time zone NOT NULL,
    PRIMARY KEY (created)
);

COMMENT ON TABLE statements_history.snapshots IS
$$This table contains a full aggregate of the pg_stat_statements view
at the time of the snapshot. This allows for very fast queries that require
a very high level overview$$;

/*
 * To reduce the storage requirement of saving query statistics
 * at a consistent interval, we store the query text in a separate
 * table and join it as necessary. The queryid is the identifier
 * for each query across tables.
 */
CREATE TABLE IF NOT EXISTS statements_history.queries (
    queryid bigint NOT NULL,
    rolname text,
    datname text,
    query text,
    PRIMARY KEY (queryid, datname, rolname)
);

COMMENT ON TABLE statements_history.queries IS
$$This table contains all query text, this allows us to not repeatably store the query text$$;


/*
 * Finally, we store the individual statistics for each queryid
 * each time we take a snapshot. This allows you to dig into a
 * specific interval of time and see the snapshot-by-snapshot view
 * of query performance and resource usage
 */
CREATE TABLE IF NOT EXISTS statements_history.statements (
    created timestamp with time zone NOT NULL,
    queryid bigint NOT NULL,
    plans bigint NOT NULL,
    total_plan_time double precision NOT NULL,
    calls bigint NOT NULL,
    total_exec_time double precision NOT NULL,
    rows bigint NOT NULL,
    shared_blks_hit bigint NOT NULL,
    shared_blks_read bigint NOT NULL,
    shared_blks_dirtied bigint NOT NULL,
    shared_blks_written bigint NOT NULL,
    local_blks_hit bigint NOT NULL,
    local_blks_read bigint NOT NULL,
    local_blks_dirtied bigint NOT NULL,
    local_blks_written bigint NOT NULL,
    temp_blks_read bigint NOT NULL,
    temp_blks_written bigint NOT NULL,
    blk_read_time double precision NOT NULL,
    blk_write_time double precision NOT NULL,
    wal_records bigint NOT NULL,
    wal_fpi bigint NOT NULL,
    wal_bytes numeric NOT NULL,
    rolname text NOT NULL,
    datname text NOT NULL,
    PRIMARY KEY (created, queryid, rolname, datname),
    FOREIGN KEY (queryid, datname, rolname) REFERENCES statements_history.queries (queryid, datname, rolname) ON DELETE CASCADE
);


/*
 * These next statements create each fo these tables as
 * TimescaleDB hypertables to unlock automatic table partitioning
 * and other features like columnar compression and data retention.
 */
SELECT * FROM create_hypertable(
    'statements_history.snapshots',
    'created',
    create_default_indexes => false,
    chunk_time_interval => interval '4 weeks',
    migrate_data => true
);

SELECT * FROM create_hypertable(
    'statements_history.statements',
    'created',
    create_default_indexes => false,
    chunk_time_interval => interval '1 week',
    migrate_data => true
);

/*
* Enable hypertable compression on the statements
* hypertable. This will automatically compress chunks
* that are more than one week old. Adjust as appropriate.
*/
ALTER TABLE statements_history.statements SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'datname,rolname,queryid',
    timescaledb.compress_orderby = 'created'
);

SELECT add_compression_policy(
    'statements_history.statements',
    compress_after => interval '1 week',
    if_not_exists => true
);


/*
 * We need to fill the tables with data on a timed basis. This
 * can be done with TimescaleDB User-Defined Actions or other
 * tools like pg_cron.
 * 
 * This example procedure is specifically written for TimescaleDB
 * User Defined Actions. The inner SQL can be adapted for other
 * job scheduling sessions.
 */
CREATE OR REPLACE PROCEDURE statements_history.create_snapshot(
    job_id int,
    config jsonb
)
LANGUAGE plpgsql AS
$function$
DECLARE
    snapshot_time timestamp with time zone := now();
BEGIN
	/*
	 * This first CTE queries pg_stat_statements and joins
	 * to the roles and database table for more detail that
	 * we will store later.
	 */
    WITH statements AS (
        SELECT
            *
        FROM
            pg_stat_statements(true)
        JOIN
            pg_roles ON (userid=pg_roles.oid)
        JOIN
            pg_database ON (dbid=pg_database.oid)
    ), 
    /*
     * We then get the individual queries out of the result
     * and store the text and queryid separately to avoid
     * storing the query text often.
     */
    queries AS (
        INSERT INTO
            statements_history.queries (queryid, query, datname, rolname)
        SELECT
            queryid, query, datname, rolname
        FROM
            statements
        ON CONFLICT
            DO NOTHING
        RETURNING
            queryid
    ), 
    /*
     * This query SUMs all data from all queries and databases
     * to get high-level cluster statistics each time the snapshot
     * is taken.
     */
    snapshot AS (
        INSERT INTO
            statements_history.snapshots
        SELECT
            now(),
            sum(calls),
            sum(total_plan_time) AS total_plan_time,
            sum(total_exec_time) AS total_exec_time,
            sum(rows) AS rows,
            sum(shared_blks_hit) AS shared_blks_hit,
            sum(shared_blks_read) AS shared_blks_read,
            sum(shared_blks_dirtied) AS shared_blks_dirtied,
            sum(shared_blks_written) AS shared_blks_written,
            sum(local_blks_hit) AS local_blks_hit,
            sum(local_blks_read) AS local_blks_read,
            sum(local_blks_dirtied) AS local_blks_dirtied,
            sum(local_blks_written) AS local_blks_written,
            sum(temp_blks_read) AS temp_blks_read,
            sum(temp_blks_written) AS temp_blks_written,
            sum(blk_read_time) AS blk_read_time,
            sum(blk_write_time) AS blk_write_time,
            sum(wal_records) AS wal_records,
            sum(wal_fpi) AS wal_fpi,
            sum(wal_bytes) AS wal_bytes,
            pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0'),
            pg_postmaster_start_time()
        FROM
            statements
    )
    /*
     * And finally, we store the individual pg_stat_statement 
     * aggregated results for each query, for each snapshot time.
     */
    INSERT INTO
        statements_history.statements
    SELECT
        snapshot_time,
        queryid,
        plans,
        total_plan_time,
        calls,
        total_exec_time,
        rows,
        shared_blks_hit,
        shared_blks_read,
        shared_blks_dirtied,
        shared_blks_written,
        local_blks_hit,
        local_blks_read,
        local_blks_dirtied,
        local_blks_written,
        temp_blks_read,
        temp_blks_written,
        blk_read_time,
        blk_write_time,
        wal_records,
        wal_fpi,
        wal_bytes,
        rolname,
        datname
    FROM
        statements;

END;
$function$;

/*
* Check that the stored procedure works as expected
*/
CALL statements_history.create_snapshot(null, null);

EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM statements_history.statements;

/*
 * Add the recurring UDA that will create the snapshot.
 * 
 * As configured below, a snapshot will be taken every minute. This
 * should be adjusted for your use case, query load, server resources,
 * etc.
 * 
 * This job runs every minute. If you want to store data less often
 * adjust the interval in the statement below.
 */
SELECT add_job(
    'statements_history.create_snapshot',
    interval '1 minutes'
)
WHERE NOT EXISTS (
    SELECT
    FROM
        timescaledb_information.jobs
    WHERE
        proc_name='create_snapshot'
        AND proc_schema='statements_history'
);

/*
* Check that the job was created and is running
*/ 
SELECT * FROM timescaledb_information.jobs;

/*
 * This is provided as an example of how to change the 
 * schedule of the UDA if you want to modify the frequency
 * of snapshot capture later.
 *
 * This is an optional step ONLY to change the interval
*/
SELECT alter_job(
            job_id,
            schedule_interval => interval '3 minutes',
         	scheduled => false
        )
FROM
    timescaledb_information.jobs
WHERE
    proc_name='create_snapshot'
    AND proc_schema='statements_history';
   

/*************************************************
 *
 * These next few queries are examples of how to start
 * querying data at both the cluster and the individual
 * statement level. They can be used with a graphing tool
 * like Grafana with some minor modifications.
 *
 ************************************************/

/*
 * This CTE queries the snapshot table (full cluster statistics)
 * to get a high-level view of the cluster state.
 * 
 * We query each row with a LAG of the previous row to retrieve
 * the delta of each value to make it suitable for graphing.
 */
WITH deltas AS (
    SELECT
        created,
        extract('epoch' from created - lag(d.created) OVER (w)) AS delta_seconds,
        d.ROWS - lag(d.rows) OVER (w) AS delta_rows,
        d.total_plan_time - lag(d.total_plan_time) OVER (w) AS delta_plan_time,
        d.total_exec_time - lag(d.total_exec_time) OVER (w) AS delta_exec_time,
        d.calls - lag(d.calls) OVER (w) AS delta_calls,
        d.wal_bytes - lag(d.wal_bytes) OVER (w) AS delta_wal_bytes,
        stats_reset
    FROM
        statements_history.snapshots AS d
    WHERE
        created > now() - INTERVAL '2 hours'
    WINDOW
        w AS (PARTITION BY stats_reset ORDER BY created ASC)
)
SELECT
    created AS "time",
    delta_rows,
    delta_calls/delta_seconds AS calls,
    delta_plan_time/delta_seconds/1000 AS plan_time,
    delta_exec_time/delta_seconds/1000 AS exec_time,
    delta_wal_bytes/delta_seconds AS wal_bytes
FROM
    deltas
ORDER BY
    created ASC;   



/*
* Top 100 queries: Individual data for each query for a 
* specified time range, which is particularly useful for 
* zeroing in on a specific query in a tool like Grafana
*/
WITH snapshots AS (
    SELECT
        max,
        -- We need at least 2 snapshots to calculate a delta. If the dashboard is currently showing
        -- a period < 5 minutes, we only have 1 snapshot, and therefore no delta. In that CASE
        -- we take the snapshot just before this window to still come up with useful deltas
        CASE
            WHEN max = min
            THEN (SELECT max(created) FROM statements_history.snapshots WHERE created < min)
            ELSE min
        END AS min
    FROM (
        SELECT
            max(created),
            min(created)
        FROM
            statements_history.snapshots WHERE created > now() - '1 hour'::interval
            -- Grafana-based filter
            --statements_history.snapshots WHERE $__timeFilter(created)
        GROUP by
            stats_reset
        ORDER by
            max(created) DESC
        LIMIT 1
    ) AS max(max, min)
), deltas AS (
    SELECT
        rolname,
        datname,
        queryid,
        extract('epoch' from max(created) - min(created)) AS delta_seconds,
        max(total_exec_time) - min(total_exec_time) AS delta_exec_time,
        max(total_plan_time) - min(total_plan_time) AS delta_plan_time,
        max(calls) - min(calls) AS delta_calls,
        max(shared_blks_hit) - min(shared_blks_hit) AS delta_shared_blks_hit,
        max(shared_blks_read) - min(shared_blks_read) AS delta_shared_blks_read
    FROM
        statements_history.statements
    WHERE
        -- granted, this looks odd, however it helps the DecompressChunk Node tremendously,
        -- as without these distinct filters, it would aggregate first and then filter.
        -- Now it filters while scanning, which has a huge knock-on effect on the upper
        -- Nodes
        (created >= (SELECT min FROM snapshots) AND created <= (SELECT max FROM snapshots))
    GROUP BY
        rolname,
        datname,
        queryid
)
SELECT
    rolname,
    datname,
    queryid::text,
    delta_exec_time/delta_seconds/1000 AS exec,
    delta_plan_time/delta_seconds/1000 AS plan,
    delta_calls/delta_seconds AS calls,
    delta_shared_blks_hit/delta_seconds*8192 AS cache_hit,
    delta_shared_blks_read/delta_seconds*8192 AS cache_miss,
    query
FROM
    deltas
JOIN
    statements_history.queries USING (rolname,datname,queryid)
WHERE
    delta_calls > 1
    AND delta_exec_time > 1
    AND query ~* $$.*$$
ORDER BY
    delta_exec_time+delta_plan_time DESC
LIMIT 100;


   
/*
 * When you want to dig into an individual query, this takes
 * a similar approach to the "snapshot" query above, but for 
 * an individual query ID.
 */
WITH deltas AS (
    SELECT
        created,
        st.calls - lag(st.calls) OVER (query_w) AS delta_calls,
        st.plans - lag(st.plans) OVER (query_w) AS delta_plans,
        st.rows - lag(st.rows) OVER (query_w) AS delta_rows,
        st.shared_blks_hit - lag(st.shared_blks_hit) OVER (query_w) AS delta_shared_blks_hit,
        st.shared_blks_read - lag(st.shared_blks_read) OVER (query_w) AS delta_shared_blks_read,
        st.temp_blks_written - lag(st.temp_blks_written) OVER (query_w) AS delta_temp_blks_written,
        st.total_exec_time - lag(st.total_exec_time) OVER (query_w) AS delta_total_exec_time,
        st.total_plan_time - lag(st.total_plan_time) OVER (query_w) AS delta_total_plan_time,
        st.wal_bytes - lag(st.wal_bytes) OVER (query_w) AS delta_wal_bytes,
        extract('epoch' from st.created - lag(st.created) OVER (query_w)) AS delta_seconds
    FROM
        statements_history.statements AS st
    join
        statements_history.snapshots USING (created)
    WHERE
        -- Adjust filters to match your queryid and time range
        created > now() - interval '25 minutes'
        AND created < now() + interval '25 minutes'
        AND queryid={queryid}
    WINDOW
        query_w AS (PARTITION BY datname, rolname, queryid, stats_reset ORDER BY created)
)
SELECT
    created AS "time",
    delta_calls/delta_seconds AS calls,
    delta_plans/delta_seconds AS plans,
    delta_total_exec_time/delta_seconds/1000 AS exec_time,
    delta_total_plan_time/delta_seconds/1000 AS plan_time,
    delta_rows/nullif(delta_calls, 0) AS rows_per_query,
    delta_shared_blks_hit/delta_seconds*8192 AS cache_hit,
    delta_shared_blks_read/delta_seconds*8192 AS cache_miss,
    delta_temp_blks_written/delta_seconds*8192 AS temp_bytes,
    delta_wal_bytes/delta_seconds AS wal_bytes,
    delta_total_exec_time/nullif(delta_calls, 0) exec_time_per_query,
    delta_total_plan_time/nullif(delta_plans, 0) AS plan_time_per_plan,
    delta_shared_blks_hit/nullif(delta_calls, 0)*8192 AS cache_hit_per_query,
    delta_shared_blks_read/nullif(delta_calls, 0)*8192 AS cache_miss_per_query,
    delta_temp_blks_written/nullif(delta_calls, 0)*8192 AS temp_bytes_written_per_query,
    delta_wal_bytes/nullif(delta_calls, 0) AS wal_bytes_per_query
FROM
    deltas
WHERE
    delta_calls > 0
ORDER BY
    created ASC;