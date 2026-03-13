-- =============================================================================
-- SECTION 15.1: ZERO-COPY CLONING — TABLES, SCHEMAS, AND DATABASES
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how Snowflake's zero-copy cloning creates instant, metadata-only
--   copies of tables, schemas, and databases without duplicating storage.
--
-- WHAT YOU WILL LEARN:
--   1. How zero-copy cloning works (metadata-only, shared micro-partitions)
--   2. Cloning tables, schemas, and entire databases
--   3. Cloning across table types (permanent → transient)
--   4. Copy-on-write behavior and storage implications
--
-- ZERO-COPY CLONING OVERVIEW (CRITICAL INTERVIEW TOPIC):
-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │ HOW IT WORKS:                                                           │
-- │                                                                         │
-- │ BEFORE CLONE:                    AFTER CLONE:                           │
-- │ ┌─────────────┐                  ┌─────────────┐  ┌─────────────┐      │
-- │ │ Source Table │                  │ Source Table │  │ Clone Table │      │
-- │ │ (metadata)  │                  │ (metadata)  │  │ (metadata)  │      │
-- │ └──────┬──────┘                  └──────┬──────┘  └──────┬──────┘      │
-- │        │                                │                │              │
-- │        ▼                                └───────┬────────┘              │
-- │ ┌─────────────┐                         ┌──────▼──────┐                │
-- │ │Micro-parts  │                         │Micro-parts  │ (SHARED!)     │
-- │ │ (data)      │                         │ (data)      │                │
-- │ └─────────────┘                         └─────────────┘                │
-- │                                                                         │
-- │ AFTER MODIFYING THE CLONE:                                              │
-- │ ┌─────────────┐  ┌─────────────┐                                       │
-- │ │ Source Table │  │ Clone Table │                                       │
-- │ └──────┬──────┘  └──────┬──────┘                                       │
-- │        │                │                                               │
-- │        ▼                ▼                                               │
-- │ ┌───────────┐   ┌───────────┐   ← NEW micro-partitions                │
-- │ │ Original  │   │ Modified  │     (copy-on-write)                      │
-- │ │ data      │   │ data      │                                          │
-- │ └───────────┘   └───────────┘                                          │
-- └──────────────────────────────────────────────────────────────────────────┘
--
-- WHAT CAN BE CLONED:
-- ┌──────────────────────┬──────────────────────────────────────────────────┐
-- │ Object               │ What Gets Cloned                                 │
-- ├──────────────────────┼──────────────────────────────────────────────────┤
-- │ Table                │ Structure + data (micro-partitions shared)       │
-- │ Schema               │ All tables, views, stages, sequences, etc.      │
-- │ Database             │ All schemas and their contained objects          │
-- │ Stage                │ Metadata only (not the external files)           │
-- │ File format          │ Definition is copied                             │
-- │ Sequence             │ Current value is copied                          │
-- └──────────────────────┴──────────────────────────────────────────────────┘
--
-- WHAT IS NOT CLONED:
--   - Privileges/grants (clone gets no grants by default)
--   - External table data (only metadata)
--   - Pipes (not included in schema/database clones)
--   - Load history (COPY INTO history is not transferred)
--
-- KEY INTERVIEW CONCEPTS:
--   - Zero-copy = no additional storage at creation time
--   - Storage cost grows only when clone diverges (copy-on-write)
--   - Clones are INDEPENDENT — changes to one don't affect the other
--   - You can clone across table types (permanent → transient)
--   - Cloning is nearly instant regardless of data size
--   - Common use case: creating dev/test environments from production
-- =============================================================================


-- =============================================
-- STEP 1: Clone a schema
-- =============================================
-- Clone an entire schema — all tables, views, and objects within it
-- are cloned as well.

-- Clone PUBLIC schema as a TRANSIENT schema (different type)
CREATE TRANSIENT SCHEMA OUR_FIRST_DB.COPIED_SCHEMA
CLONE OUR_FIRST_DB.PUBLIC;

-- Verify: all tables from PUBLIC are now in COPIED_SCHEMA
SELECT * FROM OUR_FIRST_DB.COPIED_SCHEMA.CUSTOMERS;

-- Clone from a different database
CREATE TRANSIENT SCHEMA OUR_FIRST_DB.EXTERNAL_STAGES_COPIED
CLONE MANAGE_DB.EXTERNAL_STAGES;

-- IMPORTANT: The clone is independent. Modifying the clone
-- does NOT affect the original (and vice versa).


-- =============================================
-- STEP 2: Clone an entire database
-- =============================================
-- Clone all schemas and all their objects in a single command.
CREATE TRANSIENT DATABASE OUR_FIRST_DB_COPY
CLONE OUR_FIRST_DB;

