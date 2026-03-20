# Lakehouse Federation Demo

## Introduction

Let's walk through a practical Lakehouse Federation demo. In this scenario, imagine you're a data
engineer at a company that has customer data in MySQL, order data in PostgreSQL, and you need to
combine it with your existing Delta Lake analytics tables in Databricks -- all without copying
any data. This is a very common real-world pattern where organizations have data spread across
multiple systems and need a unified query layer.

## Demo Scenario

```
Company Data Landscape:

┌─────────────────┐  ┌──────────────────┐  ┌──────────────────────┐
│   MySQL          │  │   PostgreSQL      │  │   Databricks         │
│   (CRM System)   │  │   (Order System)  │  │   (Analytics)        │
│                  │  │                   │  │                      │
│  customers       │  │  orders           │  │  production.analytics│
│  - customer_id   │  │  - order_id       │  │  .customer_segments  │
│  - name          │  │  - customer_id    │  │  - customer_id       │
│  - email         │  │  - order_date     │  │  - segment           │
│  - region        │  │  - total_amount   │  │  - ltv_score         │
│  - signup_date   │  │  - status         │  │  - churn_risk        │
│                  │  │                   │  │                      │
│  support_tickets │  │  order_items      │  │                      │
│  - ticket_id     │  │  - item_id        │  │                      │
│  - customer_id   │  │  - order_id       │  │                      │
│  - issue_type    │  │  - product_id     │  │                      │
│  - status        │  │  - quantity       │  │                      │
│                  │  │  - price          │  │                      │
└─────────────────┘  └──────────────────┘  └──────────────────────┘

Goal: Query all three systems from Databricks using standard SQL
```

## Step 1: Create Connections

```sql
-- Create connection to MySQL CRM database
CREATE CONNECTION IF NOT EXISTS mysql_crm
TYPE mysql
OPTIONS (
    host 'mysql-crm.internal.company.com',
    port '3306',
    user 'databricks_readonly',
    password secret('federation', 'mysql_crm_password')
);

-- Create connection to PostgreSQL Order database
CREATE CONNECTION IF NOT EXISTS postgres_orders
TYPE postgresql
OPTIONS (
    host 'postgres-orders.internal.company.com',
    port '5432',
    user 'databricks_readonly',
    password secret('federation', 'postgres_orders_password')
);

-- Verify connections
SHOW CONNECTIONS;

-- Output:
-- ┌──────────────────┬────────────┬─────────────────────────────────┐
-- │ name             │ type       │ host                            │
-- ├──────────────────┼────────────┼─────────────────────────────────┤
-- │ mysql_crm        │ mysql      │ mysql-crm.internal.company.com  │
-- │ postgres_orders  │ postgresql │ postgres-orders.internal...     │
-- └──────────────────┴────────────┴─────────────────────────────────┘
```

## Step 2: Create Foreign Catalogs

```sql
-- Create foreign catalog for MySQL CRM
CREATE FOREIGN CATALOG IF NOT EXISTS crm_mysql
USING CONNECTION mysql_crm
OPTIONS (database 'crm_production');

-- Create foreign catalog for PostgreSQL Orders
CREATE FOREIGN CATALOG IF NOT EXISTS orders_postgres
USING CONNECTION postgres_orders
OPTIONS (database 'orders_production');

-- Verify catalogs
SHOW CATALOGS;

-- Output:
-- ┌───────────────────┬─────────────┐
-- │ catalog_name      │ catalog_type│
-- ├───────────────────┼─────────────┤
-- │ production        │ MANAGED     │  ◀── Delta Lake catalog
-- │ crm_mysql         │ FOREIGN     │  ◀── MySQL catalog
-- │ orders_postgres   │ FOREIGN     │  ◀── PostgreSQL catalog
-- └───────────────────┴─────────────┘
```

## Step 3: Explore Federated Metadata

