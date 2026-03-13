-- =============================================================================
-- SECTION 12.80: USING TIME TRAVEL
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to query historical data using Snowflake's Time Travel feature
--   to view data as it existed at a previous point in time.
--
-- WHAT YOU WILL LEARN:
--   1. What Time Travel is and when to use it
--   2. Three methods to access historical data
--   3. How OFFSET, TIMESTAMP, and STATEMENT approaches differ
--   4. Retention period defaults and limits
--
-- TIME TRAVEL OVERVIEW (CRITICAL INTERVIEW TOPIC):
-- ┌──────────────────────┬──────────────────────────────────────────────────┐
-- │ Feature              │ Details                                          │
-- ├──────────────────────┼──────────────────────────────────────────────────┤
-- │ Purpose              │ Query data as it existed in the past             │
-- │ Default retention    │ 1 day (24 hours)                                 │
-- │ Max retention        │ 90 days (Enterprise Edition, permanent tables)   │
-- │ Transient/Temporary  │ 0-1 day retention only                           │
-- │ Storage cost         │ Additional storage for changed/deleted data      │
-- │ Enabled by default   │ Yes — no setup required                          │
-- └──────────────────────┴──────────────────────────────────────────────────┘
--
-- THREE METHODS TO ACCESS HISTORICAL DATA:
-- ┌─────────────────────────┬────────────────────────────────────────────────┐
-- │ Method                  │ Use Case                                       │
-- ├─────────────────────────┼────────────────────────────────────────────────┤
-- │ AT(OFFSET => -N)        │ Go back N seconds from now (relative)          │
-- │ BEFORE(TIMESTAMP => ..) │ Query at a specific date/time (absolute)       │
-- │ BEFORE(STATEMENT => ..) │ Query before a specific query ID ran           │
-- └─────────────────────────┴────────────────────────────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - Time Travel is automatic — no configuration needed to start using it
--   - OFFSET uses negative seconds (e.g., -60*1.5 = 90 seconds ago)
--   - TIMESTAMP requires casting to timestamp: '...'::timestamp
--   - STATEMENT uses a query ID from the query history
--   - AT returns data at the specified point; BEFORE returns data just before
--   - Time Travel only works within the retention window
-- =============================================================================


-- =============================================
-- STEP 1: Set up the test table
-- =============================================
CREATE OR REPLACE TABLE OUR_FIRST_DB.public.test (
    id         INT,
    first_name STRING,
    last_name  STRING,
    email      STRING,
    gender     STRING,
    Job        STRING,
    Phone      STRING
);

CREATE OR REPLACE FILE FORMAT MANAGE_DB.file_formats.csv_file
    type            = csv
    field_delimiter = ','
    skip_header     = 1;

CREATE OR REPLACE STAGE MANAGE_DB.external_stages.time_travel_stage
    URL         = 's3://data-snowflake-fundamentals/time-travel/'
    file_format = MANAGE_DB.file_formats.csv_file;

-- Verify files in stage
LIST @MANAGE_DB.external_stages.time_travel_stage;

-- Load data
COPY INTO OUR_FIRST_DB.public.test
FROM @MANAGE_DB.external_stages.time_travel_stage
FILES = ('customers.csv');

-- Verify the data
SELECT * FROM OUR_FIRST_DB.public.test;


-- =============================================
-- STEP 2: Simulate an accidental update
-- =============================================
-- This overwrites ALL first names — a common mistake!
UPDATE OUR_FIRST_DB.public.test
SET FIRST_NAME = 'Joyen';


-- =============================================
-- METHOD 1: OFFSET (relative time travel)
-- =============================================
-- Go back 90 seconds (60 * 1.5) from the current time.
-- OFFSET uses seconds; negative values mean "in the past."

SELECT * FROM OUR_FIRST_DB.public.test AT (OFFSET => -60*1.5);

-- SYNTAX BREAKDOWN:
--   SELECT * FROM <table> AT (OFFSET => -<seconds>)
--
-- OFFSET EXAMPLES:
--   -60       = 1 minute ago
--   -60*5     = 5 minutes ago
--   -3600     = 1 hour ago
--   -86400    = 1 day ago (24 hours)


-- =============================================
-- METHOD 2: TIMESTAMP (absolute time travel)
-- =============================================
-- Query data as it existed at a specific point in time.
-- You must cast the string to a timestamp.

SELECT * FROM OUR_FIRST_DB.public.test
BEFORE (TIMESTAMP => '2021-04-15 17:47:50.581'::timestamp);

