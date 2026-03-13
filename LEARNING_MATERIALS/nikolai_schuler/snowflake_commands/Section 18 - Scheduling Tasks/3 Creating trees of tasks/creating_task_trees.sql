-- =============================================================================
-- SECTION 18.3: CREATING TREES OF TASKS (DAG / Dependencies)
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to build task dependency trees (DAGs) where child tasks
--   execute only after their parent task completes successfully.
--
-- WHAT YOU WILL LEARN:
--   1. Using AFTER instead of SCHEDULE to create child tasks
--   2. Building multi-step ETL pipelines as task trees
--   3. Resume/suspend order requirements
--   4. How task DAGs work in Snowflake
--
-- TASK TREE STRUCTURE:
-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │                                                                         │
-- │   ┌─────────────────────┐                                               │
-- │   │  CUSTOMER_INSERT    │  ← ROOT TASK (has SCHEDULE)                   │
-- │   │  (inserts new row)  │                                               │
-- │   └─────────┬───────────┘                                               │
-- │             │ AFTER                                                     │
-- │   ┌─────────▼───────────┐                                               │
-- │   │  CUSTOMER_INSERT2   │  ← CHILD TASK (no schedule, uses AFTER)       │
-- │   │  (copies to table2) │                                               │
-- │   └─────────┬───────────┘                                               │
-- │             │ AFTER                                                     │
-- │   ┌─────────▼───────────┐                                               │
-- │   │  CUSTOMER_INSERT3   │  ← GRANDCHILD TASK                            │
-- │   │  (copies to table3) │                                               │
-- │   └─────────────────────┘                                               │
-- │                                                                         │
-- └──────────────────────────────────────────────────────────────────────────┘
--
-- TASK TREE RULES:
-- ┌──────────────────────┬──────────────────────────────────────────────────┐
-- │ Rule                 │ Details                                          │
-- ├──────────────────────┼──────────────────────────────────────────────────┤
-- │ Root task            │ Only the root has a SCHEDULE                     │
-- │ Child tasks          │ Use AFTER <parent> instead of SCHEDULE           │
-- │ Execution order      │ Child runs ONLY after parent succeeds            │
-- │ Parent failure       │ Child tasks are SKIPPED if parent fails          │
-- │ Max tree depth       │ Up to 1000 tasks in a single DAG                │
-- │ Branching            │ A task can have multiple children (fan-out)      │
-- │ Multiple parents     │ A child can depend on multiple parents (fan-in)  │
-- │ Circular deps        │ NOT allowed (must be a DAG)                      │
-- └──────────────────────┴──────────────────────────────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - Only ROOT tasks have a SCHEDULE; children use AFTER
--   - SUSPEND parent before adding/modifying children
--   - Resume order: children FIRST, then root LAST
--   - Suspend order: root FIRST, then children
--   - Task trees enable staged ETL: ingest → transform → aggregate
-- =============================================================================


-- =============================================
-- STEP 1: Verify existing setup
-- =============================================
USE TASK_DB;

SHOW TASKS;
SELECT * FROM CUSTOMERS;


-- =============================================
-- STEP 2: Create target tables for the pipeline
-- =============================================
-- Second table: receives copy of raw data
CREATE OR REPLACE TABLE CUSTOMERS2 (
    CUSTOMER_ID INT,
    FIRST_NAME  VARCHAR(40),
    CREATE_DATE DATE
);

-- Third table: adds an INSERT_DATE audit column
CREATE OR REPLACE TABLE CUSTOMERS3 (
    CUSTOMER_ID INT,
    FIRST_NAME  VARCHAR(40),
    CREATE_DATE DATE,
    INSERT_DATE DATE DEFAULT DATE(CURRENT_TIMESTAMP)
);


-- =============================================
-- STEP 3: Suspend parent before adding children
-- =============================================
-- CRITICAL: You must suspend the root task before creating child tasks!
ALTER TASK CUSTOMER_INSERT SUSPEND;


