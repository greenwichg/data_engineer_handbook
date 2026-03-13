-- =============================================================================
-- SECTION 16.3: SECURE VIEWS vs NORMAL VIEWS
-- =============================================================================
--
-- OBJECTIVE:
--   Understand the difference between regular views and secure views in
--   Snowflake, and why secure views are required for data sharing.
--
-- WHAT YOU WILL LEARN:
--   1. Regular views expose their SQL definition to authorized users
--   2. Secure views hide the definition and optimizer details
--   3. Why secure views are mandatory for data sharing
--   4. Performance implications of secure views
--
-- SECURE vs NORMAL VIEW (CRITICAL INTERVIEW TOPIC):
-- ┌──────────────────────┬──────────────────────┬──────────────────────────┐
-- │ Aspect               │ Normal View          │ Secure View              │
-- ├──────────────────────┼──────────────────────┼──────────────────────────┤
-- │ CREATE syntax        │ CREATE VIEW          │ CREATE SECURE VIEW       │
-- │ SQL definition       │ Visible to grantees  │ Hidden from grantees     │
-- │ Query plan           │ Visible in EXPLAIN   │ Partially hidden         │
-- │ Optimizer behavior   │ Can push filters down│ May not push filters     │
-- │ Data Sharing         │ NOT allowed          │ Required for sharing     │
-- │ Row-level security   │ Leaks filter logic   │ Hides filter logic       │
-- │ Performance          │ Fully optimized      │ May be slightly slower   │
-- │ Use case             │ Internal convenience │ External sharing/security│
-- └──────────────────────┴──────────────────────┴──────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - Regular views expose WHERE clauses → users can see your filter logic
--   - Secure views prevent reverse-engineering of business logic
--   - SHOW VIEWS displays an "is_secure" flag
--   - Data Sharing REQUIRES secure views — regular views cause errors
--   - Secure views may have different query optimization (no filter pushdown)
--   - Use ALTER VIEW ... SET SECURE to convert an existing view
-- =============================================================================


-- =============================================
-- STEP 1: Set up database and table
-- =============================================
CREATE OR REPLACE DATABASE CUSTOMER_DB;

CREATE OR REPLACE TABLE CUSTOMER_DB.public.customers (
    id         INT,
    first_name STRING,
    last_name  STRING,
    email      STRING,
    gender     STRING,
    Job        STRING,
    Phone      STRING
);

-- Load data
CREATE OR REPLACE FILE FORMAT MANAGE_DB.file_formats.csv_file
    type            = csv
    field_delimiter = ','
    skip_header     = 1;

CREATE OR REPLACE STAGE MANAGE_DB.external_stages.time_travel_stage
    URL         = 's3://data-snowflake-fundamentals/time-travel/'
    file_format = MANAGE_DB.file_formats.csv_file;

LIST @MANAGE_DB.external_stages.time_travel_stage;

COPY INTO CUSTOMER_DB.public.customers
FROM @MANAGE_DB.external_stages.time_travel_stage
FILES = ('customers.csv');

SELECT * FROM CUSTOMER_DB.PUBLIC.CUSTOMERS;


-- =============================================
-- STEP 2: Create a NORMAL view
-- =============================================
-- This view filters out data scientists — but the filter is VISIBLE!
CREATE OR REPLACE VIEW CUSTOMER_DB.PUBLIC.CUSTOMER_VIEW AS
SELECT
    FIRST_NAME,
    LAST_NAME,
    EMAIL
FROM CUSTOMER_DB.PUBLIC.CUSTOMERS
WHERE JOB != 'DATA SCIENTIST';

-- Grant access to another role
GRANT USAGE ON DATABASE CUSTOMER_DB TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA CUSTOMER_DB.PUBLIC TO ROLE PUBLIC;
GRANT SELECT ON TABLE CUSTOMER_DB.PUBLIC.CUSTOMERS TO ROLE PUBLIC;
GRANT SELECT ON VIEW CUSTOMER_DB.PUBLIC.CUSTOMER_VIEW TO ROLE PUBLIC;

-- Check the view definition
SHOW VIEWS LIKE '%CUSTOMER%';
-- The "text" column shows the FULL SQL definition including the WHERE clause.
-- Any user with access can see: WHERE JOB != 'DATA SCIENTIST'
-- This leaks your business logic and filter criteria!


-- =============================================
-- STEP 3: Create a SECURE view
-- =============================================
-- The SECURE keyword hides the view definition from grantees.
CREATE OR REPLACE SECURE VIEW CUSTOMER_DB.PUBLIC.CUSTOMER_VIEW_SECURE AS
SELECT
    FIRST_NAME,
    LAST_NAME,
    EMAIL
FROM CUSTOMER_DB.PUBLIC.CUSTOMERS
WHERE JOB != 'DATA SCIENTIST';

GRANT SELECT ON VIEW CUSTOMER_DB.PUBLIC.CUSTOMER_VIEW_SECURE TO ROLE PUBLIC;

-- Check both views
SHOW VIEWS LIKE '%CUSTOMER%';
-- Normal view:  is_secure = false, "text" shows full SQL
-- Secure view:  is_secure = true,  "text" is hidden from non-owners

-- WHAT A NON-OWNER SEES:
--   Normal view:  Full SQL definition including WHERE JOB != 'DATA SCIENTIST'
--   Secure view:  Empty or "view definition hidden" — logic is protected


-- =============================================
-- STEP 4: Convert existing view to secure
-- =============================================
-- You can add or remove SECURE on existing views:
ALTER VIEW CUSTOMER_DB.PUBLIC.CUSTOMER_VIEW SET SECURE;
-- Now CUSTOMER_VIEW is also secure

-- To remove secure:
ALTER VIEW CUSTOMER_DB.PUBLIC.CUSTOMER_VIEW UNSET SECURE;


-- =============================================================================
-- CONCEPT GAP: WHY SECURE VIEWS MATTER FOR ROW-LEVEL SECURITY
-- =============================================================================
-- SCENARIO: Multi-tenant data where each customer should only see their data.
--
-- INSECURE APPROACH (Regular View):
--   CREATE VIEW customer_portal AS
--   SELECT * FROM all_customer_data
--   WHERE tenant_id = CURRENT_ROLE();
--
--   PROBLEM: Any user can run SHOW VIEWS and see the WHERE clause,
--   revealing the security model and potentially bypassing it.
--
-- SECURE APPROACH:
--   CREATE SECURE VIEW customer_portal AS
--   SELECT * FROM all_customer_data
--   WHERE tenant_id = CURRENT_ROLE();
--
--   BENEFIT: View definition is hidden. Users cannot see the filtering
--   logic, so they cannot attempt to bypass it.
-- =============================================================================


-- =============================================================================
-- CONCEPT GAP: SECURE VIEW PERFORMANCE IMPLICATIONS
-- =============================================================================
-- Secure views may be slightly slower because:
--   1. The optimizer CANNOT push user's WHERE filters into the view
--      (doing so could leak information about the view's internal logic)
--   2. This means more data may be scanned before filtering
--
-- EXAMPLE:
--   -- Normal view: optimizer pushes "WHERE email LIKE '%gmail%'" into
--   -- the view's query, scanning fewer micro-partitions
--
--   -- Secure view: optimizer runs the view's query FIRST, then applies
--   -- the user's filter on the result set (more data scanned)
--
-- MITIGATION:
--   - Use clustering keys on columns commonly filtered by consumers
--   - Keep secure views as simple as possible
--   - The performance difference is usually small for well-designed queries
-- =============================================================================
