# Data Access Control & Security

## Introduction

Let's do a deep dive into data access control and security in Databricks. This is one of the
most heavily tested topics on the exam because it's so critical to real-world data engineering.
You need to understand how Unity Catalog's permission model works, how to implement fine-grained
access control at the row and column level, and how the security architecture protects data at
rest and in transit.

## The Security Model

Databricks uses a layered security model:

```
Databricks Security Layers:

┌──────────────────────────────────────────────────────────────┐
│ Layer 1: IDENTITY & AUTHENTICATION                          │
│   Who are you?                                               │
│   - SSO / SAML / OAuth integration                          │
│   - Personal access tokens                                   │
│   - Service principals for automation                        │
└──────────────────────────────────────────────────────────────┘
          │
          ▼
┌──────────────────────────────────────────────────────────────┐
│ Layer 2: AUTHORIZATION (Unity Catalog)                      │
│   What can you do?                                           │
│   - GRANT / REVOKE privileges                                │
│   - Catalog → Schema → Table hierarchy                       │
│   - Row-level and column-level security                      │
└──────────────────────────────────────────────────────────────┘
          │
          ▼
┌──────────────────────────────────────────────────────────────┐
│ Layer 3: DATA PROTECTION                                    │
│   How is data protected?                                     │
│   - Encryption at rest (S3 SSE, KMS)                         │
│   - Encryption in transit (TLS)                              │
│   - Network isolation (VPC / private endpoints)              │
└──────────────────────────────────────────────────────────────┘
```

## GRANT and REVOKE Syntax

The core of access control in Unity Catalog:

```sql
-- Basic GRANT syntax
GRANT privilege ON securable_type securable_name TO principal;

-- Basic REVOKE syntax
REVOKE privilege ON securable_type securable_name FROM principal;

-- Examples
GRANT SELECT ON TABLE production.finance.transactions TO analysts;
GRANT MODIFY ON TABLE production.finance.transactions TO data_engineers;
GRANT USE CATALOG ON CATALOG production TO all_users;
GRANT USE SCHEMA ON SCHEMA production.finance TO finance_team;
GRANT CREATE TABLE ON SCHEMA production.finance TO data_engineers;
GRANT ALL PRIVILEGES ON SCHEMA production.staging TO etl_service;

-- View current grants
SHOW GRANTS ON TABLE production.finance.transactions;
SHOW GRANTS TO analysts;
```

## Fine-Grained Access Control

### Dynamic Views (Column and Row Filtering)

Before Unity Catalog introduced native row/column security, dynamic views were the primary
approach:

```sql
-- Dynamic view that filters rows based on user's group membership
CREATE OR REPLACE VIEW production.finance.transactions_secure AS
SELECT
    transaction_id,
    amount,
    region,
    -- Column masking: only finance_admins see customer names
    CASE
        WHEN is_account_group_member('finance_admins') THEN customer_name
        ELSE '***REDACTED***'
    END AS customer_name,
    -- Column masking: redact SSN for non-authorized users
    CASE
        WHEN is_account_group_member('pii_authorized') THEN ssn
        ELSE CONCAT('***-**-', RIGHT(ssn, 4))
    END AS ssn,
    transaction_date
FROM production.finance.transactions_raw
-- Row filtering: users only see their region's data
WHERE
    is_account_group_member('finance_admins')
    OR region = current_user_region();
```

```
Dynamic View Security:

User "alice" (member of: analysts, us_region)
  → Sees: transactions WHERE region = 'US'
  → customer_name: '***REDACTED***'
  → ssn: '***-**-1234'

User "bob" (member of: finance_admins)
  → Sees: ALL transactions (no row filter)
  → customer_name: 'John Smith' (full value)
  → ssn: '123-45-6789' (full value)
```

### Row Filters (Unity Catalog Native)

Unity Catalog supports native row-level security through row filters:

```sql
-- Create a row filter function
CREATE OR REPLACE FUNCTION production.finance.region_filter(region_col STRING)
RETURNS BOOLEAN
RETURN
    is_account_group_member('finance_admins')
    OR region_col = (SELECT region FROM production.hr.user_regions
                     WHERE email = current_user());

-- Apply the row filter to a table
ALTER TABLE production.finance.transactions
SET ROW FILTER production.finance.region_filter ON (region);
```

```
Row Filter Behavior:

Table: transactions
┌─────────┬─────────┬────────┐
│ id      │ amount  │ region │  ← Row filter on this column
├─────────┼─────────┼────────┤
│ 1       │ 100     │ US     │  ← User in US region sees this
│ 2       │ 200     │ EU     │  ← User in US region CANNOT see this
│ 3       │ 150     │ US     │  ← User in US region sees this
│ 4       │ 300     │ APAC   │  ← User in US region CANNOT see this
└─────────┴─────────┴────────┘

finance_admins see ALL rows (filter returns TRUE for all)
```

### Column Masks (Unity Catalog Native)

```sql
-- Create a column mask function
CREATE OR REPLACE FUNCTION production.finance.mask_ssn(ssn_col STRING)
RETURNS STRING
RETURN
    CASE
        WHEN is_account_group_member('pii_authorized') THEN ssn_col
        ELSE CONCAT('***-**-', RIGHT(ssn_col, 4))
    END;

-- Apply the column mask to a table
ALTER TABLE production.finance.customers
ALTER COLUMN ssn SET MASK production.finance.mask_ssn;
```

