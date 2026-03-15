# Introduction to Data Governance

## Introduction

Alright, let's talk about data governance -- one of those topics that might sound dry at first
but is absolutely critical for any organization that takes its data seriously. As a data engineer,
you're not just building pipelines and transforming data. You're responsible for ensuring that
data is accurate, secure, discoverable, and compliant with regulations. Data governance is the
framework that makes all of that possible.

In the context of Databricks and the certification exam, data governance is primarily implemented
through **Unity Catalog** -- which we covered earlier. But this section goes deeper into the
governance concepts themselves and how Databricks provides the tooling to implement them.

## What Is Data Governance?

Data governance is a set of policies, processes, and standards that ensure an organization's
data is managed properly throughout its lifecycle. It answers fundamental questions about your
data:

```
Core Data Governance Questions:

┌──────────────────────────────────────────────────────────────┐
│                                                              │
│  WHO can access this data?          → Access Control         │
│                                                              │
│  WHAT data do we have?              → Data Discovery         │
│                                                              │
│  WHERE did this data come from?     → Lineage                │
│                                                              │
│  WHEN was this data last updated?   → Audit Trails           │
│                                                              │
│  HOW is this data being used?       → Usage Monitoring       │
│                                                              │
│  WHY does this data look this way?  → Data Quality           │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## The Four Pillars of Data Governance

```
Four Pillars of Data Governance:

┌────────────────┐  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐
│   DATA         │  │   DATA         │  │   DATA         │  │   DATA         │
│   ACCESS       │  │   DISCOVERY    │  │   LINEAGE &    │  │   QUALITY      │
│   CONTROL      │  │                │  │   AUDIT        │  │                │
│                │  │                │  │                │  │                │
│ - Who can read │  │ - What tables  │  │ - Where did    │  │ - Is the data  │
│   or write?    │  │   exist?       │  │   data come    │  │   accurate?    │
│ - Fine-grained │  │ - What do they │  │   from?        │  │ - Is it         │
│   permissions  │  │   contain?     │  │ - Who changed  │  │   complete?    │
│ - Row/column   │  │ - Tags and     │  │   it and when? │  │ - Does it meet │
│   level        │  │   metadata     │  │ - What depends │  │   standards?   │
│                │  │ - Search       │  │   on it?       │  │                │
└────────────────┘  └────────────────┘  └────────────────┘  └────────────────┘
```

### 1. Data Access Control

Controlling who can access what data is the foundation of governance:

```
Access Control Levels:

Coarse-grained:
  → Catalog-level: GRANT USE CATALOG ON catalog_name TO group
  → Schema-level:  GRANT USE SCHEMA ON schema_name TO group
  → Table-level:   GRANT SELECT ON table_name TO group

Fine-grained:
  → Column-level:  Column masks (hide sensitive columns)
  → Row-level:     Row filters (users see only their data)

Example hierarchy:
  catalog: production
    └── schema: finance
        └── table: transactions
            ├── column: customer_name  → Masked for analysts
            ├── column: amount         → Visible to all
            └── rows: region='US'      → Filtered by user's region
```

### 2. Data Discovery

Making data findable is essential. If people can't find data, they'll create duplicates or
make decisions without it:

```
Data Discovery Features in Databricks:

┌─────────────────────────┬──────────────────────────────────────┐
│ Feature                 │ How It Helps                         │
├─────────────────────────┼──────────────────────────────────────┤
│ Unity Catalog search    │ Search across all tables, views,     │
│                         │ functions by name or description     │
├─────────────────────────┼──────────────────────────────────────┤
│ Table comments          │ Describe what a table contains       │
│                         │ and how it should be used            │
├─────────────────────────┼──────────────────────────────────────┤
│ Column comments         │ Describe individual columns          │
│                         │ (business meaning, units, etc.)      │
├─────────────────────────┼──────────────────────────────────────┤
│ Tags                    │ Label tables and columns with        │
│                         │ key-value metadata (e.g., PII,       │
│                         │ classification, owner)               │
├─────────────────────────┼──────────────────────────────────────┤
│ Data Explorer UI        │ Browse catalogs, schemas, tables     │
│                         │ visually in the Databricks workspace │
└─────────────────────────┴──────────────────────────────────────┘
```

### 3. Data Lineage and Audit

Knowing where data came from and who touched it:

```
Data Lineage Example:

  S3 files → bronze_orders → silver_orders → gold_revenue
                                                  │
                                                  ▼
                                           dashboard_v2

Lineage answers:
  "If I change bronze_orders, what downstream tables are affected?"
  "Where does gold_revenue get its data from?"
  "Who queried this table last week?"
```

### 4. Data Quality

Ensuring data meets defined standards:

```
Data Quality Mechanisms in Databricks:

1. DLT Expectations (covered in Section 14)
   → @dlt.expect, @dlt.expect_or_drop, @dlt.expect_or_fail

2. Table Constraints
   → ALTER TABLE ADD CONSTRAINT check_positive CHECK (amount > 0)

3. Schema Enforcement (Delta Lake)
   → Prevents writing data with wrong schema

4. NOT NULL Constraints
   → Column-level nullability enforcement
```

## Why Data Governance Matters

```
Without Governance:                 With Governance:

❌ Anyone can access any data       ✓ Role-based access control
❌ No one knows what data exists    ✓ Searchable data catalog
❌ Can't trace data issues          ✓ Full lineage tracking
❌ Compliance violations (GDPR,     ✓ Audit trails for regulators
   HIPAA, SOX)
❌ Duplicate/conflicting data       ✓ Single source of truth
❌ Shadow IT and ungoverned copies  ✓ Centralized management
```

## Governance in Databricks: Unity Catalog

Unity Catalog is Databricks' answer to data governance. It provides a unified governance layer
across all data assets:

```
Unity Catalog Governance Stack:

┌──────────────────────────────────────────────────────────┐
│                    UNITY CATALOG                         │
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │ Centralized Access Control                        │  │
│  │ (GRANT/REVOKE, groups, row/column security)       │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │ Data Discovery & Catalog                          │  │
│  │ (Search, tags, comments, Data Explorer)           │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │ Audit Logging                                     │  │
│  │ (Who accessed what, when, from where)             │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │ Data Lineage                                      │  │
│  │ (Automatic upstream/downstream tracking)          │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │ Three-Level Namespace                             │  │
│  │ (catalog.schema.table)                            │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

## Key Exam Points

1. **Data governance** covers access control, data discovery, lineage/audit, and data quality
2. **Unity Catalog** is Databricks' unified governance solution for all data and AI assets
3. **Access control** operates at multiple levels: catalog, schema, table, column, and row
4. **Data discovery** uses table/column comments, tags, and the Data Explorer UI
5. **Data lineage** automatically tracks upstream and downstream dependencies
6. **Audit logging** records who accessed what data, when, and from which workspace
7. **Data quality** is enforced through DLT expectations, Delta Lake schema enforcement,
   and table constraints
8. **Compliance** (GDPR, HIPAA, etc.) requires governance controls -- this is a key business
   driver
9. **Three-level namespace** (catalog.schema.table) is the organizational backbone
10. **Governance applies to all assets** -- tables, views, functions, models, volumes, and
    connections
