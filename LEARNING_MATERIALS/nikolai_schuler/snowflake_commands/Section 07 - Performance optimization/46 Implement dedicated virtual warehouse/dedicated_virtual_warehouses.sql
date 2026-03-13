-- =============================================================================
-- SECTION 7.46: DEDICATED VIRTUAL WAREHOUSES (Workload Isolation)
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to isolate workloads by creating separate virtual warehouses
--   for different teams, preventing resource contention and enabling
--   independent scaling and cost tracking.
--
-- WHAT YOU WILL LEARN:
--   1. Creating warehouses with appropriate sizing for each team
--   2. Configuring AUTO_SUSPEND and AUTO_RESUME for cost control
--   3. Creating roles and granting warehouse access (RBAC)
--   4. Creating users and assigning roles with default warehouses
--
-- WHY DEDICATED WAREHOUSES?
--   - Workload isolation: Data scientists' heavy queries don't slow down DBAs
--   - Independent scaling: Size each warehouse for its specific workload
--   - Cost attribution: Track credits per team/department separately
--   - Concurrency control: Each warehouse has its own query queue
--
-- WAREHOUSE SIZES AND CREDITS (CONCEPT GAP FILLED):
-- ┌─────────────┬──────────┬────────────────────┬───────────────────────┐
-- │ Size        │ Credits/ │ Nodes              │ Best For              │
-- │             │ Hour     │                    │                       │
-- ├─────────────┼──────────┼────────────────────┼───────────────────────┤
-- │ X-Small     │ 1        │ 1                  │ Light queries, dev    │
-- │ Small       │ 2        │ 2                  │ Standard analytics    │
-- │ Medium      │ 4        │ 4                  │ Medium ETL jobs       │
-- │ Large       │ 8        │ 8                  │ Large ETL, complex    │
-- │ X-Large     │ 16       │ 16                 │ Heavy processing      │
-- │ 2X-Large    │ 32       │ 32                 │ Very heavy processing │
-- │ 3X-Large    │ 64       │ 64                 │ Massive workloads     │
-- │ 4X-Large    │ 128      │ 128                │ Extreme workloads     │
-- │ 5X-Large    │ 256      │ 256                │ Maximum performance   │
-- │ 6X-Large    │ 512      │ 512                │ Largest available     │
-- └─────────────┴──────────┴────────────────────┴───────────────────────┘
--   NOTE: Each size doubles the compute power AND cost of the previous size.
--
-- KEY INTERVIEW CONCEPTS:
--   - Warehouse sizing (XSMALL to 6XLARGE) based on workload needs
--   - AUTO_SUSPEND / AUTO_RESUME for cost control
--   - RBAC: granting warehouse USAGE to roles, assigning roles to users
--   - Each warehouse is an independent compute cluster with its own billing
--   - Scaling UP (bigger warehouse) for complex/slow queries
--   - Scaling OUT (more clusters) for high concurrency (covered in next section)
-- =============================================================================


-- =============================================
-- STEP 1: Create dedicated warehouses
-- =============================================

-- Warehouse for Data Scientists: SMALL size for analytics/ML workloads
CREATE WAREHOUSE DS_WH
WITH
    WAREHOUSE_SIZE     = 'SMALL'       -- 2 credits/hour when active
    WAREHOUSE_TYPE     = 'STANDARD'    -- Standard (vs Snowpark-optimized)
    AUTO_SUSPEND       = 300           -- Suspend after 5 minutes of inactivity
    AUTO_RESUME        = TRUE          -- Auto-start when a query arrives
    MIN_CLUSTER_COUNT  = 1             -- Minimum clusters (multi-cluster WH)
    MAX_CLUSTER_COUNT  = 1             -- Maximum clusters (single cluster)
    SCALING_POLICY     = 'STANDARD';   -- Scaling policy for multi-cluster

-- Warehouse for DBAs: X-SMALL size for admin/monitoring tasks
CREATE WAREHOUSE DBA_WH
WITH
    WAREHOUSE_SIZE     = 'XSMALL'      -- 1 credit/hour (cheapest option)
    WAREHOUSE_TYPE     = 'STANDARD'
    AUTO_SUSPEND       = 300           -- 5 minutes idle timeout
    AUTO_RESUME        = TRUE
    MIN_CLUSTER_COUNT  = 1
    MAX_CLUSTER_COUNT  = 1
    SCALING_POLICY     = 'STANDARD';

-- INTERVIEW TIP: AUTO_SUSPEND is in SECONDS, not minutes.
--   60   = 1 minute  (aggressive, saves cost, but cold start on resume)
--   300  = 5 minutes (good default balance)
--   3600 = 1 hour    (keeps cache warm, costs more)
--   0    = Never suspend (only for 24/7 workloads)

-- CONCEPT GAP FILLED - AUTO_SUSPEND TRADE-OFFS:
--   Low AUTO_SUSPEND (60s):
--     + Saves credits when warehouse is idle
--     - Loses local disk cache on suspend (cold start on resume)
--   High AUTO_SUSPEND (3600s):
--     + Keeps local disk cache warm (faster subsequent queries)
--     - Costs credits even when idle
--   BEST PRACTICE: 300s for interactive, 60s for batch/ETL warehouses


