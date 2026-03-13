-- =============================================================================
-- SECTION 4.21: COPY INTO COMMAND - VARIATIONS AND FILE SELECTION
-- =============================================================================
--
-- OBJECTIVE:
--   Master the different ways to use COPY INTO: basic load, fully qualified
--   stage names, loading specific files, and pattern-based file selection.
--
-- WHAT YOU WILL LEARN:
--   1. Basic COPY INTO from a stage
--   2. Fully qualified stage references (db.schema.stage)
--   3. Loading specific files with files=('...')
--   4. Pattern-based file selection with pattern='...'
--   5. Using LIST to discover files before loading
--
-- KEY INTERVIEW CONCEPTS:
--   - COPY INTO from @stage vs @db.schema.stage (fully qualified)
--   - files=('file.csv') to load specific files by exact name
--   - pattern='.*regex.*' to match file names with regex
--   - files= and pattern= are MUTUALLY EXCLUSIVE (cannot combine them)
--   - LIST @stage to inspect available files before loading
--
-- COPY INTO SYNTAX (CONCEPT GAP FILLED):
--   COPY INTO <table>
--     FROM @<stage>[/<path>]
--     [FILES = ('file1.csv', 'file2.csv')]
--     [PATTERN = '.*regex.*']
--     [FILE_FORMAT = (...)]
--     [COPY_OPTIONS]
--
-- IMPORTANT BEHAVIORS:
--   - Snowflake loads ALL files in the stage by default (if no files/pattern)
--   - Already-loaded files are automatically skipped (64-day metadata window)
--   - Column mapping is POSITIONAL (CSV col 1 -> table col 1)
-- =============================================================================


-- =============================================
-- STEP 1: Create the target table
-- =============================================
CREATE OR REPLACE TABLE OUR_FIRST_DB.PUBLIC.ORDERS (
    ORDER_ID    VARCHAR(30),
    AMOUNT      INT,
    PROFIT      INT,
    QUANTITY    INT,
    CATEGORY    VARCHAR(30),
    SUBCATEGORY VARCHAR(30)
);

-- Verify table is empty
SELECT * FROM OUR_FIRST_DB.PUBLIC.ORDERS;


-- =============================================
-- STEP 2: Basic COPY using short stage name
-- =============================================
-- Works when your current context (USE DATABASE/SCHEMA) matches the stage location.
-- This loads ALL files in the stage (no files/pattern filter).

COPY INTO OUR_FIRST_DB.PUBLIC.ORDERS
    FROM @aws_stage
    file_format = (type = csv field_delimiter = ',' skip_header = 1);

-- WARNING: If the stage contains non-CSV files or files with different schemas,
-- this will fail. Always use files= or pattern= in production.


-- =============================================
-- STEP 3: COPY using fully qualified stage name
-- =============================================
-- Best practice: Always use fully qualified names to avoid context-dependent errors.
-- Format: @DATABASE.SCHEMA.STAGE_NAME

COPY INTO OUR_FIRST_DB.PUBLIC.ORDERS
    FROM @MANAGE_DB.external_stages.aws_stage
    file_format = (type = csv field_delimiter = ',' skip_header = 1);

-- INTERVIEW TIP: Fully qualified names make your SQL portable across worksheets,
-- stored procedures, and tasks (which may run under different contexts).


-- =============================================
-- STEP 4: List files in the stage
-- =============================================
-- Always inspect available files before writing COPY commands.

LIST @MANAGE_DB.external_stages.aws_stage;

-- This returns: name, size, md5, last_modified
-- Use this output to determine correct file names for the files= parameter.


-- =============================================
-- STEP 5: COPY with specific file(s)
-- =============================================
-- Use files=() to load only the named file(s). Names must be EXACT matches.

COPY INTO OUR_FIRST_DB.PUBLIC.ORDERS
    FROM @MANAGE_DB.external_stages.aws_stage
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    files = ('OrderDetails.csv');

-- MULTIPLE FILES EXAMPLE:
-- files = ('OrderDetails.csv', 'OrderDetails_2.csv', 'OrderDetails_3.csv');

-- INTERVIEW TIP: File names are case-sensitive and must include the extension.


-- =============================================
-- STEP 6: COPY with pattern-based file selection
-- =============================================
-- Use pattern= with regex to match multiple files dynamically.

COPY INTO OUR_FIRST_DB.PUBLIC.ORDERS
    FROM @MANAGE_DB.external_stages.aws_stage
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    pattern = '.*Order.*';     -- Any file containing "Order" in the name

-- CONCEPT GAP FILLED - files= vs pattern=:
-- ┌────────────────────┬─────────────────────────────────────────────────┐
-- │ Feature            │ files=                  │ pattern=              │
-- ├────────────────────┼─────────────────────────┼───────────────────────┤
-- │ Match type         │ Exact file name         │ Regex pattern         │
-- │ Multiple files     │ Comma-separated list    │ Single regex          │
-- │ Case sensitive     │ Yes                     │ Yes                   │
-- │ Use case           │ Known specific files    │ Dynamic/date-based    │
-- │ Can combine?       │ NO - mutually exclusive with pattern=           │
-- └────────────────────┴─────────────────────────────────────────────────┘
-- =============================================================================
