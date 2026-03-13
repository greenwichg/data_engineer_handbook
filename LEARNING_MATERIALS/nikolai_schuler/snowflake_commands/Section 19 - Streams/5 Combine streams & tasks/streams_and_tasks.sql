-- =============================================================================
-- SECTION 19.5: COMBINING STREAMS AND TASKS FOR AUTOMATION
-- =============================================================================
--
-- OBJECTIVE:
--   Build fully automated, incremental data pipelines by combining streams
--   with tasks and the SYSTEM$STREAM_HAS_DATA() function.
--
-- WHAT YOU WILL LEARN:
--   1. Using SYSTEM$STREAM_HAS_DATA() in the WHEN clause
--   2. Building the complete automated CDC pipeline
--   3. Verifying execution with TASK_HISTORY()
--
-- THE AUTOMATED CDC PIPELINE (CRITICAL INTERVIEW TOPIC):
-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │                                                                         │
-- │   ┌──────────┐   DML    ┌──────────┐   WHEN has_data   ┌──────────┐   │
-- │   │ Source   │────────>│  Stream  │──────────────────>│   Task   │   │
-- │   │ Table    │         │ (tracks) │                   │ (MERGE)  │   │
-- │   └──────────┘         └──────────┘                   └────┬─────┘   │
-- │                                                            │          │
-- │                                                     ┌──────▼──────┐   │
-- │                                                     │  Target     │   │
-- │                                                     │  Table      │   │
-- │                                                     └─────────────┘   │
-- │                                                                         │
-- │   WHEN SYSTEM$STREAM_HAS_DATA('stream'):                                │
-- │     TRUE  → Task executes (MERGE from stream)                          │
-- │     FALSE → Task SKIPS (no warehouse started = no cost!)               │
-- └──────────────────────────────────────────────────────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - SYSTEM$STREAM_HAS_DATA() prevents unnecessary task execution
--   - The WHEN clause is evaluated BEFORE the warehouse starts (zero cost if FALSE)
--   - This is Snowflake's native approach to automated incremental ELT
--   - Replaces traditional ETL tools for many use cases
--   - Stream + Task + MERGE = the "Snowflake CDC trifecta"
-- =============================================================================


-- =============================================
-- STEP 1: Create the automated task
-- =============================================
CREATE OR REPLACE TASK all_data_changes
    WAREHOUSE = COMPUTE_WH
    SCHEDULE  = '1 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('SALES_STREAM')  -- Only run if stream has data!
AS
MERGE INTO SALES_FINAL_TABLE F
USING (
    SELECT STRE.*, ST.location, ST.employees
    FROM SALES_STREAM STRE
    JOIN STORE_TABLE ST ON STRE.store_id = ST.store_id
) S
ON F.id = S.id
WHEN MATCHED
    AND S.METADATA$ACTION = 'DELETE'
    AND S.METADATA$ISUPDATE = 'FALSE'
    THEN DELETE
WHEN MATCHED
    AND S.METADATA$ACTION = 'INSERT'
    AND S.METADATA$ISUPDATE = 'TRUE'
    THEN UPDATE
    SET F.product  = S.product,
        F.price    = S.price,
        F.amount   = S.amount,
        F.store_id = S.store_id
WHEN NOT MATCHED
    AND S.METADATA$ACTION = 'INSERT'
    THEN INSERT (id, product, price, store_id, amount, employees, location)
    VALUES (S.id, S.product, S.price, S.store_id, S.amount, S.employees, S.location);

-- Resume the task
ALTER TASK all_data_changes RESUME;
SHOW TASKS;


-- =============================================
-- STEP 2: Make changes to the source table
-- =============================================
-- These changes will be automatically propagated by the task!
INSERT INTO SALES_RAW_STAGING VALUES (11, 'Milk', 1.99, 1, 2);
INSERT INTO SALES_RAW_STAGING VALUES (12, 'Chocolate', 4.49, 1, 2);
INSERT INTO SALES_RAW_STAGING VALUES (13, 'Cheese', 3.89, 1, 1);

UPDATE SALES_RAW_STAGING
SET PRODUCT = 'Chocolate bar'
WHERE PRODUCT = 'Chocolate';

DELETE FROM SALES_RAW_STAGING
WHERE PRODUCT = 'Mango';


-- =============================================
-- STEP 3: Verify automatic processing
-- =============================================
-- Wait ~1-2 minutes for the task to execute, then check:
SELECT * FROM SALES_RAW_STAGING;
SELECT * FROM SALES_STREAM;           -- Should be empty (consumed by task)
SELECT * FROM SALES_FINAL_TABLE;      -- Should reflect all changes


-- =============================================
-- STEP 4: Verify with task history
-- =============================================
SELECT *
FROM TABLE(information_schema.task_history())
ORDER BY name ASC, scheduled_time DESC;

-- Look for:
--   STATE = 'SUCCEEDED' → Task ran and processed changes
--   STATE = 'SKIPPED'   → Task skipped because stream was empty (saves cost!)


-- =============================================================================
-- CONCEPT GAP: COST OPTIMIZATION WITH WHEN CLAUSE
-- =============================================================================
-- WITHOUT WHEN clause:
--   Task starts warehouse every minute → ~$0.07/min for XS warehouse
--   30 days × 24 hours × 60 min = 43,200 executions
--   Even if no data changed, you still pay for warehouse startup
--
-- WITH WHEN SYSTEM$STREAM_HAS_DATA():
--   Warehouse ONLY starts when there's data to process
--   If data changes 10 times/day: 300 executions/month (99.3% savings!)
--
-- The WHEN clause is evaluated by Snowflake's cloud services layer
-- (always running), NOT by the warehouse. So checking is FREE.
-- =============================================================================


-- =============================================================================
-- CONCEPT GAP: COMPLETE CDC PIPELINE ARCHITECTURE
-- =============================================================================
-- PRODUCTION PIPELINE PATTERN:
--
-- 1. DATA INGESTION (Snowpipe or COPY INTO):
--    Files arrive in S3 → Snowpipe loads into staging_table
--
-- 2. CHANGE TRACKING (Stream):
--    CREATE STREAM staging_stream ON TABLE staging_table;
--
-- 3. AUTOMATED PROCESSING (Task + MERGE):
--    CREATE TASK process_changes
--      SCHEDULE = '5 MINUTE'
--      WHEN SYSTEM$STREAM_HAS_DATA('staging_stream')
--    AS MERGE INTO production_table ...
--
-- 4. MONITORING (Task History):
--    SELECT * FROM TABLE(information_schema.task_history())
--    WHERE STATE = 'FAILED';
--
-- This gives you a fully automated, incremental, near-real-time
-- data pipeline with ZERO external tools — all within Snowflake.
-- =============================================================================
