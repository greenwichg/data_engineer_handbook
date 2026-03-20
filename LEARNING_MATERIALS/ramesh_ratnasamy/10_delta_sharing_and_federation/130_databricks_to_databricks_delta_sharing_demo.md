# Databricks to Databricks Delta Sharing Demo

## Introduction

Now let's walk through a practical Databricks-to-Databricks Delta Sharing scenario. This is the
more streamlined of the two sharing models because both the provider and recipient are on
Databricks, so Unity Catalog handles all the authentication and access management automatically.
There's no need for credential files or activation links -- it's all managed through the
metastore.

In a real-world scenario, think of this as two departments within a large enterprise, or two
partner companies that both use Databricks. The provider team has curated data that the recipient
team needs to access for their own analytics, but you don't want to copy the data -- you want to
share it securely and keep it up to date.

## Demo Setup

```
Databricks-to-Databricks Sharing Setup:

┌──────────────────────────┐          ┌──────────────────────────┐
│   PROVIDER WORKSPACE     │          │   RECIPIENT WORKSPACE    │
│                          │          │                          │
│  Metastore: provider_ms  │          │  Metastore: recipient_ms │
│                          │          │                          │
│  Catalog: production     │          │  Will access shared      │
│  Schema: analytics       │          │  data as a catalog       │
│  Tables:                 │          │                          │
│   - customer_summary     │          │                          │
│   - monthly_revenue      │          │                          │
│   - product_performance  │          │                          │
│                          │          │                          │
└──────────────────────────┘          └──────────────────────────┘

Both workspaces must be registered under the same
Databricks account OR have cross-account sharing enabled.
```

## Step 1: Create the Share (Provider Side)

```sql
-- On the PROVIDER workspace

-- Create a share
CREATE SHARE IF NOT EXISTS partner_analytics_share
COMMENT 'Analytics data shared with partner workspace';

-- Verify the share was created
SHOW SHARES;

-- Output:
-- ┌──────────────────────────┬────────────────────┬────────────────────┐
-- │ name                     │ owner              │ comment            │
-- ├──────────────────────────┼────────────────────┼────────────────────┤
-- │ partner_analytics_share  │ account_admin      │ Analytics data...  │
-- └──────────────────────────┴────────────────────┴────────────────────┘
```

## Step 2: Add Tables to the Share

```sql
-- Add tables to the share
ALTER SHARE partner_analytics_share
ADD TABLE production.analytics.customer_summary;

ALTER SHARE partner_analytics_share
ADD TABLE production.analytics.monthly_revenue;

-- Add a table with alias (appears with a different name to the recipient)
ALTER SHARE partner_analytics_share
ADD TABLE production.analytics.product_performance
AS shared_analytics.products.performance_metrics;

-- Share specific partitions only
ALTER SHARE partner_analytics_share
ADD TABLE production.analytics.regional_sales
PARTITION (region = 'us-east', region = 'us-west');

-- View the contents of the share
SHOW ALL IN SHARE partner_analytics_share;

-- Output:
-- ┌─────────────────────────────────────┬────────┬──────────────────────┐
-- │ name                                │ type   │ shared_using         │
-- ├─────────────────────────────────────┼────────┼──────────────────────┤
-- │ production.analytics.customer_summ  │ TABLE  │ FULL                 │
-- │ production.analytics.monthly_rev    │ TABLE  │ FULL                 │
-- │ shared_analytics.products.perf_met  │ TABLE  │ ALIAS                │
-- │ production.analytics.regional_sales │ TABLE  │ PARTITION (region..) │
-- └─────────────────────────────────────┴────────┴──────────────────────┘
```

## Step 3: Create the Recipient

```sql
-- Create a Databricks-to-Databricks recipient
-- You need the recipient's sharing identifier (account ID + metastore ID)
CREATE RECIPIENT IF NOT EXISTS partner_team
USING ID '<recipient-account-id>:<recipient-metastore-id>'
COMMENT 'Partner team Databricks workspace';

-- The sharing identifier can be found in the recipient workspace:
-- Workspace Settings → Metastore → Sharing Identifier

-- Verify the recipient
SHOW RECIPIENTS;

-- Output:
-- ┌─────────────────┬──────────────────────┬───────────────────────┐
-- │ name            │ authentication_type  │ comment               │
-- ├─────────────────┼──────────────────────┼───────────────────────┤
-- │ partner_team    │ DATABRICKS           │ Partner team DB...    │
-- └─────────────────┴──────────────────────┴───────────────────────┘
```

