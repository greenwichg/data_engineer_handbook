# Create Delta Lake Table - Overview

## Introduction

Alright, let's talk about creating Delta Lake tables. This is where we move from understanding
what Delta Lake is to actually using it. If you've been following along, you know that Delta Lake
is an open-source storage layer that brings ACID transactions, schema enforcement, and time travel
to data lakes. But how do you actually create a Delta table? That's what we're covering in this
lesson -- the different ways to create Delta Lake tables and the key concepts behind each approach.

In Databricks, Delta is the default table format. So when you create a table without specifying a
format, you're creating a Delta table. But it's important to understand exactly what's happening
under the hood and the different ways you can go about it.

## Types of Delta Tables

There are two fundamental types of tables in Databricks: **managed tables** and **external tables**
(also called unmanaged tables). This distinction is critical and comes up in interviews all the time.

```
+====================================================================+
|                  TYPES OF DELTA TABLES                              |
+====================================================================+
|                                                                    |
|  +-----------------------------+  +------------------------------+ |
|  |      MANAGED TABLE          |  |      EXTERNAL TABLE          | |
|  |                             |  |                              | |
|  |  - Databricks manages       |  |  - You manage both metadata  | |
|  |    both metadata AND data   |  |    AND data storage          | |
|  |                             |  |                              | |
|  |  - Data stored in default   |  |  - Data stored at a          | |
|  |    warehouse location       |  |    user-specified LOCATION   | |
|  |                             |  |                              | |
|  |  - DROP TABLE deletes       |  |  - DROP TABLE deletes only   | |
|  |    metadata AND data        |  |    metadata, NOT data        | |
|  |                             |  |                              | |
|  |  - Simpler to manage        |  |  - More control over         | |
|  |                             |  |    storage location          | |
|  |                             |  |                              | |
|  +-----------------------------+  +------------------------------+ |
|                                                                    |
+====================================================================+
```

## Creating Managed Tables

A managed table is the simplest way to create a Delta table. When you create a managed table,
Databricks controls both the metadata (in the metastore) and the actual data files. The data
is stored in the default warehouse directory, which is configured at the metastore or catalog level.

### Using SQL

```sql
-- Create a managed Delta table using SQL
CREATE TABLE employees (
    id INT,
    name STRING,
    department STRING,
    salary DOUBLE,
    hire_date DATE
);
```

Notice that we didn't specify `USING DELTA` -- that's because Delta is the default format in
Databricks. But you can be explicit if you want:

```sql
-- Explicitly specifying Delta format
CREATE TABLE employees (
    id INT,
    name STRING,
    department STRING,
    salary DOUBLE,
    hire_date DATE
) USING DELTA;
```

### Using PySpark

```python
# Create a managed Delta table using PySpark DataFrame API
from pyspark.sql.types import StructType, StructField, IntegerType, StringType, DoubleType, DateType

schema = StructType([
    StructField("id", IntegerType(), True),
    StructField("name", StringType(), True),
    StructField("department", StringType(), True),
    StructField("salary", DoubleType(), True),
    StructField("hire_date", DateType(), True)
])

# Create an empty DataFrame with the schema and write as Delta
empty_df = spark.createDataFrame([], schema)
empty_df.write.format("delta").saveAsTable("employees")
```

## Creating External Tables

An external table stores data at a location you specify. This is useful when you want full control
over where your data lives, or when you want the data to persist even after the table is dropped.

### Using SQL

```sql
-- Create an external Delta table
CREATE TABLE sales (
    order_id INT,
    product STRING,
    amount DOUBLE,
    order_date DATE
)
LOCATION 's3://my-bucket/sales_data/';
```

The key difference is the `LOCATION` clause. When you specify a location, Databricks stores the
data there instead of in the default warehouse directory. If you drop this table, the metadata
is removed from the metastore, but the data files remain at the specified location.

### Using PySpark

```python
# Create an external Delta table using PySpark
df.write.format("delta") \
    .option("path", "s3://my-bucket/sales_data/") \
    .saveAsTable("sales")
```

## Managed vs External Tables: Key Differences

| Feature | Managed Table | External Table |
|---------|--------------|----------------|
| **Data Location** | Default warehouse directory | User-specified path |
| **DROP TABLE behavior** | Deletes metadata AND data | Deletes metadata ONLY |
| **Use Case** | Simpler management, full Databricks control | Data shared across systems, need control |
| **LOCATION clause** | Not specified | Required |
| **Data Lifecycle** | Tied to table lifecycle | Independent of table |
| **UNDROP support** | Yes (Unity Catalog) | Yes (metadata only) |