-- This creates:
--   OUR_FIRST_DB_COPY
--     ├── PUBLIC (with all tables, views, etc.)
--     ├── COPIED_SCHEMA
--     ├── EXTERNAL_STAGES_COPIED
--     └── (any other schemas in OUR_FIRST_DB)

-- PERFORMANCE: Cloning a 10 TB database takes seconds (metadata only)
-- The underlying micro-partitions are shared, not copied.


-- =============================================
-- STEP 3: Clean up
-- =============================================
DROP DATABASE OUR_FIRST_DB_COPY;
DROP SCHEMA OUR_FIRST_DB.EXTERNAL_STAGES_COPIED;
DROP SCHEMA OUR_FIRST_DB.COPIED_SCHEMA;


-- =============================================================================
-- CONCEPT GAP: CLONING ACROSS TABLE TYPES
-- =============================================================================
-- You can change the table type during cloning:
--
-- Clone permanent table AS transient:
--   CREATE TRANSIENT TABLE dev_customers CLONE prod_customers;
--   → Lower storage cost for dev/test (no Fail-Safe)
--
-- Clone transient table AS permanent:
--   CREATE TABLE prod_customers CLONE staging_customers;
--   → Promote staging data to production with full protection
--
-- RULES:
-- ┌──────────────────────────────┬──────────────────────────────────────────┐
-- │ Clone Direction              │ Allowed?                                 │
-- ├──────────────────────────────┼──────────────────────────────────────────┤
-- │ Permanent → Permanent        │ Yes (default)                           │
-- │ Permanent → Transient        │ Yes (reduces cost)                      │
-- │ Permanent → Temporary        │ Yes (session-scoped clone)              │
-- │ Transient → Permanent        │ Yes (promotes to full protection)       │
-- │ Transient → Transient        │ Yes (default)                           │
-- │ Transient → Temporary        │ Yes                                     │
-- │ Temporary → Permanent        │ Yes                                     │
-- │ Temporary → Transient        │ Yes                                     │
-- │ Temporary → Temporary        │ Yes (default)                           │
-- └──────────────────────────────┴──────────────────────────────────────────┘
-- All combinations are supported!
-- =============================================================================


-- =============================================================================
-- CONCEPT GAP: COPY-ON-WRITE STORAGE BEHAVIOR
-- =============================================================================
-- Initial clone: 0 bytes additional storage (shares micro-partitions)
--
-- After INSERT into clone:
--   → New micro-partitions created ONLY in the clone
--   → Source table unaffected
--   → Additional storage = size of new data only
--
-- After UPDATE in clone:
--   → Modified micro-partitions are replaced with new ones in the clone
--   → Original micro-partitions remain shared (for unchanged data)
--   → Additional storage = size of modified micro-partitions
--
-- After DELETE in clone:
--   → Metadata updated to exclude deleted rows
--   → Micro-partitions may be reclaimed if fully empty
--   → Storage may decrease slightly
--
-- EXAMPLE:
--   Source table: 100 GB (1000 micro-partitions)
--   Clone created: 0 GB additional (all 1000 shared)
--   Update 10% of clone: ~10 GB additional (100 new micro-partitions)
--   Total: source (100 GB) + clone additions (~10 GB) = ~110 GB
-- =============================================================================


-- =============================================================================
-- CONCEPT GAP: COMMON CLONING USE CASES (INTERVIEW SCENARIOS)
-- =============================================================================
-- 1. DEV/TEST ENVIRONMENTS:
--    CREATE TRANSIENT DATABASE dev_db CLONE prod_db;
--    → Instant copy of production for development
--    → Transient = lower cost (no Fail-Safe needed for dev)
--
-- 2. DATA BACKUP BEFORE RISKY OPERATIONS:
--    CREATE TABLE customers_backup CLONE customers;
--    ALTER TABLE customers ADD COLUMN new_col STRING;
--    → If something goes wrong, the backup is ready
--
-- 3. DATA SCIENCE / ANALYTICS SANDBOXES:
--    CREATE SCHEMA analytics_sandbox CLONE production_schema;
--    → Analysts get their own copy to experiment with
--
-- 4. MIGRATION TESTING:
--    CREATE DATABASE migration_test CLONE production_db;
--    → Test migration scripts without risking production
--
-- 5. POINT-IN-TIME SNAPSHOTS (with Time Travel — see Section 15.2):
--    CREATE TABLE snapshot CLONE source AT (TIMESTAMP => '...'::TIMESTAMP);
--    → Create a clone of historical data
-- =============================================================================
