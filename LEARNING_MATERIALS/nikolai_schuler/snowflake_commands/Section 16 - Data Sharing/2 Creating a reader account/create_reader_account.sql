-- =============================================================================
-- SECTION 16.2: CREATING A READER ACCOUNT
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to share data with consumers who do NOT have a Snowflake account
--   by creating a managed reader account controlled by the provider.
--
-- WHAT YOU WILL LEARN:
--   1. What reader accounts are and when to use them
--   2. Creating a managed reader account
--   3. Setting up the reader with a warehouse, users, and privileges
--   4. Consuming shared data from the reader account
--
-- READER ACCOUNTS vs FULL ACCOUNTS (INTERVIEW TOPIC):
-- ┌──────────────────────┬──────────────────────┬──────────────────────────┐
-- │ Aspect               │ Full Account (share) │ Reader Account (managed) │
-- ├──────────────────────┼──────────────────────┼──────────────────────────┤
-- │ Consumer has SF acct │ Yes                  │ No (provider creates it) │
-- │ Who pays compute     │ Consumer             │ Provider                 │
-- │ Who manages account  │ Consumer             │ Provider                 │
-- │ Warehouse setup      │ Consumer does it     │ Provider must create it  │
-- │ User management      │ Consumer does it     │ Provider must create it  │
-- │ Use case             │ B2B sharing           │ External partners, demos│
-- └──────────────────────┴──────────────────────┴──────────────────────────┘
--
-- KEY INTERVIEW CONCEPTS:
--   - Reader accounts are for consumers without Snowflake accounts
--   - Provider pays ALL costs (storage + compute for reader)
--   - Provider must create warehouse and users for the reader
--   - SHARE_RESTRICTIONS=false enables cross-region/cross-cloud sharing
--   - GRANT IMPORTED PRIVILEGES gives reader users access to shared data
--   - Reader accounts can ONLY access shared data — no local storage
-- =============================================================================


-- =============================================
-- STEP 1: Create a managed reader account
-- =============================================
-- Must be run as ACCOUNTADMIN role
CREATE MANAGED ACCOUNT tech_joy_account
    ADMIN_NAME     = tech_joy_admin,
    ADMIN_PASSWORD = 'set-pwd',
    TYPE           = READER;

-- IMPORTANT: Note the account locator returned — you'll need it.

-- View all managed reader accounts
SHOW MANAGED ACCOUNTS;
-- Key columns: name, cloud, region, locator, url


-- =============================================
-- STEP 2: Add reader account to the share
-- =============================================
-- Same region sharing
ALTER SHARE ORDERS_SHARE
ADD ACCOUNT = <reader-account-id>;

-- Cross-region or cross-cloud sharing requires SHARE_RESTRICTIONS=false
ALTER SHARE ORDERS_SHARE
ADD ACCOUNT = <reader-account-id>
SHARE_RESTRICTIONS = false;

-- SHARE_RESTRICTIONS EXPLAINED:
--   true (default)  → Share only works within the same cloud region
--   false           → Enables cross-region and cross-cloud sharing
--                      (data may be replicated, adding latency and cost)


-- =============================================
-- STEP 3: Set up the reader account (run IN the reader account)
-- =============================================
-- Log into the reader account using the admin credentials created above.

-- View available shares
SHOW SHARES;

-- See details about the specific share
DESC SHARE <provider_account>.ORDERS_SHARE;

-- Create a database from the share
CREATE DATABASE DATA_SHARE_DB FROM SHARE <provider_account>.ORDERS_SHARE;

-- Query the shared data
SELECT * FROM DATA_SHARE_DB.PUBLIC.ORDERS;


-- =============================================
-- STEP 4: Create a warehouse for the reader
-- =============================================
-- Reader accounts have NO warehouse by default — provider must create one.
CREATE WAREHOUSE READ_WH WITH
    WAREHOUSE_SIZE     = 'X-SMALL'
    AUTO_SUSPEND       = 180
    AUTO_RESUME        = TRUE
    INITIALLY_SUSPENDED = TRUE;

-- TIP: Use small warehouses and aggressive auto-suspend to control costs,
-- since the PROVIDER pays for reader account compute.


-- =============================================
-- STEP 5: Create users and grant privileges
-- =============================================
-- Create a user for the reader account
CREATE USER MYRIAM PASSWORD = 'difficult_passw@ord=123';

-- Grant warehouse usage to the PUBLIC role
GRANT USAGE ON WAREHOUSE READ_WH TO ROLE PUBLIC;

-- Grant access to the shared database
-- IMPORTED PRIVILEGES is a special grant type for shared databases
GRANT IMPORTED PRIVILEGES ON DATABASE DATA_SHARE_DB TO ROLE PUBLIC;

-- IMPORTED PRIVILEGES EXPLAINED:
--   Shared databases don't support normal GRANT SELECT.
--   Instead, use GRANT IMPORTED PRIVILEGES to give users
--   access to all objects within the shared database.
--   This is the ONLY way to grant access to shared data.


-- =============================================================================
-- CONCEPT GAP: READER ACCOUNT LIMITATIONS
-- =============================================================================
-- Reader accounts CANNOT:
--   ✗ Create their own databases or tables (no local storage)
--   ✗ Load data into the account
--   ✗ Share data with others
--   ✗ Use features like tasks, streams, or pipes
--   ✗ Access Snowflake Marketplace
--
-- Reader accounts CAN:
--   ✓ Query shared data (READ-ONLY)
--   ✓ Create views on shared data
--   ✓ Use warehouses created by the provider
--   ✓ Have multiple users with role-based access
--
-- COST IMPLICATIONS:
--   Provider pays for:
--     - Storage of the shared data (same as always)
--     - Compute credits consumed by the reader's warehouse
--   This makes reader accounts expensive for the provider.
--   Use them only when the consumer truly cannot get a Snowflake account.
-- =============================================================================