```sql
-- Browse the MySQL foreign catalog (just like a regular catalog)
SHOW SCHEMAS IN crm_mysql;

-- Output:
-- ┌───────────────┐
-- │ schema_name   │
-- ├───────────────┤
-- │ customers     │
-- │ support       │
-- └───────────────┘

-- List tables in a schema
SHOW TABLES IN crm_mysql.customers;

-- Output:
-- ┌────────────────┐
-- │ table_name     │
-- ├────────────────┤
-- │ customer_info  │
-- │ contact_prefs  │
-- └────────────────┘

-- Describe a federated table (see column types)
DESCRIBE TABLE crm_mysql.customers.customer_info;

-- Output:
-- ┌──────────────┬──────────┬─────────┐
-- │ col_name     │ data_type│ comment │
-- ├──────────────┼──────────┼─────────┤
-- │ customer_id  │ int      │         │
-- │ name         │ string   │         │
-- │ email        │ string   │         │
-- │ region       │ string   │         │
-- │ signup_date  │ date     │         │
-- └──────────────┴──────────┴─────────┘
```

## Step 4: Query Federated Data

```sql
-- Simple query against MySQL (federated)
SELECT
    customer_id,
    name,
    email,
    region
FROM crm_mysql.customers.customer_info
WHERE region = 'us-east'
LIMIT 10;

-- Simple query against PostgreSQL (federated)
SELECT
    order_id,
    customer_id,
    order_date,
    total_amount,
    status
FROM orders_postgres.public.orders
WHERE order_date >= '2025-01-01'
  AND status = 'completed'
ORDER BY total_amount DESC
LIMIT 10;
```

## Step 5: Cross-System Joins

```sql
-- Join data across MySQL, PostgreSQL, and Delta Lake
-- This is the real power of Lakehouse Federation

SELECT
    c.name AS customer_name,
    c.region,
    seg.segment,
    seg.ltv_score,
    COUNT(o.order_id) AS total_orders,
    SUM(o.total_amount) AS total_spend,
    MAX(o.order_date) AS last_order_date
FROM crm_mysql.customers.customer_info c           -- MySQL
JOIN orders_postgres.public.orders o                -- PostgreSQL
    ON c.customer_id = o.customer_id
JOIN production.analytics.customer_segments seg     -- Delta Lake
    ON c.customer_id = seg.customer_id
WHERE o.order_date >= '2025-01-01'
  AND o.status = 'completed'
GROUP BY c.name, c.region, seg.segment, seg.ltv_score
ORDER BY total_spend DESC
LIMIT 20;

-- ┌──────────────┬─────────┬──────────┬───────────┬──────────┬─────────────┬────────────────┐
-- │ customer_name│ region  │ segment  │ ltv_score │ orders   │ total_spend │ last_order_date│
-- ├──────────────┼─────────┼──────────┼───────────┼──────────┼─────────────┼────────────────┤
-- │ Acme Corp    │ us-east │ premium  │ 95.2      │ 47       │ 234500.00   │ 2025-03-15     │
-- │ Beta Inc     │ us-west │ premium  │ 91.8      │ 38       │ 189200.00   │ 2025-03-18     │
-- └──────────────┴─────────┴──────────┴───────────┴──────────┴─────────────┴────────────────┘
```

## Step 6: Create Views Over Federated Data

```sql
-- Create a view that combines federated data for easy reuse
CREATE OR REPLACE VIEW production.analytics.unified_customer_360
AS
SELECT
    c.customer_id,
    c.name,
    c.email,
    c.region,
    c.signup_date,
    seg.segment,
    seg.ltv_score,
    seg.churn_risk,
    order_stats.total_orders,
    order_stats.total_spend,
    order_stats.avg_order_value,
    order_stats.last_order_date,
    ticket_stats.open_tickets
FROM crm_mysql.customers.customer_info c
LEFT JOIN production.analytics.customer_segments seg
    ON c.customer_id = seg.customer_id
LEFT JOIN (
    SELECT
        customer_id,
        COUNT(*) AS total_orders,
        SUM(total_amount) AS total_spend,
        AVG(total_amount) AS avg_order_value,
        MAX(order_date) AS last_order_date
    FROM orders_postgres.public.orders
    WHERE status = 'completed'
    GROUP BY customer_id
) order_stats ON c.customer_id = order_stats.customer_id
LEFT JOIN (
    SELECT
        customer_id,
        COUNT(*) AS open_tickets
    FROM crm_mysql.support.support_tickets
    WHERE status = 'open'
    GROUP BY customer_id
) ticket_stats ON c.customer_id = ticket_stats.customer_id;

-- Now anyone can query the unified view
SELECT * FROM production.analytics.unified_customer_360
WHERE churn_risk > 0.7
ORDER BY ltv_score DESC;
```

