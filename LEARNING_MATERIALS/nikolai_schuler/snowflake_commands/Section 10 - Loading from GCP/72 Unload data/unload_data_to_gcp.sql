-- =============================================================================
-- SECTION 10.72: UNLOADING (EXPORTING) DATA TO GCS
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to export data FROM a Snowflake table TO cloud storage (GCS)
--   using COPY INTO @stage syntax (the reverse of data loading).
--
-- WHAT YOU WILL LEARN:
--   1. The difference between loading and unloading
--   2. COPY INTO @stage FROM table syntax
--   3. Updating storage integration allowed locations
--   4. Unload file behavior (auto-splitting, naming)
--
-- LOADING vs UNLOADING (CONCEPT GAP FILLED):
-- ┌─────────────────────────────┬──────────────────────────────────────────┐
-- │ Loading (Ingest)            │ Unloading (Export)                      │
-- ├─────────────────────────────┼──────────────────────────────────────────┤
-- │ COPY INTO table FROM @stage │ COPY INTO @stage FROM table             │
-- │ Cloud -> Snowflake          │ Snowflake -> Cloud                      │
-- │ Reads from files            │ Writes to files                         │
-- │ Default format: stage's     │ Default format: CSV                     │
-- │ Uses file_format for parse  │ Uses file_format for output format      │
-- └─────────────────────────────┴──────────────────────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - COPY INTO @stage FROM table exports data to cloud storage
--   - Unloaded files are SPLIT into multiple parts by default (for parallelism)
--   - File naming: data_0_0_0.csv.gz, data_0_1_0.csv.gz, etc.
--   - ALTER STORAGE INTEGRATION can update STORAGE_ALLOWED_LOCATIONS
--   - Unload supports CSV, JSON, and PARQUET output formats
--
-- UNLOAD OPTIONS (CONCEPT GAP FILLED):
--   COPY INTO @stage FROM table
--       FILE_FORMAT = (TYPE = CSV|JSON|PARQUET)
--       SINGLE = TRUE|FALSE          -- Single file vs multiple parts
--       MAX_FILE_SIZE = 16777216     -- Max size per file (bytes, default 16MB)
--       OVERWRITE = TRUE|FALSE       -- Overwrite existing files
--       HEADER = TRUE|FALSE          -- Include column headers (CSV only)
--       COMPRESSION = AUTO|GZIP|NONE -- Output compression
-- =============================================================================


-- =============================================
-- STEP 1: Setup (ensure integration allows write location)
-- =============================================
USE ROLE ACCOUNTADMIN;
USE DATABASE DEMO_DB;

-- Recreate/update integration with the correct allowed locations
CREATE STORAGE INTEGRATION gcp_integration
    TYPE                      = EXTERNAL_STAGE
    STORAGE_PROVIDER          = GCS
    ENABLED                   = TRUE
    STORAGE_ALLOWED_LOCATIONS = (
        'gcs://snowflakebucketgcp',
        'gcs://snowflakebucketgcpjson'
    );

-- You can also ALTER an existing integration to add locations:
ALTER STORAGE INTEGRATION gcp_integration
SET STORAGE_ALLOWED_LOCATIONS = (
    'gcs://snowflakebucketgcp',
    'gcs://snowflakebucketgcpjson'
);


-- =============================================
-- STEP 2: Create file format and stage for unloading
-- =============================================
CREATE OR REPLACE FILE FORMAT demo_db.public.fileformat_gcp
    TYPE            = CSV
    FIELD_DELIMITER = ','
    SKIP_HEADER     = 1;

CREATE OR REPLACE STAGE demo_db.public.stage_gcp
    STORAGE_INTEGRATION = gcp_integration
    URL                 = 'gcs://snowflakebucketgcp/csv_happiness'
    FILE_FORMAT         = fileformat_gcp;


-- =============================================
-- STEP 3: Unload (export) data to GCS
-- =============================================
-- Verify the data we want to export
SELECT * FROM HAPPINESS;

-- Export the table to GCS
COPY INTO @stage_gcp
FROM HAPPINESS;

-- This creates files in: gcs://snowflakebucketgcp/csv_happiness/
-- Files are auto-named like: data_0_0_0.csv.gz, data_0_1_0.csv.gz
-- Default compression is GZIP.

-- CONCEPT GAP FILLED - UNLOAD EXAMPLES:
-- Export as single CSV file with header:
--   COPY INTO @stage_gcp FROM HAPPINESS
--       SINGLE = TRUE HEADER = TRUE
--       MAX_FILE_SIZE = 5368709120;  -- 5 GB max

-- Export as Parquet:
--   COPY INTO @stage_gcp FROM HAPPINESS
--       FILE_FORMAT = (TYPE = PARQUET);

-- Export with custom file prefix:
--   COPY INTO @stage_gcp/export_2024/ FROM HAPPINESS;

-- Export query results (not just a table):
--   COPY INTO @stage_gcp FROM (
--       SELECT country_name, ladder_score FROM HAPPINESS WHERE ladder_score > 7
--   );


-- =============================================================================
-- CONCEPT GAP: UNLOAD USE CASES
-- =============================================================================
-- 1. DATA SHARING: Export to cloud storage for external partners
-- 2. BACKUP: Export critical tables to cloud storage as insurance
-- 3. DATA LAKE: Feed Snowflake outputs into a data lake (S3/GCS/ADLS)
-- 4. MIGRATION: Move data between Snowflake accounts or to other systems
-- 5. REPORTING: Generate CSV/Parquet files for BI tools or email delivery
--
-- INTERVIEW TIP: For sharing data WITHIN Snowflake, use Snowflake's native
-- Data Sharing (Section 16) instead of unloading. It's zero-copy, real-time,
-- and doesn't require cloud storage as an intermediary.
-- =============================================================================
