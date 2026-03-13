-- =============================================================================
-- SECTION 5.29: WORKING WITH REJECTED RECORDS
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to capture, store, and parse rejected records from failed loads
--   using result_scan(), validate(), and string parsing functions.
--
-- WHAT YOU WILL LEARN:
--   1. Capturing validation output with result_scan(last_query_id())
--   2. Using validate() to get errors after ON_ERROR=CONTINUE
--   3. Storing rejected records in a permanent table
--   4. Parsing rejected CSV rows with SPLIT_PART()
--
-- WHY CAPTURE REJECTED RECORDS?
--   - Debug data quality issues at the row level
--   - Create data quality reports for data producers
--   - Build an error tracking table for monitoring over time
--   - Identify patterns in data errors (e.g., specific columns always fail)
--
-- KEY INTERVIEW CONCEPTS:
--   - result_scan(last_query_id()) captures output of the previous query
--   - validate(table, job_id => '_last') gets errors after ON_ERROR=CONTINUE
--   - CREATE TABLE AS SELECT from result_scan for error storage
--   - SPLIT_PART(rejected_record, ',', n) to parse CSV error rows
--
-- CONCEPT GAP FILLED - result_scan() vs validate():
-- ┌───────────────────────┬──────────────────────────────────────────────────┐
-- │ Function              │ Use Case                                        │
-- ├───────────────────────┼──────────────────────────────────────────────────┤
-- │ result_scan()         │ Captures output of ANY previous query.          │
-- │                       │ Used after VALIDATION_MODE to get error rows.   │
-- │ validate()            │ Returns errors from a completed COPY INTO.      │
-- │                       │ Used after ON_ERROR=CONTINUE load.              │
-- │                       │ Only works with the specific table and job.     │
-- └───────────────────────┴──────────────────────────────────────────────────┘
-- =============================================================================


-- =============================================
-- SETUP: Stage with error files
-- =============================================
CREATE OR REPLACE STAGE COPY_DB.PUBLIC.aws_stage_copy
    url = 's3://snowflakebucket-copyoption/returnfailed/';

LIST @COPY_DB.PUBLIC.aws_stage_copy;


-- =============================================
-- STEP 1: Run validation to find errors
-- =============================================
-- First, find all error rows using VALIDATION_MODE.

COPY INTO COPY_DB.PUBLIC.ORDERS
    FROM @aws_stage_copy
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    pattern = '.*Order.*'
    VALIDATION_MODE = RETURN_ERRORS;

-- Preview first row to verify format is correct
COPY INTO COPY_DB.PUBLIC.ORDERS
    FROM @aws_stage_copy
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    pattern = '.*Order.*'
    VALIDATION_MODE = RETURN_1_rows;


-- =============================================================================
-- METHOD 1: Saving rejected records AFTER VALIDATION_MODE
-- =============================================================================

-- Recreate table to start fresh
CREATE OR REPLACE TABLE COPY_DB.PUBLIC.ORDERS (
    ORDER_ID    VARCHAR(30),
    AMOUNT      VARCHAR(30),
    PROFIT      INT,
    QUANTITY    INT,
    CATEGORY    VARCHAR(30),
    SUBCATEGORY VARCHAR(30)
);

-- Run validation to get error rows
COPY INTO COPY_DB.PUBLIC.ORDERS
    FROM @aws_stage_copy
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    pattern = '.*Order.*'
    VALIDATION_MODE = RETURN_ERRORS;

-- IMMEDIATELY capture the result into a table using result_scan().
-- result_scan() accesses the result set of the most recent query.

-- Option A: Create a new table from the result
CREATE OR REPLACE TABLE rejected AS
SELECT rejected_record
FROM TABLE(result_scan(last_query_id()));

-- Option B: Insert into existing table
INSERT INTO rejected
SELECT rejected_record
FROM TABLE(result_scan(last_query_id()));

-- CRITICAL: result_scan() only works for the MOST RECENT query.
-- If you run ANY other query between VALIDATION_MODE and result_scan(),
-- the validation results are LOST. Save them immediately!

SELECT * FROM rejected;


-- =============================================================================
-- METHOD 2: Saving rejected records AFTER ON_ERROR=CONTINUE load
-- =============================================================================
-- When you actually load data with ON_ERROR=CONTINUE, use validate()
-- to retrieve the rows that were skipped.

COPY INTO COPY_DB.PUBLIC.ORDERS
    FROM @aws_stage_copy
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    pattern = '.*Order.*'
    ON_ERROR = CONTINUE;

-- validate() retrieves error details from the last COPY job on this table.
-- job_id => '_last' refers to the most recent COPY job for the specified table.

SELECT * FROM TABLE(validate(orders, job_id => '_last'));

-- VALIDATE() OUTPUT COLUMNS:
--   FILE, LINE, CHARACTER, CATEGORY, CODE, MESSAGE,
--   COLUMN_NAME, ROW_NUMBER, REJECTED_RECORD


-- =============================================================================
-- METHOD 3: Parsing rejected records into structured columns
-- =============================================================================
-- Rejected records are stored as raw CSV strings.
-- Use SPLIT_PART() to extract individual field values.

SELECT REJECTED_RECORD FROM rejected;

-- Parse each CSV field into a separate column
CREATE OR REPLACE TABLE rejected_values AS
SELECT
    SPLIT_PART(rejected_record, ',', 1) AS ORDER_ID,     -- 1st field
    SPLIT_PART(rejected_record, ',', 2) AS AMOUNT,       -- 2nd field
    SPLIT_PART(rejected_record, ',', 3) AS PROFIT,       -- 3rd field
    SPLIT_PART(rejected_record, ',', 4) AS QUANTITY,      -- 4th field
    SPLIT_PART(rejected_record, ',', 5) AS CATEGORY,     -- 5th field
    SPLIT_PART(rejected_record, ',', 6) AS SUBCATEGORY   -- 6th field
FROM rejected;

SELECT * FROM rejected_values;

-- INTERVIEW TIP: SPLIT_PART(string, delimiter, part_number) is 1-based.
-- It's similar to Python's str.split(',')[n-1].


-- =============================================================================
-- CONCEPT GAP: COMPREHENSIVE ERROR HANDLING WORKFLOW
-- =============================================================================
-- Production pattern for capturing and analyzing load errors:
--
-- -- 1. Create a persistent error tracking table
-- CREATE TABLE IF NOT EXISTS load_errors (
--     error_timestamp  TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
--     source_file      VARCHAR,
--     line_number      INT,
--     error_message    VARCHAR,
--     rejected_record  VARCHAR,
--     load_job_id      VARCHAR
-- );
--
-- -- 2. Load data with CONTINUE
-- COPY INTO target_table FROM @stage
--     ON_ERROR = CONTINUE;
--
-- -- 3. Capture errors into tracking table
-- INSERT INTO load_errors (source_file, line_number, error_message, rejected_record)
-- SELECT file, line, error, rejected_record
-- FROM TABLE(validate(target_table, job_id => '_last'));
--
-- -- 4. Alert if error count exceeds threshold
-- SELECT COUNT(*) AS error_count FROM load_errors
-- WHERE error_timestamp >= DATEADD(hour, -1, CURRENT_TIMESTAMP());
-- =============================================================================
