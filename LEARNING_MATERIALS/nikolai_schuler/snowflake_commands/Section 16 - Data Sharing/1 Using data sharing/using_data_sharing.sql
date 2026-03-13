-- =============================================================================
-- SECTION 16.1: USING DATA SHARING (Provider Setup)
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to set up Snowflake Secure Data Sharing from the provider side:
--   creating a share object, granting layered privileges, and adding consumers.
--
-- WHAT YOU WILL LEARN:
--   1. What Snowflake Data Sharing is and why it's unique
--   2. Creating a SHARE object and granting privileges
--   3. The required grant chain: DATABASE → SCHEMA → TABLE
--   4. Adding consumer accounts to a share
--
-- DATA SHARING OVERVIEW (CRITICAL INTERVIEW TOPIC):
-- ┌──────────────────────────────────────────────────────────────────────────┐
-- │ HOW IT WORKS:                                                           │
-- │                                                                         │
-- │ ┌──────────────────┐     SHARE     ┌──────────────────┐                │
-- │ │  PROVIDER ACCT    │──────────────>│  CONSUMER ACCT   │                │
-- │ │ (owns the data)   │   (metadata   │ (reads the data)  │               │
-- │ │                   │    pointer)   │                   │                │
-- │ │ ┌──────────────┐ │              │ ┌──────────────┐ │                 │
-- │ │ │ Actual Data  │ │              │ │  Read-Only   │ │                 │
-- │ │ │ (storage)    │◄├──────────────┤─│  Access      │ │                 │
-- │ │ └──────────────┘ │              │ └──────────────┘ │                 │
-- │ └──────────────────┘              └──────────────────┘                  │
-- │                                                                         │
-- │ KEY POINTS:                                                             │
-- │ • NO data is copied or moved — consumer queries provider's storage     │
-- │ • Consumer sees real-time data (always up-to-date)                     │
-- │ • Provider pays for storage; consumer pays for compute                 │
-- │ • Consumer access is READ-ONLY                                         │
-- └──────────────────────────────────────────────────────────────────────────┘
--
-- DATA SHARING vs TRADITIONAL APPROACHES:
-- ┌──────────────────────┬──────────────────────┬──────────────────────────┐
-- │ Aspect               │ Traditional (ETL/API) │ Snowflake Data Sharing   │
-- ├──────────────────────┼──────────────────────┼──────────────────────────┤
-- │ Data movement        │ Copied/transferred   │ Zero-copy (no movement)  │
-- │ Latency              │ Minutes to hours     │ Real-time (live data)    │
-- │ Storage duplication  │ Yes (double cost)    │ No (shared storage)      │
-- │ Data freshness       │ Stale until refresh  │ Always current           │
-- │ Setup complexity     │ ETL pipelines needed │ SQL commands only        │
-- │ Maintenance          │ Ongoing pipeline mgmt│ Zero maintenance         │
-- └──────────────────────┴──────────────────────┴──────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - Data Sharing is zero-copy and real-time — no ETL needed
--   - Grants must be layered: DATABASE → SCHEMA → TABLE (all three required)
--   - Consumer access is READ-ONLY
--   - Provider controls what's shared (tables, views, or secure views)
--   - Works across Snowflake accounts (same region by default)
--   - Cross-region/cross-cloud sharing requires replication or SHARE_RESTRICTIONS=false
-- =============================================================================


-- =============================================
-- STEP 1: Create source database and load data
-- =============================================
CREATE OR REPLACE DATABASE DATA_S;

CREATE OR REPLACE STAGE aws_stage
    URL = 's3://bucketsnowflakes3';

-- Verify files in stage
LIST @aws_stage;

-- Create the table to share
CREATE OR REPLACE TABLE ORDERS (
    ORDER_ID    VARCHAR(30),
    AMOUNT      NUMBER(38,0),
    PROFIT      NUMBER(38,0),
    QUANTITY    NUMBER(38,0),
    CATEGORY    VARCHAR(30),
    SUBCATEGORY VARCHAR(30)
);

-- Load data
COPY INTO ORDERS
    FROM @MANAGE_DB.external_stages.aws_stage
    file_format = (type = csv field_delimiter = ',' skip_header = 1)
    pattern = '.*OrderDetails.*';

SELECT * FROM ORDERS;


-- =============================================
-- STEP 2: Create a SHARE object
-- =============================================
-- A SHARE is a named object that defines what data is shared
-- and with whom. Think of it as a "package" of shared objects.
CREATE OR REPLACE SHARE ORDERS_SHARE;


-- =============================================
-- STEP 3: Grant layered privileges to the share
-- =============================================
-- CRITICAL: All three levels of grants are REQUIRED.
-- Missing any level will cause "Object does not exist" errors for the consumer.

-- Level 1: Grant usage on the DATABASE
GRANT USAGE ON DATABASE DATA_S TO SHARE ORDERS_SHARE;

-- Level 2: Grant usage on the SCHEMA
GRANT USAGE ON SCHEMA DATA_S.PUBLIC TO SHARE ORDERS_SHARE;

-- Level 3: Grant SELECT on the TABLE
GRANT SELECT ON TABLE DATA_S.PUBLIC.ORDERS TO SHARE ORDERS_SHARE;

-- GRANT CHAIN EXPLAINED:
--   DATABASE usage → Consumer can "see" the database
--   SCHEMA usage   → Consumer can "see" the schema within the database
--   TABLE select   → Consumer can query the table within the schema
--
-- Without DATABASE usage: Consumer cannot create a database from the share
-- Without SCHEMA usage:   Consumer sees the database but no schemas
-- Without TABLE select:   Consumer sees the schema but no tables

-- Verify all grants are in place
SHOW GRANTS TO SHARE ORDERS_SHARE;


-- =============================================
-- STEP 4: Add consumer account to the share
-- =============================================
-- The consumer must have a Snowflake account in the same region (by default).
ALTER SHARE ORDERS_SHARE ADD ACCOUNT = <consumer-account-id>;

-- WHAT HAPPENS ON THE CONSUMER SIDE:
--   1. Consumer runs: SHOW SHARES; (sees the inbound share)
--   2. Consumer runs: CREATE DATABASE shared_db FROM SHARE <provider>.ORDERS_SHARE;
--   3. Consumer can now: SELECT * FROM shared_db.PUBLIC.ORDERS;
--   4. Data is READ-ONLY — consumer cannot INSERT, UPDATE, or DELETE


-- =============================================================================
-- CONCEPT GAP: WHAT CAN BE SHARED
-- =============================================================================
-- ┌──────────────────────┬──────────────────────────────────────────────────┐
-- │ Object Type          │ Shareable?                                       │
-- ├──────────────────────┼──────────────────────────────────────────────────┤
-- │ Tables               │ Yes (SELECT only)                                │
-- │ Secure Views         │ Yes (recommended for filtered/curated data)      │
-- │ Secure UDFs          │ Yes (share functions without exposing logic)     │
-- │ Regular Views        │ No — will cause errors for consumer              │
-- │ Stages               │ No                                               │
-- │ Pipes                │ No                                               │
-- │ Tasks                │ No                                               │
-- │ Streams              │ No                                               │
-- └──────────────────────┴──────────────────────────────────────────────────┘
-- =============================================================================
