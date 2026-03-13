-- =============================================================================
-- SECTION 7.52: CLUSTERING KEYS (Performance Optimization)
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how clustering keys improve query performance by controlling
--   the physical ordering of data in micro-partitions for better pruning.
--
-- WHAT YOU WILL LEARN:
--   1. What clustering is and how micro-partitions work
--   2. Adding and changing cluster keys on tables
--   3. Clustering on expressions (e.g., MONTH(date))
--   4. Monitoring clustering quality
--
-- MICRO-PARTITIONS AND CLUSTERING (CONCEPT GAP FILLED):
--   Snowflake stores data in micro-partitions (~16 MB compressed each).
--   Each micro-partition records MIN/MAX values for each column.
--   When you filter with WHERE, Snowflake PRUNES (skips) micro-partitions
--   where the filter value falls outside the MIN/MAX range.
--
--   WITHOUT clustering: Data is randomly distributed across micro-partitions.
--     -> A WHERE clause scans most/all partitions (no pruning).
--   WITH clustering: Data is physically sorted by the cluster key.
--     -> A WHERE clause prunes most partitions (fast queries).
--
-- WHEN TO USE CLUSTERING (CRITICAL INTERVIEW KNOWLEDGE):
--   USE clustering when:
--   - Table is LARGE (multi-TB, billions of rows)
--   - Queries frequently filter on specific columns (WHERE, JOIN)
--   - Query performance is degrading over time (natural clustering is lost)
--
--   DON'T USE clustering when:
--   - Table is small (< 1 TB, Snowflake handles this well naturally)
--   - Queries don't filter on predictable columns
--   - Table has very few writes (natural clustering is maintained)
--
-- KEY INTERVIEW CONCEPTS:
--   - CLUSTER BY defines the clustering key for micro-partition ordering
--   - SYSTEM$CLUSTERING_INFORMATION shows clustering depth and overlap
--   - Snowflake auto-reclusters in the background (Automatic Clustering)
--   - Clustering has maintenance costs (credits for re-clustering service)
--   - Choose columns frequently used in WHERE/JOIN conditions
-- =============================================================================


-- =============================================
-- STEP 1: Setup - Create stage and load data
-- =============================================

CREATE OR REPLACE STAGE MANAGE_DB.external_stages.aws_stage
    url = 's3://bucketsnowflakes3';

LIST @MANAGE_DB.external_stages.aws_stage;

-- Load base data
COPY INTO OUR_FIRST_DB.PUBLIC.ORDERS
    FROM @MANAGE_DB.external_stages.aws_stage
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    pattern = '.*OrderDetails.*';


-- =============================================
-- STEP 2: Create a large table for testing
-- =============================================
-- Use CROSS JOIN to multiply rows into a large dataset.
-- Add a random DATE column to simulate real-world date-partitioned data.

CREATE OR REPLACE TABLE ORDERS_CACHING (
    ORDER_ID    VARCHAR(30),
    AMOUNT      NUMBER(38,0),
    PROFIT      NUMBER(38,0),
    QUANTITY    NUMBER(38,0),
    CATEGORY    VARCHAR(30),
    SUBCATEGORY VARCHAR(30),
    DATE        DATE
);

INSERT INTO ORDERS_CACHING
SELECT
    t1.ORDER_ID,
    t1.AMOUNT,
    t1.PROFIT,
    t1.QUANTITY,
    t1.CATEGORY,
    t1.SUBCATEGORY,
    DATE(UNIFORM(1500000000, 1700000000, (RANDOM())))  -- Random date between 2017-2023
FROM ORDERS t1
CROSS JOIN (SELECT * FROM ORDERS) t2
CROSS JOIN (SELECT TOP 100 * FROM ORDERS) t3;

-- This creates millions of rows with random dates across micro-partitions.


