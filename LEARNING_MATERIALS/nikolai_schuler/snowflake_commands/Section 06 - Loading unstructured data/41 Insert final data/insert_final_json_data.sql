-- =============================================================================
-- SECTION 6.41: INSERTING FINAL DATA FROM JSON (JSON Part 5 of 5)
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to materialize parsed JSON into a permanent structured table
--   using CREATE TABLE AS SELECT (CTAS) and INSERT INTO SELECT.
--
-- WHAT YOU WILL LEARN:
--   1. CREATE TABLE AS SELECT (CTAS) to create and populate in one step
--   2. INSERT INTO SELECT for loading into an existing table
--   3. The complete two-step JSON loading pattern
--   4. TRUNCATE + re-INSERT for idempotent reload workflows
--
-- COMPLETE JSON LOADING PATTERN:
--   Step 1: Raw load    -> COPY INTO variant_table FROM @stage
--   Step 2: Parse/Load  -> CTAS or INSERT INTO structured_table
--                          SELECT ... FROM variant_table, FLATTEN(...)
--
-- KEY INTERVIEW CONCEPTS:
--   - CREATE TABLE AS SELECT (CTAS) creates and populates at once
--   - INSERT INTO SELECT loads into an existing table from a query
--   - The raw VARIANT table is a STAGING layer
--   - Always create a final STRUCTURED table for analytics
--   - TRUNCATE + re-INSERT for idempotent (repeatable) reloads
--
-- CTAS vs INSERT INTO (CONCEPT GAP FILLED):
-- ┌──────────────────────┬──────────────────────────────────────────────────┐
-- │ Feature              │ CTAS                   │ INSERT INTO SELECT      │
-- ├──────────────────────┼────────────────────────┼─────────────────────────┤
-- │ Creates table?       │ Yes (new table)         │ No (must exist)        │
-- │ Column types         │ Inferred from SELECT    │ Must match table def   │
-- │ Constraints          │ None inherited           │ Table constraints apply│
-- │ Idempotent?          │ Yes (CREATE OR REPLACE)  │ No (appends data)    │
-- │ Existing data        │ Replaced                 │ Preserved (appended) │
-- │ Use case             │ One-time creation        │ Incremental loads    │
-- └──────────────────────┴────────────────────────┴─────────────────────────┘
-- =============================================================================


-- =============================================
-- OPTION 1: CREATE TABLE AS SELECT (CTAS)
-- =============================================
-- Creates a new table and populates it in a single statement.
-- Uses FLATTEN to unnest the spoken_languages array.

CREATE OR REPLACE TABLE Languages AS
SELECT
    RAW_FILE:first_name::STRING    AS first_name,
    f.value:language::STRING       AS language,
    f.value:level::STRING          AS level_spoken
FROM OUR_FIRST_DB.PUBLIC.JSON_RAW,
     TABLE(FLATTEN(RAW_FILE:spoken_languages)) f;

-- Verify the result
SELECT * FROM Languages;

-- INTERVIEW TIP: CTAS infers column data types from the SELECT.
-- Since we cast with ::STRING, all columns are VARCHAR.
-- For explicit control over types, use CREATE TABLE + INSERT INTO.


-- =============================================
-- Demonstrate idempotent reload with TRUNCATE
-- =============================================
-- TRUNCATE removes all data but keeps the table structure.
TRUNCATE TABLE Languages;


-- =============================================
-- OPTION 2: INSERT INTO SELECT
-- =============================================
-- Loads data into the existing (now empty) Languages table.

INSERT INTO Languages
SELECT
    RAW_FILE:first_name::STRING    AS first_name,
    f.value:language::STRING       AS language,
    f.value:level::STRING          AS level_spoken
FROM OUR_FIRST_DB.PUBLIC.JSON_RAW,
     TABLE(FLATTEN(RAW_FILE:spoken_languages)) f;

-- Verify the result
SELECT * FROM Languages;

-- NOTE: Running INSERT INTO again WITHOUT truncating first would
-- create DUPLICATE rows. Always TRUNCATE before re-inserting for
-- full refresh patterns.


-- =============================================================================
-- CONCEPT GAP: PRODUCTION JSON PIPELINE PATTERN
-- =============================================================================
-- A complete production pipeline for JSON data:
--
-- -- 1. Raw staging layer (persistent)
-- CREATE TABLE raw.json_employees (
--     raw_data      VARIANT,
--     source_file   VARCHAR DEFAULT METADATA$FILENAME,
--     load_ts       TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
-- );
--
-- -- 2. Load raw JSON
-- COPY INTO raw.json_employees (raw_data)
--     FROM (SELECT $1 FROM @json_stage)
--     file_format = (TYPE = JSON);
--
-- -- 3. Parsed/structured layer
-- CREATE OR REPLACE TABLE curated.employees AS
-- SELECT
--     raw_data:id::INT               AS employee_id,
--     raw_data:first_name::STRING    AS first_name,
--     raw_data:last_name::STRING     AS last_name,
--     raw_data:job.title::STRING     AS job_title,
--     raw_data:job.salary::NUMBER    AS salary,
--     source_file,
--     load_ts
-- FROM raw.json_employees;
--
-- -- 4. Flattened arrays (separate table for 1:N relationships)
-- CREATE OR REPLACE TABLE curated.employee_languages AS
-- SELECT
--     raw_data:id::INT               AS employee_id,
--     f.value:language::STRING       AS language,
--     f.value:level::STRING          AS proficiency_level
-- FROM raw.json_employees,
--      TABLE(FLATTEN(input => raw_data:spoken_languages, OUTER => TRUE)) f;
--
-- INTERVIEW TIP: This raw -> curated pattern is a simplified version of
-- the Medallion Architecture (Bronze -> Silver -> Gold) used in modern
-- data lakehouse platforms.
-- =============================================================================
