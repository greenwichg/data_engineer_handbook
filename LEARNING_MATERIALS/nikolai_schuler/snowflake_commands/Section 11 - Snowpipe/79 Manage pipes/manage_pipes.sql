-- =============================================================================
-- SECTION 11.79: MANAGING PIPES (Snowpipe Lifecycle)
-- =============================================================================
--
-- OBJECTIVE:
--   Learn the complete pipe lifecycle: listing, pausing, modifying,
--   refreshing, and resuming Snowpipe objects.
--
-- WHAT YOU WILL LEARN:
--   1. Listing and filtering pipes with SHOW PIPES
--   2. Pausing and resuming pipes safely
--   3. Modifying pipe definitions (recreate pattern)
--   4. Handling existing files after pipe recreation
--   5. Monitoring pipe state during transitions
--
-- PIPE LIFECYCLE (CONCEPT GAP FILLED):
--   Create -> Running -> Pause -> Modify -> Resume -> Drop
--
--   CRITICAL: You cannot ALTER the COPY statement inside a pipe.
--   To change the COPY definition, you must:
--     1. PAUSE the pipe
--     2. Wait for pendingFileCount = 0
--     3. CREATE OR REPLACE the pipe with new definition
--     4. REFRESH to process existing files
--     5. RESUME the pipe (or it starts automatically with auto_ingest)
--
-- KEY INTERVIEW CONCEPTS:
--   - SHOW PIPES lists pipes with filters (LIKE, IN DATABASE/SCHEMA)
--   - SYSTEM$PIPE_STATUS() checks state and pending files
--   - ALTER PIPE SET PIPE_EXECUTION_PAUSED = true/false to pause/resume
--   - Always verify pendingFileCount = 0 before modifying a pipe
--   - After recreating, use REFRESH for existing files
-- =============================================================================


-- =============================================
-- STEP 1: Describe and list pipes
-- =============================================

-- Describe a specific pipe (shows definition and notification channel)
DESC PIPE MANAGE_DB.pipes.employee_pipe;

-- List ALL pipes in the account
SHOW PIPES;

-- Filter pipes by name pattern
SHOW PIPES LIKE '%employee%';

-- Filter by database
SHOW PIPES IN DATABASE MANAGE_DB;

-- Filter by schema
SHOW PIPES IN SCHEMA MANAGE_DB.pipes;

-- Combine filters
SHOW PIPES LIKE '%employee%' IN DATABASE MANAGE_DB;


-- =============================================
-- STEP 2: Safely pause a pipe
-- =============================================
-- ALWAYS pause before modifying to avoid data loss or duplicates.

-- Step 2a: Prepare the new target table (before pausing)
CREATE OR REPLACE TABLE OUR_FIRST_DB.PUBLIC.employees2 (
    id         INT,
    first_name STRING,
    last_name  STRING,
    email      STRING,
    location   STRING,
    department STRING
);

-- Step 2b: Pause the pipe
ALTER PIPE MANAGE_DB.pipes.employee_pipe SET PIPE_EXECUTION_PAUSED = TRUE;

-- Step 2c: Verify the pipe is paused AND has no pending files
SELECT SYSTEM$PIPE_STATUS('MANAGE_DB.pipes.employee_pipe');
-- Check: executionState = "PAUSED" and pendingFileCount = 0
-- WAIT until pendingFileCount = 0 before proceeding!

-- INTERVIEW TIP: If you recreate a pipe while files are still pending,
-- those files may be lost (not loaded by old or new pipe).


-- =============================================
-- STEP 3: Recreate pipe with new definition
-- =============================================
-- Change the target table from employees to employees2.

CREATE OR REPLACE PIPE MANAGE_DB.pipes.employee_pipe
    auto_ingest = TRUE
AS
    COPY INTO OUR_FIRST_DB.PUBLIC.employees2
    FROM @MANAGE_DB.external_stages.csv_folder;

-- The pipe is recreated with a new COPY INTO target.
-- With auto_ingest = TRUE, it will start automatically when events arrive.


-- =============================================
-- STEP 4: Handle existing files
-- =============================================
-- REFRESH tells the pipe to scan the stage for any unloaded files.

ALTER PIPE MANAGE_DB.pipes.employee_pipe REFRESH;

-- List files in stage (for reference)
LIST @MANAGE_DB.external_stages.csv_folder;

-- Check if data was loaded
SELECT * FROM OUR_FIRST_DB.PUBLIC.employees2;

-- For files that were already loaded by the OLD pipe definition,
-- they won't be reloaded by REFRESH (Snowpipe tracks them).
-- Use a manual COPY INTO to backfill these files:

COPY INTO OUR_FIRST_DB.PUBLIC.employees2
FROM @MANAGE_DB.external_stages.csv_folder;

-- This manual COPY loads files that REFRESH skipped.


-- =============================================
-- STEP 5: Resume the pipe
-- =============================================
ALTER PIPE MANAGE_DB.pipes.employee_pipe SET PIPE_EXECUTION_PAUSED = FALSE;

-- Verify the pipe is running
SELECT SYSTEM$PIPE_STATUS('MANAGE_DB.pipes.employee_pipe');
-- Check: executionState = "RUNNING"


-- =============================================================================
-- CONCEPT GAP: PIPE MANAGEMENT BEST PRACTICES
-- =============================================================================
-- 1. SAFE MODIFICATION PATTERN:
--    a. PAUSE pipe
--    b. Wait for pendingFileCount = 0
--    c. Recreate pipe (CREATE OR REPLACE)
--    d. REFRESH to queue existing unloaded files
--    e. Manual COPY for files from old pipe definition
--    f. Pipe auto-resumes with auto_ingest = TRUE
--
-- 2. PIPE OWNERSHIP:
--    Pipes are owned by a role. Only the owner (or ACCOUNTADMIN) can:
--    - ALTER, DROP, or REFRESH the pipe
--    GRANT OWNERSHIP ON PIPE my_pipe TO ROLE my_role;
--
-- 3. MONITORING DASHBOARD QUERY:
--    SELECT
--        "name" AS pipe_name,
--        "database_name",
--        "schema_name",
--        "definition",
--        "notification_channel",
--        "is_autoingest_enabled",
--        "owner"
--    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))  -- After SHOW PIPES
--    WHERE "is_autoingest_enabled" = 'YES';
--
-- 4. COST MONITORING:
--    SELECT
--        pipe_name,
--        SUM(credits_used) AS total_credits
--    FROM SNOWFLAKE.ACCOUNT_USAGE.PIPE_USAGE_HISTORY
--    WHERE start_time >= DATEADD(day, -30, CURRENT_TIMESTAMP())
--    GROUP BY pipe_name
--    ORDER BY total_credits DESC;
--
-- 5. SNOWPIPE STREAMING (newer alternative):
--    Snowpipe Streaming uses the Snowflake Ingest SDK to write rows
--    directly (without staging files). It offers:
--    - Sub-second latency (vs ~1 min for file-based Snowpipe)
--    - No cloud storage needed (direct API ingestion)
--    - Lower cost for high-frequency, small-payload ingestion
--    - Works with Kafka Connector for Snowflake
-- =============================================================================
