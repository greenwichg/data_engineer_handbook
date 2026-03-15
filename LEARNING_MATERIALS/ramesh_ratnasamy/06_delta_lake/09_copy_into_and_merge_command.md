# COPY INTO and MERGE Command

## Introduction

Alright, in this lesson we're covering two of the most important commands in Delta Lake for
data ingestion and upserts -- **COPY INTO** and **MERGE**. These are commands you'll use constantly
in real-world data engineering pipelines.

COPY INTO is designed for incremental data ingestion from external file sources (like cloud storage
landing zones). MERGE is the go-to command for upserts -- combining inserts and updates (and even
deletes) into a single atomic operation. Both are essential for building reliable ETL/ELT pipelines
in Databricks.

## COPY INTO Command

COPY INTO is an idempotent command that loads data from a file location into a Delta table. The key
word here is **idempotent** -- if you run the same COPY INTO command multiple times, it will only
load files that haven't been loaded before. It tracks which files have already been processed and
skips them.

### Basic Syntax

```sql
COPY INTO my_table
FROM 's3://my-bucket/landing_zone/'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header' = 'true',
    'inferSchema' = 'true',
    'delimiter' = ','
)
COPY_OPTIONS (
    'mergeSchema' = 'true'
);
```

### How COPY INTO Works

```
COPY INTO Execution Flow:

+-------------------------------------------+
|  1. Scan source file location             |
|     - List all files in the source path   |
|     - Identify file format (CSV, JSON,    |
|       Parquet, Avro, etc.)                |
+-------------------------------------------+
            |
            v
+-------------------------------------------+
|  2. Check file tracking state             |
|     - Compare against previously loaded   |
|       files (tracked in table metadata)   |
|     - Filter out already-loaded files     |
+-------------------------------------------+
            |
            v
+-------------------------------------------+
|  3. Load NEW files only                   |
|     - Read and parse new files            |
|     - Apply format options                |
|     - Apply any schema mapping            |
+-------------------------------------------+
            |
            v
+-------------------------------------------+
|  4. Write to Delta table                  |
|     - Append new data                     |
|     - Update file tracking state          |
|     - Commit transaction                  |
+-------------------------------------------+
```

### Supported File Formats

| Format | FILEFORMAT Value | Common Use Case |
|--------|-----------------|-----------------|
| CSV | `CSV` | Flat file exports, legacy systems |
| JSON | `JSON` | API responses, log files |
| Parquet | `PARQUET` | Data lake transfers, efficient columnar |
| Avro | `AVRO` | Kafka consumers, schema evolution |
| ORC | `ORC` | Hive migrations |
| Text | `TEXT` | Raw log files |
| Binary | `BINARYFILE` | Images, documents |

### FORMAT_OPTIONS

```sql
-- CSV options
COPY INTO my_table
FROM '/landing/csv_files/'
FILEFORMAT = CSV
FORMAT_OPTIONS (
    'header' = 'true',
    'delimiter' = '|',
    'inferSchema' = 'true',
    'nullValue' = 'NA',
    'dateFormat' = 'yyyy-MM-dd'
);

-- JSON options
COPY INTO my_table
FROM '/landing/json_files/'
FILEFORMAT = JSON
FORMAT_OPTIONS (
    'multiLine' = 'true',
    'inferSchema' = 'true'
);
```

### COPY_OPTIONS

| Option | Description |
|--------|-------------|
| `mergeSchema` | Allow schema evolution when new files have additional columns |
| `force` | Re-load all files, ignoring file tracking (overrides idempotency) |

```sql
-- Force reload all files (ignore tracking)
COPY INTO my_table
FROM '/landing/csv_files/'
FILEFORMAT = CSV
FORMAT_OPTIONS ('header' = 'true')
COPY_OPTIONS ('force' = 'true');
```

### COPY INTO with Column Mapping

```sql
-- Select specific columns and rename them
COPY INTO my_table
FROM (
    SELECT
        _c0 AS id,
        _c1 AS name,
        _c2 AS email,
        current_timestamp() AS load_timestamp
    FROM '/landing/csv_files/'
)
FILEFORMAT = CSV
FORMAT_OPTIONS ('header' = 'false');
```

## COPY INTO vs Auto Loader

This is a very common interview question. Both COPY INTO and Auto Loader (Structured Streaming
with `cloudFiles`) are used for incremental file ingestion, but they have different strengths.

