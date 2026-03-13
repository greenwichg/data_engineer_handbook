-- =============================================================================
-- SECTION 19.2: STREAMS — UPDATE OPERATION
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how streams capture UPDATE operations and how to use MERGE
--   with stream metadata columns to propagate updates to a target table.
--
-- WHAT YOU WILL LEARN:
--   1. How UPDATEs appear in streams (DELETE + INSERT pair)
--   2. Using METADATA$ACTION and METADATA$ISUPDATE to filter updates
--   3. MERGE INTO pattern for applying stream updates
--
-- HOW UPDATES APPEAR IN STREAMS (CRITICAL INTERVIEW CONCEPT):
-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │ When you UPDATE a row, the stream records TWO entries:                  │
-- │                                                                         │
-- │   1. DELETE of the OLD row:                                             │
-- │      METADATA$ACTION = 'DELETE', METADATA$ISUPDATE = TRUE              │
-- │      → This is the "before" version of the row                         │
-- │                                                                         │
-- │   2. INSERT of the NEW row:                                             │
-- │      METADATA$ACTION = 'INSERT', METADATA$ISUPDATE = TRUE              │
-- │      → This is the "after" version of the row                          │
-- │                                                                         │
-- │ To apply ONLY the updated values, filter for:                           │
-- │   METADATA$ACTION = 'INSERT' AND METADATA$ISUPDATE = TRUE              │
-- └──────────────────────────────────────────────────────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - UPDATE in stream = DELETE (old) + INSERT (new), both with ISUPDATE=TRUE
--   - MERGE INTO is the standard pattern for applying stream changes
--   - WHEN MATCHED + metadata filters target only updated rows
--   - After MERGE consumes the stream, it resets to empty
-- =============================================================================


-- =============================================
-- UPDATE EXAMPLE 1: Change product name
-- =============================================
SELECT * FROM SALES_RAW_STAGING;
SELECT * FROM SALES_STREAM;

-- Update a row in the source table
UPDATE SALES_RAW_STAGING
SET PRODUCT = 'Potato' WHERE PRODUCT = 'Banana';

-- View the stream — you'll see TWO rows for this one UPDATE:
-- Row 1: METADATA$ACTION='DELETE', METADATA$ISUPDATE=TRUE  (old: Banana)
-- Row 2: METADATA$ACTION='INSERT', METADATA$ISUPDATE=TRUE  (new: Potato)

-- Apply the update to the target using MERGE
MERGE INTO SALES_FINAL_TABLE F
USING SALES_STREAM S
    ON F.id = S.id
WHEN MATCHED
    AND S.METADATA$ACTION = 'INSERT'
    AND S.METADATA$ISUPDATE = 'TRUE'
    THEN UPDATE
    SET F.product  = S.product,
        F.price    = S.price,
        F.amount   = S.amount,
        F.store_id = S.store_id;

-- MERGE BREAKDOWN:
--   MERGE INTO target USING stream ON join_key
--   WHEN MATCHED                          → Row exists in target
--     AND ACTION = 'INSERT'               → This is the NEW version
--     AND ISUPDATE = 'TRUE'               → It's from an UPDATE (not a fresh insert)
--     THEN UPDATE SET ...                 → Apply the new values

-- Verify
SELECT * FROM SALES_FINAL_TABLE;   -- Banana → Potato
SELECT * FROM SALES_RAW_STAGING;
SELECT * FROM SALES_STREAM;        -- Empty (consumed)


-- =============================================
-- UPDATE EXAMPLE 2: Another product change
-- =============================================
UPDATE SALES_RAW_STAGING
SET PRODUCT = 'Green apple' WHERE PRODUCT = 'Apple';

-- Apply to target
MERGE INTO SALES_FINAL_TABLE F
USING SALES_STREAM S
    ON F.id = S.id
WHEN MATCHED
    AND S.METADATA$ACTION = 'INSERT'
    AND S.METADATA$ISUPDATE = 'TRUE'
    THEN UPDATE
    SET F.product  = S.product,
        F.price    = S.price,
        F.amount   = S.amount,
        F.store_id = S.store_id;

-- Verify
SELECT * FROM SALES_FINAL_TABLE;   -- Apple → Green apple
SELECT * FROM SALES_RAW_STAGING;
SELECT * FROM SALES_STREAM;        -- Empty (consumed)


-- =============================================================================
-- CONCEPT GAP: METADATA COLUMNS CHEAT SHEET
-- =============================================================================
-- ┌─────────────────────┬─────────────────┬───────────────────┬─────────────┐
-- │ Source DML           │ METADATA$ACTION │ METADATA$ISUPDATE │ Meaning     │
-- ├─────────────────────┼─────────────────┼───────────────────┼─────────────┤
-- │ INSERT              │ INSERT          │ FALSE             │ New row     │
-- │ UPDATE (old value)  │ DELETE          │ TRUE              │ Before-image│
-- │ UPDATE (new value)  │ INSERT          │ TRUE              │ After-image │
-- │ DELETE              │ DELETE          │ FALSE             │ Removed row │
-- └─────────────────────┴─────────────────┴───────────────────┴─────────────┘
--
-- FILTERING PATTERNS:
--   Pure inserts only:   ACTION = 'INSERT' AND ISUPDATE = FALSE
--   Update after-image:  ACTION = 'INSERT' AND ISUPDATE = TRUE
--   Update before-image: ACTION = 'DELETE' AND ISUPDATE = TRUE
--   Pure deletes only:   ACTION = 'DELETE' AND ISUPDATE = FALSE
-- =============================================================================