-- =============================================
-- STEP 3: Query BEFORE adding cluster key
-- =============================================
-- Without a cluster key, the DATE values are randomly distributed.
-- A date filter must scan many/all micro-partitions.

SELECT * FROM ORDERS_CACHING WHERE DATE = '2020-06-09';

-- Check the Query Profile:
--   "Partitions scanned" will be high relative to "Partitions total"
--   This means poor pruning efficiency.


-- =============================================
-- STEP 4: Add a cluster key and compare
-- =============================================
-- Cluster by DATE so micro-partitions are organized by date ranges.

ALTER TABLE ORDERS_CACHING CLUSTER BY (DATE);

-- After clustering, Snowflake's Automatic Clustering service will
-- reorganize micro-partitions in the background. This takes time.

-- Query again with a date filter
SELECT * FROM ORDERS_CACHING WHERE DATE = '2020-01-05';

-- Check the Query Profile:
--   "Partitions scanned" should be MUCH lower (better pruning).

-- MONITOR CLUSTERING QUALITY:
-- SELECT SYSTEM$CLUSTERING_INFORMATION('ORDERS_CACHING');
-- Returns: cluster_by_keys, total_partition_count, average_depth,
--          average_overlap, total_constant_partition_count

-- CLUSTERING METRICS EXPLAINED:
--   average_depth:   Lower is better (1.0 = perfectly clustered)
--   average_overlap: Lower is better (0.0 = no overlap between partitions)
--   total_constant_partition_count: Partitions with single cluster key value


-- =============================================
-- STEP 5: Cluster by expression
-- =============================================
-- If queries typically filter by MONTH (not exact date),
-- clustering by MONTH(DATE) is more effective.

-- This query filters by month - current clustering by DATE may not be optimal
SELECT * FROM ORDERS_CACHING WHERE MONTH(DATE) = 11;

-- Change cluster key to MONTH expression
ALTER TABLE ORDERS_CACHING CLUSTER BY (MONTH(DATE));

-- Now micro-partitions are grouped by month, improving pruning
-- for MONTH-based filters.


-- =============================================================================
-- CONCEPT GAP: CLUSTERING KEY BEST PRACTICES
-- =============================================================================
-- 1. COLUMN SELECTION (order matters!):
--    - Put the most selective column FIRST in the cluster key
--    - Maximum of 3-4 columns recommended
--    - Common patterns:
--      CLUSTER BY (date_column)                      -- Time-series data
--      CLUSTER BY (date_column, category_column)     -- Time + category
--      CLUSTER BY (region, date_column)              -- Multi-tenant + time
--
-- 2. EXPRESSION-BASED CLUSTERING:
--    - CLUSTER BY (MONTH(date))       -- When filtering by month
--    - CLUSTER BY (YEAR(date))        -- When filtering by year
--    - CLUSTER BY (TO_DATE(timestamp))-- When filtering dates from timestamps
--
-- 3. COST AWARENESS:
--    - Automatic Clustering runs in the background and costs credits
--    - High-churn tables (frequent DML) incur more re-clustering costs
--    - Monitor with:
--      SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.AUTOMATIC_CLUSTERING_HISTORY
--      WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP());
--
-- 4. REMOVING CLUSTER KEYS:
--    ALTER TABLE my_table DROP CLUSTERING KEY;
--    -- Stops re-clustering costs, data stays as-is (gradually degrades)
--
-- 5. SEARCH OPTIMIZATION SERVICE (Alternative/Complement):
--    ALTER TABLE my_table ADD SEARCH OPTIMIZATION ON EQUALITY(col1, col2);
--    -- Builds a search access path for point lookups (WHERE col = value)
--    -- Complements clustering for equality predicates
--
-- INTERVIEW TIP: "When would you NOT use clustering?"
--   - Small tables (under 1 TB) - natural clustering is usually sufficient
--   - Tables with heavy DML - re-clustering costs may outweigh benefits
--   - Queries that don't filter on predictable columns
-- =============================================================================
