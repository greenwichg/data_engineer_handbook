-- =============================================================================
-- SECTION 8.59: HANDLING JSON DATA FROM S3
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to query, transform, and load semi-structured JSON data from
--   an S3 stage, including date parsing with DATE() and DATE_FROM_PARTS().
--
-- WHAT YOU WILL LEARN:
--   1. Querying JSON from a stage using $1:key notation
--   2. Type casting VARIANT values to proper data types
--   3. DATE() conversion from Unix timestamps (epoch seconds)
--   4. DATE_FROM_PARTS() for building dates from string components
--   5. CASE WHEN for handling inconsistent date formats
--   6. Loading transformed JSON into a structured table
--
-- KEY INTERVIEW CONCEPTS:
--   - $1:key_name extracts JSON fields from staged files
--   - ::STRING, ::INT for type casting VARIANT values
--   - DATE(unix_timestamp) converts epoch seconds to a date
--   - DATE_FROM_PARTS(year, month, day) builds dates from components
--   - String functions (LEFT, RIGHT, SUBSTRING) for date parsing
--
-- DATE HANDLING IN SNOWFLAKE (CONCEPT GAP FILLED):
-- ┌──────────────────────────────┬─────────────────────────────────────────┐
-- │ Function                     │ Use Case                               │
-- ├──────────────────────────────┼─────────────────────────────────────────┤
-- │ DATE(epoch_seconds)          │ Unix timestamp -> DATE                  │
-- │ TO_DATE(string, format)      │ Formatted string -> DATE                │
-- │ DATE_FROM_PARTS(y, m, d)     │ Individual components -> DATE           │
-- │ TRY_TO_DATE(string, format)  │ Safe conversion (NULL on failure)       │
-- │ DATEADD(part, n, date)       │ Add/subtract from a date                │
-- │ DATEDIFF(part, d1, d2)       │ Difference between dates                │
-- └──────────────────────────────┴─────────────────────────────────────────┘
-- =============================================================================


-- =============================================
-- STEP 1: Preview raw JSON from stage
-- =============================================
-- View the raw JSON structure to understand the schema.

SELECT * FROM @MANAGE_DB.external_stages.json_folder;

-- Each row is a JSON object like:
-- {"asin":"B001","helpful":[2,3],"overall":5,"reviewText":"Great...","reviewTime":"02 22, 2014",...}


-- =============================================
-- STEP 2: Extract individual JSON fields
-- =============================================
-- Use $1:key to access each JSON field.
-- $1 refers to the single VARIANT column from the staged JSON file.

SELECT
    $1:asin,
    $1:helpful,
    $1:overall,
    $1:reviewText,
    $1:reviewTime,
    $1:reviewerID,
    $1:reviewerName,
    $1:summary,
    $1:unixReviewTime
FROM @MANAGE_DB.external_stages.json_folder;


-- =============================================
-- STEP 3: Cast to proper types + Unix date conversion
-- =============================================
SELECT
    $1:asin::STRING               AS asin,
    $1:helpful                    AS helpful,          -- Keep as VARIANT (array)
    $1:overall                    AS overall,
    $1:reviewText::STRING         AS reviewtext,
    $1:reviewTime::STRING         AS review_time_str,
    $1:reviewerID::STRING         AS reviewer_id,
    $1:reviewerName::STRING       AS reviewer_name,
    $1:summary::STRING            AS summary,
    DATE($1:unixReviewTime::INT)  AS review_date       -- Unix epoch -> DATE
FROM @MANAGE_DB.external_stages.json_folder;

-- DATE() with an integer interprets it as seconds since Unix epoch (1970-01-01).
-- Example: DATE(1393027200) = '2014-02-22'


-- =============================================
-- STEP 4: Parse custom date strings with DATE_FROM_PARTS
-- =============================================
-- The reviewTime field has format like "02 22, 2014" or "2 8, 2014"
-- This is NOT a standard date format, so we parse it manually.

-- Problem: Single-digit days cause inconsistent string positions.
-- "02 22, 2014"  -> month=02, day=22, year=2014
-- "2 8, 2014"    -> month=2,  day=8,  year=2014

