# Introduction to Lakehouse Federation

## Introduction

Alright, let's shift gears and talk about Lakehouse Federation. While Delta Sharing is about
sharing your Databricks data with others, Lakehouse Federation is about the opposite direction --
bringing external data INTO Databricks. In the real world, organizations have data spread across
many different systems: MySQL databases, PostgreSQL, SQL Server, Snowflake, BigQuery, Redshift,
and more. Traditionally, if you wanted to query that data from Databricks, you'd need to build
ETL pipelines to copy the data into Delta Lake first. That takes time, costs money, and creates
stale copies.

Lakehouse Federation solves this by letting you query external databases directly from Databricks
without moving the data. You create a connection to the external system, register it in Unity
Catalog, and then query it using standard SQL -- just like any other table in your lakehouse.

## What Is Lakehouse Federation?

```
Lakehouse Federation:

┌──────────────────────────────────────────────────────────────────┐
│                   LAKEHOUSE FEDERATION                            │
│                                                                  │
│   Query external databases directly from Databricks              │
│   WITHOUT copying or moving the data                             │
│                                                                  │
│   Key Properties:                                                │
│   - No data movement (query in place)                            │
│   - Unified governance through Unity Catalog                     │
│   - Standard SQL interface                                       │
│   - Read-only access to external systems                         │
│   - Supports multiple database engines                           │
│   - Central metadata management                                  │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## How It Works

```
Lakehouse Federation Architecture:

                    ┌────────────────────────────┐
                    │      DATABRICKS            │
                    │                            │
                    │  ┌──────────────────────┐  │
                    │  │   Unity Catalog      │  │
                    │  │                      │  │
                    │  │  ┌───────────────┐   │  │
                    │  │  │  CONNECTIONS  │   │  │
                    │  │  │  (credentials │   │  │
                    │  │  │   & endpoints)│   │  │
                    │  │  └───────┬───────┘   │  │
                    │  │          │            │  │
                    │  │  ┌───────▼───────┐   │  │
                    │  │  │  FOREIGN      │   │  │
                    │  │  │  CATALOGS     │   │  │
                    │  │  │  (metadata    │   │  │
                    │  │  │   wrappers)   │   │  │
                    │  │  └───────┬───────┘   │  │
                    │  │          │            │  │
                    │  └──────────┼────────────┘  │
                    │             │                │
                    │    SQL Warehouse /           │
                    │    All-Purpose Cluster       │
                    │             │                │
                    └─────────────┼────────────────┘
                                  │
                    ┌─────────────┼─────────────────┐
                    │             │                  │
              ┌─────▼──────┐ ┌───▼────────┐ ┌──────▼───────┐
              │  MySQL     │ │ PostgreSQL │ │ Snowflake    │
              │            │ │            │ │              │
              │ customers  │ │ orders     │ │ analytics    │
              │ products   │ │ payments   │ │ reports      │
              └────────────┘ └────────────┘ └──────────────┘

              External databases (data stays in place)
```

## Supported External Systems

```
Supported Data Sources:

┌────────────────────────────────────────────────────────────────┐
│                                                                │
│  Relational Databases:                                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐  │
│  │  MySQL   │ │PostgreSQL│ │SQL Server│ │ Oracle           │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────────┘  │
│                                                                │
│  Cloud Data Warehouses:                                        │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────────┐  │
│  │Snowflake │ │ BigQuery │ │ Redshift │ │ Azure Synapse    │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────────────┘  │
│                                                                │
│  Other:                                                        │
│  ┌──────────┐ ┌──────────────────────────────────────────────┐ │
│  │ Teradata │ │ Any JDBC-compatible database                 │ │
│  └──────────┘ └──────────────────────────────────────────────┘ │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

## Key Components

```
Lakehouse Federation Components:

┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  CONNECTION                                                      │
│  ├── Stores credentials and endpoint info for external system    │
│  ├── Securely managed by Unity Catalog                           │
│  ├── Contains: host, port, username, password                    │
│  └── One connection per external database                        │
│                                                                  │
│  FOREIGN CATALOG                                                 │
│  ├── A Unity Catalog object that mirrors external DB metadata    │
│  ├── Exposes external schemas and tables in UC namespace         │
│  ├── Tables appear as three-level namespace: catalog.schema.table│
│  └── Metadata is synced from the external system                 │
│                                                                  │
│  Relationship:                                                   │
│                                                                  │
│  CONNECTION ──referenced by──▶ FOREIGN CATALOG ──exposes──▶ TABLES│
│  (credentials)                (metadata wrapper)   (queryable)   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## Creating a Connection

```sql
-- Create a connection to a MySQL database
CREATE CONNECTION IF NOT EXISTS mysql_production
TYPE mysql
OPTIONS (
    host 'mysql-prod.company.com',
    port '3306',
    user 'databricks_reader',
    password secret('federation_scope', 'mysql_password')
);

-- Create a connection to PostgreSQL
CREATE CONNECTION IF NOT EXISTS postgres_orders
TYPE postgresql
OPTIONS (
    host 'postgres-orders.company.com',
    port '5432',
    user 'databricks_reader',
    password secret('federation_scope', 'postgres_password')
);

-- Create a connection to Snowflake
CREATE CONNECTION IF NOT EXISTS snowflake_analytics
TYPE snowflake
OPTIONS (
    host 'org-account.snowflakecomputing.com',
    user 'databricks_reader',
    password secret('federation_scope', 'snowflake_password'),
    sfWarehouse 'COMPUTE_WH'
);