## Step 7: Set Up Access Control

```sql
-- Grant access to the foreign catalogs
GRANT USE CATALOG ON CATALOG crm_mysql TO `data_analysts`;
GRANT USE CATALOG ON CATALOG orders_postgres TO `data_analysts`;

-- Grant schema-level access
GRANT USE SCHEMA ON SCHEMA crm_mysql.customers TO `data_analysts`;
GRANT USE SCHEMA ON SCHEMA orders_postgres.public TO `data_analysts`;

-- Grant table-level access
GRANT SELECT ON TABLE crm_mysql.customers.customer_info TO `data_analysts`;
GRANT SELECT ON TABLE orders_postgres.public.orders TO `data_analysts`;

-- Restrict sensitive tables
-- (support tickets may contain PII -- only grant to specific group)
GRANT SELECT ON TABLE crm_mysql.support.support_tickets TO `support_team`;
```

## Managing Connections

```sql
-- Update connection credentials (e.g., after password rotation)
ALTER CONNECTION mysql_crm
SET OPTIONS (
    password secret('federation', 'mysql_crm_new_password')
);

-- Drop a foreign catalog (removes metadata, not the external data)
DROP CATALOG IF EXISTS crm_mysql;

-- Drop a connection
DROP CONNECTION IF EXISTS mysql_crm;

-- Note: You must drop the foreign catalog before
-- dropping the connection it depends on
```

## Federation vs ETL: When to Use Which

```
Decision Guide:

┌─────────────────────────┬──────────────────────┬─────────────────────┐
│ Factor                  │ Use Federation       │ Use ETL to Delta    │
├─────────────────────────┼──────────────────────┼─────────────────────┤
│ Data freshness needed   │ Real-time            │ Batch is OK         │
│ Query frequency         │ Occasional / ad-hoc  │ Frequent / repeated │
│ Data volume             │ Small to medium      │ Any size            │
│ Query performance       │ Acceptable latency   │ Need fastest speed  │
│ Data transformation     │ Minimal              │ Heavy transforms    │
│ Historical analysis     │ Not needed           │ Time travel needed  │
│ Joins with local data   │ Simple joins         │ Complex pipelines   │
│ Setup effort            │ Minutes              │ Hours to days       │
└─────────────────────────┴──────────────────────┴─────────────────────┘

Best practice: Use federation for exploration and ad-hoc queries.
Use ETL/ingestion for production analytics with strict SLAs.
```

## Key Exam Points

1. **Lakehouse Federation** enables querying external databases without data movement
2. **Two objects to create**: Connection (credentials) → Foreign Catalog (metadata)
3. **Foreign catalogs** appear alongside regular catalogs in Unity Catalog
4. **Cross-system joins** let you combine MySQL, PostgreSQL, Snowflake, and Delta Lake in one query
5. **Query pushdown** sends filters to external systems for better performance
6. **Access control** works the same as regular catalogs -- GRANT/REVOKE through Unity Catalog
7. **Read-only** -- federation does not support writing to external systems
8. **Use `secret()` function** to store connection passwords securely
9. **Federation is best for ad-hoc queries**; use ETL for production workloads with SLA requirements
10. **Drop order matters**: drop foreign catalog first, then the connection
