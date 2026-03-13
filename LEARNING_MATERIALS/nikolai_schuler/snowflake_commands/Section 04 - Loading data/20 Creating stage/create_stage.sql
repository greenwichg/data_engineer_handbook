-- =============================================================================
-- SECTION 4.20: CREATING AND MANAGING EXTERNAL STAGES
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to create reusable external stage objects that point to cloud
--   storage (S3), so COPY commands reference a stage name instead of raw URLs.
--
-- WHAT YOU WILL LEARN:
--   1. Creating a dedicated database/schema for management objects
--   2. Creating external stages with and without credentials
--   3. Altering stage credentials
--   4. Listing files in a stage
--   5. Using stages in COPY commands
--
-- WHY USE STAGES?
--   - Decouple storage location from SQL logic (change URL in one place)
--   - Centralize credential management (don't repeat keys in every COPY)
--   - Enable file listing (LIST @stage) for discovery
--   - Support pattern-based file selection in COPY commands
--   - Reusable across multiple COPY commands and tables
--
-- STAGE TYPES IN SNOWFLAKE (CONCEPT GAP FILLED):
--   1. EXTERNAL STAGE  - Points to cloud storage (S3, Azure Blob, GCS)
--   2. INTERNAL STAGE  - Snowflake-managed storage (user/table/named stages)
--      a. User Stage    (@~)     - Private to each user, auto-created
--      b. Table Stage   (@%table) - One per table, auto-created
--      c. Named Stage   (@name)  - Explicitly created, most flexible
--
-- KEY INTERVIEW CONCEPTS:
--   - CREATE STAGE with url and credentials (aws_key_id, aws_secret_key)
--   - ALTER STAGE to update credentials
--   - Public vs private S3 buckets (no credentials = public bucket)
--   - LIST @stage to view files in the external location
--   - pattern='.*regex.*' for selective file loading
-- =============================================================================


-- =============================================
-- STEP 1: Create a management database
-- =============================================
-- Best practice: Keep stages, file formats, and other management objects
-- in a dedicated database, separate from your data tables.

CREATE OR REPLACE DATABASE MANAGE_DB;

CREATE OR REPLACE SCHEMA external_stages;

-- INTERVIEW TIP: This separation follows the principle of "separation of
-- concerns" - data objects vs infrastructure objects in different databases.


-- =============================================
-- STEP 2: Create an external stage (with credentials)
-- =============================================
-- This stage points to a PRIVATE S3 bucket requiring AWS credentials.

CREATE OR REPLACE STAGE MANAGE_DB.external_stages.aws_stage
    url = 's3://bucketsnowflakes3'
    credentials = (
        aws_key_id     = 'ABCD_DUMMY_ID'       -- AWS Access Key ID
        aws_secret_key = '1234abcd_key'         -- AWS Secret Access Key
    );

-- SECURITY NOTE: In production, NEVER hardcode credentials in SQL scripts.
-- Use STORAGE INTEGRATION objects instead (covered in Section 8).
-- Storage integrations use IAM roles, which are more secure and rotatable.


-- =============================================
-- STEP 3: Inspect stage properties
-- =============================================
-- DESC STAGE shows all properties: URL, credentials status, file format, etc.

DESC STAGE MANAGE_DB.external_stages.aws_stage;


-- =============================================
-- STEP 4: Alter stage credentials
-- =============================================
-- Use ALTER STAGE to update credentials without recreating the stage.
-- Existing COPY commands referencing this stage are unaffected.

ALTER STAGE aws_stage
    SET credentials = (
        aws_key_id     = 'XYZ_DUMMY_ID'
        aws_secret_key = '987xyz'
    );

-- CONCEPT GAP FILLED - WHAT YOU CAN ALTER ON A STAGE:
--   - credentials (key/secret or storage integration)
--   - url (change the bucket/path)
--   - file_format (default format for the stage)
--   - copy_options (default COPY options)
--   - comment (description text)


-- =============================================
-- STEP 5: Create a stage for a PUBLIC bucket
-- =============================================
-- Public S3 buckets don't require credentials.
-- Simply omit the credentials parameter.

CREATE OR REPLACE STAGE MANAGE_DB.external_stages.aws_stage
    url = 's3://bucketsnowflakes3';

-- INTERVIEW TIP: Public buckets are common for demo/training data.
-- In production, always use private buckets with proper IAM controls.


-- =============================================
-- STEP 6: List files in the stage
-- =============================================
-- LIST shows file names, sizes, MD5 hashes, and last modified dates.

LIST @aws_stage;

-- CONCEPT GAP FILLED - LIST OUTPUT COLUMNS:
--   name             - Full file path within the stage
--   size             - File size in bytes
--   md5              - MD5 hash (for change detection)
--   last_modified    - Timestamp of last modification


-- =============================================
-- STEP 7: Load data using the stage with pattern matching
-- =============================================
-- Use pattern= to selectively load files matching a regex.

COPY INTO OUR_FIRST_DB.PUBLIC.ORDERS
    FROM @aws_stage
    file_format = (
        type            = csv
        field_delimiter = ','
        skip_header     = 1
    )
    pattern = '.*Order.*';     -- Loads only files with "Order" in the name

-- PATTERN EXAMPLES (CONCEPT GAP FILLED):
--   '.*'            - All files
--   '.*\.csv'       - All CSV files
--   '.*Order.*'     - Files containing "Order" anywhere in the name
--   '.*2024.*'      - Files with "2024" in the name (e.g., date partitions)
--   'data_[0-9]+'   - Files like data_1, data_2, data_123
-- =============================================================================
