-- =============================================================================
-- SECTION 19.3: STREAMS — DELETE OPERATION
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how streams capture DELETE operations and how to use MERGE
--   to propagate deletions from source to target table.
--
-- WHAT YOU WILL LEARN:
--   1. How DELETEs appear in streams
--   2. Distinguishing true deletes from update-related deletes
--   3. MERGE with WHEN MATCHED THEN DELETE pattern
--
-- HOW DELETES APPEAR IN STREAMS:
-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │ A true DELETE produces ONE stream entry:                                │
-- │   METADATA$ACTION = 'DELETE', METADATA$ISUPDATE = FALSE                │
-- │                                                                         │
-- │ IMPORTANT — Distinguish from UPDATE-related deletes:                   │
-- │   True DELETE:    ACTION='DELETE', ISUPDATE=FALSE                       │
-- │   UPDATE (old):   ACTION='DELETE', ISUPDATE=TRUE   ← NOT a real delete│
-- └──────────────────────────────────────────────────────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - Filter true deletes: ACTION='DELETE' AND ISUPDATE='FALSE'
--   - MERGE with WHEN MATCHED THEN DELETE applies deletions
--   - This keeps target tables in sync with source deletions
-- =============================================================================


-- =============================================
-- STEP 1: Verify current state
-- =============================================
SELECT * FROM SALES_FINAL_TABLE;
SELECT * FROM SALES_RAW_STAGING;
SELECT * FROM SALES_STREAM;


-- =============================================
-- STEP 2: Delete a row from the source
-- =============================================
DELETE FROM SALES_RAW_STAGING
WHERE PRODUCT = 'Lemon';

-- View the stream
-- METADATA$ACTION = 'DELETE', METADATA$ISUPDATE = FALSE
-- This confirms it's a TRUE delete (not part of an UPDATE)
SELECT * FROM SALES_STREAM;


-- =============================================
-- STEP 3: Apply the delete to the target
-- =============================================
MERGE INTO SALES_FINAL_TABLE F
USING SALES_STREAM S
    ON F.id = S.id
WHEN MATCHED
    AND S.METADATA$ACTION = 'DELETE'
    AND S.METADATA$ISUPDATE = 'FALSE'
    THEN DELETE;

-- MERGE BREAKDOWN:
--   WHEN MATCHED              → Row exists in target
--   AND ACTION = 'DELETE'     → Stream says it was deleted from source
--   AND ISUPDATE = 'FALSE'   → It's a TRUE delete (not an UPDATE's delete-half)
--   THEN DELETE               → Remove the row from target

-- Verify: Lemon is gone from both tables
SELECT * FROM SALES_FINAL_TABLE;
SELECT * FROM SALES_RAW_STAGING;
SELECT * FROM SALES_STREAM;           -- Empty (consumed)
