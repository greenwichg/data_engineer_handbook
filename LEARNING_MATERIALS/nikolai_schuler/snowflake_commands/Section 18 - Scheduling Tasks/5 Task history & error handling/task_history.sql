-- =============================================================================
-- SECTION 18.5: TASK HISTORY AND ERROR HANDLING
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to monitor task execution history, filter by task name
--   and time range, and debug failed pipeline runs.
--
-- WHAT YOU WILL LEARN:
--   1. Using TASK_HISTORY() table function to view execution history
--   2. Filtering by task name, time range, and result limit
--   3. Understanding task execution states
--   4. Building monitoring queries for pipeline health
--
-- TASK EXECUTION STATES:
-- ┌──────────────────────┬──────────────────────────────────────────────────┐
-- │ State                │ Meaning                                          │
-- ├──────────────────────┼──────────────────────────────────────────────────┤
-- │ SUCCEEDED            │ Task completed successfully                      │
-- │ FAILED               │ Task encountered an error                        │
-- │ SKIPPED              │ Task skipped (WHEN condition was FALSE, or       │
-- │                      │ previous run still executing)                    │
-- │ CANCELLED            │ Task was cancelled (e.g., warehouse suspended)   │
-- └──────────────────────┴──────────────────────────────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - TASK_HISTORY() is in INFORMATION_SCHEMA (database-scoped)
--   - SNOWFLAKE.ACCOUNT_USAGE.TASK_HISTORY is account-scoped (with latency)
--   - Filter by task_name, scheduled_time_range, and result_limit
--   - DATEADD is useful for looking back N hours
--   - Monitor FAILED and SKIPPED states for pipeline health
-- =============================================================================


-- =============================================
-- STEP 1: View all task history
-- =============================================
SHOW TASKS;

USE DEMO_DB;

-- Query all task history, most recent first
SELECT *
FROM TABLE(information_schema.task_history())
ORDER BY scheduled_time DESC;

-- KEY COLUMNS:
--   NAME             = Task name
--   STATE            = SUCCEEDED, FAILED, SKIPPED, CANCELLED
--   SCHEDULED_TIME   = When the task was scheduled to run
--   COMPLETED_TIME   = When the task finished
--   ERROR_CODE       = Error code if FAILED
--   ERROR_MESSAGE    = Error description if FAILED
--   QUERY_ID         = ID of the SQL query executed by the task


-- =============================================
-- STEP 2: Filter by task name and time range
-- =============================================
-- View last 5 runs of a specific task in the past 4 hours
SELECT *
FROM TABLE(information_schema.task_history(
    scheduled_time_range_start => DATEADD('hour', -4, CURRENT_TIMESTAMP()),
    result_limit               => 5,
    task_name                  => 'CUSTOMER_INSERT2'
));


-- =============================================
-- STEP 3: Filter by specific time window
-- =============================================
-- Query history for a precise time period
SELECT *
FROM TABLE(information_schema.task_history(
    scheduled_time_range_start => TO_TIMESTAMP_LTZ('2021-04-22 11:28:32.776 -0700'),
    scheduled_time_range_end   => TO_TIMESTAMP_LTZ('2021-04-22 11:35:32.776 -0700')
));

-- Get the current timestamp for reference
SELECT TO_TIMESTAMP_LTZ(CURRENT_TIMESTAMP);


-- =============================================
-- STEP 4: Monitoring query — failed tasks
-- =============================================
-- Find all failed tasks in the past 24 hours
SELECT
    NAME,
    STATE,
    SCHEDULED_TIME,
    ERROR_CODE,
    ERROR_MESSAGE,
    QUERY_ID
FROM TABLE(information_schema.task_history(
    scheduled_time_range_start => DATEADD('hour', -24, CURRENT_TIMESTAMP())
))
WHERE STATE = 'FAILED'
ORDER BY SCHEDULED_TIME DESC;


-- =============================================
-- STEP 5: Pipeline health dashboard query
-- =============================================
-- Summary of task execution by state in the past 24 hours
SELECT
    NAME,
    STATE,
    COUNT(*) AS EXECUTION_COUNT,
    MIN(SCHEDULED_TIME) AS FIRST_RUN,
    MAX(SCHEDULED_TIME) AS LAST_RUN,
    AVG(DATEDIFF('second', SCHEDULED_TIME, COMPLETED_TIME)) AS AVG_DURATION_SEC
FROM TABLE(information_schema.task_history(
    scheduled_time_range_start => DATEADD('hour', -24, CURRENT_TIMESTAMP())
))
GROUP BY NAME, STATE
ORDER BY NAME, STATE;


-- =============================================================================
-- CONCEPT GAP: TASK_HISTORY LOCATIONS
-- =============================================================================
-- ┌────────────────────────────────────────┬───────────────────────────────────┐
-- │ Source                                 │ Details                           │
-- ├────────────────────────────────────────┼───────────────────────────────────┤
-- │ information_schema.task_history()      │ Current database only             │
-- │                                        │ Real-time (no latency)            │
-- │                                        │ Last 7 days of history            │
-- ├────────────────────────────────────────┼───────────────────────────────────┤
-- │ SNOWFLAKE.ACCOUNT_USAGE.TASK_HISTORY   │ All databases in account          │
-- │                                        │ Up to 45-minute latency           │
-- │                                        │ Last 365 days of history          │
-- └────────────────────────────────────────┴───────────────────────────────────┘
-- =============================================================================


-- =============================================================================
-- CONCEPT GAP: ERROR HANDLING AND ALERTING
-- =============================================================================
-- OPTION 1: Email notifications (built-in)
--   ALTER TASK my_task SET
--     ERROR_INTEGRATION = my_notification_integration;
--   → Sends email alerts when a task fails
--
-- OPTION 2: Monitoring task that checks for failures
--   CREATE TASK monitor_failures
--     SCHEDULE = '30 MINUTE'
--   AS
--     CALL check_and_alert_on_failures();
--   → Custom procedure that queries TASK_HISTORY and sends alerts
--
-- OPTION 3: Task retry
--   Tasks do NOT automatically retry on failure.
--   Implement retry logic inside stored procedures:
--     BEGIN
--       -- attempt operation
--     EXCEPTION
--       WHEN OTHER THEN
--         -- log error, optionally retry
--     END;
-- =============================================================================
