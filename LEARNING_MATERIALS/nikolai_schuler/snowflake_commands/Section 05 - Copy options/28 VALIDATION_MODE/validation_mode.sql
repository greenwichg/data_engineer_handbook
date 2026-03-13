-- =============================================================================
-- SECTION 5.28: VALIDATION_MODE - DRY-RUN DATA VALIDATION
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to validate staged data WITHOUT actually loading it, using
--   VALIDATION_MODE as a pre-flight check before production loads.
--
-- WHAT YOU WILL LEARN:
--   1. RETURN_ERRORS - preview all rows that would cause errors
--   2. RETURN_n_ROWS - preview first n rows as they would be loaded
--   3. Why validation should always precede production loads
--
-- WHY USE VALIDATION_MODE?
--   - Preview data before committing to a load
--   - Identify ALL errors in one pass (not just the first one)
--   - Test file format settings without side effects
--   - No data is inserted, no load history is recorded
--   - Essential for data quality gates in CI/CD pipelines
--
-- KEY INTERVIEW CONCEPTS:
--   - VALIDATION_MODE = RETURN_ERRORS (returns all error rows)
--   - VALIDATION_MODE = RETURN_n_ROWS (returns first n rows as preview)
--   - No data is loaded when VALIDATION_MODE is used
--   - Cannot be combined with ON_ERROR (they're mutually exclusive)
--   - Load metadata is NOT recorded (file can still be loaded after)
--
-- VALIDATION_MODE OPTIONS:
-- ┌─────────────────────┬──────────────────────────────────────────────────┐
-- │ Option              │ Behavior                                        │
-- ├─────────────────────┼──────────────────────────────────────────────────┤
-- │ RETURN_ERRORS       │ Returns all rows that would cause errors.       │
-- │                     │ If no errors, returns empty result set.         │
-- │ RETURN_n_ROWS       │ Returns first n rows as they would be loaded.   │
-- │                     │ Also validates those rows for errors.           │
-- │                     │ Replace n with a number (e.g., RETURN_5_ROWS).  │
-- └─────────────────────┴──────────────────────────────────────────────────┘
--
-- CONCEPT GAP FILLED - VALIDATION vs ON_ERROR:
--   VALIDATION_MODE: Preview/check BEFORE loading (no data inserted)
--   ON_ERROR:        Control behavior DURING loading (data may be inserted)
--   Use VALIDATION_MODE first, then ON_ERROR for the actual load.
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

-- Stage pointing to files with potential errors
CREATE OR REPLACE STAGE COPY_DB.PUBLIC.aws_stage_copy
    url = 's3://snowflakebucket-copyoption/size/';

-- List files to inspect what's available
LIST @COPY_DB.PUBLIC.aws_stage_copy;


-- =============================================
-- DEMO 1: RETURN_ERRORS - Find all problematic rows
-- =============================================
-- This does NOT load any data. It scans all matching files and returns
-- every row that would cause an error during actual loading.

COPY INTO COPY_DB.PUBLIC.ORDERS
    FROM @aws_stage_copy
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    pattern = '.*Order.*'
    VALIDATION_MODE = RETURN_ERRORS;

-- OUTPUT COLUMNS (when errors exist):
--   FILE        - Source file name
--   LINE        - Line number in the source file
--   CHARACTER   - Character position of the error
--   CATEGORY    - Error category (e.g., conversion_error)
--   CODE        - Snowflake error code
--   MESSAGE     - Human-readable error message
--   COLUMN_NAME - Target column where error occurred
--   ROW_NUMBER  - Row number in the file
--   REJECTED_RECORD - Full text of the rejected row

-- If no errors: Returns empty result set (all rows are valid).


-- =============================================
-- DEMO 2: RETURN_n_ROWS - Preview data before loading
-- =============================================
-- Returns the first 5 rows as they would appear after loading.
-- Also validates those rows for errors.

COPY INTO COPY_DB.PUBLIC.ORDERS
    FROM @aws_stage_copy
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    pattern = '.*Order.*'
    VALIDATION_MODE = RETURN_5_ROWS;

-- USE CASES FOR RETURN_n_ROWS:
--   - Verify column mapping is correct (data lands in right columns)
--   - Check data types parse correctly
--   - Confirm file format settings (delimiter, header skip) are right
--   - Quick sanity check before a large production load

-- INTERVIEW TIP: RETURN_n_ROWS validates the first n rows AND returns
-- them as a result set. If any of those n rows have errors, the errors
-- are shown instead of the data.


-- =============================================================================
-- CONCEPT GAP: VALIDATION WORKFLOW BEST PRACTICE
-- =============================================================================
-- A production-grade data loading workflow:
--
-- 1. LIST @stage                          -- Discover files
-- 2. VALIDATION_MODE = RETURN_5_ROWS      -- Quick preview / format check
-- 3. VALIDATION_MODE = RETURN_ERRORS      -- Full error scan
-- 4. If errors found:
--    a. Fix source data, OR
--    b. Adjust file format, OR
--    c. Use ON_ERROR = CONTINUE/SKIP_FILE with error logging
-- 5. COPY INTO ... (actual load)          -- Production load
-- 6. SELECT COUNT(*) FROM table           -- Verify row count
-- 7. Query load_history                   -- Audit the load
-- =============================================================================
