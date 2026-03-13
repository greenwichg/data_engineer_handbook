-- =============================================================================
-- SECTION 18.1: CREATING TASKS IN SNOWFLAKE
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to create, schedule, resume, and suspend Snowflake tasks
--   for automated SQL execution on a defined interval.
--
-- WHAT YOU WILL LEARN:
--   1. Creating tasks with CREATE TASK and a SCHEDULE
--   2. Tasks start SUSPENDED — must be explicitly resumed
--   3. AUTOINCREMENT columns with scheduled inserts
--   4. Managing task state with ALTER TASK RESUME/SUSPEND
--
-- TASKS OVERVIEW (CRITICAL INTERVIEW TOPIC):
-- ┌──────────────────────┬──────────────────────────────────────────────────┐
-- │ Feature              │ Details                                          │
-- ├──────────────────────┼──────────────────────────────────────────────────┤
-- │ Purpose              │ Schedule SQL execution (like a cron job)         │
-- │ Compute              │ Uses a specified warehouse (or serverless)       │
-- │ Default state        │ SUSPENDED (must resume to start)                 │
-- │ Schedule types       │ Simple interval (n MINUTE) or CRON expression   │
-- │ SQL supported        │ Single SQL statement, CALL procedure, or        │
-- │                      │ Snowflake Scripting block                        │
-- │ Dependencies         │ Can chain tasks with AFTER clause (DAGs)        │
-- │ Conditional exec     │ WHEN clause (e.g., SYSTEM$STREAM_HAS_DATA)     │
-- └──────────────────────┴──────────────────────────────────────────────────┘
--
-- TASKS vs EXTERNAL SCHEDULERS:
-- ┌──────────────────────┬──────────────────────┬──────────────────────────┐
-- │ Aspect               │ Snowflake Tasks      │ External (Airflow, etc.) │
-- ├──────────────────────┼──────────────────────┼──────────────────────────┤
-- │ Setup                │ SQL only             │ Separate infrastructure  │
-- │ Dependencies         │ AFTER clause (DAGs)  │ Full DAG support         │
-- │ Complex logic        │ Limited (single stmt)│ Unlimited (Python, etc.) │
-- │ Monitoring           │ TASK_HISTORY()       │ Built-in UI              │
-- │ Error handling       │ Basic (retry, email) │ Advanced (callbacks)     │
-- │ Cross-system         │ Snowflake only       │ Multi-system orchestration│
-- │ Cost                 │ Included in compute  │ Separate compute cost    │
-- └──────────────────────┴──────────────────────┴──────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - Tasks are ALWAYS created in SUSPENDED state — must ALTER TASK RESUME
--   - Simple schedule: SCHEDULE = 'n MINUTE' (interval-based)
--   - Tasks consume credits only when executing via the assigned warehouse
--   - SHOW TASKS displays all tasks and their current state
--   - A task executes a SINGLE SQL statement (use procedures for complex logic)
-- =============================================================================


-- =============================================
-- STEP 1: Create database and target table
-- =============================================
CREATE OR REPLACE TRANSIENT DATABASE TASK_DB;

-- AUTOINCREMENT generates surrogate keys automatically
CREATE OR REPLACE TABLE CUSTOMERS (
    CUSTOMER_ID INT AUTOINCREMENT START = 1 INCREMENT = 1,
    FIRST_NAME  VARCHAR(40) DEFAULT 'JENNIFER',
    CREATE_DATE DATE
);

-- AUTOINCREMENT EXPLAINED:
--   START = 1      → First value is 1
--   INCREMENT = 1  → Each new row gets previous + 1
--   No need to specify CUSTOMER_ID in INSERT — it auto-fills


-- =============================================
-- STEP 2: Create a task
-- =============================================
CREATE OR REPLACE TASK CUSTOMER_INSERT
    WAREHOUSE = COMPUTE_WH
    SCHEDULE  = '1 MINUTE'
AS
    INSERT INTO CUSTOMERS(CREATE_DATE) VALUES(CURRENT_TIMESTAMP);

-- TASK ANATOMY:
--   WAREHOUSE = <name>    → Which warehouse executes the SQL
--   SCHEDULE = 'n MINUTE' → Run every n minutes
--   AS <sql_statement>    → The SQL to execute each run

-- View the task (it starts SUSPENDED!)
SHOW TASKS;
-- state = 'suspended' — it will NOT run until resumed


-- =============================================
-- STEP 3: Resume and suspend the task
-- =============================================
-- Start the task (it will begin executing on schedule)
ALTER TASK CUSTOMER_INSERT RESUME;

-- After some time, check the results
SELECT * FROM CUSTOMERS;
-- You should see rows being added every minute

-- Stop the task
ALTER TASK CUSTOMER_INSERT SUSPEND;


-- =============================================================================
-- CONCEPT GAP: TASK EXECUTION TIMING
-- =============================================================================
-- SCHEDULE = '1 MINUTE' means:
--   - The task runs approximately every 1 minute
--   - The first run starts ~1 minute after RESUME
--   - If a run takes longer than the interval, the next run is SKIPPED
--   - The interval is measured from the START of the previous run
--
-- MINIMUM INTERVAL: 1 minute
-- MAXIMUM INTERVAL: 11520 minutes (8 days)
--
-- For more precise scheduling (e.g., daily at 6 AM), use CRON (see 18.2).
-- =============================================================================


-- =============================================================================
-- CONCEPT GAP: SERVERLESS TASKS (NO WAREHOUSE NEEDED)
-- =============================================================================
-- Instead of specifying a warehouse, you can use serverless compute:
--
--   CREATE TASK my_task
--     USER_TASK_MANAGED_INITIAL_WAREHOUSE_SIZE = 'XSMALL'
--     SCHEDULE = '5 MINUTE'
--   AS
--     INSERT INTO my_table VALUES (CURRENT_TIMESTAMP);
--
-- SERVERLESS ADVANTAGES:
--   - No need to manage warehouse sizing or auto-suspend
--   - Snowflake automatically scales compute to fit the workload
--   - Ideal for lightweight, frequent tasks
--
-- SERVERLESS DISADVANTAGES:
--   - Slightly higher per-credit cost than dedicated warehouses
--   - Less control over compute resources
-- =============================================================================
