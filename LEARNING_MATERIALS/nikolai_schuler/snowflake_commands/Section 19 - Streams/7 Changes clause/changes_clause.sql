-- =============================================================================
-- SECTION 19.7: CHANGES CLAUSE (Lightweight Change Tracking)
-- =============================================================================
--
-- OBJECTIVE:
--   Learn the CHANGES clause as an alternative to streams for querying
--   historical changes on a table using Time Travel, without creating
--   a persistent stream object.
--
-- WHAT YOU WILL LEARN:
--   1. Enabling CHANGE_TRACKING on a table
--   2. Using the CHANGES clause with Time Travel offsets and timestamps
--   3. default vs append_only information modes
--   4. When to use CHANGES clause vs streams
--
-- CHANGES CLAUSE vs STREAMS:
-- ┌──────────────────────┬──────────────────────┬──────────────────────────┐
-- │ Aspect               │ Streams              │ CHANGES Clause           │
-- ├──────────────────────┼──────────────────────┼──────────────────────────┤
-- │ Persistent object    │ Yes (CREATE STREAM)  │ No (stateless query)     │
-- │ Tracks offset        │ Yes (auto-advances)  │ No (you specify AT/BEFORE│
-- │ Consumed on DML use  │ Yes (offset advances)│ No (always re-queryable) │
-- │ Requires setup       │ CREATE STREAM        │ ALTER TABLE SET          │
-- │                      │                      │ CHANGE_TRACKING = TRUE   │
-- │ Automation support   │ Yes (with tasks)     │ No (manual/ad-hoc)       │
-- │ Use case             │ Automated pipelines  │ Ad-hoc auditing, one-off │
-- │                      │                      │ change extraction        │
-- └──────────────────────┴──────────────────────┴──────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - CHANGE_TRACKING = TRUE must be enabled BEFORE changes occur
--   - CHANGES clause is stateless — does not consume or advance an offset
--   - Supports both 'default' (all DML) and 'append_only' information modes
--   - Uses Time Travel AT/BEFORE to specify the change window
--   - Results can be materialized with CREATE TABLE AS SELECT
--   - Great for ad-hoc auditing without creating persistent objects
-- =============================================================================


-- =============================================
-- STEP 1: Set up table and enable change tracking
-- =============================================
CREATE OR REPLACE DATABASE SALES_DB;

CREATE OR REPLACE TABLE sales_raw (
    id       VARCHAR,
    product  VARCHAR,
    price    VARCHAR,
    amount   VARCHAR,
    store_id VARCHAR
);

-- Insert initial data
INSERT INTO sales_raw
VALUES
    (1, 'Eggs', 1.39, 1, 1),
    (2, 'Baking powder', 0.99, 1, 1),
    (3, 'Eggplants', 1.79, 1, 2),
    (4, 'Ice cream', 1.89, 1, 2),
    (5, 'Oats', 1.98, 2, 1);

-- Enable change tracking on the table
ALTER TABLE sales_raw
SET CHANGE_TRACKING = TRUE;

-- IMPORTANT: Changes are only tracked AFTER enabling this setting.
-- Data modifications before this point are NOT captured.


-- =============================================
-- STEP 2: Query changes using OFFSET
-- =============================================
-- View changes from the last 30 seconds
SELECT * FROM SALES_RAW
CHANGES(information => default)
AT (offset => -0.5*60);

-- SYNTAX BREAKDOWN:
--   CHANGES(information => default)  → Track all DML types
--   AT (offset => -30)               → From 30 seconds ago to now
--
-- information modes:
--   'default'      → Shows INSERT, UPDATE (as DELETE+INSERT), DELETE
--   'append_only'  → Shows only INSERTs

-- Note the current timestamp for the next query
SELECT CURRENT_TIMESTAMP;


-- =============================================
-- STEP 3: Insert new rows and query by timestamp
-- =============================================
INSERT INTO SALES_RAW VALUES (6, 'Bread', 2.99, 1, 2);
INSERT INTO SALES_RAW VALUES (7, 'Onions', 2.89, 1, 2);

-- Query changes since a specific timestamp
SELECT * FROM SALES_RAW
CHANGES(information => default)
AT (timestamp => 'your-timestamp'::timestamp_tz);

-- Replace 'your-timestamp' with the CURRENT_TIMESTAMP from Step 2


-- =============================================
-- STEP 4: Test with UPDATE
-- =============================================
UPDATE SALES_RAW
SET PRODUCT = 'Toast' WHERE ID = 6;

-- With 'default' mode — shows the UPDATE as DELETE + INSERT pair
SELECT * FROM SALES_RAW
CHANGES(information => default)
AT (timestamp => 'your-timestamp'::timestamp_tz);

-- With 'append_only' mode — shows ONLY the INSERTs, ignores the UPDATE
SELECT * FROM SALES_RAW
CHANGES(information => append_only)
AT (timestamp => 'your-timestamp'::timestamp_tz);


-- =============================================
-- STEP 5: Materialize changes into a table
-- =============================================
-- Create a table from the append-only changes
CREATE OR REPLACE TABLE PRODUCTS AS
SELECT * FROM SALES_RAW
CHANGES(information => append_only)
AT (timestamp => 'your-timestamp'::timestamp_tz);

SELECT * FROM PRODUCTS;


-- =============================================================================
-- CONCEPT GAP: CHANGE_TRACKING vs STREAMS
-- =============================================================================
-- CHANGE_TRACKING = TRUE:
--   - Enables the CHANGES clause on the table
--   - Also required for streams (streams enable it automatically)
--   - Adds minimal overhead to DML operations (metadata tracking)
--   - Can be disabled: ALTER TABLE t SET CHANGE_TRACKING = FALSE;
--
-- WHEN A STREAM IS CREATED:
--   Snowflake automatically sets CHANGE_TRACKING = TRUE on the source table.
--   You don't need to do it manually if you're using streams.
--
-- WHEN TO USE CHANGES CLAUSE INSTEAD OF STREAMS:
--   ✓ One-time data extraction ("What changed last Tuesday?")
--   ✓ Ad-hoc auditing ("Who modified this data?")
--   ✓ Change analysis without modifying any pipeline
--   ✓ Exploring changes before building a stream-based pipeline
--   ✗ NOT for automated pipelines (use streams + tasks instead)
-- =============================================================================


-- =============================================================================
-- CONCEPT GAP: CHANGES CLAUSE LIMITATIONS
-- =============================================================================
-- 1. Only works within the Time Travel retention period
--    (Cannot query changes older than retention allows)
--
-- 2. CHANGE_TRACKING must be enabled BEFORE the changes you want to see
--    (Not retroactive — doesn't track past changes)
--
-- 3. The CHANGES clause is STATELESS — every query re-scans from the
--    specified AT point. For repeated processing, use streams instead.
--
-- 4. No WHEN clause integration — cannot be used in task conditions.
--    Use SYSTEM$STREAM_HAS_DATA() with streams for conditional execution.
-- =============================================================================
