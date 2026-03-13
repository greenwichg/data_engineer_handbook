-- =============================================================================
-- SECTION 12.84: TIME TRAVEL STORAGE COST
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to monitor and manage the storage costs associated with
--   Snowflake's Time Travel feature using account usage views.
--
-- WHAT YOU WILL LEARN:
--   1. How Time Travel consumes storage
--   2. Querying account-level and table-level storage metrics
--   3. Identifying tables with high Time Travel storage costs
--   4. Strategies to optimize Time Travel storage
--
-- HOW TIME TRAVEL STORAGE WORKS (INTERVIEW TOPIC):
-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │ When data is modified or deleted, Snowflake keeps the OLD version of    │
-- │ the data in Time Travel storage. This additional storage accrues for    │
-- │ the duration of the retention period.                                   │
-- │                                                                         │
-- │ Storage breakdown for a table:                                          │
-- │   ACTIVE_BYTES        = Current data in the table                       │
-- │   TIME_TRAVEL_BYTES   = Historical data kept for Time Travel            │
-- │   FAILSAFE_BYTES      = Data kept in Fail-safe (7 days, non-queryable) │
-- │   TOTAL_STORAGE       = ACTIVE + TIME_TRAVEL + FAILSAFE                │
-- └──────────────────────────────────────────────────────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - Time Travel data costs additional storage beyond active data
--   - Higher retention periods = higher storage costs
--   - Frequently updated tables have the highest Time Travel storage
--   - Use SNOWFLAKE.ACCOUNT_USAGE views to monitor storage
--   - Fail-safe is separate from Time Travel (7-day non-configurable)
-- =============================================================================


-- =============================================
-- STEP 1: Account-level storage overview
-- =============================================
-- View total storage consumption over time
SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.STORAGE_USAGE
ORDER BY USAGE_DATE DESC;

-- KEY COLUMNS:
--   USAGE_DATE           = Date of the measurement
--   STORAGE_BYTES        = Total active storage
--   STAGE_BYTES          = Storage used by stages
--   FAILSAFE_BYTES       = Storage used by Fail-safe


-- =============================================
-- STEP 2: Table-level storage breakdown
-- =============================================
-- View storage metrics for all tables
SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS;

-- KEY COLUMNS:
--   TABLE_NAME           = Name of the table
--   TABLE_SCHEMA         = Schema containing the table
--   TABLE_CATALOG        = Database containing the table
--   ACTIVE_BYTES         = Current data size
--   TIME_TRAVEL_BYTES    = Storage used by Time Travel data
--   FAILSAFE_BYTES       = Storage used by Fail-safe data
--   RETAINED_FOR_CLONE_BYTES = Storage retained for clones


-- =============================================
-- STEP 3: Identify high Time Travel storage
-- =============================================
-- Query showing storage in GB, sorted by highest usage
SELECT
    ID,
    TABLE_NAME,
    TABLE_SCHEMA,
    TABLE_CATALOG,
    ACTIVE_BYTES / (1024*1024*1024)      AS STORAGE_USED_GB,
    TIME_TRAVEL_BYTES / (1024*1024*1024)  AS TIME_TRAVEL_STORAGE_USED_GB
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
ORDER BY STORAGE_USED_GB DESC, TIME_TRAVEL_STORAGE_USED_GB DESC;


-- =============================================
-- STEP 4: Detailed storage analysis (bonus)
-- =============================================
-- Find tables where Time Travel storage exceeds active storage
-- (a sign of frequent updates/deletes)
SELECT
    TABLE_CATALOG || '.' || TABLE_SCHEMA || '.' || TABLE_NAME AS FULL_TABLE_NAME,
    ACTIVE_BYTES / (1024*1024*1024)                           AS ACTIVE_GB,
    TIME_TRAVEL_BYTES / (1024*1024*1024)                      AS TIME_TRAVEL_GB,
    FAILSAFE_BYTES / (1024*1024*1024)                         AS FAILSAFE_GB,
    (ACTIVE_BYTES + TIME_TRAVEL_BYTES + FAILSAFE_BYTES)
        / (1024*1024*1024)                                    AS TOTAL_GB,
    CASE
        WHEN ACTIVE_BYTES > 0
        THEN ROUND(TIME_TRAVEL_BYTES / ACTIVE_BYTES * 100, 2)
        ELSE 0
    END                                                       AS TT_TO_ACTIVE_RATIO_PCT
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
WHERE ACTIVE_BYTES > 0
ORDER BY TIME_TRAVEL_GB DESC;


-- =============================================================================
-- CONCEPT GAP: TIME TRAVEL vs FAIL-SAFE
-- =============================================================================
-- ┌──────────────────────┬──────────────────────────────────────────────────┐
-- │ Time Travel          │ Fail-Safe                                        │
-- ├──────────────────────┼──────────────────────────────────────────────────┤
-- │ User-accessible      │ Snowflake support only                           │
-- │ 0-90 days retention  │ Always 7 days (non-configurable)                 │
-- │ Query with AT/BEFORE │ Cannot query — disaster recovery only            │
-- │ Starts immediately   │ Starts AFTER Time Travel period ends             │
-- │ Configurable         │ Not configurable                                 │
-- │ All table types      │ Permanent tables only (not transient/temporary)  │
-- └──────────────────────┴──────────────────────────────────────────────────┘
--
-- TIMELINE EXAMPLE (90-day retention):
--   Day 0 ──────────────── Day 90 ──────── Day 97
--   |← Time Travel (user) →|← Fail-Safe →|← Data purged
--
-- TIMELINE EXAMPLE (1-day retention):
--   Day 0 ── Day 1 ──────── Day 8
--   |← TT →|← Fail-Safe →|← Data purged
-- =============================================================================


-- =============================================================================
-- CONCEPT GAP: OPTIMIZING TIME TRAVEL COSTS
-- =============================================================================
-- STRATEGIES TO REDUCE TIME TRAVEL STORAGE:
--
-- 1. LOWER RETENTION for non-critical tables:
--    ALTER TABLE staging_table SET DATA_RETENTION_TIME_IN_DAYS = 0;
--
-- 2. USE TRANSIENT TABLES for staging/temp data:
--    CREATE TRANSIENT TABLE staging_data (...);
--    -- Max 1-day retention, no Fail-safe storage
--
-- 3. USE TEMPORARY TABLES for session-scoped work:
--    CREATE TEMPORARY TABLE temp_calc (...);
--    -- Dropped automatically at end of session
--
-- 4. BATCH UPDATES instead of row-by-row:
--    -- Each DML creates a new micro-partition version
--    -- Fewer DMLs = less Time Travel data
--
-- 5. MINIMIZE RETENTION at schema/database level:
--    ALTER SCHEMA staging SET DATA_RETENTION_TIME_IN_DAYS = 1;
--
-- COST FORMULA (approximate):
--   Time Travel cost = changed_data_size × retention_days × storage_rate
--   Storage rate ≈ $23-40/TB/month (varies by cloud provider and region)
-- =============================================================================