-- SYNTAX BREAKDOWN:
--   SELECT * FROM <table> BEFORE (TIMESTAMP => '<datetime>'::timestamp)
--
-- TIP: Set timezone for consistency
ALTER SESSION SET TIMEZONE = 'UTC';

-- Recreate and reload table for next demo
CREATE OR REPLACE TABLE OUR_FIRST_DB.public.test (
    id         INT,
    first_name STRING,
    last_name  STRING,
    email      STRING,
    gender     STRING,
    Job        STRING,
    Phone      STRING
);

COPY INTO OUR_FIRST_DB.public.test
FROM @MANAGE_DB.external_stages.time_travel_stage
FILES = ('customers.csv');

SELECT * FROM OUR_FIRST_DB.public.test;

-- Another accidental update
UPDATE OUR_FIRST_DB.public.test
SET Job = 'Data Scientist';

-- Query data before the update using timestamp
SELECT * FROM OUR_FIRST_DB.public.test
BEFORE (TIMESTAMP => '2021-04-16 07:30:47.145'::timestamp);


-- =============================================
-- METHOD 3: STATEMENT (query ID time travel)
-- =============================================
-- Query data as it existed before a specific SQL statement ran.
-- This is the MOST PRECISE method — no time guessing needed.

-- Recreate table
CREATE OR REPLACE TABLE OUR_FIRST_DB.public.test (
    id         INT,
    first_name STRING,
    last_name  STRING,
    email      STRING,
    gender     STRING,
    Phone      STRING,
    Job        STRING
);

COPY INTO OUR_FIRST_DB.public.test
FROM @MANAGE_DB.external_stages.time_travel_stage
FILES = ('customers.csv');

SELECT * FROM OUR_FIRST_DB.public.test;

-- Accidental update: wipe out all emails
UPDATE OUR_FIRST_DB.public.test
SET EMAIL = null;

-- View the damage
SELECT * FROM OUR_FIRST_DB.public.test;

-- Recover using the query ID of the UPDATE statement
-- (Copy the query ID from the Query History tab)
SELECT * FROM OUR_FIRST_DB.public.test
BEFORE (STATEMENT => '019b9ee5-0500-8473-0043-4d8300073062');

-- SYNTAX BREAKDOWN:
--   SELECT * FROM <table> BEFORE (STATEMENT => '<query-id>')
--
-- HOW TO FIND THE QUERY ID:
--   1. Snowflake UI: Query History tab → copy the query ID
--   2. QUERY_HISTORY function:
--      SELECT query_id, query_text FROM TABLE(information_schema.query_history())
--      WHERE query_text LIKE '%UPDATE%' ORDER BY start_time DESC;
--   3. LAST_QUERY_ID() function (for the most recent query):
--      SELECT LAST_QUERY_ID();


-- =============================================================================
-- CONCEPT GAP: AT vs BEFORE
-- =============================================================================
-- AT(OFFSET => -60):
--   Returns data as it existed exactly 60 seconds ago.
--   If a change happened at that exact second, it IS included.
--
-- BEFORE(TIMESTAMP => ...):
--   Returns data as it existed just BEFORE the specified timestamp.
--   If a change happened at that exact timestamp, it is NOT included.
--
-- BEFORE(STATEMENT => ...):
--   Returns data as it existed just BEFORE the specified statement ran.
--   This is the safest method for recovery — no timestamp guessing.
--
-- INTERVIEW TIP: BEFORE(STATEMENT) is preferred for data recovery because:
--   1. It's exact — no ambiguity about timestamps or offsets
--   2. You can find the problematic query ID in the history
--   3. It works even if you don't know when the change happened
-- =============================================================================


-- =============================================================================
-- CONCEPT GAP: RETENTION PERIOD BY EDITION & TABLE TYPE
-- =============================================================================
-- ┌──────────────────────┬────────────────┬──────────────────────────────────┐
-- │ Table Type           │ Standard Ed.   │ Enterprise Edition               │
-- ├──────────────────────┼────────────────┼──────────────────────────────────┤
-- │ Permanent            │ 0-1 day        │ 0-90 days                        │
-- │ Transient            │ 0-1 day        │ 0-1 day                          │
-- │ Temporary            │ 0-1 day        │ 0-1 day                          │
-- └──────────────────────┴────────────────┴──────────────────────────────────┘
--
-- Set retention per table:
--   ALTER TABLE my_table SET DATA_RETENTION_TIME_IN_DAYS = 90;
--
-- Set retention at schema or database level:
--   ALTER SCHEMA my_schema SET DATA_RETENTION_TIME_IN_DAYS = 30;
--   ALTER DATABASE my_db SET DATA_RETENTION_TIME_IN_DAYS = 7;
-- =============================================================================
