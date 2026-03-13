-- =============================================================================
-- SECTION 13.1: FAIL-SAFE STORAGE MONITORING
-- =============================================================================
--
-- OBJECTIVE:
--   Understand Snowflake's Fail-Safe feature and learn how to monitor
--   Fail-Safe storage consumption at both account and table level.
--
-- WHAT YOU WILL LEARN:
--   1. What Fail-Safe is and how it differs from Time Travel
--   2. How to query account-level storage usage
--   3. How to query table-level storage metrics
--   4. How to identify tables with high Fail-Safe costs
--
-- FAIL-SAFE OVERVIEW (CRITICAL INTERVIEW TOPIC):
-- ┌──────────────────────┬──────────────────────────────────────────────────┐
-- │ Feature              │ Details                                          │
-- ├──────────────────────┼──────────────────────────────────────────────────┤
-- │ Purpose              │ Last-resort disaster recovery by Snowflake       │
-- │ Duration             │ 7 days (non-configurable)                        │
-- │ Who can access       │ Snowflake Support ONLY (not user-accessible)     │
-- │ When it starts       │ AFTER Time Travel period expires                 │
-- │ Applies to           │ Permanent tables ONLY                            │
-- │ Storage cost         │ Yes — additional storage beyond active + TT      │
-- │ Can be disabled      │ No (use transient/temporary tables to avoid it)  │
-- └──────────────────────┴──────────────────────────────────────────────────┘
--
-- DATA LIFECYCLE TIMELINE:
--   ┌────────────┐   ┌──────────────┐   ┌─────────────┐   ┌─────────────┐
--   │   Active   │──>│ Time Travel  │──>│  Fail-Safe  │──>│   Purged    │
--   │   (live)   │   │ (1-90 days)  │   │  (7 days)   │   │  (deleted)  │
--   └────────────┘   └──────────────┘   └─────────────┘   └─────────────┘
--         ↑                  ↑                  ↑
--    You query this    You can query      Only Snowflake
--    normally          via AT/BEFORE      Support can access
--
-- FAIL-SAFE vs TIME TRAVEL (INTERVIEW COMPARISON):
-- ┌──────────────────────┬──────────────────────┬──────────────────────────┐
-- │ Aspect               │ Time Travel          │ Fail-Safe                │
-- ├──────────────────────┼──────────────────────┼──────────────────────────┤
-- │ Duration             │ 0-90 days (config.)  │ 7 days (fixed)           │
-- │ User accessible      │ Yes (AT/BEFORE)      │ No (Snowflake only)      │
-- │ When active          │ Immediately          │ After TT expires         │
-- │ Configurable         │ Yes (per table)      │ No                       │
-- │ Table types          │ All types            │ Permanent only           │
-- │ Recovery method      │ Self-service query   │ Contact Snowflake Support│
-- │ Use case             │ Accidental changes   │ Disaster recovery        │
-- └──────────────────────┴──────────────────────┴──────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - Fail-Safe is Snowflake's last-resort recovery — you CANNOT access it yourself
--   - You must contact Snowflake Support to recover data from Fail-Safe
--   - Fail-Safe adds 7 days of storage cost for every permanent table
--   - Transient and temporary tables do NOT have Fail-Safe (cost savings)
--   - Monitor Fail-Safe costs via SNOWFLAKE.ACCOUNT_USAGE views
-- =============================================================================


-- =============================================
-- STEP 1: Account-level storage overview
-- =============================================
-- View total storage consumption broken down by type
SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.STORAGE_USAGE
ORDER BY USAGE_DATE DESC;


-- =============================================
-- STEP 2: Account-level storage in GB (formatted)
-- =============================================
-- Convert bytes to GB for readability
SELECT
    USAGE_DATE,
    STORAGE_BYTES   / (1024*1024*1024) AS STORAGE_GB,
    STAGE_BYTES     / (1024*1024*1024) AS STAGE_GB,
    FAILSAFE_BYTES  / (1024*1024*1024) AS FAILSAFE_GB
FROM SNOWFLAKE.ACCOUNT_USAGE.STORAGE_USAGE
ORDER BY USAGE_DATE DESC;

-- KEY COLUMNS:
--   STORAGE_BYTES   = Active data storage across all tables
--   STAGE_BYTES     = Data stored in internal stages
--   FAILSAFE_BYTES  = Data retained in the Fail-Safe period


-- =============================================
-- STEP 3: Table-level storage breakdown
-- =============================================
-- View raw storage metrics for every table in the account
SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS;


