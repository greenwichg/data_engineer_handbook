# PySpark Implementation: Incremental Load with High Watermark

## Problem Statement
Design an incremental data loading pipeline that extracts only new or changed records from a source table since the last processed timestamp (high watermark). Merge the incremental data into an existing target table -- inserting new records and updating changed ones. After processing, persist the new high watermark for the next run. This is a foundational pattern in production ETL.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, max as _max, current_timestamp, lit, when, coalesce
)
from datetime import datetime

spark = SparkSession.builder \
    .appName("IncrementalLoad") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog",
            "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .getOrCreate()

# Existing target table (already loaded in a prior run)
target_data = [
    (1, "Alice",   "alice@v1.com",   "2024-01-01 10:00:00"),
    (2, "Bob",     "bob@v1.com",     "2024-01-01 10:00:00"),
    (3, "Charlie", "charlie@v1.com", "2024-01-01 10:00:00"),
]
target_df = spark.createDataFrame(
    target_data, ["id", "name", "email", "updated_at"]
)

# Source table (contains new + changed records)
source_data = [
    (2, "Bob",     "bob@v2.com",     "2024-01-15 08:00:00"),  # updated
    (3, "Charlie", "charlie@v1.com", "2024-01-01 10:00:00"),  # unchanged
    (4, "Diana",   "diana@v1.com",   "2024-01-15 09:00:00"),  # new
    (5, "Eve",     "eve@v1.com",     "2024-01-15 09:30:00"),  # new
]
source_df = spark.createDataFrame(
    source_data, ["id", "name", "email", "updated_at"]
)

# Last watermark from previous run
last_watermark = "2024-01-01 10:00:00"
```

### Expected Output (Target After Merge)

| id | name    | email         | updated_at          |
|----|---------|---------------|---------------------|
| 1  | Alice   | alice@v1.com  | 2024-01-01 10:00:00 |
| 2  | Bob     | bob@v2.com    | 2024-01-15 08:00:00 |
| 3  | Charlie | charlie@v1.com| 2024-01-01 10:00:00 |
| 4  | Diana   | diana@v1.com  | 2024-01-15 09:00:00 |
| 5  | Eve     | eve@v1.com    | 2024-01-15 09:30:00 |

New watermark: `2024-01-15 09:30:00`

---

## Method 1: DataFrame-Based Incremental Merge (Recommended)

```python
# Step 1: Extract incremental records using the watermark
incremental_df = source_df.filter(col("updated_at") > lit(last_watermark))
incremental_df.show()

# Step 2: Separate updates from inserts
# Records that exist in target are updates; others are inserts
updates = incremental_df.alias("inc").join(
    target_df.alias("tgt"),
    col("inc.id") == col("tgt.id"),
    "inner"
).select("inc.*")

inserts = incremental_df.alias("inc").join(
    target_df.alias("tgt"),
    col("inc.id") == col("tgt.id"),
    "left_anti"
)

# Step 3: Build the merged target
# Remove old versions of updated records, then union everything
unchanged = target_df.alias("tgt").join(
    updates.alias("upd"),
    col("tgt.id") == col("upd.id"),
    "left_anti"
)

merged_target = unchanged.unionByName(updates).unionByName(inserts)
merged_target.orderBy("id").show()

# Step 4: Compute and persist the new watermark
new_watermark = incremental_df.agg(
    _max("updated_at").alias("max_ts")
).collect()[0]["max_ts"]

