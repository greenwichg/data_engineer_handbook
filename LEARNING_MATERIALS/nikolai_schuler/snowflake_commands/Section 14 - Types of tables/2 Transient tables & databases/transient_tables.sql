-- =============================================================================
-- SECTION 14.2: TRANSIENT TABLES AND DATABASES
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to create and use transient tables, understand their Time Travel
--   limitations, the absence of Fail-Safe, and inheritance behavior when
--   tables are created inside transient schemas.
--
-- WHAT YOU WILL LEARN:
--   1. Creating transient tables and schemas with the TRANSIENT keyword
--   2. Time Travel limitations (0-1 day only)
--   3. No Fail-Safe period — reduced storage costs
--   4. Inheritance: tables in a transient schema are automatically transient
--   5. UNDROP behavior when retention is set to 0
--
-- TRANSIENT TABLE CHARACTERISTICS:
-- ┌──────────────────────┬──────────────────────────────────────────────────┐
-- │ Feature              │ Details                                          │
-- ├──────────────────────┼──────────────────────────────────────────────────┤
-- │ Keyword              │ CREATE TRANSIENT TABLE ...                       │
-- │ Time Travel          │ 0-1 day only (cannot exceed 1 day)              │
-- │ Fail-Safe            │ None (0 days)                                    │
-- │ Storage cost         │ Lower than permanent (no Fail-Safe overhead)     │
-- │ Persistence          │ Until explicitly dropped (survives sessions)     │
-- │ Visibility           │ All sessions, all users (with grants)            │
-- │ UNDROP support       │ Yes, but only if retention > 0                   │
-- │ Best for             │ ETL staging, dev/test, reproducible data         │
-- └──────────────────────┴──────────────────────────────────────────────────┘
--
-- TRANSIENT vs PERMANENT (INTERVIEW COMPARISON):
-- ┌──────────────────────┬──────────────────────┬──────────────────────────┐
-- │ Aspect               │ Permanent            │ Transient                │
-- ├──────────────────────┼──────────────────────┼──────────────────────────┤
-- │ CREATE keyword       │ (none — default)     │ TRANSIENT                │
-- │ Time Travel max      │ 90 days (Enterprise) │ 1 day                    │
-- │ Fail-Safe            │ 7 days               │ None                     │
-- │ Survives sessions    │ Yes                  │ Yes                      │
-- │ Storage cost         │ Highest              │ Lower                    │
-- │ Data recoverability  │ Full                 │ Limited                  │
-- └──────────────────────┴──────────────────────┴──────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - Transient tables persist across sessions (unlike temporary tables)
--   - They sacrifice Fail-Safe for lower storage costs
--   - Tables inherit the transient property from their parent schema
--   - Setting DATA_RETENTION_TIME_IN_DAYS = 0 disables Time Travel AND UNDROP
--   - You CANNOT set retention > 1 day on a transient table (error)
-- =============================================================================


-- =============================================
-- STEP 1: Create a transient table
-- =============================================
CREATE OR REPLACE DATABASE TDB;

-- The TRANSIENT keyword creates a table without Fail-Safe protection.
CREATE OR REPLACE TRANSIENT TABLE TDB.public.customers_transient (
    id         INT,
    first_name STRING,
    last_name  STRING,
    email      STRING,
    gender     STRING,
    Job        STRING,
    Phone      STRING
);

-- Load data using CROSS JOIN to generate volume
INSERT INTO TDB.public.customers_transient
SELECT t1.*
FROM OUR_FIRST_DB.public.customers t1
CROSS JOIN (SELECT * FROM OUR_FIRST_DB.public.customers) t2;

-- Verify the table — note the "kind" column
SHOW TABLES;
-- kind = "TRANSIENT" confirms the table type


-- =============================================
-- STEP 2: Query storage metrics
-- =============================================
-- View raw metrics
SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS;

-- Formatted view — notice FAILSAFE_BYTES is 0 for transient tables
SELECT
    ID,
    TABLE_NAME,
    TABLE_SCHEMA,
    TABLE_CATALOG,
    ACTIVE_BYTES,
    TIME_TRAVEL_BYTES / (1024*1024*1024) AS TIME_TRAVEL_STORAGE_USED_GB,
    FAILSAFE_BYTES    / (1024*1024*1024) AS FAILSAFE_STORAGE_USED_GB,
    IS_TRANSIENT,
    DELETED,
    TABLE_CREATED,
    TABLE_DROPPED,
    TABLE_ENTERED_FAILSAFE
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
WHERE TABLE_CATALOG = 'TDB'
ORDER BY TABLE_CREATED DESC;