-- =============================================
-- STEP 4: Table-level storage in GB (formatted)
-- =============================================
-- Identify which tables consume the most Fail-Safe storage
SELECT
    ID,
    TABLE_NAME,
    TABLE_SCHEMA,
    ACTIVE_BYTES       / (1024*1024*1024) AS STORAGE_USED_GB,
    TIME_TRAVEL_BYTES  / (1024*1024*1024) AS TIME_TRAVEL_STORAGE_USED_GB,
    FAILSAFE_BYTES     / (1024*1024*1024) AS FAILSAFE_STORAGE_USED_GB
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
ORDER BY FAILSAFE_STORAGE_USED_GB DESC;


-- =============================================
-- STEP 5: Comprehensive storage analysis
-- =============================================
-- Show total storage breakdown with percentages for cost optimization
SELECT
    TABLE_CATALOG || '.' || TABLE_SCHEMA || '.' || TABLE_NAME AS FULL_TABLE_NAME,
    ACTIVE_BYTES       / (1024*1024*1024) AS ACTIVE_GB,
    TIME_TRAVEL_BYTES  / (1024*1024*1024) AS TIME_TRAVEL_GB,
    FAILSAFE_BYTES     / (1024*1024*1024) AS FAILSAFE_GB,
    (ACTIVE_BYTES + TIME_TRAVEL_BYTES + FAILSAFE_BYTES)
                       / (1024*1024*1024) AS TOTAL_GB,
    IS_TRANSIENT,
    CASE
        WHEN ACTIVE_BYTES > 0
        THEN ROUND(FAILSAFE_BYTES * 100.0 / ACTIVE_BYTES, 2)
        ELSE 0
    END AS FAILSAFE_PCT_OF_ACTIVE
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
WHERE ACTIVE_BYTES > 0
ORDER BY FAILSAFE_GB DESC;


-- =============================================================================
-- CONCEPT GAP: WHEN TO USE FAIL-SAFE RECOVERY
-- =============================================================================
-- Fail-Safe is designed for DISASTER recovery scenarios where:
--   1. Time Travel has already expired (data is past the retention window)
--   2. A critical table was accidentally dropped and missed the TT window
--   3. Data corruption occurred and wasn't detected within the TT period
--
-- TO REQUEST FAIL-SAFE RECOVERY:
--   1. File a support case with Snowflake (severity depends on urgency)
--   2. Provide: account name, database, schema, table name
--   3. Specify the approximate time of the data loss
--   4. Snowflake engineers will attempt recovery (not guaranteed)
--   5. Recovery may take hours to days depending on data size
--
-- IMPORTANT: Fail-Safe recovery is BEST-EFFORT, not guaranteed.
-- Always design your data pipelines with proper Time Travel retention
-- as your primary recovery mechanism.
-- =============================================================================


-- =============================================================================
-- CONCEPT GAP: REDUCING FAIL-SAFE STORAGE COSTS
-- =============================================================================
-- Fail-Safe storage cannot be configured or disabled for permanent tables.
-- To reduce costs, consider these strategies:
--
-- 1. USE TRANSIENT TABLES for staging/ETL data:
--    CREATE TRANSIENT TABLE staging_data (...);
--    -- No Fail-Safe = lower storage cost
--
-- 2. USE TEMPORARY TABLES for session-scoped scratch data:
--    CREATE TEMPORARY TABLE temp_calc (...);
--    -- No Fail-Safe, auto-dropped at session end
--
-- 3. MINIMIZE UNNECESSARY PERMANENT TABLES:
--    -- Only use permanent tables for production/critical data
--    -- Use transient for development, testing, staging
--
-- 4. DROP UNUSED TABLES promptly:
--    -- Dropped tables still incur Fail-Safe costs for 7 days
--    -- But after 7 days, storage is fully released
--
-- STORAGE COST COMPARISON:
-- ┌──────────────────────┬──────────┬────────────┬────────────┐
-- │ Table Type           │ Active   │ Time Travel│ Fail-Safe  │
-- ├──────────────────────┼──────────┼────────────┼────────────┤
-- │ Permanent            │ Yes      │ 0-90 days  │ 7 days     │
-- │ Transient            │ Yes      │ 0-1 day    │ None       │
-- │ Temporary            │ Yes      │ 0-1 day    │ None       │
-- └──────────────────────┴──────────┴────────────┴────────────┘
-- =============================================================================
