# Databricks SQL Overview

## Introduction

Alright, let's talk about Databricks SQL -- or DBSQL as it's commonly called. This is the
Databricks persona designed for analysts, data engineers, and anyone who needs to run SQL
queries against data in the lakehouse. Think of it as a full SQL analytics environment built
on top of the Databricks Lakehouse Platform.

If you've used tools like AWS Redshift, Google BigQuery, or Snowflake, Databricks SQL serves
a similar purpose -- it provides a SQL-native interface for querying data, building
visualizations, and creating dashboards. But unlike those standalone data warehouses, DBSQL
queries data directly in your Delta Lake tables, which means there's no data copying or ETL
needed to make your data available for analytics. Your data engineers write data to Delta
tables, and analysts query them immediately through DBSQL.

## What Is Databricks SQL?

```
Databricks SQL Components:

┌──────────────────────────────────────────────────────────────┐
│                    DATABRICKS SQL                            │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                  SQL EDITOR                            │  │
│  │  Write and execute SQL queries in a web-based IDE      │  │
│  │  - Auto-complete, syntax highlighting                  │  │
│  │  - Query history and saved queries                     │  │
│  │  - Schema browser (Unity Catalog integration)          │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                SQL WAREHOUSES                          │  │
│  │  Managed compute clusters optimized for SQL workloads  │  │
│  │  - Auto-scaling, auto-start/stop                       │  │
│  │  - Photon engine for fast query execution              │  │
│  │  - Fully managed (no cluster configuration needed)     │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │           DASHBOARDS & VISUALIZATIONS                  │  │
│  │  Build charts, graphs, and dashboards from queries     │  │
│  │  - Multiple visualization types                        │  │
│  │  - Auto-refresh schedules                              │  │
│  │  - Parameterized queries                               │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                    ALERTS                              │  │
│  │  Automated notifications based on query results        │  │
│  │  - Threshold-based alerts                              │  │
│  │  - Email and webhook notifications                     │  │
│  │  - Scheduled evaluation                                │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

## Where DBSQL Fits in the Lakehouse

```
Databricks Lakehouse Architecture:

  ┌──────────────────────────────────────────────────────────┐
  │                   PERSONAS                               │
  │                                                          │
  │  ┌──────────┐  ┌──────────────┐  ┌──────────────────┐   │
  │  │ Data     │  │ Data         │  │ Machine          │   │
  │  │ Science  │  │ Engineering  │  │ Learning         │   │
  │  │          │  │              │  │                  │   │
  │  │ Notebooks│  │ Notebooks,  │  │ Notebooks,       │   │
  │  │ ML       │  │ Jobs, DLT   │  │ MLflow           │   │
  │  └────┬─────┘  └──────┬──────┘  └────────┬─────────┘   │
  │       │               │                  │              │
  │       ▼               ▼                  ▼              │
  │  ┌──────────────────────────────────────────────────┐   │
  │  │           ALL-PURPOSE CLUSTERS                   │   │
  │  │     (Interactive + Job compute)                  │   │
  │  └──────────────────────────────────────────────────┘   │
  │                                                          │
  │  ┌──────────────────────────────────────────────────┐   │
  │  │           DATABRICKS SQL                         │   │
  │  │                                                  │   │
  │  │  ┌──────────┐  Analysts, BI users               │   │
  │  │  │   SQL    │  SQL queries, dashboards           │   │
  │  │  │ Warehouse│  Visualizations, alerts            │   │
  │  │  └──────────┘                                    │   │
  │  └──────────────────────────────────────────────────┘   │
  │                       │                                  │
  │                       ▼                                  │
  │  ┌──────────────────────────────────────────────────┐   │
  │  │        UNITY CATALOG + DELTA LAKE                │   │
  │  │     (Shared governance and storage layer)        │   │
  │  └──────────────────────────────────────────────────┘   │
  └──────────────────────────────────────────────────────────┘
