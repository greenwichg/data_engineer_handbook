# Data Discovery, Audit & Lineage Demo

## Introduction

Let's get hands-on with three of Unity Catalog's most powerful governance features: data
discovery, audit logging, and lineage tracking. These features work together to give you
complete visibility into what data exists, who's using it, and how it flows through your
pipelines. For the exam, you need to know how these features work and how to use them in
practice.

## Data Discovery

Data discovery is about making your data findable and understandable. Unity Catalog provides
several tools for this.

### Table and Column Comments

```sql
-- Add a description to a table
COMMENT ON TABLE production.finance.transactions IS
  'Daily financial transactions including purchases, refunds, and adjustments.
   Source: ERP system via nightly batch load.
   Owner: Finance Data Engineering team.';

-- Add descriptions to columns
ALTER TABLE production.finance.transactions
  ALTER COLUMN transaction_id COMMENT 'Unique transaction identifier from ERP';

ALTER TABLE production.finance.transactions
  ALTER COLUMN amount COMMENT 'Transaction amount in USD, negative for refunds';

ALTER TABLE production.finance.transactions
  ALTER COLUMN customer_id COMMENT 'Foreign key to dim_customers table';
```

```sql
-- View table details including comments
DESCRIBE TABLE EXTENDED production.finance.transactions;

-- View all tables in a schema with their comments
SHOW TABLES IN production.finance;
```

### Tags

Tags are key-value metadata that you can attach to tables, columns, schemas, and catalogs:

```sql
-- Tag a table
ALTER TABLE production.finance.transactions
  SET TAGS ('domain' = 'finance', 'sensitivity' = 'high', 'pii' = 'true');

-- Tag specific columns
ALTER TABLE production.finance.transactions
  ALTER COLUMN customer_name SET TAGS ('pii' = 'true', 'data_class' = 'name');

ALTER TABLE production.finance.transactions
  ALTER COLUMN email SET TAGS ('pii' = 'true', 'data_class' = 'email');

-- Remove a tag
ALTER TABLE production.finance.transactions
  UNSET TAGS ('pii');
```

```
Tag Use Cases:

┌──────────────────────┬──────────────────────────────────────────┐
│ Tag                  │ Purpose                                  │
├──────────────────────┼──────────────────────────────────────────┤
│ pii = true           │ Identify columns with personal data     │
│ sensitivity = high   │ Data classification for security        │
│ domain = finance     │ Organize by business domain             │
│ sla = tier_1         │ Track data freshness requirements       │
│ owner = team_name    │ Identify responsible team               │
│ gdpr_relevant = true │ Flag tables for compliance workflows    │
│ deprecated = true    │ Warn users table will be removed        │
└──────────────────────┴──────────────────────────────────────────┘
```

### Data Explorer UI

The Databricks Data Explorer provides a visual interface for browsing and searching:

```
Data Explorer Features:

┌─────────────────────────────────────────────────────────────┐
│                    DATA EXPLORER                            │
│                                                             │
│  Search: [transactions_______]  🔍                          │
│                                                             │
│  📁 production (catalog)                                    │
│    📁 finance (schema)                                      │
│      📊 transactions                                        │
│        ├── Columns (8)                                      │
│        │   ├── transaction_id  STRING  "Unique trans ID"   │
│        │   ├── amount          DECIMAL "Amount in USD"     │
│        │   └── ...                                          │
│        ├── Sample Data (preview)                            │
│        ├── Details (owner, created, location)               │
│        ├── Permissions (who has access)                     │
│        ├── History (version history)                        │
│        ├── Lineage (upstream/downstream)                    │
│        └── Tags (pii, domain, etc.)                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Information Schema

Unity Catalog exposes metadata through the standard SQL `INFORMATION_SCHEMA`:

```sql
-- List all tables you have access to
SELECT table_catalog, table_schema, table_name, table_type, comment
FROM system.information_schema.tables
WHERE table_schema = 'finance';

