-- =============================================================================
-- SECTION 14.3: TEMPORARY TABLES
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how temporary tables work in Snowflake, including their
--   session-scoped lifecycle, name shadowing behavior, and appropriate
--   use cases.
--
-- WHAT YOU WILL LEARN:
--   1. Temporary tables are session-scoped and auto-dropped at session end
--   2. They shadow permanent tables with the same name within the session
--   3. Other sessions cannot see your temporary tables
--   4. No Fail-Safe, limited Time Travel (0-1 day)
--
-- TEMPORARY TABLE CHARACTERISTICS:
-- ┌──────────────────────┬──────────────────────────────────────────────────┐
-- │ Feature              │ Details                                          │
-- ├──────────────────────┼──────────────────────────────────────────────────┤
-- │ Keyword              │ CREATE TEMPORARY TABLE ...                       │
-- │ Time Travel          │ 0-1 day only                                    │
-- │ Fail-Safe            │ None (0 days)                                    │
-- │ Storage cost         │ Lowest (no TT overhead, no Fail-Safe)            │
-- │ Persistence          │ Session only — auto-dropped when session ends    │
-- │ Visibility           │ Current session ONLY (invisible to others)       │
-- │ UNDROP support       │ Yes, within retention (but only in same session) │
-- │ Name shadowing       │ Shadows permanent tables with the same name      │
-- │ Best for             │ Scratch data, intermediate calcs, session work   │
-- └──────────────────────┴──────────────────────────────────────────────────┘
--
-- ALL THREE TABLE TYPES COMPARED (CRITICAL INTERVIEW TOPIC):
-- ┌──────────────────────┬────────────┬────────────┬──────────────────────┐
-- │ Feature              │ Permanent  │ Transient  │ Temporary            │
-- ├──────────────────────┼────────────┼────────────┼──────────────────────┤
-- │ CREATE keyword       │ (default)  │ TRANSIENT  │ TEMPORARY            │
-- │ Time Travel max      │ 90 days    │ 1 day      │ 1 day                │
-- │ Fail-Safe            │ 7 days     │ None       │ None                 │
-- │ Survives sessions    │ Yes        │ Yes        │ No (session-scoped)  │
-- │ Visible to others    │ Yes        │ Yes        │ No (session only)    │
-- │ Shadows same name    │ No         │ No         │ Yes (within session) │
-- │ Storage cost         │ Highest    │ Medium     │ Lowest               │
-- │ Use case             │ Production │ Staging    │ Scratch/intermediate │
-- └──────────────────────┴────────────┴────────────┴──────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - TEMPORARY and TEMP are interchangeable keywords
--   - Temporary tables shadow permanent tables of the same name in the session
--   - The permanent table is NOT modified or deleted — it's just hidden
--   - When the session ends, the temporary table disappears and the permanent one is visible again
--   - Temporary tables are not shown to other users in SHOW TABLES
--   - You cannot create a temporary DATABASE or SCHEMA (tables only)
-- =============================================================================


-- =============================================
-- STEP 1: Create a permanent table first
-- =============================================
USE DATABASE PDB;

-- Create a permanent table with data
CREATE OR REPLACE TABLE PDB.public.customers (
    id         INT,
    first_name STRING,
    last_name  STRING,
    email      STRING,
    gender     STRING,
    Job        STRING,
    Phone      STRING
);

INSERT INTO PDB.public.customers
SELECT t1.*
FROM OUR_FIRST_DB.public.customers t1;

-- Verify data exists
SELECT * FROM PDB.public.customers;
-- Returns the permanent table's data


-- =============================================
-- STEP 2: Create a temporary table with the SAME name
-- =============================================
-- This creates a temporary table that SHADOWS the permanent one.
-- The permanent table still exists — it's just hidden in this session.
CREATE OR REPLACE TEMPORARY TABLE PDB.public.customers (
    id         INT,
    first_name STRING,
    last_name  STRING,
    email      STRING,
    gender     STRING,
    Job        STRING,
    Phone      STRING
);

-- NAME SHADOWING BEHAVIOR:
--   BEFORE creating temporary table:
--     SELECT * FROM customers → returns PERMANENT table data
--
--   AFTER creating temporary table (same session):
--     SELECT * FROM customers → returns TEMPORARY table data (empty!)
--
--   IN OTHER SESSIONS:
--     SELECT * FROM customers → still returns PERMANENT table data