```
Column Mask Behavior:

SELECT customer_name, ssn FROM production.finance.customers;

User in 'pii_authorized' group:
┌────────────────┬─────────────┐
│ customer_name  │ ssn         │
├────────────────┼─────────────┤
│ Alice Smith    │ 123-45-6789 │   ← Full value
│ Bob Jones      │ 987-65-4321 │   ← Full value
└────────────────┴─────────────┘

User NOT in 'pii_authorized' group:
┌────────────────┬─────────────┐
│ customer_name  │ ssn         │
├────────────────┼─────────────┤
│ Alice Smith    │ ***-**-6789 │   ← Masked
│ Bob Jones      │ ***-**-4321 │   ← Masked
└────────────────┴─────────────┘
```

### Row Filters vs Column Masks vs Dynamic Views

```
┌──────────────────┬────────────────┬────────────────┬──────────────────┐
│ Feature          │ Row Filters    │ Column Masks   │ Dynamic Views    │
├──────────────────┼────────────────┼────────────────┼──────────────────┤
│ Applied to       │ Tables directly│ Columns        │ Views (separate  │
│                  │                │ directly       │ object)          │
├──────────────────┼────────────────┼────────────────┼──────────────────┤
│ Granularity      │ Row-level      │ Column-level   │ Both row and     │
│                  │                │                │ column           │
├──────────────────┼────────────────┼────────────────┼──────────────────┤
│ Transparency     │ Automatic,     │ Automatic,     │ Users must query │
│                  │ users query    │ users query    │ the view, not    │
│                  │ table directly │ table directly │ the base table   │
├──────────────────┼────────────────┼────────────────┼──────────────────┤
│ UC Native?       │ Yes            │ Yes            │ Older approach   │
└──────────────────┴────────────────┴────────────────┴──────────────────┘
```

## Helper Security Functions

Unity Catalog provides built-in functions for access control logic:

```sql
-- Check if current user is a member of a group
SELECT is_account_group_member('finance_team');  -- Returns TRUE/FALSE

-- Get the current user's email
SELECT current_user();  -- Returns 'alice@company.com'

-- These are used in:
--   - Dynamic views
--   - Row filter functions
--   - Column mask functions
```

## Storage Credentials and External Locations

For accessing external data (outside UC-managed storage), you need:

```
External Data Access Chain:

  ┌──────────────┐     ┌──────────────────┐     ┌──────────────┐
  │ Storage      │────▶│ External         │────▶│ External     │
  │ Credential   │     │ Location         │     │ Table        │
  │              │     │                  │     │              │
  │ (IAM role    │     │ (S3 path that    │     │ (Table       │
  │  for S3      │     │  uses the        │     │  pointing    │
  │  access)     │     │  credential)     │     │  to the      │
  │              │     │                  │     │  location)   │
  └──────────────┘     └──────────────────┘     └──────────────┘

SQL:
  -- Create a storage credential (admin operation)
  CREATE STORAGE CREDENTIAL aws_s3_cred
  WITH IAM_ROLE = 'arn:aws:iam::123456789:role/databricks-s3-access';

  -- Create an external location using the credential
  CREATE EXTERNAL LOCATION finance_landing
  URL 's3://finance-data-lake/landing/'
  WITH (STORAGE CREDENTIAL aws_s3_cred);

  -- Grant access to the external location
  GRANT READ FILES ON EXTERNAL LOCATION finance_landing TO data_engineers;

  -- Create an external table at the location
  CREATE TABLE production.finance.ext_transactions
  LOCATION 's3://finance-data-lake/landing/transactions/';
```

## Cluster and Compute Security

```
Compute Access Control:

┌─────────────────────────────────────────────────────────────┐
│ SQL Warehouses                                              │
│                                                             │
│ - UC-enforced access control on all queries                 │
│ - Users can only access data they have GRANT permissions for│
│ - No direct file system access                              │
│ - Recommended for data analysts and BI tools                │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ Shared Access Mode Clusters                                 │
│                                                             │
│ - Multiple users share the same cluster                     │
│ - UC-enforced access control                                │
│ - Users isolated from each other                            │
│ - Cannot run arbitrary JVM code                             │
│ - Recommended for interactive analytics                     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ Single User Access Mode Clusters                            │
│                                                             │
│ - Assigned to one user or service principal                  │
│ - UC-enforced access control                                │
│ - Can run arbitrary code (ML libraries, custom JARs)        │
│ - Recommended for ML workloads and custom code              │
└─────────────────────────────────────────────────────────────┘
```

## Key Exam Points

1. **GRANT requires three levels**: USE CATALOG + USE SCHEMA + the specific privilege (SELECT, etc.)
2. **Row filters** are functions applied to tables that control which rows a user can see
3. **Column masks** are functions applied to columns that transform values based on the user's identity
4. **`is_account_group_member()`** is the key function for dynamic security decisions
5. **`current_user()`** returns the email of the current user
6. **Dynamic views** are an older approach to row/column security; native row filters and
   column masks are the UC-native approach
7. **Storage credentials** link IAM roles to Unity Catalog for external storage access
8. **External locations** map S3 paths to storage credentials for controlled access
9. **Shared access mode** clusters enforce UC permissions for multi-user environments
10. **Ownership** grants ALL PRIVILEGES on an object -- the creator is the default owner
11. **Grant to groups, not individual users** is the recommended best practice
12. **SHOW GRANTS** reveals current permissions on any securable object