```
+====================================================================+
|          COPY INTO vs AUTO LOADER                                   |
+====================================================================+
|                                                                    |
|  COPY INTO                          AUTO LOADER                    |
|  ─────────                          ───────────                    |
|                                                                    |
|  - Batch-oriented                   - Streaming-oriented           |
|  - SQL command                      - PySpark Structured Streaming |
|  - Good for thousands of files      - Good for millions of files   |
|  - File tracking via table          - File tracking via            |
|    metadata                           RocksDB checkpoint           |
|  - Simpler to set up               - More scalable                |
|  - Re-scans directory each run     - Uses file notification        |
|                                       (event-driven)               |
|  - Best for periodic batch loads   - Best for near-real-time       |
|                                       ingestion                    |
|                                                                    |
+====================================================================+
```

**Rule of thumb**: Use COPY INTO when you have up to thousands of files arriving periodically.
Use Auto Loader when you have millions of files or need near-real-time ingestion.

## MERGE Command

MERGE is Delta Lake's implementation of the SQL MERGE (also called UPSERT) operation. It lets you
compare a source dataset against a target Delta table and perform different actions based on whether
rows match or not -- insert new rows, update existing rows, or delete rows, all in a single atomic
transaction.

### Basic MERGE Syntax

```sql
MERGE INTO target_table AS target
USING source_table AS source
ON target.id = source.id
WHEN MATCHED THEN
    UPDATE SET *
WHEN NOT MATCHED THEN
    INSERT *;
```

### MERGE Operation Flow

```
MERGE Execution Flow:

+-------------------------------------------+
|  SOURCE DATA        TARGET TABLE          |
|  (new/changed)      (existing Delta)      |
+-------------------------------------------+
            |                |
            v                v
+-------------------------------------------+
|  JOIN on merge condition                  |
|  (target.id = source.id)                  |
+-------------------------------------------+
            |
      +-----+-----+
      |           |
      v           v
+----------+ +-------------------+
| MATCHED  | | NOT MATCHED       |
| (exists  | | (new rows in      |
|  in both)| |  source only)     |
+----------+ +-------------------+
      |           |
      v           v
+----------+ +-------------------+
| UPDATE   | | INSERT            |
| or DELETE| | new rows          |
| existing | |                   |
+----------+ +-------------------+
```

### MERGE with All Clauses

```sql
MERGE INTO customers AS target
USING staging_customers AS source
ON target.customer_id = source.customer_id

-- When a match is found and the source has an active record
WHEN MATCHED AND source.status = 'ACTIVE' THEN
    UPDATE SET
        target.name = source.name,
        target.email = source.email,
        target.updated_at = current_timestamp()

-- When a match is found and the source has a deleted record
WHEN MATCHED AND source.status = 'DELETED' THEN
    DELETE

-- When no match is found in the target (new customer)
WHEN NOT MATCHED THEN
    INSERT (customer_id, name, email, status, created_at, updated_at)
    VALUES (source.customer_id, source.name, source.email, source.status,
            current_timestamp(), current_timestamp())

-- When no match is found in the source (customer not in source)
WHEN NOT MATCHED BY SOURCE THEN
    UPDATE SET target.status = 'INACTIVE';
```

### MERGE Clause Types

| Clause | When It Fires | Typical Action |
|--------|--------------|----------------|
| `WHEN MATCHED` | Row exists in both source and target | UPDATE or DELETE |
| `WHEN NOT MATCHED` | Row exists in source but not target | INSERT |
| `WHEN NOT MATCHED BY SOURCE` | Row exists in target but not source | UPDATE or DELETE |

### Using Wildcards with MERGE

The `*` syntax is a shorthand that maps all columns automatically:

```sql
-- UPDATE SET * updates all columns from source to target
-- INSERT * inserts all columns from source
MERGE INTO target AS t
USING source AS s
ON t.id = s.id
WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *;
```

**Important**: For `*` to work, the source and target must have the same schema (same column
names and compatible types).

### MERGE with Schema Evolution

```sql
-- Enable automatic schema evolution during MERGE
SET spark.databricks.delta.schema.autoMerge.enabled = true;

MERGE INTO target AS t
USING source AS s
ON t.id = s.id
WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *;
```

With schema auto-merge enabled, if the source has columns that don't exist in the target,
Delta Lake will automatically add those columns to the target table.

### MERGE in PySpark

```python
from delta.tables import DeltaTable

# Load the target Delta table
target_table = DeltaTable.forName(spark, "customers")

# Perform the merge
target_table.alias("target") \
    .merge(
        source_df.alias("source"),
        "target.customer_id = source.customer_id"
    ) \
    .whenMatchedUpdate(set={
        "name": "source.name",
        "email": "source.email",
        "updated_at": "current_timestamp()"
    }) \
    .whenNotMatchedInsert(values={
        "customer_id": "source.customer_id",
        "name": "source.name",
        "email": "source.email",
        "created_at": "current_timestamp()",
        "updated_at": "current_timestamp()"
    }) \
    .execute()
```