-- =============================================
-- STEP 3: Validate the shadowing
-- =============================================
-- This returns the TEMPORARY table (which is empty)
SELECT * FROM PDB.public.customers;
-- Result: 0 rows (temporary table has no data)

-- The permanent table's data is still safe — just hidden.
-- When this session ends, the temporary table disappears
-- and the permanent table becomes visible again.


-- =============================================
-- STEP 4: Create another temporary table (unique name)
-- =============================================
CREATE OR REPLACE TEMPORARY TABLE PDB.public.temp_table (
    id         INT,
    first_name STRING,
    last_name  STRING,
    email      STRING,
    gender     STRING,
    Job        STRING,
    Phone      STRING
);

-- Insert data from the shadowed customers table
-- (this inserts from the TEMPORARY customers table, which is empty)
INSERT INTO PDB.public.temp_table
SELECT * FROM PDB.public.customers;

SELECT * FROM PDB.public.temp_table;

-- Check table properties
SHOW TABLES;
-- The "kind" column shows "TEMPORARY" for temporary tables
-- Other sessions running SHOW TABLES will NOT see your temporary tables


-- =============================================================================
-- CONCEPT GAP: TEMPORARY TABLE SHADOWING IN DETAIL
-- =============================================================================
--
-- SESSION A (creates temporary table):
--   CREATE TEMPORARY TABLE customers (...);
--   SELECT * FROM customers;  → Returns TEMPORARY table (empty)
--   INSERT INTO customers VALUES (1, 'Alice', ...);
--   SELECT * FROM customers;  → Returns 1 row from TEMPORARY table
--
-- SESSION B (at the same time):
--   SELECT * FROM customers;  → Returns PERMANENT table (original data)
--   -- Session B has NO knowledge of Session A's temporary table
--
-- SESSION A ENDS:
--   -- Temporary table is automatically dropped
--   -- Permanent table becomes visible again in future sessions
--
-- IMPORTANT: The permanent table is NEVER modified by shadowing.
-- CREATE OR REPLACE TEMPORARY TABLE does NOT drop the permanent table.
-- It creates a separate temporary object that takes precedence in the session.
-- =============================================================================


-- =============================================================================
-- CONCEPT GAP: WHEN TO USE TEMPORARY TABLES
-- =============================================================================
-- USE TEMPORARY TABLES FOR:
--   ✓ Intermediate calculation results within a stored procedure
--   ✓ Session-scoped scratch data (no cleanup needed)
--   ✓ Temporary materialization of complex CTEs for performance
--   ✓ Ad-hoc analysis that doesn't need to persist
--   ✓ Avoiding naming conflicts with permanent tables
--
-- DO NOT USE TEMPORARY TABLES FOR:
--   ✗ Data that needs to survive beyond the current session
--   ✗ Data shared between multiple sessions or users
--   ✗ ETL staging (use transient tables — they persist across sessions)
--   ✗ Anything requiring Time Travel beyond 1 day
--
-- TEMPORARY vs TRANSIENT — COMMON INTERVIEW QUESTION:
-- "What's the difference between transient and temporary tables?"
--
-- Answer: Both lack Fail-Safe and have max 1-day Time Travel.
-- The KEY difference is SCOPE:
--   - Transient: persists until explicitly dropped (like permanent)
--   - Temporary: auto-dropped at session end (session-scoped)
--
-- Another difference: VISIBILITY
--   - Transient: visible to all sessions/users (with grants)
--   - Temporary: visible ONLY to the creating session
-- =============================================================================


-- =============================================================================
-- CONCEPT GAP: TEMPORARY TABLES IN STORED PROCEDURES
-- =============================================================================
-- Temporary tables created inside a stored procedure are scoped
-- to the CALLER'S session, not the procedure itself.
--
-- This means:
--   1. The temporary table exists after the procedure finishes
--   2. It remains accessible in the session until the session ends
--   3. Other procedures in the same session can access it
--
-- EXAMPLE:
--   CREATE PROCEDURE process_data()
--   RETURNS STRING
--   AS $$
--     CREATE TEMPORARY TABLE temp_results AS
--       SELECT ... FROM source_table WHERE ...;
--     -- temp_results is available after the procedure returns
--   $$;
--
--   CALL process_data();
--   SELECT * FROM temp_results;  -- Works! Table is in the session scope
-- =============================================================================
