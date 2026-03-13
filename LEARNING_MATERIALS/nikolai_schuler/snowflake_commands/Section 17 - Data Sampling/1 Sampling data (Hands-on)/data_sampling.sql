-- =============================================================================
-- SECTION 17.1: DATA SAMPLING IN SNOWFLAKE
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to sample data from large tables using ROW (Bernoulli) and
--   SYSTEM (block) sampling methods, with SEED for reproducibility.
--
-- WHAT YOU WILL LEARN:
--   1. ROW sampling (Bernoulli) — precise, row-level random selection
--   2. SYSTEM sampling (block) — fast, micro-partition-level selection
--   3. Using SEED for reproducible results
--   4. Creating sampled views for reuse
--
-- SAMPLING METHODS COMPARED (CRITICAL INTERVIEW TOPIC):
-- ┌──────────────────────┬──────────────────────┬──────────────────────────┐
-- │ Aspect               │ ROW (Bernoulli)      │ SYSTEM (Block)           │
-- ├──────────────────────┼──────────────────────┼──────────────────────────┤
-- │ Granularity          │ Individual rows      │ Entire micro-partitions  │
-- │ Randomness           │ Uniform distribution │ Clustered (by partition) │
-- │ Sample size accuracy │ Very close to %      │ Approximate (varies)     │
-- │ Performance          │ Slower (scans all)   │ Much faster (skips parts)│
-- │ Best for             │ Small-medium tables  │ Very large tables (TB+)  │
-- │ Syntax               │ SAMPLE ROW (n)       │ SAMPLE SYSTEM (n)        │
-- └──────────────────────┴──────────────────────┴──────────────────────────┘
--
-- HOW EACH METHOD WORKS:
--   ROW (Bernoulli):
--     Scans EVERY row and includes each with probability n%.
--     → 1% sample of 1M rows ≈ exactly ~10,000 rows
--     → Truly random distribution across the dataset
--
--   SYSTEM (Block):
--     Includes entire micro-partitions with probability n%.
--     → 1% sample of 1M rows ≈ approximately 10,000 rows (can vary)
--     → Rows within selected partitions are NOT individually sampled
--     → Much faster because unselected partitions are never read
--
-- KEY INTERVIEW CONCEPTS:
--   - SAMPLE and TABLESAMPLE are synonyms in Snowflake
--   - SEED(n) makes results reproducible — same seed = same sample
--   - ROW sampling is more accurate but slower; SYSTEM is faster but less precise
--   - Sampling is useful for: exploration, query testing, prototype building
--   - Sampled views persist the sample definition for reuse
-- =============================================================================


-- =============================================
-- STEP 1: Create a database for sampling
-- =============================================
CREATE OR REPLACE TRANSIENT DATABASE SAMPLING_DB;


-- =============================================
-- STEP 2: ROW sampling with SEED (reproducible)
-- =============================================
-- Create a view that samples 1% of rows with a fixed seed.
-- The same seed always returns the same sample.
CREATE OR REPLACE VIEW ADDRESS_SAMPLE AS
SELECT *
FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.CUSTOMER_ADDRESS
SAMPLE ROW (1) SEED(27);

SELECT * FROM ADDRESS_SAMPLE;

-- SYNTAX BREAKDOWN:
--   SAMPLE ROW (1)  → Include each row with 1% probability
--   SEED(27)        → Use seed 27 for reproducibility
--
-- Without SEED: every execution returns a different random sample
-- With SEED: every execution returns the SAME sample


-- =============================================
-- STEP 3: Verify sample representativeness
-- =============================================
-- Check if the sample distribution matches the full dataset
SELECT
    CA_LOCATION_TYPE,
    COUNT(*) / 3254250 * 100 AS SAMPLE_PCT
FROM ADDRESS_SAMPLE
GROUP BY CA_LOCATION_TYPE;

-- A good sample should have similar distribution percentages
-- as the full dataset. ROW sampling preserves distributions well.


-- =============================================
-- STEP 4: SYSTEM (block) sampling
-- =============================================
-- 1% sample using SYSTEM (micro-partition level)
SELECT *
FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.CUSTOMER_ADDRESS
SAMPLE SYSTEM (1) SEED(23);

-- 10% sample using SYSTEM — still very fast on large tables
SELECT *
FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.CUSTOMER_ADDRESS
SAMPLE SYSTEM (10) SEED(23);

-- PERFORMANCE COMPARISON ON A 10 TB TABLE:
--   ROW (1%)    → Scans entire table, returns ~1% of rows → Minutes
--   SYSTEM (1%) → Reads ~1% of micro-partitions          → Seconds


-- =============================================
-- STEP 5: Fixed-size sampling with ROWS
-- =============================================
-- Instead of a percentage, you can request a fixed number of rows:
SELECT *
FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.CUSTOMER_ADDRESS
SAMPLE (1000 ROWS);

-- SYNTAX:
--   SAMPLE (n ROWS)     → Return approximately n rows
--   SAMPLE ROW (p)      → Return approximately p% of rows
--   SAMPLE SYSTEM (p)   → Return approximately p% using block sampling


-- =============================================================================
-- CONCEPT GAP: WHEN TO USE WHICH SAMPLING METHOD
-- =============================================================================
-- USE ROW SAMPLING WHEN:
--   ✓ You need a statistically representative sample
--   ✓ Table is small-to-medium (< 100 GB)
--   ✓ Distribution accuracy matters (e.g., ML training data)
--   ✓ You're validating data quality or testing transformations
--
-- USE SYSTEM SAMPLING WHEN:
--   ✓ Table is very large (100 GB+)
--   ✓ Speed matters more than perfect distribution
--   ✓ You're doing exploratory analysis or quick profiling
--   ✓ Approximate results are acceptable
--
-- USE FIXED ROWS WHEN:
--   ✓ You need exactly N rows for testing
--   ✓ You want consistent result set sizes regardless of table growth
-- =============================================================================


-- =============================================================================
-- CONCEPT GAP: SAMPLING vs LIMIT
-- =============================================================================
-- SELECT * FROM table LIMIT 1000;
--   → Returns the FIRST 1000 rows (deterministic but NOT random)
--   → Rows are from the first micro-partitions scanned
--   → Biased toward early data — NOT representative
--
-- SELECT * FROM table SAMPLE ROW (1000 ROWS);
--   → Returns ~1000 RANDOM rows from across the entire table
--   → Rows are scattered throughout the dataset
--   → Statistically representative
--
-- INTERVIEW TIP: Use SAMPLE for representative data, LIMIT for quick peeks.
-- =============================================================================
