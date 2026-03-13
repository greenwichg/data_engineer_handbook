-- =============================================================================
-- SECTION 2.11: LOADING DATA IN SNOWFLAKE (Your First Data Load)
-- =============================================================================
--
-- OBJECTIVE:
--   Learn the basic end-to-end workflow for loading CSV data from an S3 bucket
--   into Snowflake. This is the simplest possible data loading pattern.
--
-- WHAT YOU WILL LEARN:
--   1. Creating a table with all-STRING columns for initial raw data load
--   2. Using COPY INTO to load data directly from an S3 URL
--   3. Inline file_format specification (type, delimiter, skip_header)
--
-- REAL-WORLD CONTEXT:
--   In production, you would typically:
--   - Use a named STAGE object instead of an inline S3 URL
--   - Use a named FILE FORMAT object instead of inline options
--   - Use proper data types (not all STRING) in the target table
--   - This "all STRING" approach is fine for initial exploration/prototyping
--
-- KEY INTERVIEW CONCEPTS:
--   - CREATE TABLE with all-STRING columns for flexible initial load
--   - COPY INTO from S3 with inline file_format (type, delimiter, skip_header)
--   - Direct S3 URL reference (without a named stage)
--   - Snowflake's load tracking: re-running COPY skips already-loaded files
--
-- CONCEPT GAP FILLED - SNOWFLAKE LOAD TRACKING:
--   Snowflake maintains a 64-day load metadata history. If you COPY the same
--   file again (same name + same content), Snowflake skips it silently.
--   To force a reload, use FORCE=TRUE (covered in Section 5.33).
--
-- PREREQUISITES:
--   - Database OUR_FIRST_DB must exist (create it via UI or SQL)
--   - S3 bucket must be publicly accessible (no credentials needed here)
-- =============================================================================


-- =============================================
-- STEP 1: Create the target table
-- =============================================
-- NOTE: All columns are STRING type intentionally.
-- This is a common "raw/staging" pattern:
--   - Avoids type-casting errors during initial load
--   - Data can be validated and cast to proper types later
--   - Trade-off: No type enforcement at load time

CREATE TABLE "OUR_FIRST_DB"."PUBLIC"."LOAN_PAYMENT" (
    "Loan_ID"        STRING,    -- Unique loan identifier
    "loan_status"    STRING,    -- Current status (e.g., PAIDOFF, COLLECTION)
    "Principal"      STRING,    -- Loan principal amount (loaded as string)
    "terms"          STRING,    -- Loan term in days
    "effective_date" STRING,    -- Date loan was issued
    "due_date"       STRING,    -- Payment due date
    "paid_off_time"  STRING,    -- Actual payoff date (NULL if unpaid)
    "past_due_days"  STRING,    -- Number of days past due
    "age"            STRING,    -- Borrower age
    "education"      STRING,    -- Education level (e.g., college, High School)
    "Gender"         STRING     -- Borrower gender
);

-- INTERVIEW TIP: Using quoted identifiers ("Loan_ID") makes column names
-- case-sensitive. Without quotes, Snowflake uppercases all identifiers.
-- Best practice: Use UPPERCASE without quotes for consistency.


-- =============================================
-- STEP 2: Verify the table is empty
-- =============================================
USE DATABASE OUR_FIRST_DB;

SELECT * FROM LOAN_PAYMENT;
-- Expected: 0 rows (table was just created)


-- =============================================
-- STEP 3: Load data from S3 using COPY INTO
-- =============================================
-- COPY INTO is Snowflake's bulk loading command.
-- Here we use an inline S3 URL (no named stage required for public buckets).

COPY INTO LOAN_PAYMENT
    FROM s3://bucketsnowflakes3/Loan_payments_data.csv
    file_format = (
        type         = csv          -- File type: CSV
        field_delimiter = ','       -- Column separator
        skip_header  = 1            -- Skip the first row (header row)
    );

-- WHAT HAPPENS UNDER THE HOOD:
--   1. Snowflake connects to the S3 bucket (public, no credentials)
--   2. Downloads and parses the CSV file
--   3. Maps CSV columns by POSITION to table columns (left to right)
--   4. Inserts all rows into LOAN_PAYMENT
--   5. Records this file in load metadata (prevents re-loading)

-- INTERVIEW TIP: Column mapping in COPY is positional by default.
--   CSV column 1 -> Table column 1, CSV column 2 -> Table column 2, etc.
--   Column NAMES in the CSV header are ignored (just skipped via skip_header).


-- =============================================
-- STEP 4: Validate the loaded data
-- =============================================
SELECT * FROM LOAN_PAYMENT;
-- Expected: All rows from the CSV file, all values as strings

-- CONCEPT GAP FILLED - USEFUL VALIDATION QUERIES:
-- Check row count:
SELECT COUNT(*) AS total_rows FROM LOAN_PAYMENT;

-- Check for NULLs in critical columns:
SELECT COUNT(*) AS null_loan_ids
FROM LOAN_PAYMENT
WHERE "Loan_ID" IS NULL;

-- Preview distinct values in a column:
SELECT DISTINCT "loan_status" FROM LOAN_PAYMENT;


-- =============================================================================
-- CONCEPT GAP: DATA TYPES BEST PRACTICE
-- =============================================================================
-- After validating the raw data, you would typically create a properly-typed
-- table and INSERT INTO it with CAST/TRY_CAST:
--
-- CREATE TABLE OUR_FIRST_DB.PUBLIC.LOAN_PAYMENT_TYPED (
--     Loan_ID        VARCHAR(20),
--     loan_status    VARCHAR(20),
--     Principal      NUMBER(10,2),      -- Proper numeric type
--     terms          INT,                -- Integer for term days
--     effective_date DATE,               -- Proper date type
--     due_date       DATE,
--     paid_off_time  DATE,
--     past_due_days  INT,
--     age            INT,
--     education      VARCHAR(50),
--     Gender         VARCHAR(10)
-- );
--
-- INSERT INTO LOAN_PAYMENT_TYPED
-- SELECT
--     "Loan_ID",
--     "loan_status",
--     TRY_CAST("Principal" AS NUMBER(10,2)),
--     TRY_CAST("terms" AS INT),
--     TRY_TO_DATE("effective_date", 'MM/DD/YYYY'),
--     TRY_TO_DATE("due_date", 'MM/DD/YYYY'),
--     TRY_TO_DATE("paid_off_time", 'MM/DD/YYYY'),
--     TRY_CAST("past_due_days" AS INT),
--     TRY_CAST("age" AS INT),
--     "education",
--     "Gender"
-- FROM LOAN_PAYMENT;
--
-- INTERVIEW TIP: TRY_CAST and TRY_TO_DATE return NULL on failure instead
-- of raising an error. This is safer than CAST for data quality issues.
-- =============================================================================
