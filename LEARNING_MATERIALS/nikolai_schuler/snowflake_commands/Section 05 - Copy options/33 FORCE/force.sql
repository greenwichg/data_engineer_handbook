-- =============================================================================
-- SECTION 5.33: FORCE OPTION - RELOADING ALREADY-LOADED FILES
-- =============================================================================
--
-- OBJECTIVE:
--   Understand how Snowflake's load tracking works and how FORCE=TRUE
--   bypasses it to reload previously-loaded files.
--
-- WHAT YOU WILL LEARN:
--   1. Snowflake's automatic load deduplication mechanism
--   2. FORCE = TRUE to override load tracking and reload files
--   3. Risks of duplicate data when using FORCE
--
-- SNOWFLAKE LOAD TRACKING (CONCEPT GAP FILLED):
--   Snowflake automatically tracks which files have been loaded:
--   - Metadata is stored for 64 days by default
--   - Tracking is based on file NAME + content HASH (ETag/MD5)
--   - If a file is renamed but content is the same -> still detected
--   - If content changes but name is the same -> loaded again (new content)
--   - After 64 days, file can be re-loaded without FORCE
--
-- KEY INTERVIEW CONCEPTS:
--   - FORCE = TRUE (reload previously loaded files)
--   - Without FORCE, re-running COPY skips already-loaded files
--   - Can cause DUPLICATE DATA if table is not truncated first
--   - Load metadata is tracked for 64 days by default
--
-- WHEN TO USE FORCE = TRUE:
--   1. Source file was corrected and needs to be reloaded
--   2. Table was truncated and needs to be repopulated
--   3. Load happened with wrong file_format and data is corrupt
--   4. Testing/development iterations
--
-- DANGER: FORCE bypasses deduplication. Always consider:
--   - TRUNCATE the table first, OR
--   - Use a staging table + MERGE for upsert logic
-- =============================================================================


-- =============================================
-- SETUP
-- =============================================
CREATE OR REPLACE TABLE COPY_DB.PUBLIC.ORDERS (
    ORDER_ID    VARCHAR(30),
    AMOUNT      VARCHAR(30),
    PROFIT      INT,
    QUANTITY    INT,
    CATEGORY    VARCHAR(30),
    SUBCATEGORY VARCHAR(30)
);

CREATE OR REPLACE STAGE COPY_DB.PUBLIC.aws_stage_copy
    url = 's3://snowflakebucket-copyoption/size/';

LIST @COPY_DB.PUBLIC.aws_stage_copy;


-- =============================================
-- STEP 1: Initial load (first time)
-- =============================================
COPY INTO COPY_DB.PUBLIC.ORDERS
    FROM @aws_stage_copy
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    pattern = '.*Order.*';

-- Expected: Files load successfully.


-- =============================================
-- STEP 2: Re-run COPY (without FORCE)
-- =============================================
-- Snowflake detects these files were already loaded and skips them.

COPY INTO COPY_DB.PUBLIC.ORDERS
    FROM @aws_stage_copy
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    pattern = '.*Order.*';

-- Expected output: "Copy executed with 0 files processed."
-- The files are SKIPPED because Snowflake's metadata says they're already loaded.

SELECT * FROM ORDERS;
-- Row count is the same as after Step 1.


-- =============================================
-- STEP 3: Re-run COPY WITH FORCE = TRUE
-- =============================================
-- FORCE = TRUE tells Snowflake to ignore load history and reload the files.

COPY INTO COPY_DB.PUBLIC.ORDERS
    FROM @aws_stage_copy
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    pattern = '.*Order.*'
    FORCE = TRUE;

-- Expected: Files are loaded AGAIN.
-- WARNING: The table now has DUPLICATE rows (2x the original data)!
-- This is because we didn't TRUNCATE before reloading.


-- =============================================================================
-- CONCEPT GAP: SAFE RELOAD PATTERNS
-- =============================================================================
-- Pattern 1: TRUNCATE + FORCE (full reload)
--   TRUNCATE TABLE orders;
--   COPY INTO orders FROM @stage FORCE = TRUE;
--
-- Pattern 2: Staging table + MERGE (upsert / no duplicates)
--   -- Load into a temp staging table
--   CREATE TEMPORARY TABLE orders_staging LIKE orders;
--   COPY INTO orders_staging FROM @stage FORCE = TRUE;
--   -- Merge into production table
--   MERGE INTO orders t USING orders_staging s
--       ON t.order_id = s.order_id
--       WHEN MATCHED THEN UPDATE SET ...
--       WHEN NOT MATCHED THEN INSERT ...;
--   DROP TABLE orders_staging;
--
-- Pattern 3: CREATE OR REPLACE (atomic swap)
--   -- Load into a new table, then swap
--   CREATE OR REPLACE TABLE orders AS
--   SELECT ... FROM @stage (file_format => ...);
--
-- INTERVIEW TIP: The MERGE pattern is the most production-grade approach
-- for idempotent data loading. It handles both new and updated records.
-- =============================================================================
