-- =============================================================================
-- SECTION 8.58: LOADING CSV DATA FROM S3 (With Storage Integration)
-- =============================================================================
--
-- OBJECTIVE:
--   Complete end-to-end CSV loading from S3 using the production-grade approach:
--   storage integration + named file format + named stage + COPY INTO.
--
-- WHAT YOU WILL LEARN:
--   1. Creating a table for Netflix movie data
--   2. Creating a file format with CSV best-practice options
--   3. Creating a stage with STORAGE_INTEGRATION (no credentials)
--   4. Loading data with COPY INTO
--   5. Handling quoted CSV fields with FIELD_OPTIONALLY_ENCLOSED_BY
--
-- KEY INTERVIEW CONCEPTS:
--   - Stage = integration + URL + file format (all-in-one reference)
--   - FIELD_OPTIONALLY_ENCLOSED_BY = '"' handles quoted CSV fields
--   - NULL_IF = ('NULL', 'null') converts string literals to SQL NULL
--   - EMPTY_FIELD_AS_NULL = TRUE converts empty strings to NULL
--   - STORAGE_INTEGRATION on stage avoids embedding credentials
--
-- FIELD_OPTIONALLY_ENCLOSED_BY (CONCEPT GAP FILLED):
--   Many CSV files enclose fields in quotes, especially when values contain:
--   - Commas: "Smith, John"
--   - Newlines: "Line 1\nLine 2"
--   - Quotes: "He said ""hello"""
--   Without FIELD_OPTIONALLY_ENCLOSED_BY, these fields break the parser.
-- =============================================================================


-- =============================================
-- STEP 1: Create the target table
-- =============================================
CREATE OR REPLACE TABLE OUR_FIRST_DB.PUBLIC.movie_titles (
    show_id      STRING,       -- Unique show/movie ID
    type         STRING,       -- 'Movie' or 'TV Show'
    title        STRING,       -- Title of the content
    director     STRING,       -- Director name(s)
    cast         STRING,       -- Cast members (comma-separated within quotes)
    country      STRING,       -- Country of production
    date_added   STRING,       -- Date added to Netflix
    release_year STRING,       -- Year of release
    rating       STRING,       -- Content rating (PG, R, etc.)
    duration     STRING,       -- Duration (e.g., "90 min" or "2 Seasons")
    listed_in    STRING,       -- Genre categories
    description  STRING        -- Show/movie description
);


-- =============================================
-- STEP 2: Create file format (first attempt)
-- =============================================
CREATE OR REPLACE FILE FORMAT MANAGE_DB.file_formats.csv_fileformat
    type                 = csv
    field_delimiter      = ','
    skip_header          = 1
    null_if              = ('NULL', 'null')   -- Convert "NULL" strings to SQL NULL
    empty_field_as_null  = TRUE;               -- Convert "" to NULL


-- =============================================
-- STEP 3: Create stage with storage integration
-- =============================================
-- The stage combines: integration (auth) + URL (location) + file format (parsing)

CREATE OR REPLACE STAGE MANAGE_DB.external_stages.csv_folder
    URL                 = 's3://<your-bucket-name>/<your-path>/'
    STORAGE_INTEGRATION = s3_int
    FILE_FORMAT         = MANAGE_DB.file_formats.csv_fileformat;

-- No credentials in the stage definition!
-- Authentication is handled by the s3_int integration via IAM role.


-- =============================================
-- STEP 4: Load data
-- =============================================
COPY INTO OUR_FIRST_DB.PUBLIC.movie_titles
    FROM @MANAGE_DB.external_stages.csv_folder;

-- If this fails with parsing errors (fields containing commas), fix the
-- file format with FIELD_OPTIONALLY_ENCLOSED_BY (see Step 5).


-- =============================================
-- STEP 5: Fix file format for quoted fields
-- =============================================
-- Netflix data has fields like cast="Actor1, Actor2, Actor3"
-- The commas inside quotes are NOT delimiters.

CREATE OR REPLACE FILE FORMAT MANAGE_DB.file_formats.csv_fileformat
    type                         = csv
    field_delimiter              = ','
    skip_header                  = 1
    null_if                      = ('NULL', 'null')
    empty_field_as_null          = TRUE
    FIELD_OPTIONALLY_ENCLOSED_BY = '"';  -- Handle quoted fields!

-- Now reload (need to recreate table to clear bad data)
-- CREATE OR REPLACE TABLE OUR_FIRST_DB.PUBLIC.movie_titles (...);
-- COPY INTO OUR_FIRST_DB.PUBLIC.movie_titles
--     FROM @MANAGE_DB.external_stages.csv_folder;

SELECT * FROM OUR_FIRST_DB.PUBLIC.movie_titles;


-- =============================================================================
-- CONCEPT GAP: COMMON CSV PARSING ISSUES AND SOLUTIONS
-- =============================================================================
-- ISSUE                          │ SOLUTION
-- ───────────────────────────────────────────────────────────────────────
-- Commas inside field values     │ FIELD_OPTIONALLY_ENCLOSED_BY = '"'
-- "NULL" string instead of NULL  │ NULL_IF = ('NULL', 'null', 'N/A', '')
-- Extra columns in some rows     │ ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
-- Windows line endings (\r\n)    │ RECORD_DELIMITER = '\r\n' or leave AUTO
-- Non-UTF8 encoding              │ ENCODING = 'WINDOWS1252' or 'ISO-8859-1'
-- Tab-delimited files            │ FIELD_DELIMITER = '\t'
-- Pipe-delimited files           │ FIELD_DELIMITER = '|'
-- Compressed files               │ COMPRESSION = AUTO (detects GZIP, etc.)
-- =============================================================================
