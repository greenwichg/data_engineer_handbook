-- =============================================================================
-- SECTION 6.43: LOADING PARQUET DATA INTO TABLE (Parquet Part 2 of 2)
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to load Parquet data into a structured Snowflake table using
--   COPY INTO with column mapping, metadata injection, and audit columns.
--
-- WHAT YOU WILL LEARN:
--   1. COPY INTO with SELECT subquery for Parquet column mapping
--   2. METADATA$FILENAME and METADATA$FILE_ROW_NUMBER for data lineage
--   3. Adding load timestamps for audit/tracking
--   4. CREATE TABLE with DEFAULT for auto-populated columns
--
-- KEY INTERVIEW CONCEPTS:
--   - COPY INTO with SELECT subquery for Parquet -> table column mapping
--   - METADATA$FILENAME: source file name (for lineage tracking)
--   - METADATA$FILE_ROW_NUMBER: row number within the source file
--   - TO_TIMESTAMP_NTZ(current_timestamp) for load audit columns
--   - DEFAULT values in CREATE TABLE for auto-populated timestamps
--
-- METADATA COLUMNS (CONCEPT GAP FILLED):
--   Available ONLY during COPY or direct stage queries:
-- ┌────────────────────────────┬─────────────────────────────────────────────┐
-- │ Column                     │ Description                                │
-- ├────────────────────────────┼─────────────────────────────────────────────┤
-- │ METADATA$FILENAME          │ Full path of the source file               │
-- │ METADATA$FILE_ROW_NUMBER   │ Row number within the source file (1-based)│
-- │ METADATA$FILE_CONTENT_KEY  │ Unique content fingerprint of the file     │
-- │ METADATA$FILE_LAST_MODIFIED│ Last modified timestamp of the file        │
-- │ METADATA$START_SCAN_TIME   │ Time when scanning of the file started     │
-- └────────────────────────────┴─────────────────────────────────────────────┘
--
-- IMPORTANT: METADATA$ columns are NOT stored in the table automatically.
-- You must explicitly include them in SELECT to capture them.
-- =============================================================================


-- =============================================
-- STEP 1: Preview data with metadata columns
-- =============================================
-- Add metadata columns to understand data lineage.

SELECT
    $1:__index_level_0__::INT       AS index_level,
    $1:cat_id::VARCHAR(50)          AS category,
    DATE($1:date::INT)              AS date,
    $1:"dept_id"::VARCHAR(50)       AS dept_id,
    $1:"id"::VARCHAR(50)            AS id,
    $1:"item_id"::VARCHAR(50)       AS item_id,
    $1:"state_id"::VARCHAR(50)      AS state_id,
    $1:"store_id"::VARCHAR(50)      AS store_id,
    $1:"value"::INT                 AS value,
    METADATA$FILENAME               AS filename,          -- Source file path
    METADATA$FILE_ROW_NUMBER        AS rownumber,         -- Row # in source file
    TO_TIMESTAMP_NTZ(current_timestamp) AS load_date      -- When data was loaded
FROM @MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE;

-- INTERVIEW TIP: METADATA columns are invaluable for debugging.
-- If a row has bad data, FILENAME + ROWNUMBER tells you exactly where
-- it came from in the source file.

SELECT TO_TIMESTAMP_NTZ(current_timestamp);


-- =============================================
-- STEP 2: Create the destination table
-- =============================================
-- Include audit columns (row_number, load_date) for data lineage.

CREATE OR REPLACE TABLE OUR_FIRST_DB.PUBLIC.PARQUET_DATA (
    ROW_NUMBER  INT,
    index_level INT,
    cat_id      VARCHAR(50),
    date        DATE,
    dept_id     VARCHAR(50),
    id          VARCHAR(50),
    item_id     VARCHAR(50),
    state_id    VARCHAR(50),
    store_id    VARCHAR(50),
    value       INT,
    load_date   TIMESTAMP DEFAULT TO_TIMESTAMP_NTZ(current_timestamp)
    -- DEFAULT: auto-fills with current timestamp if not explicitly provided
);


-- =============================================
-- STEP 3: Load the Parquet data with COPY INTO
-- =============================================
-- Use a SELECT subquery to map Parquet columns to table columns.

COPY INTO OUR_FIRST_DB.PUBLIC.PARQUET_DATA
    FROM (
        SELECT
            METADATA$FILE_ROW_NUMBER,               -- -> ROW_NUMBER
            $1:__index_level_0__::INT,               -- -> index_level
            $1:cat_id::VARCHAR(50),                  -- -> cat_id
            DATE($1:date::INT),                      -- -> date
            $1:"dept_id"::VARCHAR(50),               -- -> dept_id
            $1:"id"::VARCHAR(50),                    -- -> id
            $1:"item_id"::VARCHAR(50),               -- -> item_id
            $1:"state_id"::VARCHAR(50),              -- -> state_id
            $1:"store_id"::VARCHAR(50),              -- -> store_id
            $1:"value"::INT,                         -- -> value
            TO_TIMESTAMP_NTZ(current_timestamp)      -- -> load_date
        FROM @MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE
    );

-- NOTE: Column mapping is POSITIONAL in the SELECT.
-- The first SELECT column maps to the first table column, etc.
-- Column names in the SELECT aliases are ignored - only order matters.


-- =============================================
-- STEP 4: Verify the loaded data
-- =============================================
SELECT * FROM OUR_FIRST_DB.PUBLIC.PARQUET_DATA;


-- =============================================================================
-- CONCEPT GAP: PARQUET LOADING BEST PRACTICES
-- =============================================================================
-- 1. SCHEMA INFERENCE (Snowflake can auto-detect Parquet schema):
--    SELECT *
--    FROM TABLE(INFER_SCHEMA(
--        LOCATION => '@my_stage/data.parquet',
--        FILE_FORMAT => 'parquet_format'
--    ));
--    -- Returns: column_name, type, nullable, expression, etc.
--    -- Use this to auto-generate CREATE TABLE statements!
--
-- 2. MATCH_BY_COLUMN_NAME (auto-map by column name, not position):
--    COPY INTO my_table
--    FROM @my_stage
--    FILE_FORMAT = (TYPE = PARQUET)
--    MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;
--    -- Columns are matched by NAME instead of position
--    -- Much safer than positional mapping!
--
-- 3. AUTO TABLE CREATION:
--    CREATE TABLE my_table
--    USING TEMPLATE (
--        SELECT ARRAY_AGG(object_construct(*))
--        FROM TABLE(INFER_SCHEMA(
--            LOCATION => '@my_stage',
--            FILE_FORMAT => 'parquet_format'
--        ))
--    );
--    -- Creates table with schema matching the Parquet file!
--
-- INTERVIEW TIP: MATCH_BY_COLUMN_NAME is a game-changer for Parquet loads.
-- It eliminates positional mapping errors and makes COPY more robust.
-- Available for Parquet, Avro, and ORC file formats.
-- =============================================================================
