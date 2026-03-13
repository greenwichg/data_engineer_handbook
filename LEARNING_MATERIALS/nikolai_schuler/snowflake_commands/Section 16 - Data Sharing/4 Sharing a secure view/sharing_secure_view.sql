-- =============================================================================
-- SECTION 16.4: SHARING A SECURE VIEW VIA DATA SHARING
-- =============================================================================
--
-- OBJECTIVE:
--   Learn how to share views through Snowflake Data Sharing, understanding
--   why only secure views are allowed and the grant chain required.
--
-- WHAT YOU WILL LEARN:
--   1. Sharing views (not just tables) via Data Sharing
--   2. Why regular views FAIL and secure views SUCCEED in shares
--   3. The complete grant chain for sharing views
--   4. Multi-tenant data delivery patterns
--
-- SHARING VIEWS — RULES:
-- ┌──────────────────────┬──────────────────────────────────────────────────┐
-- │ Object in Share      │ Result for Consumer                              │
-- ├──────────────────────┼──────────────────────────────────────────────────┤
-- │ Table                │ Works — consumer sees all rows                   │
-- │ Secure View          │ Works — consumer sees filtered/curated data      │
-- │ Normal View          │ FAILS — error when consumer creates DB from share│
-- │ Secure UDF           │ Works — consumer can call the function           │
-- └──────────────────────┴──────────────────────────────────────────────────┘
--
-- WHY SHARE VIEWS INSTEAD OF TABLES:
--   - Column filtering: expose only specific columns (hide PII)
--   - Row filtering: show only data relevant to the consumer
--   - Data transformation: apply business logic before sharing
--   - Multi-tenant: same table, different views per consumer
--
-- KEY INTERVIEW CONCEPTS:
--   - Only SECURE views can be shared — regular views cause consumer errors
--   - Grant chain for views: DATABASE usage → SCHEMA usage → VIEW select
--   - Sharing views is the recommended pattern for curated data delivery
--   - One source table can have multiple secure views for different consumers
-- =============================================================================


-- =============================================
-- STEP 1: View existing shares
-- =============================================
SHOW SHARES;
-- Shows both outbound (provider) and inbound (consumer) shares


-- =============================================
-- STEP 2: Create a share for views
-- =============================================
CREATE OR REPLACE SHARE VIEW_SHARE;

-- Grant the required chain of privileges
GRANT USAGE ON DATABASE CUSTOMER_DB TO SHARE VIEW_SHARE;
GRANT USAGE ON SCHEMA CUSTOMER_DB.PUBLIC TO SHARE VIEW_SHARE;

-- Grant SELECT on both views
GRANT SELECT ON VIEW CUSTOMER_DB.PUBLIC.CUSTOMER_VIEW TO SHARE VIEW_SHARE;
GRANT SELECT ON VIEW CUSTOMER_DB.PUBLIC.CUSTOMER_VIEW_SECURE TO SHARE VIEW_SHARE;

-- WHAT HAPPENS:
--   CUSTOMER_VIEW (normal):  Consumer will get an ERROR when trying to use it
--   CUSTOMER_VIEW_SECURE:    Consumer can query it successfully


-- =============================================
-- STEP 3: Add consumer account
-- =============================================
ALTER SHARE VIEW_SHARE
ADD ACCOUNT = <consumer-account-id>;


-- =============================================
-- STEP 4: Consumer side (run in consumer account)
-- =============================================
-- Create database from the share
-- CREATE DATABASE shared_views FROM SHARE <provider>.VIEW_SHARE;

-- Query the secure view — WORKS
-- SELECT * FROM shared_views.PUBLIC.CUSTOMER_VIEW_SECURE;

-- Query the normal view — FAILS with error
-- SELECT * FROM shared_views.PUBLIC.CUSTOMER_VIEW;
-- ERROR: "Shared view 'CUSTOMER_VIEW' is not secure"


-- =============================================================================
-- CONCEPT GAP: MULTI-TENANT SHARING PATTERN
-- =============================================================================
-- SCENARIO: You have one orders table but want to share different
--           subsets with different partner companies.
--
-- -- Source table has all data
-- CREATE TABLE all_orders (order_id INT, partner_id INT, amount NUMBER, ...);
--
-- -- Secure view for Partner A (only their orders)
-- CREATE SECURE VIEW partner_a_orders AS
-- SELECT * FROM all_orders WHERE partner_id = 100;
--
-- -- Secure view for Partner B (only their orders)
-- CREATE SECURE VIEW partner_b_orders AS
-- SELECT * FROM all_orders WHERE partner_id = 200;
--
-- -- Share A: only partner_a_orders view
-- CREATE SHARE partner_a_share;
-- GRANT ... TO SHARE partner_a_share;
-- GRANT SELECT ON VIEW partner_a_orders TO SHARE partner_a_share;
-- ALTER SHARE partner_a_share ADD ACCOUNT = <partner_a_account>;
--
-- -- Share B: only partner_b_orders view
-- CREATE SHARE partner_b_share;
-- GRANT ... TO SHARE partner_b_share;
-- GRANT SELECT ON VIEW partner_b_orders TO SHARE partner_b_share;
-- ALTER SHARE partner_b_share ADD ACCOUNT = <partner_b_account>;
--
-- RESULT: Each partner sees ONLY their own data from the same source table.
-- =============================================================================


-- =============================================================================
-- CONCEPT GAP: DATA SHARING BEST PRACTICES
-- =============================================================================
-- 1. ALWAYS use secure views (not raw tables) for external sharing
-- 2. NEVER expose PII columns — filter them out in the view
-- 3. USE separate shares for different consumers (not one mega-share)
-- 4. MONITOR shared data access via SNOWFLAKE.ACCOUNT_USAGE views
-- 5. REVOKE access promptly when a consumer relationship ends:
--    ALTER SHARE my_share REMOVE ACCOUNT = <old_consumer>;
-- 6. DOCUMENT what's shared: use SHOW GRANTS TO SHARE <name>;
-- 7. TEST shared views by creating a reader account for validation
-- =============================================================================
