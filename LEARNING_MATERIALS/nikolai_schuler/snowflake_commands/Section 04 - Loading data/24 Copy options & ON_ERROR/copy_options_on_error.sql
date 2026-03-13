-- =============================================================================
-- SECTION 4.24: COPY OPTIONS & ON_ERROR HANDLING
-- =============================================================================
--
-- OBJECTIVE:
--   Master the ON_ERROR option to control how COPY INTO handles rows and
--   files with errors. Understand the trade-offs of each error strategy.
--
-- WHAT YOU WILL LEARN:
--   1. Default error behavior (ABORT_STATEMENT)
--   2. CONTINUE - skip bad rows, load the rest
--   3. SKIP_FILE - skip entire file on any error
--   4. SKIP_FILE_<n> - skip file after n errors
--   5. SKIP_FILE_<n>% - skip file after n% error rate
--   6. SIZE_LIMIT to throttle data loading
--
-- ON_ERROR OPTIONS SUMMARY:
-- ┌───────────────────────┬─────────────────────────────────────────────────┐
-- │ Option                │ Behavior                                       │
-- ├───────────────────────┼─────────────────────────────────────────────────┤
-- │ ABORT_STATEMENT       │ Stop entire COPY on first error (DEFAULT)      │
-- │ CONTINUE              │ Skip bad rows, load all good rows from all     │
-- │                       │ files. May result in partial data.             │
-- │ SKIP_FILE             │ Skip entire file if ANY row has an error.      │
-- │                       │ Other files still load normally.               │
-- │ SKIP_FILE_<n>         │ Skip file if error count >= n.                 │
-- │                       │ e.g., SKIP_FILE_2 skips after 2+ errors.      │
-- │ SKIP_FILE_<n>%        │ Skip file if error percentage >= n%.           │
-- │                       │ e.g., SKIP_FILE_0.5% skips at 0.5% error rate.│
-- └───────────────────────┴─────────────────────────────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - ABORT_STATEMENT is the default (safest for data integrity)
--   - CONTINUE loads partial data (use with caution - validate after!)
--   - SKIP_FILE variants provide file-level granularity
--   - SIZE_LIMIT = n (max bytes to load per COPY execution)
--
-- CONCEPT GAP FILLED - ERROR HANDLING BEST PRACTICES:
--   1. Development/Testing: Use CONTINUE to see all errors at once
--   2. Production (strict): Use ABORT_STATEMENT (default) or SKIP_FILE
--   3. Production (tolerant): Use SKIP_FILE_<n>% with a threshold
--   4. Always: Use VALIDATION_MODE first (Section 5.28) to preview errors
-- =============================================================================


-- =============================================
-- SETUP: Create stage pointing to error data
-- =============================================
CREATE OR REPLACE STAGE MANAGE_DB.external_stages.aws_stage_errorex
    url = 's3://bucketsnowflakes4';

-- List files to see what's available
LIST @MANAGE_DB.external_stages.aws_stage_errorex;

-- Create target table
CREATE OR REPLACE TABLE OUR_FIRST_DB.PUBLIC.ORDERS_EX (
    ORDER_ID    VARCHAR(30),
    AMOUNT      INT,
    PROFIT      INT,
    QUANTITY    INT,
    CATEGORY    VARCHAR(30),
    SUBCATEGORY VARCHAR(30)
);


-- =============================================
-- DEMO 1: Default behavior (error demonstration)
-- =============================================
-- Without ON_ERROR, the default is ABORT_STATEMENT.
-- The entire COPY fails on the first error row.

COPY INTO OUR_FIRST_DB.PUBLIC.ORDERS_EX
    FROM @MANAGE_DB.external_stages.aws_stage_errorex
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    files = ('OrderDetails_error.csv');

-- Expected: Error message showing the problematic row.
-- No data is loaded at all.

-- Verify table is still empty
SELECT * FROM OUR_FIRST_DB.PUBLIC.ORDERS_EX;


-- =============================================
-- DEMO 2: ON_ERROR = CONTINUE
-- =============================================
-- Skip bad rows, load all valid rows from all files.

COPY INTO OUR_FIRST_DB.PUBLIC.ORDERS_EX
    FROM @MANAGE_DB.external_stages.aws_stage_errorex
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    files = ('OrderDetails_error.csv')
    ON_ERROR = 'CONTINUE';

-- COPY output shows: rows_loaded, errors_seen, first_error, first_error_line
-- WARNING: CONTINUE can lead to partial/inconsistent data.
-- Always check the COPY output for error counts!

SELECT * FROM OUR_FIRST_DB.PUBLIC.ORDERS_EX;
SELECT COUNT(*) FROM OUR_FIRST_DB.PUBLIC.ORDERS_EX;

-- Reset for next demo
TRUNCATE TABLE OUR_FIRST_DB.PUBLIC.ORDERS_EX;


-- =============================================
-- DEMO 3: ON_ERROR = ABORT_STATEMENT (explicit)
-- =============================================
-- Same as default, but stated explicitly for clarity.
-- Stops the entire COPY on the first error in ANY file.

