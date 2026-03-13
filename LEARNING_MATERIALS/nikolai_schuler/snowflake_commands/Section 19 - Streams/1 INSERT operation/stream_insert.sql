-- =============================================================================
-- SECTION 19.1: STREAMS — INSERT OPERATION (Change Data Capture)
-- =============================================================================
--
-- OBJECTIVE:
--   Understand Snowflake Streams for Change Data Capture (CDC) — how to
--   create a stream, detect INSERT changes, and consume the stream to
--   propagate new rows into a target table.
--
-- WHAT YOU WILL LEARN:
--   1. What streams are and how they track changes (CDC)
--   2. Creating a stream on a source table
--   3. Querying the stream to see pending changes
--   4. Consuming the stream (advancing the offset)
--
-- STREAMS OVERVIEW (CRITICAL INTERVIEW TOPIC):
-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │ HOW STREAMS WORK:                                                       │
-- │                                                                         │
-- │   ┌─────────────┐    DML changes    ┌─────────────┐                    │
-- │   │ Source Table │───────────────────>│   Stream    │                    │
-- │   │ (staging)    │                   │ (tracks Δ)  │                    │
-- │   └─────────────┘                   └──────┬──────┘                    │
-- │                                            │ consume                    │
-- │                                     ┌──────▼──────┐                    │
-- │                                     │ Target Table│                    │
-- │                                     │ (final)     │                    │
-- │                                     └─────────────┘                    │
-- │                                                                         │
-- │ 1. Stream records all DML changes (INSERT/UPDATE/DELETE) on source     │
-- │ 2. Querying the stream shows ONLY unconsumed changes                   │
-- │ 3. Using the stream in DML (INSERT/MERGE) CONSUMES it                 │
-- │ 4. After consumption, the stream resets (shows no changes)             │
-- └──────────────────────────────────────────────────────────────────────────┘
--
-- STREAM METADATA COLUMNS:
-- ┌──────────────────────┬──────────────────────────────────────────────────┐
-- │ Column               │ Meaning                                          │
-- ├──────────────────────┼──────────────────────────────────────────────────┤
-- │ METADATA$ACTION      │ 'INSERT' or 'DELETE'                             │
-- │ METADATA$ISUPDATE    │ TRUE if the row is part of an UPDATE             │
-- │ METADATA$ROW_ID      │ Unique ID for the row (for tracking)             │
-- └──────────────────────┴──────────────────────────────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - Streams enable incremental/delta processing (not full table scans)
--   - Consuming a stream = using it in a DML statement within a transaction
--   - After consumption, the stream offset advances and changes are cleared
--   - Streams have NO additional storage cost (they use table metadata)
--   - A stream becomes STALE if not consumed within the retention period
-- =============================================================================


-- =============================================
-- STEP 1: Set up tables
-- =============================================
CREATE OR REPLACE TRANSIENT DATABASE STREAMS_DB;

-- Source (staging) table
CREATE OR REPLACE TABLE sales_raw_staging (
    id       VARCHAR,
    product  VARCHAR,
    price    VARCHAR,
    amount   VARCHAR,
    store_id VARCHAR
);

-- Insert initial data
INSERT INTO sales_raw_staging
VALUES
    (1, 'Banana', 1.99, 1, 1),
    (2, 'Lemon', 0.99, 1, 1),
    (3, 'Apple', 1.79, 1, 2),
    (4, 'Orange Juice', 1.89, 1, 2),
    (5, 'Cereals', 5.98, 2, 1);

-- Reference table
CREATE OR REPLACE TABLE store_table (
    store_id  NUMBER,
    location  VARCHAR,
    employees NUMBER
);

INSERT INTO STORE_TABLE VALUES (1, 'Chicago', 33);
INSERT INTO STORE_TABLE VALUES (2, 'London', 12);

-- Target (final) table — enriched with store info
CREATE OR REPLACE TABLE sales_final_table (
    id        INT,
    product   VARCHAR,
    price     NUMBER,
    amount    INT,
    store_id  INT,
    location  VARCHAR,
    employees INT
);

-- Initial load: populate final table from staging + store join
INSERT INTO sales_final_table
SELECT
    SA.id, SA.product, SA.price, SA.amount,
    ST.STORE_ID, ST.LOCATION, ST.EMPLOYEES
FROM SALES_RAW_STAGING SA
JOIN STORE_TABLE ST ON ST.STORE_ID = SA.STORE_ID;


-- =============================================
-- STEP 2: Create a stream on the staging table
-- =============================================
CREATE OR REPLACE STREAM sales_stream ON TABLE sales_raw_staging;

-- View stream metadata
SHOW STREAMS;
DESC STREAM sales_stream;

-- Query the stream — should be EMPTY (no changes since creation)
SELECT * FROM sales_stream;


-- =============================================
-- STEP 3: Insert new rows into the source table
-- =============================================
INSERT INTO sales_raw_staging
VALUES
    (6, 'Mango', 1.99, 1, 2),
    (7, 'Garlic', 0.99, 1, 1);

-- Now the stream shows the 2 new rows!
SELECT * FROM sales_stream;
-- METADATA$ACTION = 'INSERT' for both rows
-- METADATA$ISUPDATE = FALSE (these are pure inserts)

-- The staging table shows all 7 rows
SELECT * FROM sales_raw_staging;

-- The final table still has only 5 rows (not yet updated)
SELECT * FROM sales_final_table;


-- =============================================
-- STEP 4: Consume the stream (propagate to target)
-- =============================================
-- Using the stream in an INSERT statement CONSUMES it
INSERT INTO sales_final_table
SELECT
    SA.id, SA.product, SA.price, SA.amount,
    ST.STORE_ID, ST.LOCATION, ST.EMPLOYEES
FROM SALES_STREAM SA                    -- Read from STREAM (not staging)
JOIN STORE_TABLE ST ON ST.STORE_ID = SA.STORE_ID;

-- Stream is now EMPTY — changes have been consumed
SELECT * FROM sales_stream;
-- Result: 0 rows


-- =============================================
-- STEP 5: Repeat the cycle
-- =============================================
-- Insert more data
INSERT INTO sales_raw_staging
VALUES
    (8, 'Paprika', 4.99, 1, 2),
    (9, 'Tomato', 3.99, 1, 2);

-- Consume again
INSERT INTO sales_final_table
SELECT
    SA.id, SA.product, SA.price, SA.amount,
    ST.STORE_ID, ST.LOCATION, ST.EMPLOYEES
FROM SALES_STREAM SA
JOIN STORE_TABLE ST ON ST.STORE_ID = SA.STORE_ID;

-- Verify all data
SELECT * FROM SALES_FINAL_TABLE;     -- 9 rows
SELECT * FROM SALES_RAW_STAGING;     -- 9 rows
SELECT * FROM SALES_STREAM;          -- 0 rows (consumed)


-- =============================================================================
-- CONCEPT GAP: STREAM OFFSET AND STALENESS
-- =============================================================================
-- The stream maintains an OFFSET — a pointer to the last consumed position.
--
-- OFFSET BEHAVIOR:
--   - Stream created → offset = current table state
--   - Data changes → stream shows changes since offset
--   - Stream consumed → offset advances to current state
--   - Stream queried (SELECT only) → offset does NOT advance
--
-- STALENESS:
--   If a stream is not consumed within the table's Time Travel retention
--   period, it becomes STALE and can no longer be used.
--   → The stream offset is too old, and the historical data is gone.
--   → You must recreate the stream.
--
-- CHECK STALENESS:
--   DESC STREAM my_stream;
--   → Look at the "stale" column (TRUE = stale, need to recreate)
-- =============================================================================