## What Happens Under the Hood

When you create a Delta table, here's what actually happens:

```
CREATE TABLE employees (id INT, name STRING, salary DOUBLE)

                    |
                    v
+-------------------------------------------+
|  1. Register table in Metastore           |
|     - Table name, schema, properties      |
|     - Storage location                    |
+-------------------------------------------+
                    |
                    v
+-------------------------------------------+
|  2. Create _delta_log/ directory          |
|     - Initial commit (version 0)          |
|     - Contains schema metadata            |
|     - Contains table configuration        |
+-------------------------------------------+
                    |
                    v
+-------------------------------------------+
|  3. Create initial commit JSON file       |
|     _delta_log/00000000000000000000.json  |
|     - metaData action with schema         |
|     - protocol action with versions       |
|     - commitInfo action                   |
+-------------------------------------------+
```

The initial commit file (`00000000000000000000.json`) contains:

- **metaData**: The table schema, partition columns, format, and configuration
- **protocol**: The minimum reader and writer protocol versions required
- **commitInfo**: Information about when and how the table was created

## Creating Tables in Unity Catalog

With Unity Catalog, table creation follows the three-level namespace:
`catalog.schema.table`. This is important because Unity Catalog provides governance,
lineage tracking, and fine-grained access control.

```sql
-- Create a table in a specific catalog and schema
CREATE TABLE my_catalog.my_schema.employees (
    id INT,
    name STRING,
    department STRING,
    salary DOUBLE
);

-- If you've set your default catalog and schema with USE
USE CATALOG my_catalog;
USE SCHEMA my_schema;

CREATE TABLE employees (
    id INT,
    name STRING,
    department STRING,
    salary DOUBLE
);
```

---

## CONCEPT GAP: Table Creation Best Practices

When creating Delta tables in production environments, there are several best practices
worth knowing:

**1. Always use Unity Catalog namespaces**: Use the three-level namespace
(`catalog.schema.table`) for clarity and governance.

**2. Choose managed tables by default**: Unless you have a specific reason to use an
external table (like sharing data with non-Databricks systems), managed tables are simpler
and benefit from full lifecycle management.

**3. Define schemas explicitly**: While Delta Lake supports schema evolution, it's good
practice to define your schema explicitly at table creation time rather than relying on
schema inference.

**4. Consider partitioning at creation time**: If your table will contain a large amount
of data, think about partitioning when you create the table. But don't over-partition --
we'll cover this in detail in a later lesson.

**5. Use table properties wisely**: Table properties control important behaviors like
auto-optimization, data retention, and more. Set these at creation time when possible.

---

## KEY INTERVIEW QUESTIONS AND ANSWERS

### Q1: What are the two types of Delta tables in Databricks?
**A:** The two types are managed tables and external (unmanaged) tables. Managed tables have both metadata and data managed by Databricks in the default warehouse location. External tables store data at a user-specified location and only metadata is managed by Databricks.

### Q2: What happens when you DROP a managed table vs an external table?
**A:** When you drop a managed table, both the metadata in the metastore and the underlying data files are deleted. When you drop an external table, only the metadata is removed from the metastore -- the data files remain at the specified location.

### Q3: What is the default table format in Databricks?
**A:** Delta is the default table format in Databricks. When you create a table without specifying a format using the USING clause, it automatically creates a Delta table.

### Q4: What is created in the file system when you create a new Delta table?
**A:** When a Delta table is created, a `_delta_log/` directory is created containing an initial commit file (version 0 JSON file). This file includes the metaData action (schema, partition info, configuration), protocol action (reader/writer versions), and commitInfo action.

### Q5: What is the three-level namespace in Unity Catalog for table creation?
**A:** The three-level namespace is `catalog.schema.table`. This provides a hierarchical organization for data governance, access control, and data discovery. For example: `my_catalog.my_schema.employees`.

### Q6: How do you create an external Delta table?
**A:** You create an external Delta table by specifying the LOCATION clause in your CREATE TABLE statement. The LOCATION points to an external storage path (e.g., S3, GCS) where the data files will be stored. Example: `CREATE TABLE my_table (id INT) LOCATION 's3://my-bucket/path'`.

### Q7: When should you choose an external table over a managed table?
**A:** Choose an external table when you need the data to persist independently of the table metadata, when data is shared across multiple systems or platforms, when you need full control over the storage location, or when you want to prevent accidental data deletion when the table is dropped.

---