-- View connections
SHOW CONNECTIONS;
```

## Creating a Foreign Catalog

```sql
-- Create a foreign catalog for the MySQL database
CREATE FOREIGN CATALOG IF NOT EXISTS mysql_prod
USING CONNECTION mysql_production
OPTIONS (database 'production_db');

-- Create a foreign catalog for PostgreSQL
CREATE FOREIGN CATALOG IF NOT EXISTS postgres_orders
USING CONNECTION postgres_orders
OPTIONS (database 'orders_db');

-- Create a foreign catalog for Snowflake
CREATE FOREIGN CATALOG IF NOT EXISTS snowflake_analytics
USING CONNECTION snowflake_analytics
OPTIONS (database 'ANALYTICS_DB');

-- View foreign catalogs
SHOW CATALOGS;
-- Foreign catalogs appear alongside regular catalogs
```

## Querying Federated Data

```sql
-- Query external MySQL data as if it were local
SELECT
    customer_id,
    customer_name,
    email
FROM mysql_prod.customers.customer_info
WHERE region = 'us-east'
LIMIT 100;

-- Join external data with local Delta Lake data
SELECT
    c.customer_name,
    o.order_id,
    o.order_total,
    d.lifetime_value
FROM mysql_prod.customers.customer_info c
JOIN postgres_orders.public.orders o
    ON c.customer_id = o.customer_id
JOIN production.analytics.customer_metrics d
    ON c.customer_id = d.customer_id
WHERE o.order_date >= '2025-01-01'
ORDER BY o.order_total DESC;

-- This single query joins data from:
-- 1. MySQL (customer info)
-- 2. PostgreSQL (orders)
-- 3. Delta Lake (customer metrics)
-- All without copying any data!
```

## Query Pushdown

```
Query Pushdown Optimization:

  When you run a federated query, Databricks optimizes it
  by pushing filters and projections to the external system.

  Your Query:
  SELECT customer_name, email
  FROM mysql_prod.customers.customer_info
  WHERE region = 'us-east' AND active = true;

  What Databricks sends to MySQL:
  SELECT customer_name, email
  FROM customer_info
  WHERE region = 'us-east' AND active = true;
                          ▲
                          │
          Filter pushed down to MySQL
          (only matching rows are transferred)

  Without pushdown:
  ┌──────────┐  ALL rows   ┌───────────┐  filter   ┌────────┐
  │  MySQL   │────────────▶│ Databricks│──────────▶│ Result │
  └──────────┘  (slow!)    └───────────┘           └────────┘

  With pushdown:
  ┌──────────┐  filtered   ┌───────────┐           ┌────────┐
  │  MySQL   │────────────▶│ Databricks│──────────▶│ Result │
  └──────────┘  rows only  └───────────┘           └────────┘
                (fast!)
```

## Governance with Unity Catalog

```
Federation Governance:

┌──────────────────────────────────────────────────────────────────┐
│                     UNITY CATALOG                                │
│                                                                  │
│  Manages ALL catalogs uniformly:                                 │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │ Regular      │  │ Foreign      │  │ Shared       │           │
│  │ Catalogs     │  │ Catalogs     │  │ Catalogs     │           │
│  │ (Delta Lake) │  │ (Federated)  │  │ (Delta Share)│           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│         │                 │                 │                     │
│         └─────────────────┼─────────────────┘                    │
│                           │                                      │
│                    Same governance:                               │
│                    - Access control (GRANT/REVOKE)                │
│                    - Audit logging                                │
│                    - Data lineage                                 │
│                    - Three-level namespace                        │
│                    - Consistent SQL interface                     │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘

-- Grant access to federated data
GRANT USE CATALOG ON CATALOG mysql_prod TO `analysts`;
GRANT USE SCHEMA ON SCHEMA mysql_prod.customers TO `analysts`;
GRANT SELECT ON TABLE mysql_prod.customers.customer_info TO `analysts`;
```

## Limitations

```
Lakehouse Federation Limitations:

┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  1. READ-ONLY access                                             │
│     - Cannot INSERT, UPDATE, or DELETE external data             │
│     - Can only SELECT from federated tables                      │
│                                                                  │
│  2. Performance depends on external system                       │
│     - Queries are limited by the external DB's capacity          │
│     - Large joins across systems can be slow                     │
│     - Network latency affects query speed                        │
│                                                                  │
│  3. Not all SQL features supported                               │
│     - Some Databricks SQL functions may not push down            │
│     - Complex operations may require local execution             │
│                                                                  │
│  4. Requires SQL Warehouse or All-Purpose Cluster                │
│     - Must use compute that supports federation                  │
│                                                                  │
│  5. Connection credentials must be maintained                    │
│     - Password changes in external system require                │
│       updating the connection                                    │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## Key Exam Points

1. **Lakehouse Federation** lets you query external databases from Databricks without moving data
2. **Two key objects**: Connection (credentials) and Foreign Catalog (metadata)
3. **Supported sources**: MySQL, PostgreSQL, SQL Server, Snowflake, BigQuery, Redshift, and more
4. **Three-level namespace** is preserved: foreign_catalog.schema.table
5. **Query pushdown** optimizes performance by sending filters to the external system
6. **Read-only access** -- you cannot modify data in external systems through federation
7. **Unity Catalog governs** federated data with the same access control as local data
8. **Cross-system joins** are possible -- join Delta Lake tables with external DB tables in one query
9. **Credentials are stored securely** using Databricks secrets in connection definitions
10. **Federation vs Delta Sharing**: Federation brings external data in; Delta Sharing pushes your data out