-- List all columns and their metadata
SELECT table_name, column_name, data_type, comment
FROM system.information_schema.columns
WHERE table_schema = 'finance'
  AND table_name = 'transactions';

-- List all tags
SELECT *
FROM system.information_schema.table_tags
WHERE tag_name = 'pii';

-- List column-level tags
SELECT *
FROM system.information_schema.column_tags
WHERE tag_name = 'pii' AND tag_value = 'true';
```

## Audit Logging

Unity Catalog automatically logs all access and operations. This is critical for compliance
(GDPR, HIPAA, SOX) and security monitoring.

### What Gets Audited

```
Audit Log Events:

┌────────────────────────────┬──────────────────────────────────────┐
│ Category                   │ Events Logged                        │
├────────────────────────────┼──────────────────────────────────────┤
│ Data Access                │ SELECT queries (who read what data)  │
│                            │ Table reads via Spark jobs            │
├────────────────────────────┼──────────────────────────────────────┤
│ Data Modification          │ INSERT, UPDATE, DELETE, MERGE        │
│                            │ CREATE TABLE, DROP TABLE             │
├────────────────────────────┼──────────────────────────────────────┤
│ Permission Changes         │ GRANT, REVOKE operations             │
│                            │ Ownership transfers                  │
├────────────────────────────┼──────────────────────────────────────┤
│ Account Administration     │ User/group management                │
│                            │ Workspace configuration changes      │
├────────────────────────────┼──────────────────────────────────────┤
│ Authentication             │ Login attempts (success/failure)     │
│                            │ Token generation                     │
└────────────────────────────┴──────────────────────────────────────┘
```

### Accessing Audit Logs

Databricks stores audit logs in the **system tables** (available in Unity Catalog):

```sql
-- Query audit logs from system tables
SELECT
    event_time,
    event_type,
    user_identity.email AS user_email,
    action_name,
    request_params,
    response.status_code
FROM system.access.audit
WHERE action_name = 'getTable'
  AND event_date >= '2025-01-01'
ORDER BY event_time DESC
LIMIT 100;
```

```sql
-- Find who accessed a specific table
SELECT
    event_time,
    user_identity.email AS user_email,
    action_name,
    request_params.full_name_arg AS table_name
FROM system.access.audit
WHERE request_params.full_name_arg = 'production.finance.transactions'
  AND action_name IN ('commandSubmit', 'getTable')
ORDER BY event_time DESC;
```

```sql
-- Find all permission changes
SELECT
    event_time,
    user_identity.email AS changed_by,
    action_name,
    request_params
FROM system.access.audit
WHERE action_name IN ('updatePermissions', 'grantPermission', 'revokePermission')
ORDER BY event_time DESC;
```

### Audit Log Delivery

```
Audit Log Delivery Options:

1. System Tables (recommended):
   → system.access.audit
   → Queryable directly with SQL
   → Retained for 365 days

2. Log Delivery to Cloud Storage:
   → Configure delivery to S3 bucket
   → JSON format, delivered in near real-time
   → Retain as long as needed
   → Integrate with SIEM tools (Splunk, etc.)

Delivery Configuration:
  Account Admin → Settings → Audit Logs → Configure Delivery
  → Specify S3 bucket path
  → Logs delivered every ~15 minutes
```

## Data Lineage

Unity Catalog automatically captures data lineage -- the flow of data from source to
destination across your pipelines.

### How Lineage Works

```
Automatic Lineage Capture:

When you run:
  df = spark.read.table("production.finance.raw_transactions")
  result = df.groupBy("date").agg(sum("amount"))
  result.write.saveAsTable("production.finance.daily_totals")

Unity Catalog automatically records:
  production.finance.raw_transactions
       │
       │ (columns: date, amount)
       ▼
  production.finance.daily_totals
       (columns: date, sum_amount)

This happens transparently -- no additional code or configuration needed.
```

Lineage is captured for:
- **Spark SQL** queries
- **DataFrame operations**
- **DLT pipelines**
- **Notebook executions**
- **Databricks Jobs**

### Viewing Lineage

```
Lineage in the UI:

