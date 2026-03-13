-- =============================================================================
-- SECTION 5.31: RETURN_FAILED_ONLY OPTION
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how RETURN_FAILED_ONLY filters the COPY command output to show
--   only files that encountered errors, simplifying error diagnosis.
--
-- WHAT YOU WILL LEARN:
--   1. RETURN_FAILED_ONLY = TRUE (filter COPY output to error files only)
--   2. Default behavior (FALSE - show all files in output)
--   3. Combining with ON_ERROR for comprehensive error visibility
--
-- KEY INTERVIEW CONCEPTS:
--   - RETURN_FAILED_ONLY = TRUE (only error files appear in COPY output)
--   - Default is FALSE (all files shown: loaded + failed)
--   - This controls the COPY RESULT METADATA only
--   - It does NOT change error handling behavior (use ON_ERROR for that)
--   - Best combined with ON_ERROR=CONTINUE to see which specific files failed
--
-- IMPORTANT DISTINCTION:
--   RETURN_FAILED_ONLY affects what you SEE in the COPY output.
--   ON_ERROR affects what HAPPENS during the COPY.
--   They are independent options that work well together.
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

-- Stage with files that contain errors
CREATE OR REPLACE STAGE COPY_DB.PUBLIC.aws_stage_copy
    url = 's3://snowflakebucket-copyoption/returnfailed/';

LIST @COPY_DB.PUBLIC.aws_stage_copy;


-- =============================================
-- DEMO 1: RETURN_FAILED_ONLY = TRUE (without ON_ERROR)
-- =============================================
-- Shows ONLY files that had errors in the COPY output.
-- Without ON_ERROR, default ABORT_STATEMENT applies - COPY stops on first error.

COPY INTO COPY_DB.PUBLIC.ORDERS
    FROM @aws_stage_copy
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    pattern = '.*Order.*'
    RETURN_FAILED_ONLY = TRUE;

-- OUTPUT: Only files with errors are shown.
-- Files that loaded successfully are hidden from the result.


-- =============================================
-- DEMO 2: RETURN_FAILED_ONLY + ON_ERROR=CONTINUE
-- =============================================
-- This is the most useful combination:
-- - ON_ERROR=CONTINUE loads good rows from all files
-- - RETURN_FAILED_ONLY=TRUE shows only the problematic files

COPY INTO COPY_DB.PUBLIC.ORDERS
    FROM @aws_stage_copy
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    pattern = '.*Order.*'
    ON_ERROR = CONTINUE
    RETURN_FAILED_ONLY = TRUE;

-- OUTPUT: Shows only files that had at least one error.
-- Each entry includes: file name, status, rows_parsed, rows_loaded,
-- error_limit, errors_seen, first_error, first_error_line, etc.

-- INTERVIEW TIP: This combination is ideal for production monitoring.
-- If the result is empty, all files loaded without errors.


-- =============================================
-- DEMO 3: Default behavior (RETURN_FAILED_ONLY = FALSE)
-- =============================================
-- Shows ALL files in the COPY output, whether they succeeded or failed.

CREATE OR REPLACE TABLE COPY_DB.PUBLIC.ORDERS (
    ORDER_ID    VARCHAR(30),
    AMOUNT      VARCHAR(30),
    PROFIT      INT,
    QUANTITY    INT,
    CATEGORY    VARCHAR(30),
    SUBCATEGORY VARCHAR(30)
);

COPY INTO COPY_DB.PUBLIC.ORDERS
    FROM @aws_stage_copy
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    pattern = '.*Order.*'
    ON_ERROR = CONTINUE;

-- OUTPUT: All files shown with their individual status.
-- Successful files show status = 'LOADED' or 'PARTIALLY_LOADED'.
-- Failed files show status = 'LOAD_FAILED'.

-- COPY OUTPUT COLUMNS (CONCEPT GAP FILLED):
-- ┌──────────────────────┬──────────────────────────────────────────────┐
-- │ Column               │ Description                                 │
-- ├──────────────────────┼──────────────────────────────────────────────┤
-- │ file                 │ Source file path                            │
-- │ status               │ LOADED, LOAD_FAILED, PARTIALLY_LOADED      │
-- │ rows_parsed          │ Total rows read from file                   │
-- │ rows_loaded          │ Rows successfully inserted                  │
-- │ error_limit          │ ON_ERROR threshold applied                  │
-- │ errors_seen          │ Number of errors encountered                │
-- │ first_error          │ Text of first error message                 │
-- │ first_error_line     │ Line number of first error                  │
-- │ first_error_character│ Character position of first error           │
-- │ first_error_column   │ Target column name of first error           │
-- └──────────────────────┴──────────────────────────────────────────────┘
-- =============================================================================