-- =============================================
-- STEP 2: Create roles and grant warehouse access
-- =============================================

-- Create functional roles
CREATE ROLE DATA_SCIENTIST;
GRANT USAGE ON WAREHOUSE DS_WH TO ROLE DATA_SCIENTIST;

CREATE ROLE DBA;
GRANT USAGE ON WAREHOUSE DBA_WH TO ROLE DBA;

-- GRANT USAGE allows the role to USE the warehouse (run queries on it).
-- Without this grant, users with the role cannot execute queries.

-- CONCEPT GAP FILLED - WAREHOUSE PRIVILEGES:
--   USAGE    - Run queries on the warehouse
--   OPERATE  - Start, stop, suspend, resume the warehouse
--   MONITOR  - View warehouse usage and performance metrics
--   MODIFY   - Change warehouse properties (size, auto_suspend, etc.)
--   ALL      - All of the above


-- =============================================
-- STEP 3: Create users and assign roles
-- =============================================

-- Data Scientists
CREATE USER DS1 PASSWORD = 'DS1' LOGIN_NAME = 'DS1'
    DEFAULT_ROLE      = 'DATA_SCIENTIST'
    DEFAULT_WAREHOUSE = 'DS_WH'
    MUST_CHANGE_PASSWORD = FALSE;

CREATE USER DS2 PASSWORD = 'DS2' LOGIN_NAME = 'DS2'
    DEFAULT_ROLE      = 'DATA_SCIENTIST'
    DEFAULT_WAREHOUSE = 'DS_WH'
    MUST_CHANGE_PASSWORD = FALSE;

CREATE USER DS3 PASSWORD = 'DS3' LOGIN_NAME = 'DS3'
    DEFAULT_ROLE      = 'DATA_SCIENTIST'
    DEFAULT_WAREHOUSE = 'DS_WH'
    MUST_CHANGE_PASSWORD = FALSE;

-- Grant role to users (users can now assume this role)
GRANT ROLE DATA_SCIENTIST TO USER DS1;
GRANT ROLE DATA_SCIENTIST TO USER DS2;
GRANT ROLE DATA_SCIENTIST TO USER DS3;

-- DBAs
CREATE USER DBA1 PASSWORD = 'DBA1' LOGIN_NAME = 'DBA1'
    DEFAULT_ROLE      = 'DBA'
    DEFAULT_WAREHOUSE = 'DBA_WH'
    MUST_CHANGE_PASSWORD = FALSE;

CREATE USER DBA2 PASSWORD = 'DBA2' LOGIN_NAME = 'DBA2'
    DEFAULT_ROLE      = 'DBA'
    DEFAULT_WAREHOUSE = 'DBA_WH'
    MUST_CHANGE_PASSWORD = FALSE;

GRANT ROLE DBA TO USER DBA1;
GRANT ROLE DBA TO USER DBA2;

-- SECURITY NOTE: In production, NEVER use simple passwords like these.
-- Use MUST_CHANGE_PASSWORD = TRUE and enforce MFA.


-- =============================================
-- CLEANUP: Drop all created objects
-- =============================================
DROP USER DBA1;
DROP USER DBA2;
DROP USER DS1;
DROP USER DS2;
DROP USER DS3;

DROP ROLE DATA_SCIENTIST;
DROP ROLE DBA;

DROP WAREHOUSE DS_WH;
DROP WAREHOUSE DBA_WH;


-- =============================================================================
-- CONCEPT GAP: WAREHOUSE BEST PRACTICES FOR INTERVIEWS
-- =============================================================================
-- 1. T-SHIRT SIZING STRATEGY:
--    Start SMALL, monitor with QUERY_HISTORY, scale up only if needed.
--    Doubling warehouse size halves query time (roughly) but doubles cost.
--
-- 2. WORKLOAD-BASED WAREHOUSES:
--    - ETL warehouse: Medium/Large, AUTO_SUSPEND=60, batch-optimized
--    - BI/Dashboard warehouse: Small, AUTO_SUSPEND=300, many concurrent users
--    - Data Science warehouse: Large, AUTO_SUSPEND=300, complex queries
--    - Admin warehouse: X-Small, AUTO_SUSPEND=300, monitoring tasks
--
-- 3. RESOURCE MONITORS (cost guardrails):
--    CREATE RESOURCE MONITOR my_monitor
--        WITH CREDIT_QUOTA = 1000
--        TRIGGERS ON 75 PERCENT DO NOTIFY
--                 ON 100 PERCENT DO SUSPEND;
--    ALTER WAREHOUSE DS_WH SET RESOURCE_MONITOR = my_monitor;
--
-- 4. WAREHOUSE TYPES:
--    STANDARD           - General purpose (default)
--    SNOWPARK-OPTIMIZED - Extra memory for Snowpark/UDF workloads (16x memory)
-- =============================================================================
