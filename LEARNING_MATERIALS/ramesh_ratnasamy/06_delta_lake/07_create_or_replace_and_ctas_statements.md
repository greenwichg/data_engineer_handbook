# Create or Replace & CTAS Statements

## Introduction

Alright, in this lesson we're going to look at two very powerful patterns for creating Delta tables:
**CREATE OR REPLACE TABLE** and **CREATE TABLE AS SELECT (CTAS)**. These are not just convenience
features -- they represent fundamentally different approaches to table creation and data loading that
you'll use constantly in production pipelines.

CREATE OR REPLACE is about idempotency -- making your table creation operations safe to re-run.
CTAS is about creating tables from query results, which is incredibly useful for transformations
and derived datasets. Let's dig into both.

## CREATE OR REPLACE TABLE (CORT)

CREATE OR REPLACE TABLE is exactly what it sounds like -- it creates a table if it doesn't exist, or
completely replaces it if it does. This is an atomic operation, which is key. It doesn't drop and
recreate the table in two steps; it does it in one transaction.

### Basic Syntax

```sql
-- Create or Replace with explicit schema
CREATE OR REPLACE TABLE employees (
    id INT,
    name STRING,
    department STRING,
    salary DOUBLE
);

-- If 'employees' doesn't exist -> creates it
-- If 'employees' exists -> replaces it (atomically)
```

### Why Use CREATE OR REPLACE?

```
+====================================================================+
|              CREATE OR REPLACE vs DROP + CREATE                     |
+====================================================================+
|                                                                    |
|  CREATE OR REPLACE                 DROP TABLE + CREATE TABLE       |
|  ─────────────────                 ─────────────────────────       |
|                                                                    |
|  - Single atomic operation         - Two separate operations       |
|  - Table history is preserved      - Table history is LOST         |
|  - Retains the table directory     - Directory may be deleted      |
|    and _delta_log                    and recreated                  |
|  - Safe to re-run (idempotent)     - Not atomic (can fail between  |
|  - Maintains table permissions       DROP and CREATE)              |
|    in Unity Catalog               - Permissions may be lost        |
|                                                                    |
+====================================================================+
```

This is a critical interview point. CREATE OR REPLACE is **not** the same as DROP TABLE followed by
CREATE TABLE. When you use CREATE OR REPLACE:

1. The table retains its history (previous versions in the transaction log)
2. Table-level permissions in Unity Catalog are preserved
3. The operation is atomic -- it either succeeds completely or fails completely
4. It's safe to re-run in an ETL pipeline without worrying about downstream failures

### CREATE OR REPLACE with Data

```sql
-- Replace with data from a query
CREATE OR REPLACE TABLE department_summary AS
SELECT
    department,
    COUNT(*) as employee_count,
    AVG(salary) as avg_salary,
    MAX(salary) as max_salary
FROM employees
GROUP BY department;
```

## CREATE TABLE AS SELECT (CTAS)

CTAS creates a new table and populates it with the results of a SELECT query. The schema of the
new table is **inferred from the query results** -- you don't specify column definitions.

### Basic Syntax

```sql
-- Basic CTAS
CREATE TABLE active_employees AS
SELECT id, name, department, salary
FROM employees
WHERE status = 'ACTIVE';
```

### Key Characteristics of CTAS

```
CTAS Operation Flow:

+-------------------------------------------+
|  1. Execute the SELECT query              |
|     - Run the query against source tables |
|     - Compute the result set              |
+-------------------------------------------+
            |
            v
+-------------------------------------------+
|  2. Infer schema from query results       |
|     - Column names from SELECT aliases    |
|     - Column types from expressions       |
|     - No manual schema definition needed  |
+-------------------------------------------+
            |
            v
+-------------------------------------------+
|  3. Create new Delta table                |
|     - Register in metastore               |
|     - Create _delta_log/                  |
|     - Write data as Parquet files         |
|     - Single atomic transaction           |
+-------------------------------------------+
```

### CTAS with Additional Options

```sql
-- CTAS with table properties and partitioning
CREATE TABLE monthly_sales
USING DELTA
PARTITIONED BY (sale_month)
COMMENT 'Monthly aggregated sales data'
TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true'
)
AS
SELECT
    product_category,
    DATE_TRUNC('MONTH', sale_date) AS sale_month,
    SUM(amount) AS total_amount,
    COUNT(*) AS transaction_count
FROM raw_sales
GROUP BY product_category, DATE_TRUNC('MONTH', sale_date);
```

### CTAS Limitations

CTAS has an important limitation -- you **cannot** specify column-level constraints or column
comments in the CTAS statement itself. The schema is entirely inferred from the SELECT query.

```sql
-- THIS DOES NOT WORK:
CREATE TABLE my_table (
    id INT NOT NULL,           -- Can't add NOT NULL in CTAS
    name STRING COMMENT 'x'   -- Can't add comments in CTAS
) AS SELECT id, name FROM source;

-- Instead, do CTAS first, then alter:
CREATE TABLE my_table AS SELECT id, name FROM source;
ALTER TABLE my_table ALTER COLUMN id SET NOT NULL;
ALTER TABLE my_table ALTER COLUMN name COMMENT 'Employee name';
```

## CREATE TABLE IF NOT EXISTS

This is a defensive pattern that only creates the table if it doesn't already exist. If the table
exists, the statement is a no-op -- nothing happens, no error is raised.

```sql
-- Only creates if it doesn't exist
CREATE TABLE IF NOT EXISTS employees (
    id INT,
    name STRING,
    department STRING,
    salary DOUBLE
);
```

### Comparison of Table Creation Patterns

