# PySpark Implementation: Delta Lake MERGE Operations

## Problem Statement

Demonstrate how to use **Delta Lake's MERGE INTO** (upsert) operation to efficiently handle inserts, updates, and deletes in a single atomic transaction. Given an existing Delta table and incoming batch of changes, perform:
1. **Update** existing records that have changed
2. **Insert** new records that don't exist
3. **Delete** records marked for deletion

Delta Lake is the industry standard for lakehouse architectures and MERGE is its most important operation — frequently asked in modern data engineering interviews.

### Sample Data

**Target Table (existing customers):**

| customer_id | name    | email              | city       | updated_at |
|-------------|---------|--------------------|-----------|-----------  |
| 101         | Alice   | alice@email.com    | New York  | 2025-01-01  |
| 102         | Bob     | bob@email.com      | Chicago   | 2025-01-01  |
| 103         | Charlie | charlie@email.com  | Boston    | 2025-01-01  |

**Source Data (incoming changes):**

| customer_id | name    | email                | city          | action |
|-------------|---------|----------------------|---------------|--------|
| 101         | Alice   | alice.new@email.com  | San Francisco | UPDATE |
| 104         | Diana   | diana@email.com      | Seattle       | INSERT |
| 103         | Charlie | charlie@email.com    | Boston        | DELETE |

### Expected Result

| customer_id | name    | email              | city          | updated_at |
|-------------|---------|--------------------|-----------    |------------|
| 101         | Alice   | alice.new@email.com| San Francisco | 2025-01-15 |
| 102         | Bob     | bob@email.com      | Chicago       | 2025-01-01 |
| 104         | Diana   | diana@email.com    | Seattle       | 2025-01-15 |

(Charlie deleted, Alice updated, Diana inserted, Bob unchanged)

---

## Method 1: Basic MERGE (Upsert)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, current_date, lit

# Initialize Spark session with Delta Lake
spark = SparkSession.builder \
    .appName("DeltaLakeMerge") \
    .config("spark.jars.packages", "io.delta:delta-spark_2.12:3.1.0") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .getOrCreate()

from delta.tables import DeltaTable

# Create target Delta table
target_data = [
    (101, "Alice", "alice@email.com", "New York", "2025-01-01"),
    (102, "Bob", "bob@email.com", "Chicago", "2025-01-01"),
    (103, "Charlie", "charlie@email.com", "Boston", "2025-01-01")
]
target_df = spark.createDataFrame(target_data,
    ["customer_id", "name", "email", "city", "updated_at"])

# Write as Delta table
target_df.write.format("delta").mode("overwrite").save("/tmp/delta/customers")

# Source data (incoming changes)
source_data = [
    (101, "Alice", "alice.new@email.com", "San Francisco", "UPDATE"),
    (104, "Diana", "diana@email.com", "Seattle", "INSERT"),
    (103, "Charlie", "charlie@email.com", "Boston", "DELETE")
]
source_df = spark.createDataFrame(source_data,
    ["customer_id", "name", "email", "city", "action"])

# Load Delta table
delta_table = DeltaTable.forPath(spark, "/tmp/delta/customers")

# MERGE: Update, Insert, Delete in one operation
delta_table.alias("target").merge(
    source_df.alias("source"),
    "target.customer_id = source.customer_id"
).whenMatchedUpdate(
    condition="source.action = 'UPDATE'",
    set={
        "name": "source.name",
        "email": "source.email",
        "city": "source.city",
        "updated_at": "current_date()"
    }
).whenMatchedDelete(
    condition="source.action = 'DELETE'"
).whenNotMatchedInsert(
    condition="source.action = 'INSERT'",
    values={
        "customer_id": "source.customer_id",
        "name": "source.name",
        "email": "source.email",
        "city": "source.city",
        "updated_at": "current_date()"
    }
).execute()

# Read the result
delta_table.toDF().orderBy("customer_id").show(truncate=False)
```

### Step-by-Step Explanation

#### The MERGE Syntax

```python
delta_table.alias("target").merge(
    source_df.alias("source"),
    condition="target.key = source.key"    # Match condition
)
.whenMatchedUpdate(...)     # What to do when source matches target
.whenMatchedDelete(...)     # When to delete matched rows
.whenNotMatchedInsert(...)  # What to do when source has no match in target
.execute()
```

#### What Happens for Each Source Row

| source.customer_id | Match in target? | action | Result |
|--------------------|-----------------|--------|--------|
| 101 | Yes (Alice exists) | UPDATE | Alice's email and city updated |
| 104 | No (new customer) | INSERT | Diana inserted as new row |
| 103 | Yes (Charlie exists) | DELETE | Charlie deleted from target |

---

## Method 2: Simple Upsert (No Delete)

```python
# Most common pattern: INSERT if new, UPDATE if exists
upsert_data = [
    (101, "Alice", "alice.updated@email.com", "LA"),
    (105, "Eve", "eve@email.com", "Denver")
]
upsert_df = spark.createDataFrame(upsert_data,
    ["customer_id", "name", "email", "city"])

