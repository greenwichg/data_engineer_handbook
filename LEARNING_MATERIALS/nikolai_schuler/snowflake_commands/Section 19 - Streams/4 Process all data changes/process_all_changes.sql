-- =============================================================================
-- SECTION 19.4: PROCESSING ALL DATA CHANGES SIMULTANEOUSLY
-- =============================================================================
--
-- OBJECTIVE:
--   Build a single MERGE statement that handles INSERT, UPDATE, and DELETE
--   changes from a stream in one atomic operation — the production CDC pattern.
--
-- WHAT YOU WILL LEARN:
--   1. Combining all three DML types in a single MERGE
--   2. Using subqueries in USING to join streams with reference tables
--   3. How multiple changes accumulate and cancel out in streams
--
-- THE COMPLETE CDC MERGE PATTERN (CRITICAL INTERVIEW TOPIC):
-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │  MERGE INTO target                                                      │
-- │  USING (stream + reference tables) S ON join_key                        │
-- │                                                                         │
-- │  WHEN MATCHED AND ACTION='DELETE' AND ISUPDATE='FALSE'                  │
-- │    THEN DELETE                        ← Handle deletes                  │
-- │                                                                         │
-- │  WHEN MATCHED AND ACTION='INSERT' AND ISUPDATE='TRUE'                   │
-- │    THEN UPDATE SET ...                ← Handle updates                  │
-- │                                                                         │
-- │  WHEN NOT MATCHED AND ACTION='INSERT'                                   │
-- │    THEN INSERT (...)                  ← Handle inserts                  │
-- └──────────────────────────────────────────────────────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - One MERGE handles all three DML types atomically
--   - The stream can be joined with reference tables in the USING clause
--   - Order matters: DELETE first, UPDATE second, INSERT third
--   - If a row is inserted then deleted before consumption, it cancels out
--   - This is the production-ready CDC pattern for Snowflake pipelines
-- =============================================================================


-- =============================================
-- STEP 1: The complete MERGE statement
-- =============================================
-- This single MERGE handles DELETE, UPDATE, and INSERT from the stream.

MERGE INTO SALES_FINAL_TABLE F
USING (
    -- Join stream with reference table for enrichment
    SELECT STRE.*, ST.location, ST.employees
    FROM SALES_STREAM STRE
    JOIN STORE_TABLE ST ON STRE.store_id = ST.store_id
) S
ON F.id = S.id

-- Handle DELETES
WHEN MATCHED
    AND S.METADATA$ACTION = 'DELETE'
    AND S.METADATA$ISUPDATE = 'FALSE'
    THEN DELETE

-- Handle UPDATES (apply the new values)
WHEN MATCHED
    AND S.METADATA$ACTION = 'INSERT'
    AND S.METADATA$ISUPDATE = 'TRUE'
    THEN UPDATE
    SET F.product  = S.product,
        F.price    = S.price,
        F.amount   = S.amount,
        F.store_id = S.store_id

-- Handle INSERTS (new rows)
WHEN NOT MATCHED
    AND S.METADATA$ACTION = 'INSERT'
    THEN INSERT (id, product, price, store_id, amount, employees, location)
    VALUES (S.id, S.product, S.price, S.store_id, S.amount, S.employees, S.location);


-- Verify state
SELECT * FROM SALES_RAW_STAGING;
SELECT * FROM SALES_STREAM;          -- Empty (consumed)
SELECT * FROM SALES_FINAL_TABLE;


-- =============================================
-- STEP 2: Test with canceling changes
-- =============================================
-- If a row is inserted and deleted before the stream is consumed,
-- the net effect CANCELS OUT — the stream shows nothing for that row.

-- Insert a row
INSERT INTO SALES_RAW_STAGING VALUES (2, 'Lemon', 0.99, 1, 1);

-- Update it
UPDATE SALES_RAW_STAGING
SET PRODUCT = 'Lemonade'
WHERE PRODUCT = 'Lemon';

-- Delete it
DELETE FROM SALES_RAW_STAGING
WHERE PRODUCT = 'Lemonade';

-- Check stream: the insert+update+delete for this row CANCEL OUT
-- The stream may show no changes for this row, or a simplified net result
SELECT * FROM SALES_STREAM;


-- =============================================
-- STEP 3: Test with mixed changes
-- =============================================
-- Multiple different types of changes in one batch
INSERT INTO SALES_RAW_STAGING VALUES (10, 'Lemon Juice', 2.99, 1, 1);

UPDATE SALES_RAW_STAGING
SET PRICE = 3
WHERE PRODUCT = 'Mango';

DELETE FROM SALES_RAW_STAGING
WHERE PRODUCT = 'Potato';

-- View all accumulated changes
SELECT * FROM SALES_STREAM;
-- Shows: INSERT for Lemon Juice, UPDATE pair for Mango, DELETE for Potato

-- Apply all at once with the single MERGE (re-run the MERGE from Step 1)


-- =============================================================================
-- CONCEPT GAP: NET CHANGE BEHAVIOR
-- =============================================================================
-- Streams track the NET effect of all changes since last consumption:
--
-- SCENARIO 1: INSERT then DELETE (same row) → Cancels out (no stream entry)
-- SCENARIO 2: INSERT then UPDATE → Shows as a single INSERT with final values
-- SCENARIO 3: UPDATE then UPDATE → Shows one UPDATE pair with final values
-- SCENARIO 4: UPDATE then DELETE → Shows as a single DELETE
--
-- This means the MERGE only processes the FINAL state of each row,
-- not every intermediate change. This is more efficient!
-- =============================================================================
