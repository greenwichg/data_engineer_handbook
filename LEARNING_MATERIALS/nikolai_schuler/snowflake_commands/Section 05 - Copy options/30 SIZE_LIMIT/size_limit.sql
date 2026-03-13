-- =============================================================================
-- SECTION 5.30: SIZE_LIMIT OPTION
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how SIZE_LIMIT controls the maximum amount of data loaded in a
--   single COPY command execution, enabling throttled/incremental loads.
--
-- WHAT YOU WILL LEARN:
--   1. How SIZE_LIMIT works (byte-based threshold)
--   2. Behavior when limit is reached mid-file
--   3. Use cases for throttled data loading
--
-- KEY INTERVIEW CONCEPTS:
--   - SIZE_LIMIT = n (value in BYTES, not rows or files)
--   - Snowflake finishes loading the CURRENT file even if limit is exceeded
--   - Then stops loading additional files
--   - Does NOT split files - operates at file-level granularity
--   - Useful for incremental/throttled data loading
--
-- HOW SIZE_LIMIT WORKS (CONCEPT GAP FILLED):
--   1. Snowflake starts loading files one at a time
--   2. After each file, it checks: total_bytes_loaded >= SIZE_LIMIT?
--   3. If YES -> stop, don't load the next file
--   4. If NO  -> continue to the next file
--   5. The current file ALWAYS completes (never partially loaded)
--
--   Example with SIZE_LIMIT = 50000 (50 KB):
--     File 1: 30 KB -> loaded (total: 30 KB, under limit)
--     File 2: 40 KB -> loaded (total: 70 KB, exceeds limit mid-file)
--     File 3: 20 KB -> NOT loaded (limit already exceeded)
--
-- IMPORTANT: A single file larger than SIZE_LIMIT will still load completely.
-- SIZE_LIMIT only prevents ADDITIONAL files from loading.
-- =============================================================================


-- =============================================
-- SETUP: Create database, table, and stage
-- =============================================
CREATE OR REPLACE DATABASE COPY_DB;

CREATE OR REPLACE TABLE COPY_DB.PUBLIC.ORDERS (
    ORDER_ID    VARCHAR(30),
    AMOUNT      VARCHAR(30),
    PROFIT      INT,
    QUANTITY    INT,
    CATEGORY    VARCHAR(30),
    SUBCATEGORY VARCHAR(30)
);

-- Stage with multiple files of varying sizes
CREATE OR REPLACE STAGE COPY_DB.PUBLIC.aws_stage_copy
    url = 's3://snowflakebucket-copyoption/size/';

-- List files to see their sizes (important for understanding SIZE_LIMIT)
LIST @aws_stage_copy;
-- Check the 'size' column to understand the byte sizes of each file


-- =============================================
-- DEMO: Loading with SIZE_LIMIT
-- =============================================
-- Only load up to ~20,000 bytes (20 KB) of data.
-- If the first file exceeds this, it still loads fully,
-- but no additional files will be loaded.

COPY INTO COPY_DB.PUBLIC.ORDERS
    FROM @aws_stage_copy
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    pattern = '.*Order.*'
    SIZE_LIMIT = 20000;         -- 20,000 bytes = ~20 KB

-- CHECK THE COPY OUTPUT:
-- The 'status' column shows which files were loaded and which were skipped.
-- Files loaded: status = 'LOADED'
-- Files skipped (limit reached): not shown in output


-- =============================================================================
-- CONCEPT GAP: SIZE_LIMIT USE CASES
-- =============================================================================
-- 1. COST CONTROL:
--    Limit compute time per COPY execution to avoid runaway warehouse costs.
--    Combine with a TASK to load in scheduled batches.
--
-- 2. INCREMENTAL LOADING:
--    Load a manageable chunk per run. Re-run COPY to load the next batch.
--    Snowflake automatically skips already-loaded files.
--
-- 3. TESTING:
--    Load a small sample to verify format/schema before a full load.
--    SIZE_LIMIT = 1000000 (1 MB) for a quick test.
--
-- 4. PIPELINE THROTTLING:
--    Prevent a single COPY from consuming warehouse resources for too long.
--    Combine with TASK scheduling for steady-state ingestion.
--
-- SIZE_LIMIT vs RETURN_n_ROWS:
--   SIZE_LIMIT:     Actually loads data (limited amount)
--   RETURN_n_ROWS:  Only previews data (nothing loaded)
-- =============================================================================
