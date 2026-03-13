-- =============================================================================
-- SECTION 4.25: FILE FORMAT OBJECTS
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to create reusable file format objects instead of repeating
--   inline format specifications in every COPY command.
--
-- WHAT YOU WILL LEARN:
--   1. Creating file format objects (CREATE FILE FORMAT)
--   2. Using file formats in COPY commands (FORMAT_NAME=)
--   3. Altering file format properties (ALTER FILE FORMAT)
--   4. Overriding file format properties inline at COPY time
--   5. Inspecting file format settings (DESC FILE FORMAT)
--
-- WHY USE FILE FORMAT OBJECTS?
--   - DRY principle: Define once, use everywhere
--   - Consistency: All COPY commands use the same format settings
--   - Maintainability: Change settings in one place
--   - Self-documenting: Named formats describe the data format
--
-- KEY INTERVIEW CONCEPTS:
--   - CREATE FILE FORMAT with TYPE=CSV/JSON and properties
--   - FORMAT_NAME= reference in COPY command
--   - ALTER FILE FORMAT to change properties (CANNOT change TYPE)
--   - Overriding file format properties inline in COPY command
--   - DESC FILE FORMAT to inspect current settings
--
-- FILE FORMAT TYPES (CONCEPT GAP FILLED):
--   Snowflake supports these file format types:
--   ┌──────────┬───────────────────────────────────────────────┐
--   │ Type     │ Use Case                                     │
--   ├──────────┼───────────────────────────────────────────────┤
--   │ CSV      │ Delimited text files (default type)           │
--   │ JSON     │ Semi-structured JSON data                     │
--   │ AVRO     │ Apache Avro binary format                     │
--   │ ORC      │ Apache ORC columnar format                    │
--   │ PARQUET  │ Apache Parquet columnar format                │
--   │ XML      │ XML documents                                 │
--   └──────────┴───────────────────────────────────────────────┘
-- =============================================================================


-- =============================================
-- STEP 1: Inline file format (baseline comparison)
-- =============================================
-- This is what we've been doing - specifying format inline in COPY.
-- It works but requires repeating the same options everywhere.

COPY INTO OUR_FIRST_DB.PUBLIC.ORDERS_EX
    FROM @MANAGE_DB.external_stages.aws_stage_errorex
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    files = ('OrderDetails_error.csv')
    ON_ERROR = 'SKIP_FILE_3';


-- =============================================
-- STEP 2: Create table and organizing schema
-- =============================================
CREATE OR REPLACE TABLE OUR_FIRST_DB.PUBLIC.ORDERS_EX (
    ORDER_ID    VARCHAR(30),
    AMOUNT      INT,
    PROFIT      INT,
    QUANTITY    INT,
    CATEGORY    VARCHAR(30),
    SUBCATEGORY VARCHAR(30)
);

-- Best practice: Keep file formats in a dedicated schema
CREATE OR REPLACE SCHEMA MANAGE_DB.file_formats;


-- =============================================
-- STEP 3: Create a file format object
-- =============================================
-- Default file format: TYPE=CSV with all default properties.

CREATE OR REPLACE FILE FORMAT MANAGE_DB.file_formats.my_file_format;

-- Without specifying TYPE, it defaults to CSV.
-- All CSV-specific properties also get default values.

-- Inspect the file format to see all properties and their current values
DESC FILE FORMAT MANAGE_DB.file_formats.my_file_format;

-- KEY DEFAULT VALUES FOR CSV:
--   TYPE             = CSV
--   FIELD_DELIMITER  = ','        (comma)
--   RECORD_DELIMITER = '\n'       (newline)
--   SKIP_HEADER      = 0          (no header skip)
--   FIELD_OPTIONALLY_ENCLOSED_BY = NONE
--   COMPRESSION      = AUTO
--   ESCAPE           = NONE
--   NULL_IF          = ('\\N')    (treat \N as NULL)


-- =============================================
-- STEP 4: Use file format object in COPY
-- =============================================
-- Reference the file format by name using FORMAT_NAME=

COPY INTO OUR_FIRST_DB.PUBLIC.ORDERS_EX
    FROM @MANAGE_DB.external_stages.aws_stage_errorex
    file_format = (FORMAT_NAME = MANAGE_DB.file_formats.my_file_format)
    files = ('OrderDetails_error.csv')
    ON_ERROR = 'SKIP_FILE_3';

-- NOTE: Since SKIP_HEADER defaults to 0, this will try to load the header row
-- as data, which may cause an error. Let's fix that with ALTER.


