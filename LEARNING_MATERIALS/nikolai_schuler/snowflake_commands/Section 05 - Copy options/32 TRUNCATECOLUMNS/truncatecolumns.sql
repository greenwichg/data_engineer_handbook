-- =============================================================================
-- SECTION 5.32: TRUNCATECOLUMNS OPTION
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how TRUNCATECOLUMNS silently truncates string values that exceed
--   the target column's maximum width, instead of raising an error.
--
-- WHAT YOU WILL LEARN:
--   1. Default behavior (error on data exceeding column width)
--   2. TRUNCATECOLUMNS = TRUE (silently truncate to fit)
--   3. When to use vs when to avoid this option
--
-- KEY INTERVIEW CONCEPTS:
--   - TRUNCATECOLUMNS = TRUE truncates strings to column max length
--   - Default is FALSE (raises error if data exceeds column width)
--   - Only applies to STRING/VARCHAR columns (not numeric or date)
--   - Data is SILENTLY LOST when truncated (no warning in COPY output)
--
-- DATA INTEGRITY WARNING:
--   Using TRUNCATECOLUMNS = TRUE means you may lose data without knowing.
--   Prefer these alternatives when data integrity matters:
--   1. Widen the target column: ALTER TABLE ... ALTER COLUMN ... SET DATA TYPE VARCHAR(500)
--   2. Use VALIDATION_MODE first to find oversized values
--   3. Transform data during COPY with SUBSTRING() for controlled truncation
-- =============================================================================


-- =============================================
-- SETUP: Table with a NARROW column
-- =============================================
-- CATEGORY is limited to VARCHAR(10) - intentionally narrow to trigger errors.

CREATE OR REPLACE TABLE COPY_DB.PUBLIC.ORDERS (
    ORDER_ID    VARCHAR(30),
    AMOUNT      VARCHAR(30),
    PROFIT      INT,
    QUANTITY    INT,
    CATEGORY    VARCHAR(10),     -- Narrow column: will cause issues!
    SUBCATEGORY VARCHAR(30)
);

-- Stage with normal data
CREATE OR REPLACE STAGE COPY_DB.PUBLIC.aws_stage_copy
    url = 's3://snowflakebucket-copyoption/size/';

LIST @COPY_DB.PUBLIC.aws_stage_copy;


-- =============================================
-- DEMO 1: Default behavior (TRUNCATECOLUMNS = FALSE)
-- =============================================
-- If any CATEGORY value exceeds 10 characters, COPY fails.

COPY INTO COPY_DB.PUBLIC.ORDERS
    FROM @aws_stage_copy
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    pattern = '.*Order.*';

-- Expected: Error like "String 'Technology' cannot be inserted because
-- it's too long for column CATEGORY VARCHAR(10)"


-- =============================================
-- DEMO 2: TRUNCATECOLUMNS = TRUE
-- =============================================
-- Silently truncate strings that exceed column width.
-- "Technology" (10 chars) fits, but "Office Supplies" (15 chars)
-- would be truncated to "Office Sup" (10 chars).

COPY INTO COPY_DB.PUBLIC.ORDERS
    FROM @aws_stage_copy
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    pattern = '.*Order.*'
    TRUNCATECOLUMNS = TRUE;

-- Verify the data - check for truncated values in CATEGORY
SELECT * FROM ORDERS;

-- Look for truncated values specifically:
-- SELECT DISTINCT CATEGORY, LENGTH(CATEGORY) AS len
-- FROM ORDERS
-- ORDER BY len DESC;


-- =============================================================================
-- CONCEPT GAP: ALTERNATIVES TO TRUNCATECOLUMNS
-- =============================================================================
-- 1. WIDEN THE COLUMN (preferred for data integrity):
--    ALTER TABLE ORDERS ALTER COLUMN CATEGORY SET DATA TYPE VARCHAR(100);
--
-- 2. CONTROLLED TRUNCATION in COPY transform:
--    COPY INTO orders FROM (
--        SELECT s.$1, s.$2, s.$3, s.$4,
--               LEFT(s.$5, 10) AS category,  -- Explicit, documented truncation
--               s.$6
--        FROM @stage s
--    );
--
-- 3. FIND OVERSIZED VALUES before loading:
--    COPY INTO orders FROM @stage
--        VALIDATION_MODE = RETURN_ERRORS;
--    -- Then check which values exceed the column width
--
-- INTERVIEW TIP: In production, prefer widening columns over truncation.
-- VARCHAR storage in Snowflake is based on actual data length, not declared
-- max length. VARCHAR(100) vs VARCHAR(10) uses the same storage for a
-- 5-character string. There's no penalty for wider columns.
-- =============================================================================