## SCD Type 2 with MERGE

MERGE is commonly used to implement Slowly Changing Dimension Type 2, where you track historical
changes by closing old records and inserting new versions.

```sql
MERGE INTO dim_customers AS target
USING (
    SELECT customer_id, name, email, address, 'ACTIVE' as status
    FROM staging_customers
) AS source
ON target.customer_id = source.customer_id AND target.status = 'ACTIVE'

WHEN MATCHED AND (
    target.name <> source.name OR
    target.email <> source.email OR
    target.address <> source.address
) THEN
    UPDATE SET
        target.status = 'INACTIVE',
        target.end_date = current_date()

WHEN NOT MATCHED THEN
    INSERT (customer_id, name, email, address, status, start_date, end_date)
    VALUES (source.customer_id, source.name, source.email, source.address,
            'ACTIVE', current_date(), NULL);
```

---

## CONCEPT GAP: DELETE and UPDATE Commands

Beyond MERGE, Delta Lake also supports standalone DELETE and UPDATE commands:

```sql
-- DELETE: Remove rows matching a condition
DELETE FROM employees WHERE status = 'TERMINATED' AND termination_date < '2024-01-01';

-- UPDATE: Modify rows matching a condition
UPDATE employees SET salary = salary * 1.05 WHERE department = 'Engineering';
```

Under the hood, both DELETE and UPDATE in Delta Lake work by:
1. Reading the affected Parquet files
2. Filtering out or modifying the relevant rows
3. Writing new Parquet files with the updated data
4. Adding a new commit to the transaction log that removes the old files and adds the new files

This is called **copy-on-write** -- Delta Lake doesn't modify files in place. It creates new files
and updates the transaction log. This is what enables time travel and ACID transactions.

---

## KEY INTERVIEW QUESTIONS AND ANSWERS

### Q1: What is COPY INTO and how is it different from a regular INSERT?
**A:** COPY INTO is an idempotent SQL command for incrementally loading data from external file locations into a Delta table. Unlike INSERT, it tracks which files have already been loaded and skips them on subsequent runs, preventing duplicate data. It supports various file formats (CSV, JSON, Parquet, Avro) and is designed for batch ingestion from landing zones.

### Q2: What is the difference between COPY INTO and Auto Loader?
**A:** COPY INTO is a batch SQL command that re-scans the directory on each run, suitable for up to thousands of files. Auto Loader uses Structured Streaming with event-driven file notification, suitable for millions of files with near-real-time ingestion. COPY INTO is simpler to set up while Auto Loader is more scalable.

### Q3: What is MERGE in Delta Lake and what are its use cases?
**A:** MERGE (also called UPSERT) compares a source dataset against a target Delta table and atomically performs conditional inserts, updates, and deletes in a single transaction. Common use cases include CDC processing, SCD Type 2 implementations, deduplication, and synchronizing data between systems.

### Q4: What are the different WHEN clauses available in MERGE?
**A:** MERGE supports three clause types: WHEN MATCHED (row exists in both source and target -- typically UPDATE or DELETE), WHEN NOT MATCHED (row in source but not target -- typically INSERT), and WHEN NOT MATCHED BY SOURCE (row in target but not source -- typically UPDATE or DELETE). Each clause can have additional conditions.

### Q5: How does MERGE handle schema evolution?
**A:** By enabling `spark.databricks.delta.schema.autoMerge.enabled = true`, MERGE can automatically add new columns from the source to the target table. This is useful when source data evolves over time with new fields that should be captured in the target table.

### Q6: What is the copy-on-write mechanism in Delta Lake?
**A:** Copy-on-write means Delta Lake never modifies existing Parquet files in place. For UPDATE, DELETE, and MERGE operations, it reads the affected files, applies the changes, writes new Parquet files, and updates the transaction log to remove old files and add new ones. This enables ACID transactions and time travel.

### Q7: How would you implement SCD Type 2 using MERGE?
**A:** Use MERGE with the match condition on the business key and active status. In the WHEN MATCHED clause, close the current record by setting status to INACTIVE and setting end_date. In the WHEN NOT MATCHED clause, insert the new version with status ACTIVE, start_date as current_date, and end_date as NULL. This preserves the full history of changes.

### Q8: What does the `force` option do in COPY INTO?
**A:** The `force` option in COPY_OPTIONS overrides COPY INTO's file tracking mechanism and reloads all files from the source location, regardless of whether they've been previously loaded. This is useful when you need to reprocess all source files, such as after a schema change or data correction.

---