-- =============================================
-- STEP 5: Alter file format properties
-- =============================================
-- Change specific properties without recreating the entire object.

ALTER FILE FORMAT MANAGE_DB.file_formats.my_file_format
    SET SKIP_HEADER = 1;

-- IMPORTANT: You can ALTER individual properties, but you CANNOT change TYPE.
-- To change from CSV to JSON, you must CREATE OR REPLACE.

-- COMMON PROPERTIES TO ALTER:
--   SET SKIP_HEADER = 1
--   SET FIELD_DELIMITER = '|'
--   SET FIELD_OPTIONALLY_ENCLOSED_BY = '"'
--   SET NULL_IF = ('NULL', 'null', '')
--   SET COMPRESSION = GZIP


-- =============================================
-- STEP 6: Create file format with explicit properties
-- =============================================
-- Define type and properties at creation time.

CREATE OR REPLACE FILE FORMAT MANAGE_DB.file_formats.my_file_format
    TYPE = JSON
    TIME_FORMAT = AUTO;

-- Inspect the new settings
DESC FILE FORMAT MANAGE_DB.file_formats.my_file_format;


-- =============================================
-- STEP 7: Attempting to ALTER the TYPE (will fail)
-- =============================================
-- This demonstrates that TYPE cannot be changed via ALTER.

ALTER FILE FORMAT MANAGE_DB.file_formats.my_file_format
    SET TYPE = CSV;
-- ERROR: Cannot change the TYPE of an existing file format.
-- You must use CREATE OR REPLACE to change the type.


-- =============================================
-- STEP 8: Recreate as CSV (default type)
-- =============================================
CREATE OR REPLACE FILE FORMAT MANAGE_DB.file_formats.my_file_format;
-- This recreates with default TYPE=CSV and all default properties.

DESC FILE FORMAT MANAGE_DB.file_formats.my_file_format;


-- =============================================
-- STEP 9: Override file format properties inline
-- =============================================
-- You can override specific properties at COPY time without changing the object.
-- The object itself remains unchanged.

TRUNCATE TABLE OUR_FIRST_DB.PUBLIC.ORDERS_EX;

COPY INTO OUR_FIRST_DB.PUBLIC.ORDERS_EX
    FROM @MANAGE_DB.external_stages.aws_stage_errorex
    file_format = (
        FORMAT_NAME    = MANAGE_DB.file_formats.my_file_format
        field_delimiter = ','        -- Override: not stored in the object
        skip_header    = 1           -- Override: not stored in the object
    )
    files = ('OrderDetails_error.csv')
    ON_ERROR = 'SKIP_FILE_3';

-- INTERVIEW TIP: Inline overrides are temporary and do NOT modify the
-- file format object. They only apply to this specific COPY command.
-- This is useful for one-off adjustments without affecting other users.

DESC STAGE MANAGE_DB.external_stages.aws_stage_errorex;


-- =============================================================================
-- CONCEPT GAP: FILE FORMAT ATTACHED TO STAGE
-- =============================================================================
-- You can also attach a file format directly to a stage:
--
--   CREATE STAGE my_stage
--       url = 's3://my-bucket'
--       FILE_FORMAT = MANAGE_DB.file_formats.my_file_format;
--
-- When a stage has a file format:
--   - COPY commands don't need to specify file_format at all
--   - You can still override with inline file_format in COPY
--   - Priority: COPY inline > Stage file format > Defaults
--
-- CONCEPT GAP: COMMONLY USED CSV PROPERTIES
-- ┌─────────────────────────────────┬──────────────────────────────────┐
-- │ Property                        │ Common Values                   │
-- ├─────────────────────────────────┼──────────────────────────────────┤
-- │ FIELD_DELIMITER                 │ ',' (default), '|', '\t', ';'   │
-- │ RECORD_DELIMITER                │ '\n' (default), '\r\n'          │
-- │ SKIP_HEADER                     │ 0 (default), 1                  │
-- │ FIELD_OPTIONALLY_ENCLOSED_BY    │ NONE (default), '"', '\''       │
-- │ NULL_IF                         │ ('\\N'), ('NULL','null','')     │
-- │ EMPTY_FIELD_AS_NULL             │ TRUE (default), FALSE           │
-- │ COMPRESSION                     │ AUTO, GZIP, BZ2, ZSTD, NONE   │
-- │ ENCODING                        │ UTF8 (default), others          │
-- │ ERROR_ON_COLUMN_COUNT_MISMATCH  │ TRUE (default), FALSE           │
-- └─────────────────────────────────┴──────────────────────────────────┘
-- =============================================================================
