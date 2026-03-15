# Delta Lake Table & Column Properties

## Introduction

Welcome back. Now that we know how to create Delta Lake tables, let's talk about something that
gives you fine-grained control over how your tables behave -- table properties and column properties.
These are configurations that you set on your Delta tables to control things like auto-optimization,
data retention, schema enforcement, column constraints, and more. Understanding these properties is
crucial for both the certification exam and real-world data engineering.

Think of table properties as knobs and switches that control how Delta Lake manages your data. And
column properties let you add constraints and metadata to individual columns. Together, they give
you powerful control over data quality and table behavior.

## Table Properties Overview

Table properties are key-value pairs that you set on a Delta table to configure its behavior. You
can set them when creating a table or alter them later.

```
+====================================================================+
|                    TABLE PROPERTIES                                 |
+====================================================================+
|                                                                    |
|  +----------------------------+  +-------------------------------+ |
|  |   DELTA-SPECIFIC           |  |   GENERAL TABLE               | |
|  |   PROPERTIES               |  |   PROPERTIES                  | |
|  |                            |  |                               | |
|  |  delta.autoOptimize.*      |  |  comment                     | |
|  |  delta.logRetentionDuration|  |  owner                       | |
|  |  delta.deletedFileRet...   |  |  tags                        | |
|  |  delta.enableChangeData... |  |  custom key-value pairs      | |
|  |  delta.minReaderVersion    |  |                               | |
|  |  delta.minWriterVersion    |  |                               | |
|  |                            |  |                               | |
|  +----------------------------+  +-------------------------------+ |
|                                                                    |
+====================================================================+
```

## Setting Table Properties

### At Table Creation Time

```sql
-- Setting table properties during creation
CREATE TABLE sales (
    order_id INT,
    product STRING,
    amount DOUBLE,
    order_date DATE
)
TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact' = 'true',
    'delta.logRetentionDuration' = 'interval 60 days',
    'delta.deletedFileRetentionDuration' = 'interval 14 days'
);
```

### Altering Table Properties After Creation

```sql
-- Add or modify a table property
ALTER TABLE sales SET TBLPROPERTIES (
    'delta.enableChangeDataFeed' = 'true'
);

-- Remove a table property
ALTER TABLE sales UNSET TBLPROPERTIES ('delta.enableChangeDataFeed');
```

### Viewing Table Properties

```sql
-- Show all table properties
SHOW TBLPROPERTIES sales;

-- Show a specific table property
SHOW TBLPROPERTIES sales ('delta.autoOptimize.optimizeWrite');

-- Describe extended shows properties along with other metadata
DESCRIBE EXTENDED sales;

-- Describe detail gives storage-level details
DESCRIBE DETAIL sales;
```

## Key Delta Table Properties

### Auto-Optimization Properties

These properties control automatic file optimization. They're extremely important for write-heavy
workloads where small files can accumulate.

| Property | Description | Default |
|----------|-------------|---------|
| `delta.autoOptimize.optimizeWrite` | Coalesces small files during writes | `false` |
| `delta.autoOptimize.autoCompact` | Automatically compacts small files after writes | `false` |

```sql
-- Enable auto-optimization
ALTER TABLE my_table SET TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact' = 'true'
);
```

### Data Retention Properties

These properties control how long historical data and log files are kept.

| Property | Description | Default |
|----------|-------------|---------|
| `delta.logRetentionDuration` | How long transaction log entries are kept | `interval 30 days` |
| `delta.deletedFileRetentionDuration` | How long deleted data files are kept before VACUUM can remove them | `interval 7 days` |

```sql
-- Set retention periods
ALTER TABLE my_table SET TBLPROPERTIES (
    'delta.logRetentionDuration' = 'interval 90 days',
    'delta.deletedFileRetentionDuration' = 'interval 30 days'
);
```

**Important**: `delta.deletedFileRetentionDuration` controls the safety threshold for VACUUM. If
you set this too low, you might vacuum files that active readers still need.

### Change Data Feed

```sql
-- Enable Change Data Feed
ALTER TABLE my_table SET TBLPROPERTIES (
    'delta.enableChangeDataFeed' = 'true'
);
```