delta_table.alias("target").merge(
    upsert_df.alias("source"),
    "target.customer_id = source.customer_id"
).whenMatchedUpdateAll(      # Update ALL columns when matched
).whenNotMatchedInsertAll(   # Insert ALL columns when not matched
).execute()
```

- **`whenMatchedUpdateAll()`:** Updates all columns from source — no need to specify individual columns.
- **`whenNotMatchedInsertAll()`:** Inserts all columns from source.
- **Caution:** Source and target must have the same schema for `*All()` methods.

---

## Method 3: Conditional Update (Only When Values Changed)

```python
# Only update when data actually changed (avoid unnecessary writes)
delta_table.alias("target").merge(
    source_df.filter(col("action") == "UPDATE").alias("source"),
    "target.customer_id = source.customer_id"
).whenMatchedUpdate(
    condition="""
        target.name != source.name OR
        target.email != source.email OR
        target.city != source.city
    """,
    set={
        "name": "source.name",
        "email": "source.email",
        "city": "source.city",
        "updated_at": "current_date()"
    }
).execute()
```

- **Why conditional update?** Without the condition, Delta rewrites the row even if nothing changed — wasting I/O. The condition ensures only actually-changed rows are updated.

---

## Method 4: SCD Type 2 with Delta MERGE

```python
# SCD Type 2: Close old record + Insert new version

# Step 1: Identify changes
changes = source_df.filter(col("action") == "UPDATE")

# Step 2: Merge to close old records
delta_table.alias("target").merge(
    changes.alias("source"),
    "target.customer_id = source.customer_id AND target.is_current = true"
).whenMatchedUpdate(
    set={
        "is_current": "false",
        "end_date": "current_date()"
    }
).execute()

# Step 3: Insert new versions
new_versions = changes.withColumn("is_current", lit(True)) \
    .withColumn("start_date", current_date()) \
    .withColumn("end_date", lit("9999-12-31"))

new_versions.write.format("delta").mode("append").save("/tmp/delta/customers_scd2")
```

---

## Method 5: MERGE with whenNotMatchedBySource (Delta 2.4+)

```python
# whenNotMatchedBySource: handles rows in TARGET that have no match in SOURCE
# Useful for full sync — delete target rows not present in source

delta_table.alias("target").merge(
    source_df.alias("source"),
    "target.customer_id = source.customer_id"
).whenMatchedUpdateAll(
).whenNotMatchedInsertAll(
).whenNotMatchedBySourceDelete(   # Delete target rows with no source match
).execute()

# This performs a FULL SYNC: target becomes an exact copy of source
```

---

## Method 6: Using SQL MERGE

```python
# Register tables
spark.sql("CREATE TABLE IF NOT EXISTS customers USING delta LOCATION '/tmp/delta/customers'")

spark.sql("""
    MERGE INTO customers AS target
    USING (
        SELECT customer_id, name, email, city, action
        FROM source_updates
    ) AS source
    ON target.customer_id = source.customer_id
    WHEN MATCHED AND source.action = 'UPDATE' THEN
        UPDATE SET
            target.name = source.name,
            target.email = source.email,
            target.city = source.city,
            target.updated_at = current_date()
    WHEN MATCHED AND source.action = 'DELETE' THEN
        DELETE
    WHEN NOT MATCHED AND source.action = 'INSERT' THEN
        INSERT (customer_id, name, email, city, updated_at)
        VALUES (source.customer_id, source.name, source.email, source.city, current_date())
""")
```

---

## Delta Lake Bonus Features

### Time Travel

```python
# Read previous version of the table
df_v0 = spark.read.format("delta").option("versionAsOf", 0).load("/tmp/delta/customers")
df_v0.show()  # Shows original data before MERGE

# Read as of a timestamp
df_ts = spark.read.format("delta") \
    .option("timestampAsOf", "2025-01-14") \
    .load("/tmp/delta/customers")

# View table history
delta_table.history().select("version", "timestamp", "operation", "operationMetrics").show(truncate=False)
```

### Schema Evolution

```python
# Allow schema changes during MERGE
delta_table.alias("target").merge(
    source_with_new_column.alias("source"),
    "target.customer_id = source.customer_id"
).whenMatchedUpdateAll(
).whenNotMatchedInsertAll(
).execute()

# Enable auto merge for schema evolution
spark.conf.set("spark.databricks.delta.schema.autoMerge.enabled", "true")
```

### Optimize and Z-Order

```python
# Compact small files
delta_table.optimize().executeCompaction()

# Z-order for faster queries on specific columns
delta_table.optimize().executeZOrderBy("customer_id")
```

---

## MERGE Performance Tips

| Tip | Details |
|-----|---------|
| Partition target table | Partition by date/region for faster lookups |
| Broadcast source | If source is small, `broadcast()` it |
| Narrow match condition | More specific conditions = fewer comparisons |
| Conditional update | Skip updates when values haven't changed |
| Z-Order on merge key | Speeds up the match lookup |
| Limit source data | Only pass changed records, not full source |

## Key Interview Talking Points

1. **MERGE is atomic:** The entire operation (update + insert + delete) happens in one transaction. Either all succeed or all fail — no partial updates.

2. **MERGE vs INSERT OVERWRITE:** MERGE handles mixed operations (update some, insert some, delete some). INSERT OVERWRITE replaces entire partitions — simpler but less precise.

3. **Duplicate source rows:** If multiple source rows match one target row, MERGE fails. Deduplicate the source before merging.

4. **ACID guarantees:** Delta Lake provides ACID transactions on top of Parquet files. MERGE uses optimistic concurrency control — concurrent writes are handled automatically.

5. **When to use Delta Lake:**
   - Need ACID transactions on data lake
   - CDC / incremental processing
   - Time travel / audit requirements
   - Schema enforcement and evolution
   - GDPR compliance (delete user data)

6. **Delta vs Iceberg vs Hudi:** All provide ACID on data lakes. Delta is tightly integrated with Spark/Databricks. Iceberg is engine-agnostic. Hudi focuses on incremental processing.