| Statement | Table Exists? | Behavior |
|-----------|--------------|----------|
| `CREATE TABLE` | No | Creates table |
| `CREATE TABLE` | Yes | **Error** |
| `CREATE TABLE IF NOT EXISTS` | No | Creates table |
| `CREATE TABLE IF NOT EXISTS` | Yes | No-op (no error) |
| `CREATE OR REPLACE TABLE` | No | Creates table |
| `CREATE OR REPLACE TABLE` | Yes | Replaces table atomically |

## Using PySpark Equivalents

### DataFrame Write Modes

The PySpark DataFrame API provides equivalent functionality through write modes:

```python
# Equivalent of CREATE TABLE (fails if exists)
df.write.format("delta").saveAsTable("my_table")  # mode defaults to "error"

# Equivalent of CREATE OR REPLACE TABLE
df.write.format("delta").mode("overwrite").saveAsTable("my_table")

# Equivalent of CREATE TABLE IF NOT EXISTS (append if exists)
df.write.format("delta").mode("ignore").saveAsTable("my_table")

# Append data to existing table
df.write.format("delta").mode("append").saveAsTable("my_table")
```

### Write Modes Summary

| PySpark Mode | SQL Equivalent | Behavior |
|-------------|----------------|----------|
| `"error"` (default) | `CREATE TABLE` | Fails if table exists |
| `"overwrite"` | `CREATE OR REPLACE` | Replaces table |
| `"ignore"` | `CREATE TABLE IF NOT EXISTS` | No-op if exists |
| `"append"` | `INSERT INTO` | Adds data to existing table |

## Combining Patterns: CREATE OR REPLACE TABLE AS SELECT

The most powerful combination is CREATE OR REPLACE TABLE AS SELECT, often called CORTAS. This
creates or replaces a table with query results in a single atomic operation.

```sql
-- Full CORTAS example
CREATE OR REPLACE TABLE gold_customer_metrics AS
SELECT
    c.customer_id,
    c.customer_name,
    COUNT(o.order_id) AS total_orders,
    SUM(o.amount) AS total_spent,
    AVG(o.amount) AS avg_order_value,
    MAX(o.order_date) AS last_order_date
FROM silver_customers c
JOIN silver_orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.customer_name;
```

This is the go-to pattern for building gold-layer tables in the medallion architecture. Every time
the pipeline runs, the table is atomically replaced with the latest aggregated data.

---

## CONCEPT GAP: Deep Copy vs Shallow Copy

When creating tables from existing tables, you can use either a deep copy or a shallow copy:

**Deep Copy (CTAS):**
```sql
-- Creates a full, independent copy of the data
CREATE TABLE employees_backup AS
SELECT * FROM employees;
```
This copies ALL data files to the new table location. The new table is completely independent.

**Shallow Clone:**
```sql
-- Creates a lightweight copy that references source data files
CREATE TABLE employees_dev SHALLOW CLONE employees;
```
A shallow clone doesn't copy the data files. It creates new metadata that references the source
table's files. This is fast and space-efficient for testing and development. But if the source
table's files are vacuumed, the shallow clone may lose access to those files.

**Deep Clone:**
```sql
-- Creates a full copy including data files and metadata
CREATE TABLE employees_archive DEEP CLONE employees;
```
A deep clone copies all data files and metadata. It's a full, independent copy that includes
the table's history and properties.

---

## KEY INTERVIEW QUESTIONS AND ANSWERS

### Q1: What is the difference between CREATE OR REPLACE TABLE and DROP + CREATE TABLE?
**A:** CREATE OR REPLACE TABLE is a single atomic operation that preserves table history in the transaction log and retains table-level permissions in Unity Catalog. DROP + CREATE TABLE is two separate operations that destroys all table history and may lose permissions, and it's not atomic -- a failure between the two statements leaves the table in a broken state.

### Q2: What is CTAS and what are its limitations?
**A:** CTAS (CREATE TABLE AS SELECT) creates a new table and populates it with the results of a SELECT query. The schema is inferred from the query results. Its main limitation is that you cannot specify column-level constraints (NOT NULL, CHECK) or column comments directly in the CTAS statement -- you must alter the table after creation.

### Q3: What happens if you run CREATE TABLE on a table that already exists?
**A:** The statement fails with an error. To avoid this, use CREATE TABLE IF NOT EXISTS (which silently does nothing if the table exists) or CREATE OR REPLACE TABLE (which atomically replaces the existing table).

### Q4: What are the PySpark write modes and their SQL equivalents?
**A:** The four modes are: "error" (default, equivalent to CREATE TABLE -- fails if exists), "overwrite" (equivalent to CREATE OR REPLACE -- replaces table), "ignore" (equivalent to CREATE TABLE IF NOT EXISTS -- no-op if exists), and "append" (equivalent to INSERT INTO -- adds data to existing table).

### Q5: What is the difference between a shallow clone and a deep clone?
**A:** A shallow clone creates new metadata that references the source table's data files without copying them -- it's fast and space-efficient but dependent on the source files. A deep clone copies all data files and metadata to create a fully independent copy. Shallow clones are ideal for development and testing, while deep clones are used for backups and archival.

### Q6: Why is CREATE OR REPLACE TABLE preferred in ETL pipelines?
**A:** CREATE OR REPLACE TABLE is preferred because it's idempotent (safe to re-run), atomic (all-or-nothing), preserves table history for time travel, maintains permissions, and doesn't leave the table in a broken state if the operation fails. This makes pipelines more resilient and reliable.

### Q7: Can you add partitioning and table properties to a CTAS statement?
**A:** Yes, you can add PARTITIONED BY, TBLPROPERTIES, USING DELTA, COMMENT, and LOCATION clauses to a CTAS statement. The only things you cannot specify are column-level constraints (NOT NULL, CHECK) and column comments -- those must be added with ALTER TABLE after creation.

---
