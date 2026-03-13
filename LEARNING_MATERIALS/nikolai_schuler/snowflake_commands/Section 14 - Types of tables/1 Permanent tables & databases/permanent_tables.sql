-- =============================================================================
-- SECTION 14.1: PERMANENT TABLES AND DATABASES
-- =============================================================================
--
-- OBJECTIVE:
--   Understand permanent tables — the default table type in Snowflake —
--   including their storage characteristics, Time Travel & Fail-Safe
--   behavior, and how to monitor their storage metrics.
--
-- WHAT YOU WILL LEARN:
--   1. Permanent tables are the default (no keyword needed)
--   2. They provide full Time Travel (up to 90 days) and Fail-Safe (7 days)
--   3. How to generate large datasets with CROSS JOIN for testing
--   4. How to query TABLE_STORAGE_METRICS for storage analysis
--
-- PERMANENT TABLE CHARACTERISTICS (CRITICAL INTERVIEW TOPIC):
-- ┌──────────────────────┬──────────────────────────────────────────────────┐
-- │ Feature              │ Details                                          │
-- ├──────────────────────┼──────────────────────────────────────────────────┤
-- │ Keyword              │ None (default table type)                        │
-- │ Time Travel          │ 0-90 days (Enterprise Ed.) / 0-1 day (Standard) │
-- │ Fail-Safe            │ 7 days (always, non-configurable)                │
-- │ Storage cost         │ Highest (active + time travel + fail-safe)       │
-- │ Persistence          │ Until explicitly dropped                         │
-- │ Visibility           │ All sessions, all users (with grants)            │
-- │ UNDROP support       │ Yes (within retention period)                    │
-- │ Best for             │ Production data, critical business data          │
-- └──────────────────────┴──────────────────────────────────────────────────┘
--
-- TABLE TYPES COMPARISON (OVERVIEW — detailed in 14.2 and 14.3):
-- ┌──────────────────────┬──────────┬────────────┬────────────┬────────────┐
-- │ Feature              │Permanent │ Transient  │ Temporary  │ External   │
-- ├──────────────────────┼──────────┼────────────┼────────────┼────────────┤
-- │ Time Travel (max)    │ 90 days  │ 1 day      │ 1 day      │ 0 days     │
-- │ Fail-Safe            │ 7 days   │ None       │ None       │ None       │
-- │ Persists across      │ Yes      │ Yes        │ No (session│ Yes        │
-- │ sessions             │          │            │ only)      │            │
-- │ CREATE keyword       │ (none)   │ TRANSIENT  │ TEMPORARY  │ EXTERNAL   │
-- └──────────────────────┴──────────┴────────────┴────────────┴────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - Permanent tables are the DEFAULT — CREATE TABLE makes a permanent table
--   - They have the highest storage cost due to Fail-Safe overhead
--   - Use SHOW TABLES to check the IS_TRANSIENT flag and "kind" column
--   - TABLE_STORAGE_METRICS shows ACTIVE, TIME_TRAVEL, and FAILSAFE bytes
--   - Use permanent tables for data that MUST be recoverable
-- =============================================================================


-- =============================================
-- STEP 1: Create a permanent database and tables
-- =============================================
-- CREATE DATABASE creates a PERMANENT database by default.
CREATE OR REPLACE DATABASE PDB;

-- CREATE TABLE creates a PERMANENT table by default.
-- No special keyword needed — this is the standard behavior.
CREATE OR REPLACE TABLE PDB.public.customers (
    id         INT,
    first_name STRING,
    last_name  STRING,
    email      STRING,
    gender     STRING,
    Job        STRING,
    Phone      STRING
);

-- Helper table for loading data
CREATE OR REPLACE TABLE PDB.public.helper (
    id         INT,
    first_name STRING,
    last_name  STRING,
    email      STRING,
    gender     STRING,
    Job        STRING,
    Phone      STRING
);


-- =============================================
-- STEP 2: Set up stage and load data
-- =============================================
CREATE OR REPLACE FILE FORMAT MANAGE_DB.file_formats.csv_file
    type            = csv
    field_delimiter = ','
    skip_header     = 1;

CREATE OR REPLACE STAGE MANAGE_DB.external_stages.time_travel_stage
    URL         = 's3://data-snowflake-fundamentals/time-travel/'
    file_format = MANAGE_DB.file_formats.csv_file;

-- Verify files in stage
LIST @MANAGE_DB.external_stages.time_travel_stage;

-- Load data into helper table
COPY INTO PDB.public.helper
FROM @MANAGE_DB.external_stages.time_travel_stage
FILES = ('customers.csv');

SELECT * FROM PDB.public.helper;


