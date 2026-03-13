-- =============================================================================
-- SECTION 15.2: CLONING WITH TIME TRAVEL
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to combine zero-copy cloning with Time Travel to create
--   clones of tables as they existed at a past point in time. This is
--   one of the most powerful recovery techniques in Snowflake.
--
-- WHAT YOU WILL LEARN:
--   1. Cloning a table at a specific point in the past using OFFSET
--   2. Cloning a table before a specific statement using STATEMENT
--   3. Creating clones of clones (clone-of-clone pattern)
--   4. Using Time Travel cloning as a recovery strategy
--
-- TIME TRAVEL CLONING METHODS:
-- ┌──────────────────────────────┬──────────────────────────────────────────┐
-- │ Method                       │ Syntax                                   │
-- ├──────────────────────────────┼──────────────────────────────────────────┤
-- │ OFFSET (relative time)       │ CLONE source AT (OFFSET => -seconds)     │
-- │ TIMESTAMP (absolute time)    │ CLONE source AT (TIMESTAMP => '...')     │
-- │ STATEMENT (before a query)   │ CLONE source BEFORE (STATEMENT => 'id')  │
-- └──────────────────────────────┴──────────────────────────────────────────┘
--
-- TIME TRAVEL CLONING vs TIME TRAVEL SELECT:
-- ┌──────────────────────────────┬──────────────────────────────────────────┐
-- │ Time Travel SELECT           │ Time Travel CLONE                        │
-- ├──────────────────────────────┼──────────────────────────────────────────┤
-- │ Returns rows as query result │ Creates a physical table (clone)         │
-- │ Need TRUNCATE+INSERT to      │ Single command creates the restored      │
-- │ restore                      │ table                                    │
-- │ Requires backup table pattern│ Self-contained recovery                  │
-- │ Source table must exist       │ Source table must exist                  │
-- │ Works within retention period│ Works within retention period            │
-- └──────────────────────────────┴──────────────────────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - CLONE ... AT/BEFORE creates a table with data from the past
--   - This is the cleanest way to recover from accidental changes
--   - Clones are independent — modifying a clone doesn't affect the source
--   - You can clone a clone (clone-of-clone) for iterative recovery
--   - The clone only works within the source table's retention period
--   - Clone + Time Travel = instant point-in-time recovery
-- =============================================================================


