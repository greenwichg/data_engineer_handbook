-- =============================================================================
-- SECTION 4.22: TRANSFORMING DATA DURING COPY INTO
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to apply SQL transformations during the COPY process using
--   SELECT subqueries - selecting specific columns, applying CASE logic,
--   and using string functions.
--
-- WHAT YOU WILL LEARN:
--   1. Using $1, $2, ... notation to reference staged file columns
--   2. Selecting a subset of columns during COPY
--   3. Applying CASE WHEN for conditional/derived columns
--   4. Using SUBSTRING() for string manipulation during load
--
-- WHY TRANSFORM DURING COPY?
--   - Avoid loading unnecessary columns (saves storage and compute)
--   - Derive computed columns without a separate ETL step
--   - Clean/standardize data at ingestion time
--   - Reduce post-load processing work
--
-- KEY INTERVIEW CONCEPTS:
--   - $1, $2, ... notation references CSV columns by POSITION (1-based)
--   - Alias 's' in FROM @stage s allows s.$1 syntax
--   - CASE WHEN inside COPY for conditional derived columns
--   - SUBSTRING()/SUBSTR() to truncate/extract parts of column values
--   - Only a SUBSET of SQL functions are supported in COPY transforms
--
-- SUPPORTED FUNCTIONS IN COPY TRANSFORMS (CONCEPT GAP FILLED):
--   - CAST / TRY_CAST / :: (type casting)
--   - CASE WHEN ... THEN ... ELSE ... END
--   - SUBSTRING / SUBSTR
--   - CONCAT / ||
--   - UPPER / LOWER / TRIM / LTRIM / RTRIM
--   - TO_DATE / TO_TIMESTAMP / TO_NUMBER
--   - NVL / NVL2 / COALESCE / IFF / NULLIF
--   - METADATA$FILENAME / METADATA$FILE_ROW_NUMBER
--   NOTE: Aggregate functions (SUM, COUNT, etc.) are NOT supported.
-- =============================================================================


-- =============================================
-- EXAMPLE 1: Select subset of columns
-- =============================================
-- Load only the first 2 columns from the CSV file.
-- $1 = ORDER_ID, $2 = AMOUNT (based on CSV column position)

CREATE OR REPLACE TABLE OUR_FIRST_DB.PUBLIC.ORDERS_EX (
    ORDER_ID VARCHAR(30),
    AMOUNT   INT
);

COPY INTO OUR_FIRST_DB.PUBLIC.ORDERS_EX
    FROM (
        SELECT
            s.$1,          -- CSV column 1 -> ORDER_ID
            s.$2           -- CSV column 2 -> AMOUNT
        FROM @MANAGE_DB.external_stages.aws_stage s
    )
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    files = ('OrderDetails.csv');

-- INTERVIEW TIP: The alias 's' is required when using a SELECT subquery.
-- Without it, you'd write $1 directly, but 's.' makes intent clearer.

SELECT * FROM OUR_FIRST_DB.PUBLIC.ORDERS_EX;


-- =============================================
-- EXAMPLE 2: CASE WHEN for derived columns
-- =============================================
-- Create a "profitable_flag" column based on the PROFIT value.

CREATE OR REPLACE TABLE OUR_FIRST_DB.PUBLIC.ORDERS_EX (
    ORDER_ID        VARCHAR(30),
    AMOUNT          INT,
    PROFIT          INT,
    PROFITABLE_FLAG VARCHAR(30)
);

COPY INTO OUR_FIRST_DB.PUBLIC.ORDERS_EX
    FROM (
        SELECT
            s.$1,                                  -- ORDER_ID
            s.$2,                                  -- AMOUNT
            s.$3,                                  -- PROFIT
            CASE
                WHEN CAST(s.$3 AS INT) < 0
                    THEN 'not profitable'
                ELSE 'profitable'
            END                                    -- Derived PROFITABLE_FLAG
        FROM @MANAGE_DB.external_stages.aws_stage s
    )
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    files = ('OrderDetails.csv');

-- IMPORTANT: CAST is needed because staged CSV data is initially VARCHAR.
-- Without CAST, the comparison < 0 would fail or behave unexpectedly.

SELECT * FROM OUR_FIRST_DB.PUBLIC.ORDERS_EX;


-- =============================================
-- EXAMPLE 3: SUBSTRING for string extraction
-- =============================================
-- Extract only the first 5 characters of the CATEGORY column.

CREATE OR REPLACE TABLE OUR_FIRST_DB.PUBLIC.ORDERS_EX (
    ORDER_ID           VARCHAR(30),
    AMOUNT             INT,
    PROFIT             INT,
    CATEGORY_SUBSTRING VARCHAR(5)
);

COPY INTO OUR_FIRST_DB.PUBLIC.ORDERS_EX
    FROM (
        SELECT
            s.$1,                      -- ORDER_ID
            s.$2,                      -- AMOUNT
            s.$3,                      -- PROFIT
            SUBSTRING(s.$5, 1, 5)      -- First 5 chars of CATEGORY (col 5)
        FROM @MANAGE_DB.external_stages.aws_stage s
    )
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    files = ('OrderDetails.csv');

-- NOTE: We skipped $4 (QUANTITY) entirely - it won't be loaded.
-- The SELECT determines which CSV columns map to which table columns.

SELECT * FROM OUR_FIRST_DB.PUBLIC.ORDERS_EX;


-- =============================================================================
-- CONCEPT GAP: COMMON TRANSFORMATION PATTERNS
-- =============================================================================
-- Here are additional transformation patterns you might use in interviews:
--
-- 1. CONCATENATION:
--    SELECT s.$1, s.$2 || ' - ' || s.$3 AS combined_field FROM @stage s
--
-- 2. NULL HANDLING:
--    SELECT s.$1, NVL(s.$2, 'UNKNOWN') AS category FROM @stage s
--
-- 3. DATE CONVERSION:
--    SELECT s.$1, TO_DATE(s.$4, 'YYYY-MM-DD') AS order_date FROM @stage s
--
-- 4. UPPER/LOWER CASE NORMALIZATION:
--    SELECT s.$1, UPPER(s.$5) AS category FROM @stage s
--
-- 5. TRIM WHITESPACE:
--    SELECT s.$1, TRIM(s.$2) AS clean_name FROM @stage s
-- =============================================================================
