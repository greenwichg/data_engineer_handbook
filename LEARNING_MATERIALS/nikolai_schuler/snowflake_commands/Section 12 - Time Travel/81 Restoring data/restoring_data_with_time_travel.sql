-- =============================================================================
-- SECTION 12.81: RESTORING DATA WITH TIME TRAVEL
-- =============================================================================
--
-- OBJECTIVE:
--   Learn the correct (and incorrect) ways to restore data after accidental
--   modifications using Time Travel. Understand why the "bad method" loses
--   history and how the "good method" preserves it.
--
-- WHAT YOU WILL LEARN:
--   1. Why CREATE OR REPLACE TABLE ... AS SELECT is dangerous for restores
--   2. The correct pattern: backup table + TRUNCATE + INSERT
--   3. How replacing a table resets its time travel history
--
-- BAD vs GOOD RESTORE METHODS (CRITICAL INTERVIEW TOPIC):
-- ┌────────────────────────────┬─────────────────────────────────────────────┐
-- │ Bad Method                 │ Good Method                                 │
-- ├────────────────────────────┼─────────────────────────────────────────────┤
-- │ CREATE OR REPLACE TABLE    │ CREATE backup AS SELECT (time travel query) │
-- │ ... AS SELECT (TT query)   │ TRUNCATE original table                    │
-- │                            │ INSERT INTO original FROM backup            │
-- ├────────────────────────────┼─────────────────────────────────────────────┤
-- │ Replaces table entirely    │ Preserves original table object             │
-- │ Loses ALL time travel data │ Retains time travel history                 │
-- │ Cannot undo the restore!   │ Can still recover if restore was wrong      │
-- │ New table = new history    │ Original metadata preserved                 │
-- └────────────────────────────┴─────────────────────────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - CREATE OR REPLACE TABLE creates a NEW table — the old one is dropped
--   - The dropped table's time travel data is gone (unless you UNDROP)
--   - TRUNCATE clears data but keeps the table object and its history
--   - Always create a backup table first, then restore from the backup
--   - This pattern is safer because you get another chance if something goes wrong
-- =============================================================================


-- =============================================
-- STEP 1: Set up the test table with data
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

COPY INTO OUR_FIRST_DB.public.test
FROM @MANAGE_DB.external_stages.time_travel_stage
FILES = ('customers.csv');

SELECT * FROM OUR_FIRST_DB.public.test;


-- =============================================
-- STEP 2: Simulate accidental updates
-- =============================================
-- Two separate bad updates
UPDATE OUR_FIRST_DB.public.test
SET LAST_NAME = 'Tyson';

UPDATE OUR_FIRST_DB.public.test
SET JOB = 'Data Analyst';

-- View original data using time travel (before the first UPDATE)
SELECT * FROM OUR_FIRST_DB.public.test
BEFORE (STATEMENT => '019b9eea-0500-845a-0043-4d830007402a');


-- =============================================
-- BAD METHOD: CREATE OR REPLACE TABLE (DO NOT USE)
-- =============================================
-- This REPLACES the table with a new one containing the restored data.
-- The original table is DROPPED, and its time travel history is LOST.

CREATE OR REPLACE TABLE OUR_FIRST_DB.public.test AS
SELECT * FROM OUR_FIRST_DB.public.test
BEFORE (STATEMENT => '019b9eea-0500-845a-0043-4d830007402a');

SELECT * FROM OUR_FIRST_DB.public.test;

-- WHY THIS IS BAD:
-- If the restore was wrong (e.g., wrong query ID), you CANNOT recover again.
-- The old table's time travel is gone — the new table starts fresh.

-- Attempting another time travel query on the new table will FAIL:
CREATE OR REPLACE TABLE OUR_FIRST_DB.public.test AS
SELECT * FROM OUR_FIRST_DB.public.test
BEFORE (STATEMENT => '019b9eea-0500-8473-0043-4d830007307a');
-- ERROR: This references the OLD table's history, which no longer exists.


-- =============================================
-- GOOD METHOD: Backup + Truncate + Insert
-- =============================================
-- STEP A: Create a backup table with the restored data
CREATE OR REPLACE TABLE OUR_FIRST_DB.public.test_backup AS
SELECT * FROM OUR_FIRST_DB.public.test
BEFORE (STATEMENT => '019b9ef0-0500-8473-0043-4d830007309a');

-- STEP B: Truncate the original table (clears data, keeps table object)
TRUNCATE OUR_FIRST_DB.public.test;

-- STEP C: Insert the restored data from the backup
INSERT INTO OUR_FIRST_DB.public.test
SELECT * FROM OUR_FIRST_DB.public.test_backup;

-- Verify the restoration
SELECT * FROM OUR_FIRST_DB.public.test;

-- WHY THIS IS GOOD:
--   1. Original table object is preserved (with its metadata and grants)
--   2. Time travel history continues from the original table
--   3. If the backup was wrong, you can try again — the backup table exists
--   4. You can inspect the backup before committing to the restore


-- =============================================================================
-- CONCEPT GAP: COMPLETE RESTORE WORKFLOW (INTERVIEW SCENARIO)
-- =============================================================================
-- When asked "How would you restore accidentally modified data?":
--
-- 1. IDENTIFY the problem:
--    SELECT * FROM my_table;  -- See current (bad) state
--
-- 2. FIND the query that caused the issue:
--    SELECT query_id, query_text, start_time
--    FROM TABLE(information_schema.query_history())
--    WHERE query_text LIKE '%UPDATE%my_table%'
--    ORDER BY start_time DESC;
--
-- 3. VERIFY the time travel data looks correct:
--    SELECT * FROM my_table BEFORE (STATEMENT => '<query-id>');
--
-- 4. CREATE a backup:
--    CREATE TABLE my_table_backup AS
--    SELECT * FROM my_table BEFORE (STATEMENT => '<query-id>');
--
-- 5. VALIDATE the backup:
--    SELECT COUNT(*) FROM my_table_backup;
--    SELECT * FROM my_table_backup LIMIT 10;
--
-- 6. RESTORE:
--    TRUNCATE my_table;
--    INSERT INTO my_table SELECT * FROM my_table_backup;
--
-- 7. CLEAN UP:
--    DROP TABLE my_table_backup;  -- After confirming everything is correct
-- =============================================================================


-- =============================================================================
-- CONCEPT GAP: TRUNCATE vs DELETE vs DROP
-- =============================================================================
-- ┌─────────────┬──────────────────────────────────────────────────────────────┐
-- │ Command     │ Behavior                                                     │
-- ├─────────────┼──────────────────────────────────────────────────────────────┤
-- │ TRUNCATE    │ Removes all rows, keeps table structure.                     │
-- │             │ Does NOT generate time travel data for deleted rows.          │
-- │             │ Fastest way to empty a table.                                │
-- ├─────────────┼──────────────────────────────────────────────────────────────┤
-- │ DELETE      │ Removes rows (can use WHERE clause).                         │
-- │             │ Generates time travel data — you can recover deleted rows.   │
-- │             │ Slower than TRUNCATE for full deletes.                        │
-- ├─────────────┼──────────────────────────────────────────────────────────────┤
-- │ DROP TABLE  │ Removes the entire table object.                             │
-- │             │ Can be recovered with UNDROP within retention period.         │
-- │             │ Table and all its data/history are gone after retention.      │
-- └─────────────┴──────────────────────────────────────────────────────────────┘
-- =============================================================================