print(f"New watermark: {new_watermark}")
```

### Step-by-Step Explanation

**After Step 1 -- Extract incremental data:**

| id | name  | email       | updated_at          |
|----|-------|-------------|---------------------|
| 2  | Bob   | bob@v2.com  | 2024-01-15 08:00:00 |
| 4  | Diana | diana@v1.com| 2024-01-15 09:00:00 |
| 5  | Eve   | eve@v1.com  | 2024-01-15 09:30:00 |

Charlie is excluded because his `updated_at` equals (not exceeds) the watermark. The filter uses `>` to avoid reprocessing.

**After Step 2 -- Classify updates vs inserts:**

Updates (exist in target):

| id | name | email      | updated_at          |
|----|------|------------|---------------------|
| 2  | Bob  | bob@v2.com | 2024-01-15 08:00:00 |

Inserts (new to target):

| id | name  | email        | updated_at          |
|----|-------|--------------|---------------------|
| 4  | Diana | diana@v1.com | 2024-01-15 09:00:00 |
| 5  | Eve   | eve@v1.com   | 2024-01-15 09:30:00 |

**After Step 3 -- Merge result:**

`left_anti` join removes Bob's old record from the target, then unions in the updated Bob, new Diana, and new Eve.

**After Step 4 -- New watermark:**

`max(updated_at)` from the incremental batch is `2024-01-15 09:30:00`. Store this value in a control table or file for the next run.

---

## Method 2: Delta Lake MERGE (Production-Grade)

```python
from delta.tables import DeltaTable

# Write target as a Delta table
target_path = "/tmp/target_delta"
target_df.write.format("delta").mode("overwrite").save(target_path)

# Load incremental data
incremental_df = source_df.filter(col("updated_at") > lit(last_watermark))

# Perform MERGE
delta_target = DeltaTable.forPath(spark, target_path)

delta_target.alias("tgt").merge(
    incremental_df.alias("src"),
    "tgt.id = src.id"
).whenMatchedUpdateAll() \
 .whenNotMatchedInsertAll() \
 .execute()

# Verify result
spark.read.format("delta").load(target_path).orderBy("id").show()

# Persist watermark
new_watermark = incremental_df.agg(
    _max("updated_at")
).collect()[0][0]
print(f"New watermark: {new_watermark}")
```

Delta Lake MERGE is ACID-compliant and handles concurrent writes safely. It is the standard approach for production merge operations in the Databricks and open-source Delta Lake ecosystem.

---

## Method 3: Watermark Stored in a Control Table

```python
# Create a control table to persist watermarks
watermark_data = [("sales_pipeline", "2024-01-01 10:00:00")]
watermark_df = spark.createDataFrame(watermark_data, ["pipeline", "last_watermark"])

# Read watermark at the START of the pipeline
stored_watermark = watermark_df.filter(
    col("pipeline") == "sales_pipeline"
).collect()[0]["last_watermark"]

# After successful processing, update the watermark
new_wm = incremental_df.agg(_max("updated_at")).collect()[0][0]

updated_watermark = watermark_df.withColumn(
    "last_watermark",
    when(col("pipeline") == "sales_pipeline", lit(str(new_wm)))
    .otherwise(col("last_watermark"))
)

# In production, write this back to a persistent store (Delta table, database, etc.)
updated_watermark.show()
```

---

## Key Interview Talking Points

1. **Watermark is `>` not `>=`** -- using `>` avoids reprocessing the last batch's final record. However, if multiple records can share the same timestamp, use `>=` and add deduplication logic to prevent duplicates in the target.

2. **Delta Lake MERGE is ACID** -- unlike the DataFrame approach (which involves multiple steps that are not atomic), Delta MERGE is a single atomic operation. If it fails midway, the target table remains in its prior consistent state.

3. **Watermark granularity matters** -- second-precision timestamps may miss sub-second changes. In high-throughput systems, use millisecond timestamps or sequence numbers (monotonically increasing IDs) as watermarks.

4. **Late-arriving data** -- watermark-based loads assume records appear in timestamp order. Late arrivals (records with old timestamps inserted after the watermark advances) will be missed. Solutions include periodic full reconciliation or change data capture (CDC) with deletion tracking.

5. **Persist watermark atomically with data** -- in production, store the watermark in the same transaction as the data write. With Delta Lake, you can write data and update a control table in the same streaming micro-batch.

6. **`whenMatchedUpdateAll` vs selective update** -- `whenMatchedUpdateAll` updates every column. In real pipelines you may want `whenMatchedUpdate(set={"email": "src.email", ...})` to update only specific columns or add conditions like `src.updated_at > tgt.updated_at`.

7. **Idempotency consideration** -- if the pipeline crashes after writing data but before persisting the watermark, the next run will reprocess the same batch. The merge must be idempotent (re-applying the same updates produces the same result). Delta MERGE satisfies this naturally.