## Step 4: Grant the Share to the Recipient

```sql
-- Grant access to the share
GRANT SELECT ON SHARE partner_analytics_share TO RECIPIENT partner_team;

-- Verify the grants
SHOW GRANTS ON SHARE partner_analytics_share;

-- Output:
-- ┌─────────────────┬──────────────────────────┬───────────┐
-- │ recipient       │ share                    │ privilege │
-- ├─────────────────┼──────────────────────────┼───────────┤
-- │ partner_team    │ partner_analytics_share   │ SELECT    │
-- └─────────────────┴──────────────────────────┴───────────┘
```

## Step 5: Access Shared Data (Recipient Side)

```sql
-- On the RECIPIENT workspace

-- The shared data appears as a read-only catalog
-- List available providers
SHOW PROVIDERS;

-- Create a catalog from the share
CREATE CATALOG IF NOT EXISTS partner_shared_data
USING SHARE <provider_name>.partner_analytics_share;

-- Now query the shared data just like any other catalog
SELECT * FROM partner_shared_data.analytics.customer_summary
LIMIT 10;

-- The data is live -- any updates by the provider are reflected immediately
SELECT
    region,
    SUM(revenue) as total_revenue,
    COUNT(DISTINCT customer_id) as unique_customers
FROM partner_shared_data.analytics.monthly_revenue
WHERE month >= '2025-01-01'
GROUP BY region
ORDER BY total_revenue DESC;
```

## What It Looks Like End to End

```
Databricks-to-Databricks Sharing Flow:

  PROVIDER WORKSPACE                      RECIPIENT WORKSPACE
  ──────────────────                      ────────────────────

  1. CREATE SHARE
     partner_analytics_share
          │
  2. ALTER SHARE ADD TABLE
     (add tables to share)
          │
  3. CREATE RECIPIENT
     partner_team
     USING ID '<account:metastore>'
          │
  4. GRANT SELECT ON SHARE
     TO RECIPIENT partner_team
          │                                    │
          │                                    ▼
          │                               5. SHOW PROVIDERS
          │                                  (sees provider)
          │                                    │
          │                                    ▼
          │                               6. CREATE CATALOG
          │                                  USING SHARE
          │                                    │
          │                                    ▼
          │                               7. SELECT * FROM
          │                                  partner_shared_data
          │                                  .schema.table
          │
  ┌───────┴────────┐                   ┌──────┴───────┐
  │  Delta Lake    │ ═══live data═══▶  │  Read-only   │
  │  Tables        │   (no copying)    │  Access      │
  └────────────────┘                   └──────────────┘
```

## Managing Shares

```sql
-- PROVIDER: Update shared data (just update your tables normally)
-- Recipients automatically see the latest data

-- PROVIDER: Revoke access
REVOKE SELECT ON SHARE partner_analytics_share FROM RECIPIENT partner_team;

-- PROVIDER: Remove a table from the share
ALTER SHARE partner_analytics_share
REMOVE TABLE production.analytics.monthly_revenue;

-- PROVIDER: Drop a recipient
DROP RECIPIENT IF EXISTS partner_team;

-- PROVIDER: Drop a share
DROP SHARE IF EXISTS partner_analytics_share;

-- RECIPIENT: Drop the shared catalog
DROP CATALOG IF EXISTS partner_shared_data;
```

## Key Exam Points

1. **Databricks-to-Databricks sharing** requires both workspaces to have Unity Catalog enabled
2. **Sharing identifier** (account ID + metastore ID) is used to create the recipient
3. **No credential files needed** -- authentication is managed automatically
4. **Shared data appears as a catalog** in the recipient workspace
5. **Data is live** -- recipients always see the latest version, no copying
6. **Provider controls access** -- can revoke at any time with REVOKE SELECT
7. **Table aliases** allow sharing tables with different names than the source
8. **Partition sharing** allows sharing only specific partitions, reducing exposure
9. **Recipients get read-only access** -- they cannot INSERT, UPDATE, or DELETE
10. **Supports tables, views, volumes, models, and notebooks** for Databricks-to-Databricks sharing
