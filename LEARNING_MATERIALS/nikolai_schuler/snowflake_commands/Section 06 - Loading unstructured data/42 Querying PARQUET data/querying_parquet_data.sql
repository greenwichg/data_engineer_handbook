-- =============================================================================
-- SECTION 6.42: QUERYING PARQUET DATA FROM STAGE (Parquet Part 1 of 2)
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to query Parquet files directly from a stage using
--   $1:column notation, type casting, and file format configuration.
--
-- WHAT YOU WILL LEARN:
--   1. Creating PARQUET file format and stage
--   2. Querying Parquet files directly from stage (without loading)
--   3. $1:column_name notation for Parquet fields
--   4. Type casting on Parquet columns
--   5. Passing file format in queries vs attaching to stage
--
-- PARQUET vs CSV (CONCEPT GAP FILLED):
-- ┌──────────────────────┬──────────────────────────────────────────────────┐
-- │ Feature              │ CSV                    │ Parquet                 │
-- ├──────────────────────┼────────────────────────┼─────────────────────────┤
-- │ Format               │ Row-based text         │ Columnar binary         │
-- │ Schema               │ None (positional)      │ Self-describing         │
-- │ Column access        │ $1, $2 (by position)   │ $1:col_name (by name)   │
-- │ Compression          │ Optional (GZIP, etc.)  │ Built-in (Snappy, etc.) │
-- │ Query from stage     │ SELECT $1, $2...       │ SELECT $1:col_name...   │
-- │ Read efficiency      │ Must read all columns  │ Reads only needed cols  │
-- │ File size            │ Large                  │ Small (compressed)       │
-- │ Type preservation    │ All strings            │ Preserves data types    │
-- └──────────────────────┴────────────────────────┴─────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - FILE FORMAT TYPE = 'parquet' for Parquet ingestion
--   - $1:column_name to access Parquet fields from staged files
--   - Unlike CSV, Parquet columns are accessed BY NAME (not position)
--   - Type casting (::INT, ::VARCHAR) still needed for COPY transforms
--   - SELECT * FROM @stage previews all Parquet data
-- =============================================================================


-- =============================================
-- STEP 1: Create file format and stage
-- =============================================

-- Parquet file format
CREATE OR REPLACE FILE FORMAT MANAGE_DB.FILE_FORMATS.PARQUET_FORMAT
    TYPE = 'parquet';

-- Stage with file format attached
CREATE OR REPLACE STAGE MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE
    url = 's3://snowflakeparquetdemo'
    FILE_FORMAT = MANAGE_DB.FILE_FORMATS.PARQUET_FORMAT;

-- INTERVIEW TIP: When FILE_FORMAT is attached to the stage,
-- you don't need to specify it in every SELECT or COPY command.


-- =============================================
-- STEP 2: Preview the data directly from stage
-- =============================================

-- List files in the stage
LIST @MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE;

-- Preview all data from staged Parquet files
SELECT * FROM @MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE;

-- This works because the file format is attached to the stage.
-- Snowflake automatically parses the Parquet schema.


-- =============================================
-- STEP 3: Query with file format passed explicitly
-- =============================================
-- Alternative: Stage without file format + pass format in query.

CREATE OR REPLACE STAGE MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE
    url = 's3://snowflakeparquetdemo';

-- Pass file format using the => syntax
SELECT *
FROM @MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE
    (file_format => 'MANAGE_DB.FILE_FORMATS.PARQUET_FORMAT');

-- Without quotes (when in the correct namespace)
USE MANAGE_DB.FILE_FORMATS;

SELECT *
FROM @MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE
    (file_format => MANAGE_DB.FILE_FORMATS.PARQUET_FORMAT);

-- Reattach file format to stage for convenience
CREATE OR REPLACE STAGE MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE
    url = 's3://snowflakeparquetdemo'
    FILE_FORMAT = MANAGE_DB.FILE_FORMATS.PARQUET_FORMAT;


-- =============================================
-- STEP 4: Query specific Parquet columns by name
-- =============================================
-- $1 refers to the entire Parquet row as a VARIANT object.
-- Access columns by name using $1:column_name

SELECT
    $1:__index_level_0__,
    $1:cat_id,
    $1:date,
    $1:"__index_level_0__",        -- Quoted keys for special characters
    $1:"cat_id",
    $1:"d",
    $1:"date",
    $1:"dept_id",
    $1:"id",
    $1:"item_id",
    $1:"state_id",
    $1:"store_id",
    $1:"value"
FROM @MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE;

-- NOTE: Quoting column names with " " ensures exact case matching.
-- $1:cat_id and $1:"cat_id" are equivalent when keys are lowercase.
-- Use quotes when column names have special chars or mixed case.


-- =============================================
-- STEP 5: Date conversion for Parquet date columns
-- =============================================
-- Some Parquet files store dates as integers (seconds since epoch).

SELECT 1;                           -- Simple test
SELECT DATE(365 * 60 * 60 * 24);   -- Convert epoch seconds to date


-- =============================================
-- STEP 6: Full query with type conversions and aliases
-- =============================================
-- Production-ready query with proper types and readable column names.

SELECT
    $1:__index_level_0__::INT       AS index_level,
    $1:cat_id::VARCHAR(50)          AS category,
    DATE($1:date::INT)              AS date,          -- Epoch int -> DATE
    $1:"dept_id"::VARCHAR(50)       AS dept_id,
    $1:"id"::VARCHAR(50)            AS id,
    $1:"item_id"::VARCHAR(50)       AS item_id,
    $1:"state_id"::VARCHAR(50)      AS state_id,
    $1:"store_id"::VARCHAR(50)      AS store_id,
    $1:"value"::INT                 AS value
FROM @MANAGE_DB.EXTERNAL_STAGES.PARQUETSTAGE;


-- =============================================================================
-- CONCEPT GAP: QUERYING FROM STAGE vs LOADING INTO TABLE
-- =============================================================================
-- Querying directly from stage (External Table pattern):
--   Pros: No storage cost, always reads latest files
--   Cons: Slower queries, no caching, requires warehouse each time
--
-- Loading into a table (COPY INTO pattern):
--   Pros: Fast queries, caching, time travel, clustering
--   Cons: Storage cost, load process needed, data can become stale
--
-- EXTERNAL TABLES (related concept):
--   CREATE EXTERNAL TABLE provides a middle ground:
--   - Define a schema on top of staged files
--   - Query with standard SQL (no $1: notation)
--   - Supports partition pruning for performance
--   - No data duplication (reads from stage)
--   - Materialized views can cache frequently queried data
-- =============================================================================