Data Explorer → Select Table → Lineage Tab

  UPSTREAM                          DOWNSTREAM
  (where data comes from)          (where data goes)

  ┌──────────────┐                 ┌──────────────┐
  │ raw_orders   │                 │ gold_revenue │
  │ (S3 files)   │                 │ (dashboard)  │
  └──────┬───────┘                 └──────────────┘
         │                                ▲
         ▼                                │
  ┌──────────────┐    ┌──────────────┐    │
  │ bronze_      │───▶│ silver_      │────┘
  │ orders       │    │ orders       │
  └──────────────┘    └──────────────┘

  Click any table to see:
  - Column-level lineage (which columns map to which)
  - Notebook/job that created the dependency
  - When the lineage was captured
```

### Querying Lineage Programmatically

```sql
-- View upstream dependencies (where data comes from)
-- Available through the system lineage tables
SELECT *
FROM system.access.table_lineage
WHERE target_table_full_name = 'production.finance.daily_totals'
ORDER BY event_time DESC;
```

```sql
-- View downstream dependencies (what uses this table)
SELECT *
FROM system.access.table_lineage
WHERE source_table_full_name = 'production.finance.raw_transactions'
ORDER BY event_time DESC;
```

```sql
-- Column-level lineage
SELECT *
FROM system.access.column_lineage
WHERE target_table_full_name = 'production.finance.daily_totals'
  AND target_column_name = 'total_revenue';
```

### Lineage Use Cases

```
Lineage Use Cases:

1. Impact Analysis
   "If I change the schema of raw_orders, what breaks?"
   → Check downstream dependencies before making changes

2. Root Cause Analysis
   "Why does gold_revenue have wrong numbers?"
   → Trace upstream to find where the issue originated

3. Compliance
   "Show me every table that depends on PII data"
   → Trace all downstream uses of sensitive columns

4. Documentation
   "How is this table populated?"
   → See the full pipeline path from source to target

5. Migration Planning
   "What pipelines would be affected if we move this table?"
   → Identify all dependencies before migrating
```

## Putting It All Together

Here's how discovery, audit, and lineage work together in a governance workflow:

```
Governance Workflow Example:

Scenario: "A compliance audit requires us to show how customer PII
           flows through our systems and who has accessed it."

Step 1: DISCOVERY -- Find all PII data
   SELECT * FROM system.information_schema.column_tags
   WHERE tag_name = 'pii' AND tag_value = 'true';
   → Found: customers.name, customers.email, orders.customer_name

Step 2: LINEAGE -- Trace where PII flows
   SELECT * FROM system.access.table_lineage
   WHERE source_table_full_name = 'production.crm.customers';
   → Flows to: silver_customers → gold_customer_360 → marketing_segments

Step 3: AUDIT -- Who accessed PII data?
   SELECT user_identity.email, COUNT(*)
   FROM system.access.audit
   WHERE request_params.full_name_arg LIKE '%customers%'
   GROUP BY user_identity.email;
   → 15 users accessed customer data last quarter

Step 4: ACCESS CONTROL -- Verify permissions are correct
   SHOW GRANTS ON TABLE production.crm.customers;
   → Verify only authorized groups have SELECT
```

## Key Exam Points

1. **Table/column comments** provide human-readable descriptions for data discovery
2. **Tags** are key-value metadata for classification (PII, sensitivity, domain, etc.)
3. **INFORMATION_SCHEMA** provides SQL access to metadata, tags, and table details
4. **Data Explorer UI** lets you browse, search, and inspect tables visually
5. **Audit logs** are stored in `system.access.audit` and capture all data access and changes
6. **Lineage is captured automatically** -- no additional code or configuration needed
7. **Column-level lineage** tracks which source columns map to which target columns
8. **Lineage covers**: Spark SQL, DataFrame operations, DLT pipelines, and Databricks Jobs
9. **Audit logs** can be delivered to S3 for long-term retention and SIEM integration
10. **Discovery + Lineage + Audit** together enable compliance workflows (GDPR, HIPAA, SOX)