-- =============================================
-- STEP 4: Create child tasks
-- =============================================
-- Child task 1: copies from CUSTOMERS to CUSTOMERS2
-- Uses AFTER instead of SCHEDULE
CREATE OR REPLACE TASK CUSTOMER_INSERT2
    WAREHOUSE = COMPUTE_WH
    AFTER CUSTOMER_INSERT          -- Runs after parent completes
AS
    INSERT INTO CUSTOMERS2 SELECT * FROM CUSTOMERS;

-- Child task 2: copies from CUSTOMERS2 to CUSTOMERS3
CREATE OR REPLACE TASK CUSTOMER_INSERT3
    WAREHOUSE = COMPUTE_WH
    AFTER CUSTOMER_INSERT2         -- Runs after CUSTOMER_INSERT2 completes
AS
    INSERT INTO CUSTOMERS3 (CUSTOMER_ID, FIRST_NAME, CREATE_DATE)
    SELECT * FROM CUSTOMERS2;


-- =============================================
-- STEP 5: Verify the task tree
-- =============================================
SHOW TASKS;
-- Look at the "predecessors" column to see the dependency chain

-- Optionally update root task schedule
ALTER TASK CUSTOMER_INSERT
SET SCHEDULE = '1 MINUTE';


-- =============================================
-- STEP 6: Resume tasks (CORRECT ORDER)
-- =============================================
-- RESUME ORDER: Children first, root last!
-- If you resume root first, it may run before children are ready.
ALTER TASK CUSTOMER_INSERT3 RESUME;   -- Grandchild first
ALTER TASK CUSTOMER_INSERT2 RESUME;   -- Child second
ALTER TASK CUSTOMER_INSERT RESUME;    -- Root last

-- WHAT HAPPENS EACH MINUTE:
--   1. CUSTOMER_INSERT runs  → Inserts a row into CUSTOMERS
--   2. CUSTOMER_INSERT2 runs → Copies CUSTOMERS → CUSTOMERS2
--   3. CUSTOMER_INSERT3 runs → Copies CUSTOMERS2 → CUSTOMERS3


-- =============================================
-- STEP 7: Verify data flows through the pipeline
-- =============================================
SELECT * FROM CUSTOMERS;
SELECT * FROM CUSTOMERS2;
SELECT * FROM CUSTOMERS3;


-- =============================================
-- STEP 8: Suspend tasks (CORRECT ORDER)
-- =============================================
-- SUSPEND ORDER: Root first, children last!
ALTER TASK CUSTOMER_INSERT SUSPEND;    -- Root first
ALTER TASK CUSTOMER_INSERT2 SUSPEND;   -- Child second
ALTER TASK CUSTOMER_INSERT3 SUSPEND;   -- Grandchild last


-- =============================================================================
-- CONCEPT GAP: FAN-OUT AND FAN-IN PATTERNS
-- =============================================================================
-- FAN-OUT (one parent, multiple children):
--   TASK_ROOT (SCHEDULE = '5 MINUTE')
--     ├── TASK_CHILD_A (AFTER TASK_ROOT)
--     ├── TASK_CHILD_B (AFTER TASK_ROOT)
--     └── TASK_CHILD_C (AFTER TASK_ROOT)
--   → A, B, C all run in parallel after ROOT completes
--
-- FAN-IN (multiple parents, one child):
--   TASK_A and TASK_B (both have AFTER ROOT)
--     └── TASK_FINAL (AFTER TASK_A, TASK_B)  -- waits for BOTH
--   → TASK_FINAL runs only after BOTH A and B complete
--
-- EXAMPLE:
--   CREATE TASK final_aggregation
--     WAREHOUSE = COMPUTE_WH
--     AFTER task_transform_orders, task_transform_customers
--   AS
--     INSERT INTO final_report SELECT ...;
-- =============================================================================
