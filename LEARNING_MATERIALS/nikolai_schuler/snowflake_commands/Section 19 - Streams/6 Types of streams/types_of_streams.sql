-- =============================================================================
-- SECTION 19.6: TYPES OF STREAMS (DEFAULT vs APPEND-ONLY)
-- =============================================================================
--
-- OBJECTIVE:
--   Compare the two main stream types: default (standard) streams that
--   capture all DML changes, and append-only streams that only track INSERTs.
--
-- WHAT YOU WILL LEARN:
--   1. Default streams capture INSERT, UPDATE, and DELETE
--   2. Append-only streams capture INSERT only
--   3. When to use each type
--   4. Consuming streams via DML or CREATE TABLE AS
--
-- STREAM TYPES COMPARED (CRITICAL INTERVIEW TOPIC):
-- ┌──────────────────────┬──────────────────────┬──────────────────────────┐
-- │ Aspect               │ Default (Standard)   │ Append-Only              │
-- ├──────────────────────┼──────────────────────┼──────────────────────────┤
-- │ Syntax               │ CREATE STREAM ...    │ CREATE STREAM ...        │
-- │                      │ ON TABLE t           │ ON TABLE t               │
-- │                      │                      │ APPEND_ONLY = TRUE       │
-- │ Tracks INSERT        │ Yes                  │ Yes                      │
-- │ Tracks UPDATE        │ Yes (DELETE+INSERT)  │ No (ignored)             │
-- │ Tracks DELETE        │ Yes                  │ No (ignored)             │
-- │ Best for             │ Full CDC processing  │ Event/log tables         │
-- │ MERGE support        │ Full (all 3 clauses) │ INSERT only              │
-- │ Processing overhead  │ Higher               │ Lower                    │
-- └──────────────────────┴──────────────────────┴──────────────────────────┘
--
-- ADDITIONAL STREAM TYPE:
-- ┌──────────────────────┬──────────────────────────────────────────────────┐
-- │ Insert-Only          │ For EXTERNAL TABLES only                         │
-- │                      │ Similar to append-only but for external sources  │
-- └──────────────────────┴──────────────────────────────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - Default streams = full CDC (all DML types)
--   - Append-only = INSERT only (lighter weight)
--   - Append-only ignores UPDATE and DELETE completely
--   - Use append-only for log/event tables where data is only ever inserted
--   - Streams can be consumed via DML or CREATE TABLE AS SELECT
-- =============================================================================


-- =============================================
-- STEP 1: Create both stream types
-- =============================================
USE STREAMS_DB;
SHOW STREAMS;

SELECT * FROM SALES_RAW_STAGING;

-- Default stream (captures all DML)
CREATE OR REPLACE STREAM SALES_STREAM_DEFAULT
ON TABLE SALES_RAW_STAGING;

-- Append-only stream (captures INSERT only)
CREATE OR REPLACE STREAM SALES_STREAM_APPEND
ON TABLE SALES_RAW_STAGING
APPEND_ONLY = TRUE;

-- Verify both streams
SHOW STREAMS;
-- The "mode" column shows "DEFAULT" or "APPEND_ONLY"


-- =============================================
-- STEP 2: Test with INSERT
-- =============================================
INSERT INTO SALES_RAW_STAGING VALUES (14, 'Honey', 4.99, 1, 1);
INSERT INTO SALES_RAW_STAGING VALUES (15, 'Coffee', 4.89, 1, 2);

-- BOTH streams show the inserts
SELECT * FROM SALES_STREAM_APPEND;    -- 2 rows (INSERTs captured)
SELECT * FROM SALES_STREAM_DEFAULT;   -- 2 rows (INSERTs captured)


-- =============================================
-- STEP 3: Test with DELETE
-- =============================================
SELECT * FROM SALES_RAW_STAGING;

DELETE FROM SALES_RAW_STAGING WHERE ID = 7;

-- Only the DEFAULT stream shows the delete
SELECT * FROM SALES_STREAM_APPEND;    -- Still shows only the 2 inserts
SELECT * FROM SALES_STREAM_DEFAULT;   -- Shows 2 inserts + 1 delete = 3 rows


-- =============================================
-- STEP 4: Consume streams
-- =============================================
-- Consuming via CREATE TABLE AS SELECT (alternative to MERGE)
CREATE OR REPLACE TEMPORARY TABLE PRODUCT_TABLE
AS SELECT * FROM SALES_STREAM_DEFAULT;

CREATE OR REPLACE TEMPORARY TABLE PRODUCT_TABLE
AS SELECT * FROM SALES_STREAM_APPEND;

-- Both streams are now consumed (empty)


-- =============================================
-- STEP 5: Test with UPDATE
-- =============================================
UPDATE SALES_RAW_STAGING
SET PRODUCT = 'Coffee 200g'
WHERE PRODUCT = 'Coffee';

-- Append-only stream: EMPTY (ignores updates)
SELECT * FROM SALES_STREAM_APPEND;

-- Default stream: Shows DELETE + INSERT pair for the update
SELECT * FROM SALES_STREAM_DEFAULT;


-- =============================================================================
-- CONCEPT GAP: WHEN TO USE EACH STREAM TYPE
-- =============================================================================
-- USE DEFAULT STREAMS WHEN:
--   ✓ Source table has INSERT, UPDATE, and DELETE operations
--   ✓ You need full CDC processing (all changes must be captured)
--   ✓ Building SCD Type 2 (slowly changing dimensions) pipelines
--   ✓ Keeping a target table in exact sync with a source table
--
-- USE APPEND-ONLY STREAMS WHEN:
--   ✓ Source table is insert-only (logs, events, clickstream, IoT)
--   ✓ You only care about new data, not modifications
--   ✓ Processing is simpler (no need for MERGE, just INSERT INTO)
--   ✓ Data is immutable by design (event sourcing pattern)
--
-- EXAMPLES:
--   Default:     Customer table (updates to address, phone, etc.)
--   Append-only: Web clickstream logs (new events only)
--   Default:     Product catalog (prices change, items are discontinued)
--   Append-only: IoT sensor readings (new measurements only)
-- =============================================================================
