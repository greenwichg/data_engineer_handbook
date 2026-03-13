-- =============================================================================
-- SECTION 9.66: LOAD JSON DATA FROM AZURE BLOB STORAGE
-- =============================================================================
--
-- OBJECTIVE:
--   Learn two approaches for loading JSON from Azure: direct COPY with
--   transformation vs raw VARIANT table with INSERT INTO SELECT.
--
-- WHAT YOU WILL LEARN:
--   1. Creating a JSON file format and stage for Azure
--   2. Querying JSON from Azure stage with $1:"key" notation
--   3. Direct load approach: COPY INTO with transformation subquery
--   4. Raw VARIANT approach: load raw first, then parse with INSERT INTO
--
-- TWO JSON LOADING STRATEGIES (CONCEPT GAP FILLED):
-- ┌───────────────────────┬───────────────────────────────────────────────────┐
-- │ Transform-on-Load     │ Load-then-Transform (Raw VARIANT)               │
-- ├───────────────────────┼───────────────────────────────────────────────────┤
-- │ COPY INTO table FROM  │ COPY INTO raw_table FROM @stage                 │
-- │ (SELECT ... FROM      │ INSERT INTO table SELECT ... FROM raw_table     │
-- │  @stage)              │                                                 │
-- │ One step              │ Two steps                                       │
-- │ Simpler code          │ More flexible                                   │
-- │ Raw data NOT preserved│ Raw data preserved for debugging/reprocessing   │
-- │ Best for: stable JSON │ Best for: evolving schemas, complex transforms  │
-- └───────────────────────┴───────────────────────────────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - $1:"key" (quoted) for keys with spaces/special characters
--   - $1:key (unquoted) for simple lowercase keys
--   - Both approaches produce identical results
--   - Raw VARIANT approach is more flexible for evolving JSON schemas
-- =============================================================================


-- =============================================
-- STEP 1: Create JSON file format and stage
-- =============================================
CREATE OR REPLACE FILE FORMAT demo_db.public.fileformat_azure_json
    TYPE = JSON;

CREATE OR REPLACE STAGE demo_db.public.stage_azure
    STORAGE_INTEGRATION = azure_integration
    URL = 'azure://storageaccountsnow.blob.core.windows.net/snowflakejson'
    FILE_FORMAT = fileformat_azure_json;

LIST @demo_db.public.stage_azure;


-- =============================================
-- STEP 2: Preview raw JSON from stage
-- =============================================
SELECT * FROM @demo_db.public.stage_azure;

-- Access a single attribute (note: quoted because of space in key name)
SELECT $1:"Car Model" FROM @demo_db.public.stage_azure;

-- With type casting (removes VARIANT quotes)
SELECT $1:"Car Model"::STRING FROM @demo_db.public.stage_azure;


-- =============================================
-- STEP 3: Query all attributes with types and aliases
-- =============================================
SELECT
    $1:"Car Model"::STRING      AS car_model,
    $1:"Car Model Year"::INT    AS car_model_year,
    $1:"car make"::STRING       AS car_make,        -- Lowercase key, no quotes needed
    $1:"first_name"::STRING     AS first_name,
    $1:"last_name"::STRING      AS last_name
FROM @demo_db.public.stage_azure;

-- NOTE: "Car Model" has spaces -> must use quotes: $1:"Car Model"
--       "car make" is lowercase -> quotes optional but recommended for consistency
--       JSON keys ARE case-sensitive: $1:"Car Model" != $1:"car model"


-- =============================================
-- APPROACH 1: Direct COPY with transformation
-- =============================================
CREATE OR REPLACE TABLE car_owner (
    car_model      VARCHAR,
    car_model_year INT,
    car_make       VARCHAR,
    first_name     VARCHAR,
    last_name      VARCHAR
);

COPY INTO car_owner
FROM (
    SELECT
        $1:"Car Model"::STRING      AS car_model,
        $1:"Car Model Year"::INT    AS car_model_year,
        $1:"car make"::STRING       AS car_make,
        $1:"first_name"::STRING     AS first_name,
        $1:"last_name"::STRING      AS last_name
    FROM @demo_db.public.stage_azure
);

SELECT * FROM car_owner;


-- =============================================
-- APPROACH 2: Raw VARIANT table + INSERT INTO
-- =============================================
-- Step 2a: Clear the structured table
TRUNCATE TABLE car_owner;
SELECT * FROM car_owner;  -- Verify empty

-- Step 2b: Create raw staging table
CREATE OR REPLACE TABLE car_owner_raw (
    raw VARIANT                   -- Single column for entire JSON document
);

-- Step 2c: Load raw JSON (no transformation)
COPY INTO car_owner_raw
FROM @demo_db.public.stage_azure;

SELECT * FROM car_owner_raw;

-- Step 2d: Parse and insert into structured table
INSERT INTO car_owner
SELECT
    $1:"Car Model"::STRING      AS car_model,
    $1:"Car Model Year"::INT    AS car_model_year,
    $1:"car make"::STRING       AS car_make,
    $1:"first_name"::STRING     AS first_name,
    $1:"last_name"::STRING      AS last_name
FROM car_owner_raw;

SELECT * FROM car_owner;

-- INTERVIEW TIP: The raw VARIANT approach is preferred in production because:
-- 1. Raw data is preserved (can reprocess if transformation logic changes)
-- 2. Schema evolution is easier (add new columns without re-loading)
-- 3. Debugging is simpler (compare raw vs parsed data)
-- 4. Follows the Medallion Architecture (Bronze -> Silver -> Gold)
-- =============================================================================
