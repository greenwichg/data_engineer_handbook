-- =============================================================================
-- SECTION 11.78: SNOWPIPE ERROR HANDLING & MONITORING
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to diagnose, troubleshoot, and monitor Snowpipe loading errors
--   using built-in system functions and views.
--
-- WHAT YOU WILL LEARN:
--   1. SYSTEM$PIPE_STATUS() to check pipe state
--   2. VALIDATE_PIPE_LOAD() to find recent load errors
--   3. COPY_HISTORY() for detailed load history and error messages
--   4. ALTER PIPE ... REFRESH to re-trigger file processing
--
-- SNOWPIPE MONITORING TOOLS:
-- ┌────────────────────────────┬──────────────────────────────────────────────┐
-- │ Tool                       │ Purpose                                     │
-- ├────────────────────────────┼──────────────────────────────────────────────┤
-- │ SYSTEM$PIPE_STATUS()       │ Current state: running, paused, stalled     │
-- │                            │ Shows pendingFileCount & lastIngestedFile   │
-- ├────────────────────────────┼──────────────────────────────────────────────┤
-- │ VALIDATE_PIPE_LOAD()       │ Returns errors for recent pipe loads         │
-- │                            │ Similar to validate() for batch COPY         │
-- ├────────────────────────────┼──────────────────────────────────────────────┤
-- │ COPY_HISTORY() (Info Schema│ Detailed load history: files, rows, errors   │
-- │                            │ Shows error messages and counts              │
-- ├────────────────────────────┼──────────────────────────────────────────────┤
-- │ ALTER PIPE REFRESH         │ Re-triggers processing of staged files       │
-- │                            │ Used after pipe recreation or missed events  │
-- └────────────────────────────┴──────────────────────────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - Snowpipe silently skips bad files; ALWAYS monitor for errors
--   - VALIDATE_PIPE_LOAD has a 14-day lookback window
--   - COPY_HISTORY shows both successful and failed loads
--   - ALTER PIPE REFRESH forces re-scan of files in the stage
--
-- COMMON SNOWPIPE ISSUES (CONCEPT GAP FILLED):
--   1. Files not loading: Check SYSTEM$PIPE_STATUS for pendingFileCount
--   2. Data type errors: Check VALIDATE_PIPE_LOAD for error messages
--   3. Duplicate data: Snowpipe tracks files; only happens with REFRESH
--   4. Pipe stalled: Check notification setup (SQS/Event Grid/Pub/Sub)
-- =============================================================================


-- =============================================
-- STEP 1: Ensure file format is correct
-- =============================================
CREATE OR REPLACE FILE FORMAT MANAGE_DB.file_formats.csv_fileformat
    type                = csv
    field_delimiter     = ','
    skip_header         = 1
    null_if             = ('NULL', 'null')
    empty_field_as_null = TRUE;

-- Verify current data
SELECT * FROM OUR_FIRST_DB.PUBLIC.employees;


-- =============================================
-- STEP 2: Refresh pipe (force re-scan of staged files)
-- =============================================
-- Use REFRESH when:
--   - Pipe was just recreated and needs to process existing files
--   - Event notifications were missed or delayed
--   - You want to force re-processing of files in the stage

ALTER PIPE employee_pipe REFRESH;

-- REFRESH scans the stage and queues any files that haven't been loaded yet.
-- It does NOT reload files that were already successfully loaded.


-- =============================================
-- STEP 3: Check pipe status
-- =============================================
-- SYSTEM$PIPE_STATUS returns a JSON object with the pipe's current state.

SELECT SYSTEM$PIPE_STATUS('employee_pipe');

-- OUTPUT FIELDS:
--   executionState       - "RUNNING", "PAUSED", "STALLED_*"
--   pendingFileCount     - Number of files waiting to be loaded
--   lastIngestedTimestamp - When the last file was successfully loaded
--   lastIngestedFilePath - Path of the last loaded file
--   notificationChannelName - The SQS/Event Grid endpoint
--   numOutstandingMessagesOnChannel - Unprocessed notifications
--   lastPulledFromChannelTimestamp  - When notifications were last checked

-- INTERVIEW TIP: If pendingFileCount stays high and doesn't decrease,
-- the pipe may be stalled. Check error logs and file format compatibility.


-- =============================================
-- STEP 4: Check for load errors (VALIDATE_PIPE_LOAD)
-- =============================================
-- Returns error details for recent pipe loads within the time window.

SELECT * FROM TABLE(VALIDATE_PIPE_LOAD(
    PIPE_NAME  => 'MANAGE_DB.pipes.employee_pipe',
    START_TIME => DATEADD(HOUR, -2, CURRENT_TIMESTAMP())
));

-- OUTPUT: error messages, file names, line numbers, rejected records
-- If empty: no errors occurred in the time window


-- =============================================
-- STEP 5: Check COPY_HISTORY for detailed load audit
-- =============================================
-- Shows all load operations (successful + failed) for a table.

SELECT * FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
    table_name => 'OUR_FIRST_DB.PUBLIC.EMPLOYEES',
    START_TIME => DATEADD(HOUR, -2, CURRENT_TIMESTAMP())
));

-- OUTPUT COLUMNS:
--   FILE_NAME, STAGE_LOCATION, STATUS, ROW_COUNT, ROW_PARSED,
--   FIRST_ERROR_MESSAGE, FIRST_ERROR_LINE_NUM, ERROR_COUNT,
--   PIPE_CATALOG_NAME, PIPE_SCHEMA_NAME, PIPE_NAME, etc.

-- INTERVIEW TIP: COPY_HISTORY shows whether data was loaded by
-- a batch COPY INTO or by Snowpipe (PIPE_NAME will be populated).


-- =============================================================================
-- CONCEPT GAP: SNOWPIPE ERROR NOTIFICATION INTEGRATION
-- =============================================================================
-- For production monitoring, set up error notifications:
--
-- -- 1. Create a notification integration (for SNS/Email alerts)
-- CREATE NOTIFICATION INTEGRATION my_error_notif
--     ENABLED = TRUE
--     TYPE = QUEUE
--     NOTIFICATION_PROVIDER = AWS_SNS
--     DIRECTION = OUTBOUND
--     AWS_SNS_TOPIC_ARN = 'arn:aws:sns:us-east-1:123456:snowpipe-errors'
--     AWS_SNS_ROLE_ARN = 'arn:aws:iam::123456:role/sns-role';
--
-- -- 2. Attach to pipe
-- ALTER PIPE my_pipe SET ERROR_INTEGRATION = my_error_notif;
--
-- Now Snowpipe automatically sends error notifications to SNS/Email
-- when files fail to load. No manual monitoring needed!
--
-- MONITORING QUERY (run periodically or via TASK):
-- SELECT pipe_name, error_count, first_error_message, file_name
-- FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
--     table_name => 'MY_TABLE',
--     START_TIME => DATEADD(hour, -1, CURRENT_TIMESTAMP())
-- ))
-- WHERE error_count > 0;
-- =============================================================================