COPY INTO OUR_FIRST_DB.PUBLIC.ORDERS_EX
    FROM @MANAGE_DB.external_stages.aws_stage_errorex
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    files = ('OrderDetails_error.csv', 'OrderDetails_error2.csv')
    ON_ERROR = 'ABORT_STATEMENT';

-- Expected: Entire operation fails, no data loaded from ANY file.

SELECT * FROM OUR_FIRST_DB.PUBLIC.ORDERS_EX;
SELECT COUNT(*) FROM OUR_FIRST_DB.PUBLIC.ORDERS_EX;

TRUNCATE TABLE OUR_FIRST_DB.PUBLIC.ORDERS_EX;


-- =============================================
-- DEMO 4: ON_ERROR = SKIP_FILE
-- =============================================
-- If ANY row in a file has an error, skip the ENTIRE file.
-- Other error-free files are loaded normally.

COPY INTO OUR_FIRST_DB.PUBLIC.ORDERS_EX
    FROM @MANAGE_DB.external_stages.aws_stage_errorex
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    files = ('OrderDetails_error.csv', 'OrderDetails_error2.csv')
    ON_ERROR = 'SKIP_FILE';

-- INTERVIEW TIP: SKIP_FILE is "all or nothing" per file.
-- Even 1 bad row causes the entire file to be skipped.

SELECT * FROM OUR_FIRST_DB.PUBLIC.ORDERS_EX;
SELECT COUNT(*) FROM OUR_FIRST_DB.PUBLIC.ORDERS_EX;

TRUNCATE TABLE OUR_FIRST_DB.PUBLIC.ORDERS_EX;


-- =============================================
-- DEMO 5: ON_ERROR = SKIP_FILE_<n>
-- =============================================
-- Skip file only if error count reaches the threshold n.
-- Files with fewer errors than n are still loaded (bad rows skipped).

COPY INTO OUR_FIRST_DB.PUBLIC.ORDERS_EX
    FROM @MANAGE_DB.external_stages.aws_stage_errorex
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    files = ('OrderDetails_error.csv', 'OrderDetails_error2.csv')
    ON_ERROR = 'SKIP_FILE_2';

-- BEHAVIOR: If a file has 2 or more errors, skip the entire file.
-- If a file has only 1 error, that row is skipped but the rest loads.

SELECT * FROM OUR_FIRST_DB.PUBLIC.ORDERS_EX;
SELECT COUNT(*) FROM OUR_FIRST_DB.PUBLIC.ORDERS_EX;

TRUNCATE TABLE OUR_FIRST_DB.PUBLIC.ORDERS_EX;


-- =============================================
-- DEMO 6: ON_ERROR = SKIP_FILE_<n>%
-- =============================================
-- Skip file if error percentage exceeds n%.
-- Useful when file sizes vary and absolute counts aren't meaningful.

COPY INTO OUR_FIRST_DB.PUBLIC.ORDERS_EX
    FROM @MANAGE_DB.external_stages.aws_stage_errorex
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    files = ('OrderDetails_error.csv', 'OrderDetails_error2.csv')
    ON_ERROR = 'SKIP_FILE_0.5%';

-- EXAMPLE: A file with 1000 rows and 5 errors = 0.5% error rate.
-- With SKIP_FILE_0.5%, this file would be skipped (0.5% >= 0.5%).

SELECT * FROM OUR_FIRST_DB.PUBLIC.ORDERS_EX;


-- =============================================
-- DEMO 7: Combining ON_ERROR with SIZE_LIMIT
-- =============================================
-- SIZE_LIMIT caps the total bytes loaded per COPY execution.

CREATE OR REPLACE TABLE OUR_FIRST_DB.PUBLIC.ORDERS_EX (
    ORDER_ID    VARCHAR(30),
    AMOUNT      INT,
    PROFIT      INT,
    QUANTITY    INT,
    CATEGORY    VARCHAR(30),
    SUBCATEGORY VARCHAR(30)
);

COPY INTO OUR_FIRST_DB.PUBLIC.ORDERS_EX
    FROM @MANAGE_DB.external_stages.aws_stage_errorex
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    files = ('OrderDetails_error.csv', 'OrderDetails_error2.csv')
    ON_ERROR = SKIP_FILE_3
    SIZE_LIMIT = 30;

-- NOTE: SIZE_LIMIT = 30 bytes is very small (for demo purposes).
-- In production, you'd use larger values like SIZE_LIMIT = 1073741824 (1 GB).
-- Snowflake finishes loading the CURRENT file even if limit is exceeded,
-- then stops loading additional files.


-- =============================================================================
-- CONCEPT GAP: WHEN TO USE EACH ON_ERROR STRATEGY
-- =============================================================================
-- Scenario                              │ Recommended ON_ERROR
-- ──────────────────────────────────────────────────────────────────────────
-- Initial development/testing           │ CONTINUE (see all errors at once)
-- Production - mission critical data    │ ABORT_STATEMENT (default)
-- Production - tolerant/append loads    │ SKIP_FILE or SKIP_FILE_<n>%
-- Large batch loads with known issues   │ SKIP_FILE_<n> with a threshold
-- Data quality audit before load        │ Use VALIDATION_MODE instead
-- =============================================================================