When enabled, Delta Lake records change data (inserts, updates, deletes) that can be read
incrementally. This is essential for CDC (Change Data Capture) pipelines.

### Protocol Version Properties

| Property | Description |
|----------|-------------|
| `delta.minReaderVersion` | Minimum reader protocol version required |
| `delta.minWriterVersion` | Minimum writer protocol version required |

These control which Delta Lake features are available. Higher versions enable newer features
but require compatible readers and writers.

## Column Properties

Column properties let you add constraints, comments, and metadata to individual columns.

### Column Comments

```sql
-- Add comments to columns during table creation
CREATE TABLE employees (
    id INT COMMENT 'Unique employee identifier',
    name STRING COMMENT 'Full name of the employee',
    department STRING COMMENT 'Department code',
    salary DOUBLE COMMENT 'Annual salary in USD',
    hire_date DATE COMMENT 'Date the employee was hired'
);

-- Add or modify a column comment after creation
ALTER TABLE employees ALTER COLUMN salary COMMENT 'Annual base salary in USD';
```

### NOT NULL Constraints

```sql
-- Define NOT NULL constraints at creation
CREATE TABLE orders (
    order_id INT NOT NULL,
    customer_id INT NOT NULL,
    product STRING,
    amount DOUBLE NOT NULL,
    order_date DATE NOT NULL
);

-- Add NOT NULL constraint to an existing column
ALTER TABLE orders ALTER COLUMN product SET NOT NULL;

-- Remove NOT NULL constraint
ALTER TABLE orders ALTER COLUMN product DROP NOT NULL;
```

### CHECK Constraints

CHECK constraints let you define data quality rules at the table level. Any row that violates a
CHECK constraint will be rejected.

```sql
-- Add a CHECK constraint
ALTER TABLE employees ADD CONSTRAINT salary_positive CHECK (salary > 0);
ALTER TABLE employees ADD CONSTRAINT valid_department CHECK (department IN ('ENG', 'HR', 'FIN', 'MKT'));

-- Drop a CHECK constraint
ALTER TABLE employees DROP CONSTRAINT salary_positive;
```

```
CHECK Constraint Enforcement Flow:

+-------------------------------------------+
|  INSERT/UPDATE Operation                  |
+-------------------------------------------+
            |
            v
+-------------------------------------------+
|  Evaluate CHECK Constraints               |
|                                           |
|  salary > 0?          ──> YES ──> PASS    |
|                        ──> NO  ──> REJECT |
|                                           |
|  department IN (...)? ──> YES ──> PASS    |
|                        ──> NO  ──> REJECT |
+-------------------------------------------+
            |
     All constraints pass?
            |
     YES    |     NO
      |     |      |
      v            v
+----------+  +-----------+
|  COMMIT  |  |  ABORT    |
|  Write   |  |  with     |
|          |  |  error    |
+----------+  +-----------+
```

### DEFAULT Values

```sql
-- Define default values for columns
CREATE TABLE events (
    event_id INT,
    event_type STRING,
    created_at TIMESTAMP DEFAULT current_timestamp(),
    status STRING DEFAULT 'PENDING',
    priority INT DEFAULT 0
);
```

When you insert a row without specifying values for columns with defaults, the default
values are automatically applied.

## Column Type Evolution

Delta Lake supports changing column types through schema evolution. This can be enabled
with a table property:

```sql
-- Enable column type widening
ALTER TABLE my_table SET TBLPROPERTIES (
    'delta.enableTypeWidening' = 'true'
);

-- Now you can widen column types
ALTER TABLE my_table ALTER COLUMN id TYPE BIGINT;  -- INT -> BIGINT
ALTER TABLE my_table ALTER COLUMN amount TYPE DOUBLE;  -- FLOAT -> DOUBLE
```

**Type widening only works in one direction** -- you can widen a type (INT to BIGINT, FLOAT
to DOUBLE) but you cannot narrow it.

## Table Comments

