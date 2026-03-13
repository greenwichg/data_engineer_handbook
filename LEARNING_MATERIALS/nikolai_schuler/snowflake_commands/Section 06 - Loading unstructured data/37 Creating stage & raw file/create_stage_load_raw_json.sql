-- =============================================================================
-- SECTION 6.37: LOADING RAW JSON DATA (JSON Part 1 of 5)
-- =============================================================================
--
-- OBJECTIVE:
--   Learn the first step of JSON data loading: staging raw JSON into a
--   VARIANT column for subsequent parsing and transformation.
--
-- WHAT YOU WILL LEARN:
--   1. Creating a JSON file format object
--   2. Loading JSON into a single VARIANT column
--   3. The "raw staging" pattern for semi-structured data
--
-- THE TWO-STEP JSON LOADING PATTERN:
--   Step 1 (this section): Load raw JSON -> single VARIANT column
--   Step 2 (next sections): Parse VARIANT -> structured typed columns
--
--   This pattern is important because:
--   - JSON structures vary (missing keys, different nesting)
--   - Loading into VARIANT never fails (all valid JSON is accepted)
--   - Parsing/transformation logic can be refined iteratively
--   - Raw data is preserved for debugging and reprocessing
--
-- KEY INTERVIEW CONCEPTS:
--   - VARIANT data type stores semi-structured data (JSON, Avro, XML, etc.)
--   - FILE FORMAT TYPE=JSON for JSON file ingestion
--   - Single VARIANT column approach for raw JSON staging
--   - STRIP_OUTER_ARRAY = TRUE handles JSON arrays at the root level
--
-- VARIANT DATA TYPE (CONCEPT GAP FILLED):
--   - Can hold ANY valid JSON value: object, array, string, number, boolean, null
--   - Maximum size: 16 MB per value (compressed)
--   - Stored in an optimized columnar format internally
--   - Supports querying with : (colon) and . (dot) notation
--   - No schema definition required at load time
--
-- STRIP_OUTER_ARRAY (CONCEPT GAP FILLED):
--   JSON files can have two root structures:
--   1. One JSON object per line (NDJSON): {"id":1}\n{"id":2}
--      -> Each line becomes one row. No STRIP_OUTER_ARRAY needed.
--   2. Single array of objects: [{"id":1}, {"id":2}]
--      -> Without STRIP_OUTER_ARRAY: entire array = 1 row
--      -> With STRIP_OUTER_ARRAY = TRUE: each element = 1 row
-- =============================================================================


-- =============================================
-- STEP 1: Create the JSON stage
-- =============================================
-- Points to an S3 bucket containing JSON files.

CREATE OR REPLACE STAGE MANAGE_DB.EXTERNAL_STAGES.JSONSTAGE
    url = 's3://bucketsnowflake-jsondemo';


-- =============================================
-- STEP 2: Create the JSON file format
-- =============================================
-- Defines how Snowflake should parse JSON files.

CREATE OR REPLACE FILE FORMAT MANAGE_DB.FILE_FORMATS.JSONFORMAT
    TYPE = JSON;

-- JSON FILE FORMAT PROPERTIES (CONCEPT GAP FILLED):
--   TYPE                   = JSON
--   COMPRESSION            = AUTO          -- Auto-detect compression
--   STRIP_OUTER_ARRAY      = FALSE         -- Set TRUE for [array] files
--   STRIP_NULL_VALUES      = FALSE         -- Remove keys with null values
--   ALLOW_DUPLICATE        = FALSE         -- Allow duplicate keys
--   ENABLE_OCTAL           = FALSE         -- Parse 0-prefixed numbers as octal
--   IGNORE_UTF8_ERRORS     = FALSE         -- Replace invalid UTF-8 chars


-- =============================================
-- STEP 3: Create the raw staging table
-- =============================================
-- Single VARIANT column to hold the entire JSON document per row.

CREATE OR REPLACE TABLE OUR_FIRST_DB.PUBLIC.JSON_RAW (
    raw_file VARIANT                     -- Stores complete JSON objects
);

-- INTERVIEW TIP: Naming the column "raw_file" is a common convention.
-- Other common names: "json_data", "payload", "raw_data", "src".


-- =============================================
-- STEP 4: Load JSON into the VARIANT column
-- =============================================
COPY INTO OUR_FIRST_DB.PUBLIC.JSON_RAW
    FROM @MANAGE_DB.EXTERNAL_STAGES.JSONSTAGE
    file_format = MANAGE_DB.FILE_FORMATS.JSONFORMAT
    files = ('HR_data.json');

-- NOTE: file_format is referenced by NAME here (no parentheses with FORMAT_NAME=).
-- Both syntaxes work:
--   file_format = MANAGE_DB.FILE_FORMATS.JSONFORMAT
--   file_format = (FORMAT_NAME = MANAGE_DB.FILE_FORMATS.JSONFORMAT)


-- =============================================
-- STEP 5: Verify the raw data
-- =============================================
SELECT * FROM OUR_FIRST_DB.PUBLIC.JSON_RAW;

-- Each row contains a complete JSON object in the raw_file column.
-- The JSON is stored in Snowflake's internal columnar format (not as text).
-- Querying individual fields from VARIANT is very efficient.


-- =============================================================================
-- CONCEPT GAP: LOADING DIFFERENT JSON STRUCTURES
-- =============================================================================
-- 1. NDJSON (Newline-Delimited JSON) - one object per line:
--    {"id":1,"name":"Alice"}
--    {"id":2,"name":"Bob"}
--    -> Standard load, each line = one row
--
-- 2. JSON Array - single array wrapping all objects:
--    [{"id":1,"name":"Alice"}, {"id":2,"name":"Bob"}]
--    -> Use STRIP_OUTER_ARRAY = TRUE in file format
--    CREATE FILE FORMAT json_array_format
--        TYPE = JSON
--        STRIP_OUTER_ARRAY = TRUE;
--
-- 3. Nested/Complex JSON:
--    {"department":"Engineering","employees":[{"id":1},{"id":2}]}
--    -> Load as-is, then use FLATTEN() to unnest (Section 6.40)
-- =============================================================================
