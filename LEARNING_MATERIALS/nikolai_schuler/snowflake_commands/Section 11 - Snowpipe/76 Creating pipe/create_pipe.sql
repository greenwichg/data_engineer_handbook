-- =============================================================================
-- SECTION 11.76: CREATE PIPE (Snowpipe Definition)
-- =============================================================================
--
-- OBJECTIVE:
--   Understand the CREATE PIPE syntax and how the pipe definition wraps
--   a COPY INTO statement for automated data ingestion.
--
-- WHAT YOU WILL LEARN:
--   1. CREATE PIPE syntax with auto_ingest
--   2. The embedded COPY INTO statement
--   3. Describing a pipe to get its properties
--
-- KEY INTERVIEW CONCEPTS:
--   - CREATE PIPE ... AS COPY INTO defines the loading logic
--   - auto_ingest = TRUE enables automatic loading on file arrival
--   - DESC PIPE shows notification_channel (SQS ARN for AWS)
--   - A pipe is a named object wrapping a SINGLE COPY INTO statement
--   - Changing the COPY statement requires RECREATING the pipe
--
-- PIPE PROPERTIES (CONCEPT GAP FILLED):
-- ┌─────────────────────────┬────────────────────────────────────────────┐
-- │ Property                │ Description                               │
-- ├─────────────────────────┼────────────────────────────────────────────┤
-- │ name                    │ Fully qualified pipe name                 │
-- │ definition              │ The COPY INTO statement                   │
-- │ notification_channel    │ SQS/Event Grid/Pub/Sub endpoint           │
-- │ owner                   │ Role that owns the pipe                   │
-- │ is_auto_ingest          │ TRUE if auto_ingest is enabled            │
-- │ error_integration       │ Error notification integration (optional) │
-- └─────────────────────────┴────────────────────────────────────────────┘
--
-- PIPE LIMITATIONS:
--   - One COPY INTO per pipe (can't combine multiple statements)
--   - Cannot ALTER the COPY definition (must recreate)
--   - Pipe must reference a stage with a storage integration
--   - auto_ingest requires cloud event notification setup
-- =============================================================================


-- =============================================
-- Create the pipe with auto_ingest
-- =============================================
CREATE OR REPLACE PIPE MANAGE_DB.pipes.employee_pipe
    auto_ingest = TRUE
AS
    COPY INTO OUR_FIRST_DB.PUBLIC.employees
    FROM @MANAGE_DB.external_stages.csv_folder;

-- IMPORTANT: The COPY INTO statement inside the pipe does NOT support
-- all COPY options. Notable restrictions:
--   - No VALIDATION_MODE (pipes always load data)
--   - No ON_ERROR = ABORT_STATEMENT (pipe uses SKIP_FILE behavior)
--   - FORCE is not applicable (pipe tracks its own load history)


-- =============================================
-- Describe the pipe
-- =============================================
DESC PIPE employee_pipe;

-- Use the notification_channel to configure cloud event notifications.
-- Without proper event notification setup, auto_ingest won't trigger.


-- =============================================
-- Verify loaded data
-- =============================================
SELECT * FROM OUR_FIRST_DB.PUBLIC.employees;


-- =============================================================================
-- CONCEPT GAP: PIPE COPY OPTIONS
-- =============================================================================
-- You can include some COPY options in the pipe definition:
--
-- CREATE PIPE my_pipe auto_ingest = TRUE AS
--     COPY INTO my_table FROM @my_stage
--     FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1)
--     ON_ERROR = CONTINUE           -- Skip bad rows (most common for pipes)
--     MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;  -- For Parquet/Avro
--
-- INTERVIEW TIP: Pipes default to ON_ERROR = SKIP_FILE behavior.
-- Use ON_ERROR = CONTINUE if you want to load partial files.
-- Always monitor COPY_HISTORY for error tracking (Section 11.78).
-- =============================================================================