```

Key point: All personas -- data engineers, data scientists, analysts -- share the same
underlying data through Unity Catalog. DBSQL provides the SQL-optimized interface for
the analyst persona.

## DBSQL vs Traditional Data Warehouses

```
┌────────────────────────┬────────────────────┬────────────────────────┐
│ Feature                │ Traditional DW     │ Databricks SQL         │
│                        │ (Redshift, etc.)   │                        │
├────────────────────────┼────────────────────┼────────────────────────┤
│ Data storage           │ Proprietary format │ Open Delta Lake format │
│ Data copy needed       │ Yes (ETL to DW)    │ No (query in place)    │
│ Supports unstructured  │ Limited            │ Yes (via volumes)      │
│ ML integration         │ Limited            │ Native (same platform) │
│ Streaming support      │ Separate system    │ Same platform          │
│ Open format            │ Vendor lock-in     │ Delta Lake (open)      │
│ Governance             │ Separate system    │ Unity Catalog built-in │
│ Serverless option      │ Varies             │ Yes (serverless SQL)   │
└────────────────────────┴────────────────────┴────────────────────────┘
```

## The SQL Editor

The SQL Editor is the primary interface for writing and running queries:

```
SQL Editor Features:

┌──────────────────────────────────────────────────────────────┐
│ SQL Editor                                                   │
│                                                              │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ Schema Browser          │  Query Panel                  │ │
│  │                         │                               │ │
│  │ 📁 production           │  SELECT                       │ │
│  │   📁 finance            │    customer_id,               │ │
│  │     📊 transactions     │    SUM(amount) as total       │ │
│  │     📊 customers        │  FROM production.finance      │ │
│  │   📁 marketing          │       .transactions           │ │
│  │     📊 campaigns        │  GROUP BY customer_id         │ │
│  │                         │  ORDER BY total DESC          │ │
│  │                         │  LIMIT 100;                   │ │
│  └─────────────────────────┴───────────────────────────────┘ │
│                                                              │
│  Features:                                                   │
│  - Auto-complete for table/column names                      │
│  - Syntax highlighting and error detection                   │
│  - Multiple query tabs                                       │
│  - Query history (previously run queries)                    │
│  - Saved queries (share with team)                           │
│  - Parameterized queries ({{ parameter_name }})              │
│  - Keyboard shortcuts (Ctrl+Enter to run)                    │
└──────────────────────────────────────────────────────────────┘
```

### Parameterized Queries

```sql
-- Use double curly braces for parameters
SELECT *
FROM production.finance.transactions
WHERE region = '{{ region }}'
  AND transaction_date >= '{{ start_date }}'
  AND amount > {{ min_amount }}
ORDER BY transaction_date DESC;

-- When you run this query, DBSQL prompts for parameter values
-- Parameters can have default values and dropdown options
```

## Connecting External Tools

DBSQL supports standard SQL connectivity, so you can connect external BI tools:

```
Supported Connections:

┌──────────────────────────────────────────────────────┐
│                 SQL WAREHOUSE                        │
│                                                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │
│  │ JDBC     │  │ ODBC     │  │ REST API         │   │
│  │ Driver   │  │ Driver   │  │ (Databricks SQL  │   │
│  │          │  │          │  │  Statement API)  │   │
│  └────┬─────┘  └────┬─────┘  └────────┬─────────┘   │
│       │              │                 │             │
└───────┼──────────────┼─────────────────┼─────────────┘
        │              │                 │
        ▼              ▼                 ▼
   ┌─────────┐   ┌──────────┐    ┌───────────────┐
   │ Tableau │   │ Power BI │    │ Custom apps   │
   │ Looker  │   │ Excel    │    │ Python clients│
   │ dbt     │   │          │    │ REST calls    │
   └─────────┘   └──────────┘    └───────────────┘
```

## Key Exam Points

1. **Databricks SQL** is the SQL analytics persona of Databricks -- designed for analysts
   and BI users
2. **SQL Warehouses** are the managed compute for DBSQL -- separate from all-purpose clusters
3. **No data copying** -- DBSQL queries Delta Lake tables directly in the lakehouse
4. **Four main components**: SQL Editor, SQL Warehouses, Dashboards/Visualizations, Alerts
5. **Unity Catalog integration** -- DBSQL uses UC for governance, access control, and
   three-level namespace
6. **Parameterized queries** use `{{ parameter_name }}` syntax
7. **External BI tools** connect via JDBC/ODBC drivers
8. **Photon engine** accelerates SQL queries in DBSQL
9. **DBSQL shares the same data** as notebooks and jobs -- all through Unity Catalog
10. **Serverless SQL warehouses** are available for fully managed, instant-start compute
