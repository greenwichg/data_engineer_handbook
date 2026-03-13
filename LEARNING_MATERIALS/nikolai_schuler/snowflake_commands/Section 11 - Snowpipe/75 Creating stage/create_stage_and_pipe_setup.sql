-- =============================================================================
-- SECTION 11.75: SNOWPIPE SETUP (Table, File Format, Stage, and Pipe)
-- =============================================================================
--
-- OBJECTIVE:
--   Learn the complete Snowpipe setup: target table, file format, stage,
--   and pipe with auto_ingest for continuous, event-driven data loading.
--
-- WHAT YOU WILL LEARN:
--   1. What Snowpipe is and how it differs from batch COPY INTO
--   2. Setting up the prerequisite objects (table, file format, stage)
--   3. Creating a pipe with auto_ingest = TRUE
--   4. Getting the notification channel for S3 event configuration
--
-- SNOWPIPE vs BATCH COPY INTO (CRITICAL INTERVIEW TOPIC):
-- ┌──────────────────────┬──────────────────────────────────────────────────┐
-- │ Batch COPY INTO      │ Snowpipe                                        │
-- ├──────────────────────┼──────────────────────────────────────────────────┤
-- │ Manual or scheduled  │ Event-driven (automatic on file arrival)         │
-- │ Uses a warehouse     │ Serverless (no warehouse needed)                 │
-- │ Good for large batch │ Good for continuous/streaming micro-batches      │
-- │ Billed by warehouse  │ Billed per file loaded (serverless credits)      │
-- │ You control timing   │ Near real-time (files loaded within minutes)     │
-- │ Client-managed       │ Snowflake-managed                                │
-- └──────────────────────┴──────────────────────────────────────────────────┘
--
-- HOW SNOWPIPE WORKS (CONCEPT GAP FILLED):
--   1. New file arrives in cloud storage (S3/Azure/GCS)
--   2. Cloud sends an event notification to Snowflake's SQS queue (AWS)
--      or Event Grid (Azure) or Pub/Sub (GCP)
--   3. Snowflake's serverless compute picks up the notification
--   4. Snowpipe executes the embedded COPY INTO statement
--   5. Data appears in the target table within ~1-2 minutes
--
-- KEY INTERVIEW CONCEPTS:
--   - Snowpipe enables continuous, event-driven loading (not batch)
--   - auto_ingest = TRUE triggers loading via cloud event notifications
--   - DESC PIPE reveals the notification_channel (SQS ARN for AWS)
--   - Pipe definition wraps a single COPY INTO statement
--   - Snowpipe uses serverless compute (no warehouse needed)
--   - Billed per file: ~0.06 credits per 1000 files processed
-- =============================================================================


-- =============================================
-- STEP 1: Create the target table
-- =============================================
CREATE OR REPLACE TABLE OUR_FIRST_DB.PUBLIC.employees (
    id         INT,
    first_name STRING,
    last_name  STRING,
    email      STRING,
    location   STRING,
    department STRING
);


-- =============================================
-- STEP 2: Create file format
-- =============================================
CREATE OR REPLACE FILE FORMAT MANAGE_DB.file_formats.csv_fileformat
    type                = csv
    field_delimiter     = ','
    skip_header         = 1
    null_if             = ('NULL', 'null')
    empty_field_as_null = TRUE;


-- =============================================
-- STEP 3: Create stage with storage integration
-- =============================================
CREATE OR REPLACE STAGE MANAGE_DB.external_stages.csv_folder
    URL                 = 's3://snowflakes3bucket123/csv/snowpipe'
    STORAGE_INTEGRATION = s3_int
    FILE_FORMAT         = MANAGE_DB.file_formats.csv_fileformat;

-- Verify files are accessible
LIST @MANAGE_DB.external_stages.csv_folder;


-- =============================================
-- STEP 4: Create schema for pipe objects
-- =============================================
-- Organize pipes in a dedicated schema for clarity.
CREATE OR REPLACE SCHEMA MANAGE_DB.pipes;


-- =============================================
-- STEP 5: Create the pipe
-- =============================================
-- The pipe wraps a COPY INTO statement and adds auto_ingest behavior.

CREATE OR REPLACE PIPE MANAGE_DB.pipes.employee_pipe
    auto_ingest = TRUE
AS
    COPY INTO OUR_FIRST_DB.PUBLIC.employees
    FROM @MANAGE_DB.external_stages.csv_folder;

-- ANATOMY OF A PIPE:
--   CREATE PIPE <name>
--     auto_ingest = TRUE       -- Enable automatic loading on file arrival
--   AS
--     COPY INTO <target>       -- The COPY statement to execute
--     FROM @<stage>            -- Source stage
--     [file_format = (...)]    -- Optional: override stage's file format
--     [pattern = '...']        -- Optional: only load matching files


-- =============================================
-- STEP 6: Get notification channel
-- =============================================
DESC PIPE employee_pipe;

-- KEY OUTPUT: notification_channel
-- This is the SQS queue ARN that you must configure as the
-- event destination in your S3 bucket settings:
--   S3 Console > Bucket > Properties > Event Notifications > Create
--   Event type: s3:ObjectCreated:*
--   Destination: SQS Queue
--   SQS ARN: <notification_channel value from DESC PIPE>


-- =============================================
-- STEP 7: Verify data is loading
-- =============================================
SELECT * FROM OUR_FIRST_DB.PUBLIC.employees;

-- If files were already in the stage when the pipe was created,
-- they may NOT be automatically loaded. Use ALTER PIPE ... REFRESH
-- to manually trigger loading of existing files (see Section 11.79).


-- =============================================================================
-- CONCEPT GAP: SNOWPIPE AUTO_INGEST BY CLOUD PROVIDER
-- =============================================================================
-- AWS S3:
--   Notification: S3 Event Notification -> SQS Queue
--   DESC PIPE returns: notification_channel (SQS ARN)
--   Setup: Configure S3 bucket event to send to this SQS queue
--
-- Azure Blob:
--   Notification: Azure Event Grid -> Snowflake's storage queue
--   DESC PIPE returns: notification_channel (Azure storage queue URL)
--   Setup: Create Event Grid subscription pointing to the queue
--
-- GCS:
--   Notification: GCS Pub/Sub notification
--   DESC PIPE returns: notification_channel (Pub/Sub subscription)
--   Setup: Configure GCS bucket notification to Pub/Sub topic
--
-- ALTERNATIVE: REST API (no auto_ingest)
--   Instead of event notifications, call Snowpipe REST API:
--   POST https://<account>.snowflakecomputing.com/v1/data/pipes/<pipe>/insertFiles
--   Body: {"files": [{"path": "file1.csv"}, {"path": "file2.csv"}]}
--   Use this when cloud notifications aren't available.
-- =============================================================================
