-- =============================================================================
-- SECTION 7.50: MAXIMIZING CACHING IN SNOWFLAKE
-- =============================================================================
--
-- OBJECTIVE:
--   Understand Snowflake's three caching layers and how to leverage them
--   for optimal query performance and cost reduction.
--
-- WHAT YOU WILL LEARN:
--   1. Three types of caching in Snowflake
--   2. How each cache works and when it's used
--   3. How to disable result caching for testing
--   4. Cache invalidation triggers
--
-- SNOWFLAKE'S THREE CACHING LAYERS (CRITICAL INTERVIEW TOPIC):
-- ┌──────────────────────┬────────────────────────────────────────────────────┐
-- │ Cache Type           │ Details                                           │
-- ├──────────────────────┼────────────────────────────────────────────────────┤
-- │ 1. RESULT CACHE      │ Layer: Cloud Services (global)                    │
-- │                      │ Stores: Complete query results                    │
-- │                      │ TTL: 24 hours (resets on re-use)                  │
-- │                      │ Cost: FREE (no warehouse needed)                  │
-- │                      │ Trigger: Exact same SQL + same data + same role   │
-- │                      │ Invalidation: Data changes in underlying tables   │
-- ├──────────────────────┼────────────────────────────────────────────────────┤
-- │ 2. LOCAL DISK CACHE  │ Layer: Warehouse SSD storage                      │
-- │ (Data Cache)         │ Stores: Table data (micro-partitions)             │
-- │                      │ TTL: Until warehouse is suspended                 │
-- │                      │ Cost: Warehouse must be running                   │
-- │                      │ Trigger: Accessing same table data                │
-- │                      │ Invalidation: Warehouse suspend/resume            │
-- ├──────────────────────┼────────────────────────────────────────────────────┤
-- │ 3. METADATA CACHE    │ Layer: Cloud Services (global)                    │
-- │                      │ Stores: Row counts, min/max values, NULL counts   │
-- │                      │ TTL: Always available (auto-maintained)           │
-- │                      │ Cost: FREE (no warehouse needed)                  │
-- │                      │ Trigger: COUNT(*), MIN(), MAX() on full table     │
-- │                      │ Invalidation: Automatically updated on DML        │
-- └──────────────────────┴────────────────────────────────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - Result cache: identical query reuse (24h TTL, FREE, no warehouse)
--   - Local disk cache: SSD caching on warehouse nodes (lost on suspend)
--   - Metadata cache: row counts, min/max stats in Cloud Services layer
--   - USE_CACHED_RESULT = FALSE to bypass result cache for testing
--   - Suspending a warehouse clears its local disk cache
-- =============================================================================


-- =============================================
-- DEMO 1: Result Cache in action
-- =============================================
-- Run an expensive query (first time = slow, computes from scratch)

SELECT AVG(C_BIRTH_YEAR) FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF100TCL.CUSTOMER;

-- Run the EXACT same query again immediately.
-- Snowflake returns the cached result instantly (no warehouse compute).
-- Check the Query Profile: it will show "QUERY RESULT REUSE".

SELECT AVG(C_BIRTH_YEAR) FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF100TCL.CUSTOMER;

-- RESULT CACHE REQUIREMENTS (all must be true):
--   1. Exact same SQL text (including whitespace and comments!)
--   2. Same role executing the query
--   3. Underlying data has not changed since the result was cached
--   4. USE_CACHED_RESULT session parameter is TRUE (default)
--   5. Query does not use non-deterministic functions (CURRENT_TIMESTAMP, RANDOM)


-- =============================================
-- DEMO 2: Testing with cache disabled
-- =============================================
-- Disable result cache to force re-computation (useful for benchmarking).

-- ALTER SESSION SET USE_CACHED_RESULT = FALSE;
-- SELECT AVG(C_BIRTH_YEAR) FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF100TCL.CUSTOMER;
-- ALTER SESSION SET USE_CACHED_RESULT = TRUE;   -- Re-enable afterward


-- =============================================
-- DEMO 3: Result Cache shared across users
-- =============================================
-- If two users with the SAME ROLE run the same query, the second user
-- benefits from the first user's cached result.

CREATE ROLE DATA_SCIENTIST;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE DATA_SCIENTIST;

CREATE USER DS1 PASSWORD = 'DS1' LOGIN_NAME = 'DS1'
    DEFAULT_ROLE      = 'DATA_SCIENTIST'
    DEFAULT_WAREHOUSE = 'DS_WH'
    MUST_CHANGE_PASSWORD = FALSE;

GRANT ROLE DATA_SCIENTIST TO USER DS1;

-- If DS1 runs a query, and then DS2 (with same DATA_SCIENTIST role)
-- runs the same query -> DS2 gets the cached result instantly.


-- =============================================================================
-- CONCEPT GAP: CACHING BEST PRACTICES FOR PERFORMANCE
-- =============================================================================
-- 1. MAXIMIZE RESULT CACHE:
--    - Standardize SQL queries (use views or parameterized queries)
--    - Avoid non-deterministic functions when possible
--    - Schedule data refreshes at predictable times
--    - Use the same role for similar analytical queries
--
-- 2. MAXIMIZE LOCAL DISK CACHE:
--    - Set AUTO_SUSPEND high enough to keep cache warm (300-600s)
--    - Don't resize warehouses frequently (clears cache)
--    - Run related queries on the SAME warehouse
--
-- 3. LEVERAGE METADATA CACHE:
--    - COUNT(*) on a table is instant (no warehouse needed)
--    - MIN/MAX queries on any column are instant
--    - These use Cloud Services metadata, not compute
--    Example:
--      SELECT COUNT(*) FROM my_table;           -- Instant, FREE
--      SELECT MIN(date_col) FROM my_table;      -- Instant, FREE
--      SELECT COUNT(*) WHERE date > '2024-01-01'; -- NOT metadata, needs compute
--
-- 4. CACHE-AWARE DESIGN:
--    - BI dashboards: Use same warehouse + same role = cache hits
--    - ETL: Separate warehouse (don't pollute BI cache)
--    - Ad-hoc: Accept cache misses, optimize warehouse size instead
--
-- INTERVIEW TIP: "How would you optimize a slow dashboard in Snowflake?"
--   Answer: Check if result cache is being used (Query Profile),
--   ensure consistent SQL text, keep warehouse running (auto_suspend=600),
--   consider materialized views for complex aggregations.
-- =============================================================================