```sql
-- Add a comment to the table itself
CREATE TABLE sales (
    order_id INT,
    product STRING,
    amount DOUBLE
) COMMENT 'Contains all sales transactions for the company';

-- Modify table comment
ALTER TABLE sales SET TBLPROPERTIES ('comment' = 'Updated sales transactions table');

-- Or use the COMMENT ON syntax
COMMENT ON TABLE sales IS 'All sales transactions since 2020';
```

---

## CONCEPT GAP: DESCRIBE Commands for Table Inspection

Understanding the various DESCRIBE commands is important for working with table and column
properties:

| Command | What It Shows |
|---------|---------------|
| `DESCRIBE TABLE table_name` | Column names, types, and comments |
| `DESCRIBE EXTENDED table_name` | Everything above plus table properties, location, provider |
| `DESCRIBE DETAIL table_name` | Storage-level details: location, number of files, size, partitioning |
| `SHOW TBLPROPERTIES table_name` | All table properties as key-value pairs |
| `DESCRIBE HISTORY table_name` | Transaction history with versions, timestamps, and operations |

```sql
-- Quick reference for inspecting a Delta table
DESCRIBE TABLE employees;          -- Schema info
DESCRIBE EXTENDED employees;       -- Schema + metadata + properties
DESCRIBE DETAIL employees;         -- Storage details
SHOW TBLPROPERTIES employees;      -- All properties
DESCRIBE HISTORY employees;        -- Version history
SHOW CREATE TABLE employees;       -- Full CREATE TABLE statement
```

---

## KEY INTERVIEW QUESTIONS AND ANSWERS

### Q1: What are table properties in Delta Lake and how do you set them?
**A:** Table properties are key-value configuration pairs that control Delta table behavior such as auto-optimization, data retention, and change data feed. You set them using the TBLPROPERTIES clause during CREATE TABLE or modify them using ALTER TABLE SET TBLPROPERTIES.

### Q2: What is the difference between `delta.logRetentionDuration` and `delta.deletedFileRetentionDuration`?
**A:** `delta.logRetentionDuration` controls how long transaction log entries are retained (default 30 days) and affects time travel availability. `delta.deletedFileRetentionDuration` controls the minimum age of deleted files before VACUUM can remove them (default 7 days), serving as a safety threshold for concurrent readers.

### Q3: What types of column constraints does Delta Lake support?
**A:** Delta Lake supports NOT NULL constraints (enforced at the column level), CHECK constraints (table-level data validation rules using expressions), and DEFAULT values (automatically applied when no value is specified during insert). These constraints are enforced on every write operation.

### Q4: How do you enable Change Data Feed on a Delta table?
**A:** You enable Change Data Feed by setting the table property: `ALTER TABLE my_table SET TBLPROPERTIES ('delta.enableChangeDataFeed' = 'true')`. Once enabled, Delta Lake records row-level changes (inserts, updates, deletes) that can be queried incrementally.

### Q5: What are the auto-optimization properties in Delta Lake?
**A:** The two auto-optimization properties are `delta.autoOptimize.optimizeWrite` (coalesces small files during write operations) and `delta.autoOptimize.autoCompact` (automatically triggers compaction after writes). Both default to false and can be enabled at the table level.

### Q6: What is column type widening in Delta Lake?
**A:** Column type widening allows you to change a column's data type to a wider type (e.g., INT to BIGINT, FLOAT to DOUBLE). It's enabled with the `delta.enableTypeWidening` table property. Type widening only works in one direction -- you can widen but not narrow types.

### Q7: What is the difference between DESCRIBE EXTENDED and DESCRIBE DETAIL?
**A:** DESCRIBE EXTENDED shows schema information along with table metadata and properties (like table type, location, provider, and all TBLPROPERTIES). DESCRIBE DETAIL shows storage-level details like the physical location, number of files, total size in bytes, partitioning columns, and creation timestamp.

### Q8: How do CHECK constraints work in Delta Lake?
**A:** CHECK constraints define data quality rules using boolean expressions. They are added with `ALTER TABLE ADD CONSTRAINT name CHECK (expression)`. Every INSERT or UPDATE operation evaluates the constraints, and if any row violates a constraint, the entire operation is aborted with an error. They can be dropped with ALTER TABLE DROP CONSTRAINT.

---