SELECT
    $1:asin::STRING               AS asin,
    $1:helpful                    AS helpful,
    $1:overall                    AS overall,
    $1:reviewText::STRING         AS reviewtext,
    DATE_FROM_PARTS(
        RIGHT($1:reviewTime::STRING, 4),              -- Year: last 4 chars
        LEFT($1:reviewTime::STRING, 2),                -- Month: first 2 chars
        CASE
            WHEN SUBSTRING($1:reviewTime::STRING, 5, 1) = ','
            THEN SUBSTRING($1:reviewTime::STRING, 4, 1)    -- Single digit day
            ELSE SUBSTRING($1:reviewTime::STRING, 4, 2)    -- Double digit day
        END
    )                             AS review_date,
    $1:reviewerID::STRING         AS reviewer_id,
    $1:reviewerName::STRING       AS reviewer_name,
    $1:summary::STRING            AS summary,
    DATE($1:unixReviewTime::INT)  AS unix_review_date
FROM @MANAGE_DB.external_stages.json_folder;

-- INTERVIEW TIP: This CASE logic handles the variable-length day field.
-- In production, prefer using the Unix timestamp (more reliable) or
-- TRY_TO_DATE with a format string if the date format is consistent.


-- =============================================
-- STEP 5: Create destination table and load
-- =============================================
CREATE OR REPLACE TABLE OUR_FIRST_DB.PUBLIC.reviews (
    asin            STRING,
    helpful         STRING,
    overall         STRING,
    reviewtext      STRING,
    reviewtime      DATE,
    reviewerid      STRING,
    reviewername    STRING,
    summary         STRING,
    unixreviewtime  DATE
);

-- Load with transformation in the COPY subquery
COPY INTO OUR_FIRST_DB.PUBLIC.reviews
    FROM (
        SELECT
            $1:asin::STRING              AS asin,
            $1:helpful                   AS helpful,
            $1:overall                   AS overall,
            $1:reviewText::STRING        AS reviewtext,
            DATE_FROM_PARTS(
                RIGHT($1:reviewTime::STRING, 4),
                LEFT($1:reviewTime::STRING, 2),
                CASE
                    WHEN SUBSTRING($1:reviewTime::STRING, 5, 1) = ','
                    THEN SUBSTRING($1:reviewTime::STRING, 4, 1)
                    ELSE SUBSTRING($1:reviewTime::STRING, 4, 2)
                END
            )                            AS reviewtime,
            $1:reviewerID::STRING        AS reviewerid,
            $1:reviewerName::STRING      AS reviewername,
            $1:summary::STRING           AS summary,
            DATE($1:unixReviewTime::INT) AS unixreviewtime
        FROM @MANAGE_DB.external_stages.json_folder
    );

-- Validate results
SELECT * FROM OUR_FIRST_DB.PUBLIC.reviews;


-- =============================================================================
-- CONCEPT GAP: BETTER DATE PARSING ALTERNATIVES
-- =============================================================================
-- Instead of manual string parsing, consider these approaches:
--
-- 1. TRY_TO_DATE with format string (if format is consistent):
--    TRY_TO_DATE($1:reviewTime::STRING, 'MM DD, YYYY')
--
-- 2. Use the Unix timestamp (most reliable):
--    TO_DATE(TO_TIMESTAMP($1:unixReviewTime::INT))
--
-- 3. REGEXP_REPLACE for cleanup before parsing:
--    TO_DATE(REGEXP_REPLACE($1:reviewTime::STRING, ' +', ' '), 'MM DD, YYYY')
--
-- 4. JavaScript UDF for complex parsing:
--    CREATE FUNCTION parse_date(s STRING) RETURNS DATE
--    LANGUAGE JAVASCRIPT AS 'return new Date(S)';
--
-- INTERVIEW TIP: When asked about handling messy date formats, mention:
-- "I would first check if a Unix timestamp is available (most reliable),
--  then try TRY_TO_DATE with format strings, and only use string parsing
--  as a last resort."
-- =============================================================================
