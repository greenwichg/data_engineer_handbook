-- =============================================================================
-- SECTION 5.34: QUERYING LOAD HISTORY
-- =============================================================================
--
-- OBJECTIVE:
--   Learn two ways to query data loading history in Snowflake:
--   INFORMATION_SCHEMA (database-level) and ACCOUNT_USAGE (global/account-level).
--
-- WHAT YOU WILL LEARN:
--   1. Querying load_history from INFORMATION_SCHEMA (real-time, 14 days)
--   2. Querying load_history from ACCOUNT_USAGE (all DBs, 365 days)
--   3. Filtering load history for auditing and troubleshooting
--
-- TWO SOURCES OF LOAD HISTORY:
-- ┌────────────────────────────────┬──────────────────────────────────────────┐
-- │ Source                         │ Characteristics                         │
-- ├────────────────────────────────┼──────────────────────────────────────────┤
-- │ INFORMATION_SCHEMA.LOAD_HISTORY│ - Scoped to CURRENT database only       │
-- │ (database-level)               │ - Real-time (no latency)                │
-- │                                │ - Retains data for 14 days              │
-- │                                │ - Requires database context (USE DB)    │
-- ├────────────────────────────────┼──────────────────────────────────────────┤
-- │ SNOWFLAKE.ACCOUNT_USAGE        │ - ALL databases in the account          │
-- │ .LOAD_HISTORY (account-level)  │ - 45-minute latency (not real-time)     │
-- │                                │ - Retains data for 365 days (1 year)    │
-- │                                │ - Requires ACCOUNTADMIN or granted role  │
-- └────────────────────────────────┴──────────────────────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - INFORMATION_SCHEMA: current DB, real-time, 14 days retention
--   - ACCOUNT_USAGE: all DBs, ~45 min latency, 365 days retention
--   - Filter by schema_name, table_name, error_count, date range
--   - ACCOUNT_USAGE requires elevated privileges
--
-- CONCEPT GAP FILLED - SNOWFLAKE METADATA LAYERS:
--   Snowflake has three metadata/monitoring layers:
--   1. INFORMATION_SCHEMA - Per-database, real-time, limited history
--   2. ACCOUNT_USAGE      - Account-wide, delayed, long history (in SNOWFLAKE DB)
--   3. ORGANIZATION_USAGE - Multi-account, org-level metrics
-- =============================================================================


-- =============================================
-- METHOD 1: INFORMATION_SCHEMA (Database-Level)
-- =============================================
-- Must set the database context first.

USE COPY_DB;

-- Query all load history for the current database
SELECT * FROM information_schema.load_history;

-- This returns:
--   SCHEMA_NAME, TABLE_NAME, LAST_LOAD_TIME, STATUS,
--   ROW_COUNT, ROW_PARSED, FIRST_ERROR_MESSAGE,
--   FIRST_ERROR_LINE_NUM, FIRST_ERROR_CHARACTER_POS,
--   FIRST_ERROR_COLUMN_NAME, ERROR_COUNT, ERROR_LIMIT,
--   FILE_NAME, PIPE_NAME, etc.

-- LIMITATION: Only shows load history for tables in COPY_DB.
-- Cannot see loads in other databases from here.


-- =============================================
-- METHOD 2: ACCOUNT_USAGE (Account-Level)
-- =============================================
-- Query load history across ALL databases in the account.
-- Requires ACCOUNTADMIN role or explicit grants.

SELECT * FROM snowflake.account_usage.load_history;

-- NOTE: This data has ~45 minute latency. A COPY that just ran
-- may not appear here yet. Use INFORMATION_SCHEMA for real-time.


-- =============================================
-- FILTERING EXAMPLES
-- =============================================

-- Filter by specific table and schema
SELECT *
FROM snowflake.account_usage.load_history
WHERE schema_name = 'PUBLIC'
  AND table_name  = 'ORDERS';

-- Filter for loads with errors
SELECT *
FROM snowflake.account_usage.load_history
WHERE schema_name = 'PUBLIC'
  AND table_name  = 'ORDERS'
  AND error_count > 0;

-- Filter by date range (loads older than 1 day)
SELECT *
FROM snowflake.account_usage.load_history
WHERE DATE(LAST_LOAD_TIME) <= DATEADD(days, -1, CURRENT_DATE);

-- CONCEPT GAP FILLED - MORE USEFUL LOAD HISTORY QUERIES:

-- Total rows loaded per day
-- SELECT
--     DATE(last_load_time) AS load_date,
--     table_name,
--     SUM(row_count) AS total_rows_loaded,
--     SUM(error_count) AS total_errors,
--     COUNT(*) AS num_load_operations
-- FROM snowflake.account_usage.load_history
-- WHERE last_load_time >= DATEADD(days, -30, CURRENT_DATE)
-- GROUP BY 1, 2
-- ORDER BY 1 DESC, 2;

-- Find tables with highest error rates
-- SELECT
--     table_name,
--     SUM(row_count) AS total_rows,
--     SUM(error_count) AS total_errors,
--     ROUND(SUM(error_count) * 100.0 / NULLIF(SUM(row_count), 0), 2) AS error_pct
-- FROM snowflake.account_usage.load_history
-- WHERE last_load_time >= DATEADD(days, -7, CURRENT_DATE)
-- GROUP BY table_name
-- HAVING total_errors > 0
-- ORDER BY error_pct DESC;

-- Load activity by hour (identify peak load times)
-- SELECT
--     HOUR(last_load_time) AS load_hour,
--     COUNT(*) AS num_loads,
--     SUM(row_count) AS total_rows
-- FROM snowflake.account_usage.load_history
-- WHERE last_load_time >= DATEADD(days, -7, CURRENT_DATE)
-- GROUP BY 1
-- ORDER BY 1;


-- =============================================================================
-- CONCEPT GAP: OTHER USEFUL ACCOUNT_USAGE VIEWS
-- =============================================================================
-- Besides load_history, ACCOUNT_USAGE has many useful views:
--
--   snowflake.account_usage.query_history       - All queries executed
--   snowflake.account_usage.warehouse_metering  - Warehouse credit usage
--   snowflake.account_usage.storage_usage       - Storage consumption
--   snowflake.account_usage.login_history       - User login attempts
--   snowflake.account_usage.access_history      - Column-level access audit
--   snowflake.account_usage.copy_history        - Detailed COPY metadata
--
-- INTERVIEW TIP: COPY_HISTORY (in ACCOUNT_USAGE) provides even more detail
-- than LOAD_HISTORY, including pipe information for Snowpipe loads.
-- =============================================================================