-- OBSERVATION: FAILSAFE_STORAGE_USED_GB = 0 for transient tables
-- This is the key cost benefit of using transient tables.


-- =============================================
-- STEP 3: Set retention to 0 and test UNDROP
-- =============================================
-- Setting retention to 0 disables Time Travel entirely.
ALTER TABLE TDB.public.customers_transient
SET DATA_RETENTION_TIME_IN_DAYS = 0;

-- Drop the table
DROP TABLE TDB.public.customers_transient;

-- Try to UNDROP — THIS WILL FAIL because retention was 0!
UNDROP TABLE TDB.public.customers_transient;
-- ERROR: Object not found or not authorized.
-- With 0-day retention, the table cannot be recovered.

-- LESSON: Setting retention to 0 means:
--   - No Time Travel queries possible
--   - No UNDROP recovery after DROP
--   - Absolute minimum storage cost
--   - Data is gone immediately after DROP or modification

-- Verify with SHOW TABLES
SHOW TABLES;


-- =============================================
-- STEP 4: Transient schema inheritance
-- =============================================
-- When you create a TRANSIENT schema, ALL tables within it
-- automatically become transient — even without the keyword.

CREATE OR REPLACE TRANSIENT SCHEMA TDB.TRANSIENT_SCHEMA;

-- Check schema properties
SHOW SCHEMAS;
-- The "options" column shows "TRANSIENT" for transient schemas

-- This table is AUTOMATICALLY transient (inherits from schema)
CREATE OR REPLACE TABLE TDB.TRANSIENT_SCHEMA.new_table (
    id         INT,
    first_name STRING,
    last_name  STRING,
    email      STRING,
    gender     STRING,
    Job        STRING,
    Phone      STRING
);

-- Attempting to set retention > 1 day will FAIL
ALTER TABLE TDB.TRANSIENT_SCHEMA.new_table
SET DATA_RETENTION_TIME_IN_DAYS = 2;
-- ERROR: Transient tables can only have retention of 0 or 1 day.

-- Verify: the table is transient even though we used CREATE TABLE (not TRANSIENT)
SHOW TABLES;


-- =============================================================================
-- CONCEPT GAP: TRANSIENT INHERITANCE RULES
-- =============================================================================
-- ┌──────────────────────────────────┬─────────────────────────────────────────┐
-- │ Parent Object                    │ Child Behavior                          │
-- ├──────────────────────────────────┼─────────────────────────────────────────┤
-- │ Permanent database +             │ Table is PERMANENT                      │
-- │ Permanent schema                 │                                         │
-- ├──────────────────────────────────┼─────────────────────────────────────────┤
-- │ Permanent database +             │ Table is TRANSIENT (inherits from       │
-- │ Transient schema                 │ schema)                                 │
-- ├──────────────────────────────────┼─────────────────────────────────────────┤
-- │ Transient database               │ ALL schemas and tables are TRANSIENT    │
-- │                                  │ (inherits from database)                │
-- ├──────────────────────────────────┼─────────────────────────────────────────┤
-- │ Any schema + explicit            │ Table is TRANSIENT regardless of parent │
-- │ CREATE TRANSIENT TABLE           │                                         │
-- └──────────────────────────────────┴─────────────────────────────────────────┘
--
-- NOTE: You CANNOT create a permanent table inside a transient schema.
-- The transient property is enforced at the schema level.
-- =============================================================================


-- =============================================================================
-- CONCEPT GAP: WHEN TO USE TRANSIENT TABLES
-- =============================================================================
-- USE TRANSIENT TABLES FOR:
--   ✓ ETL/ELT staging tables (data can be reloaded from source)
--   ✓ Development and testing environments
--   ✓ Intermediate transformation tables
--   ✓ Materialized reporting tables (can be recreated from source)
--   ✓ Large tables where Fail-Safe cost is not justified
--
-- DO NOT USE TRANSIENT TABLES FOR:
--   ✗ Production fact tables with critical business data
--   ✗ Financial/regulatory data requiring audit trails
--   ✗ Data that cannot be recreated from source systems
--   ✗ Tables that need >1 day of Time Travel protection
--
-- COST SAVINGS EXAMPLE:
--   10 TB permanent table with 90-day TT (worst case):
--     Active: 10 TB + TT: ~900 TB + Fail-Safe: ~70 TB = ~980 TB
--
--   10 TB transient table with 1-day TT:
--     Active: 10 TB + TT: ~10 TB + Fail-Safe: 0 = ~20 TB
--
--   → Up to 98% storage savings for frequently modified data!
-- =============================================================================