-- =============================================
-- STEP 1: Set up table with data
-- =============================================
CREATE OR REPLACE TABLE OUR_FIRST_DB.public.time_travel (
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

-- Verify and load
LIST @MANAGE_DB.external_stages.time_travel_stage;

COPY INTO OUR_FIRST_DB.public.time_travel
FROM @MANAGE_DB.external_stages.time_travel_stage
FILES = ('customers.csv');

-- View original data
SELECT * FROM OUR_FIRST_DB.public.time_travel;


-- =============================================
-- STEP 2: Make an accidental update
-- =============================================
-- Overwrite ALL first names — a common mistake
UPDATE OUR_FIRST_DB.public.time_travel
SET FIRST_NAME = 'Frank';

-- Verify the damage
SELECT * FROM OUR_FIRST_DB.public.time_travel;
-- All first names are now 'Frank'


-- =============================================
-- STEP 3: Verify with Time Travel SELECT
-- =============================================
-- First, confirm the old data is still accessible via Time Travel
SELECT * FROM OUR_FIRST_DB.public.time_travel AT (OFFSET => -60*1);
-- Shows the original data from ~1 minute ago


-- =============================================
-- STEP 4: Clone with Time Travel (OFFSET method)
-- =============================================
-- Instead of the multi-step backup+truncate+insert pattern,
-- use a single CLONE command with Time Travel!

CREATE OR REPLACE TABLE OUR_FIRST_DB.PUBLIC.time_travel_clone
CLONE OUR_FIRST_DB.public.time_travel AT (OFFSET => -60*1.5);

-- Verify the clone has the ORIGINAL data (before the UPDATE)
SELECT * FROM OUR_FIRST_DB.PUBLIC.time_travel_clone;
-- First names are restored to their original values!

-- COMPARISON OF RECOVERY APPROACHES:
--
-- Old approach (3 steps):
--   CREATE TABLE backup AS SELECT * FROM source BEFORE (...);
--   TRUNCATE source;
--   INSERT INTO source SELECT * FROM backup;
--
-- Clone approach (1 step):
--   CREATE TABLE clone CLONE source AT (...);
--
-- The clone approach is simpler, faster, and more reliable!


-- =============================================
-- STEP 5: Make another accidental change to the clone
-- =============================================
-- Even clones can be modified accidentally
UPDATE OUR_FIRST_DB.public.time_travel_clone
SET JOB = 'Snowflake Analyst';

-- The clone now has modified JOB values
SELECT * FROM OUR_FIRST_DB.public.time_travel_clone;


-- =============================================
-- STEP 6: Clone the clone (using STATEMENT method)
-- =============================================
-- You can clone a clone using the query ID of the problematic statement.
-- Find the query ID from the Snowflake Query History.

SELECT * FROM OUR_FIRST_DB.public.time_travel_clone
BEFORE (STATEMENT => '<your-query-id>');

-- Create a clone of the clone at the point before the UPDATE
CREATE OR REPLACE TABLE OUR_FIRST_DB.PUBLIC.time_travel_clone_of_clone
CLONE OUR_FIRST_DB.public.time_travel_clone
BEFORE (STATEMENT => '<your-query-id>');

-- Verify the clone-of-clone has the original JOB values
SELECT * FROM OUR_FIRST_DB.public.time_travel_clone_of_clone;


-- =============================================================================
-- CONCEPT GAP: TIME TRAVEL CLONE AS A RECOVERY STRATEGY
-- =============================================================================
-- SCENARIO: "You accidentally ran UPDATE without a WHERE clause. How do you
--            recover the data?"
--
-- BEST APPROACH — Clone with Time Travel:
--
-- 1. ASSESS the damage:
--    SELECT * FROM my_table;  -- See current (bad) state
--
-- 2. FIND the query ID:
--    SELECT query_id, query_text, start_time
--    FROM TABLE(information_schema.query_history())
--    WHERE query_text LIKE '%UPDATE%my_table%'
--    ORDER BY start_time DESC LIMIT 5;
--
-- 3. VERIFY the Time Travel data looks correct:
--    SELECT * FROM my_table BEFORE (STATEMENT => '<query-id>') LIMIT 100;
--
-- 4. CREATE a clone at the correct point:
--    CREATE TABLE my_table_recovered
--    CLONE my_table BEFORE (STATEMENT => '<query-id>');
--
-- 5. VALIDATE the recovered data:
--    SELECT COUNT(*) FROM my_table_recovered;
--
-- 6. SWAP if everything looks good:
--    ALTER TABLE my_table RENAME TO my_table_bad;
--    ALTER TABLE my_table_recovered RENAME TO my_table;
--
-- 7. CLEAN UP:
--    DROP TABLE my_table_bad;
--
-- WHY THIS IS BETTER THAN TRUNCATE+INSERT:
--   - Single command to create the recovery table
--   - Original table is preserved until you're confident
--   - The RENAME approach is atomic — no window of missing data
--   - Clone shares micro-partitions (efficient storage)
-- =============================================================================


-- =============================================================================
-- CONCEPT GAP: TIME TRAVEL CLONE LIMITATIONS
-- =============================================================================
-- 1. RETENTION WINDOW:
--    Clone with Time Travel only works within the retention period.
--    If retention is 1 day, you cannot clone data from 2 days ago.
--
-- 2. TABLE MUST EXIST:
--    You cannot clone a dropped table's history. If the table was dropped,
--    use UNDROP first, then clone if needed.
--
-- 3. SCHEMA/DATABASE CLONES WITH TIME TRAVEL:
--    CREATE SCHEMA ... CLONE ... AT (OFFSET => ...)
--    → Clones ALL tables in the schema at the specified point in time
--    → Very powerful for full environment point-in-time recovery!
--
-- 4. CLONE + TIME TRAVEL DOES NOT COPY:
--    - Grants/privileges (need to be re-applied)
--    - Load history (COPY INTO tracking)
--    - Pipes
--    - The source's Time Travel history (clone starts fresh)
-- =============================================================================


-- =============================================================================
-- CONCEPT GAP: CLONE vs CTAS (CREATE TABLE AS SELECT)
-- =============================================================================
-- ┌───────────────────────────┬────────────────────────────────────────────┐
-- │ CLONE                     │ CTAS (CREATE TABLE AS SELECT)              │
-- ├───────────────────────────┼────────────────────────────────────────────┤
-- │ Metadata-only (instant)   │ Full data copy (slow for large tables)     │
-- │ Zero additional storage   │ Doubles storage immediately                │
-- │ Shares micro-partitions   │ Creates new micro-partitions               │
-- │ Supports Time Travel      │ Supports Time Travel via SELECT ... AT     │
-- │ Preserves clustering keys │ Does NOT preserve clustering keys          │
-- │ Copies table structure    │ Infers structure from SELECT               │
-- │ Cannot transform data     │ Can transform/filter during creation       │
-- └───────────────────────────┴────────────────────────────────────────────┘
--
-- USE CLONE WHEN: You need an exact copy (with or without Time Travel)
-- USE CTAS WHEN: You need to transform, filter, or restructure the data
-- =============================================================================