-- =============================================
-- STEP 3: Generate large dataset with CROSS JOIN
-- =============================================
-- CROSS JOIN produces the Cartesian product of two tables.
-- This is useful for generating large test datasets.
--
-- If helper has 1000 rows:
--   helper × helper = 1,000,000 rows
--   × TOP 100       = 100,000,000 rows (careful with size!)

INSERT INTO PDB.public.customers
SELECT
    t1.ID,
    t1.FIRST_NAME,
    t1.LAST_NAME,
    t1.EMAIL,
    t1.GENDER,
    t1.JOB,
    t1.PHONE
FROM PDB.public.helper t1
CROSS JOIN (SELECT * FROM PDB.public.helper) t2
CROSS JOIN (SELECT TOP 100 * FROM PDB.public.helper) t3;

-- CROSS JOIN EXPLAINED:
--   SELECT * FROM A CROSS JOIN B
--   → Every row in A is paired with every row in B
--   → Result size = rows(A) × rows(B)
--   → No JOIN condition needed (ON clause is not used)
--   → Useful for: test data generation, generating date ranges,
--     creating all combinations of dimension values


-- =============================================
-- STEP 4: Verify permanent table properties
-- =============================================
-- SHOW TABLES reveals the table type and retention settings.
SHOW TABLES;

-- Key columns to look for:
--   kind           = "TABLE" for permanent, "TRANSIENT" for transient
--   is_temporary   = "N" for permanent/transient, "Y" for temporary
--   retention_time = Number of days for Time Travel


-- =============================================
-- STEP 5: Create permanent table in another DB
-- =============================================
USE OUR_FIRST_DB;

CREATE OR REPLACE TABLE customers (
    id         INT,
    first_name STRING,
    last_name  STRING,
    email      STRING,
    gender     STRING,
    Job        STRING,
    Phone      STRING
);

-- Verify database-level properties
CREATE OR REPLACE DATABASE PDB;

SHOW DATABASES;
-- Key column: "kind" shows whether the database is permanent or transient

SHOW TABLES;


-- =============================================
-- STEP 6: Query table storage metrics
-- =============================================
-- Note: Metrics may take a few minutes to appear after table creation.
SELECT *
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS;

-- Detailed storage breakdown with metadata
SELECT
    ID,
    TABLE_NAME,
    TABLE_SCHEMA,
    TABLE_CATALOG,
    ACTIVE_BYTES      / (1024*1024*1024) AS ACTIVE_STORAGE_USED_GB,
    TIME_TRAVEL_BYTES / (1024*1024*1024) AS TIME_TRAVEL_STORAGE_USED_GB,
    FAILSAFE_BYTES    / (1024*1024*1024) AS FAILSAFE_STORAGE_USED_GB,
    IS_TRANSIENT,
    DELETED,
    TABLE_CREATED,
    TABLE_DROPPED,
    TABLE_ENTERED_FAILSAFE
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLE_STORAGE_METRICS
-- WHERE TABLE_CATALOG = 'PDB'
WHERE TABLE_DROPPED IS NOT NULL
ORDER BY FAILSAFE_BYTES DESC;

-- KEY COLUMNS EXPLAINED:
--   ACTIVE_BYTES              = Current live data in the table
--   TIME_TRAVEL_BYTES         = Data retained for Time Travel queries
--   FAILSAFE_BYTES            = Data retained in the 7-day Fail-Safe window
--   IS_TRANSIENT              = 'YES' if transient, 'NO' if permanent
--   TABLE_ENTERED_FAILSAFE    = When the table entered the Fail-Safe period
--   DELETED                   = Timestamp when the table was dropped (if applicable)


-- =============================================================================
-- CONCEPT GAP: WHEN TO USE PERMANENT TABLES
-- =============================================================================
-- USE PERMANENT TABLES FOR:
--   ✓ Production fact and dimension tables
--   ✓ Financial/regulatory data requiring audit trails
--   ✓ Data that is expensive or impossible to recreate
--   ✓ Tables where 90-day recovery is a business requirement
--
-- AVOID PERMANENT TABLES FOR:
--   ✗ ETL staging tables (use transient instead)
--   ✗ Temporary calculations (use temporary instead)
--   ✗ Development/testing environments (use transient instead)
--   ✗ Large tables where Fail-Safe cost is not justified
--
-- COST IMPACT EXAMPLE:
--   A 1 TB permanent table with 90-day TT retention:
--   Active:     1 TB
--   Time Travel: Up to 90 TB (if fully changed every day)
--   Fail-Safe:  Up to 7 TB (data from TT that aged out)
--   → Total potential storage: ~98 TB for a "1 TB" table
-- =============================================================================
