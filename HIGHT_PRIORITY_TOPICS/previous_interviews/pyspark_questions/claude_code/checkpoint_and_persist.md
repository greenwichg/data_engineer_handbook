# PySpark Implementation: Checkpoint vs Persist/Cache for Fault Tolerance

## Problem Statement

Given an iterative data processing pipeline with multiple transformation stages, demonstrate how to use **checkpoint()** vs **persist()/cache()** to optimize performance and ensure fault tolerance. Explain when each approach is appropriate, the trade-offs, and how lineage truncation affects recovery.

This is a critical Spark internals question that tests understanding of the DAG execution model, fault tolerance, and memory management.

### Sample Data

**Raw Events:**
```
event_id  user_id  event_type  timestamp            value
E001      U001     click       2025-01-01 10:00:00  1.0
E002      U001     purchase    2025-01-01 10:05:00  49.99
E003      U002     click       2025-01-01 10:10:00  1.0
E004      U002     click       2025-01-01 10:15:00  1.0
E005      U003     purchase    2025-01-01 10:20:00  99.99
E006      U001     click       2025-01-01 10:25:00  1.0
E007      U003     click       2025-01-01 10:30:00  1.0
E008      U002     purchase    2025-01-01 10:35:00  29.99
```

### Expected Output

After multiple transformations, produce a user summary with enrichment:

| user_id | total_clicks | total_purchases | total_spend | avg_spend | user_tier |
|---------|-------------|-----------------|-------------|-----------|-----------|
| U001    | 2           | 1               | 49.99       | 49.99     | Silver    |
| U002    | 2           | 1               | 29.99       | 29.99     | Bronze    |
| U003    | 1           | 1               | 99.99       | 99.99     | Gold      |

---

## Method 1: Using persist() with Multiple Reuses

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, sum as spark_sum, avg as spark_avg, when, lit
from pyspark import StorageLevel

# Initialize Spark session
spark = SparkSession.builder.appName("CheckpointVsPersist").getOrCreate()

# Raw events data
events_data = [
    ("E001", "U001", "click",    "2025-01-01 10:00:00", 1.0),
    ("E002", "U001", "purchase", "2025-01-01 10:05:00", 49.99),
    ("E003", "U002", "click",    "2025-01-01 10:10:00", 1.0),
    ("E004", "U002", "click",    "2025-01-01 10:15:00", 1.0),
    ("E005", "U003", "purchase", "2025-01-01 10:20:00", 99.99),
    ("E006", "U001", "click",    "2025-01-01 10:25:00", 1.0),
    ("E007", "U003", "click",    "2025-01-01 10:30:00", 1.0),
    ("E008", "U002", "purchase", "2025-01-01 10:35:00", 29.99),
]
events_df = spark.createDataFrame(events_data, ["event_id", "user_id", "event_type", "timestamp", "value"])

# Step 1: Compute click counts per user
clicks_df = events_df.filter(col("event_type") == "click") \
    .groupBy("user_id") \
    .agg(count("*").alias("total_clicks"))

# Step 2: Compute purchase metrics per user
purchases_df = events_df.filter(col("event_type") == "purchase") \
    .groupBy("user_id") \
    .agg(
        count("*").alias("total_purchases"),
        spark_sum("value").alias("total_spend"),
        spark_avg("value").alias("avg_spend")
    )

# Step 3: Join clicks and purchases — persist because we reuse this downstream
user_summary = clicks_df.join(purchases_df, on="user_id", how="outer") \
    .fillna(0, subset=["total_clicks", "total_purchases", "total_spend", "avg_spend"])

# Persist with MEMORY_AND_DISK — keeps lineage intact for recomputation
user_summary = user_summary.persist(StorageLevel.MEMORY_AND_DISK)

# Trigger materialization
user_summary.count()

# Step 4: Reuse persisted DataFrame for multiple reports
# Report 1: Add tier classification
tiered = user_summary.withColumn(
    "user_tier",
    when(col("total_spend") >= 100, "Gold")
    .when(col("total_spend") >= 40, "Silver")
    .otherwise("Bronze")
)
tiered.orderBy("user_id").show(truncate=False)

# Report 2: High-value user filter
high_value = user_summary.filter(col("total_spend") > 30)
high_value.show()

# Report 3: Engagement score
engagement = user_summary.withColumn(
    "engagement_score",
    col("total_clicks") * 1 + col("total_purchases") * 10
)
engagement.show()

# Clean up
user_summary.unpersist()
```

### Step-by-Step Explanation

#### Step 1-2: Separate Aggregations
- Click counts and purchase metrics are computed independently from the same source DataFrame.

#### Step 3: persist(StorageLevel.MEMORY_AND_DISK)
- **What happens:** The joined `user_summary` is materialized and stored in executor memory. If memory is insufficient, partitions spill to local disk.
- **Why persist here:** `user_summary` is reused 3 times (tiered, high_value, engagement). Without persist, Spark would recompute the join + aggregations 3 times.
- **Lineage preserved:** If a cached partition is lost (executor crash), Spark can recompute it from the original transformations.

#### Step 4: Three Reports
- Each report reads from the persisted DataFrame — no recomputation needed.

---

## Method 2: Using checkpoint() for Long Lineage Chains

```python
# Set checkpoint directory (must be reliable storage — HDFS, S3, DBFS)
spark.sparkContext.setCheckpointDir("/tmp/spark_checkpoints")

# Simulate a long lineage chain (e.g., iterative algorithm)
df = events_df

# Iteration 1: Filter and enrich
df = df.filter(col("value") > 0) \
    .withColumn("adjusted_value", col("value") * 1.1)

# Iteration 2: Aggregate
df = df.groupBy("user_id", "event_type") \
    .agg(spark_sum("adjusted_value").alias("total_adjusted"))

# Iteration 3: Pivot
df = df.groupBy("user_id").pivot("event_type").sum("total_adjusted") \
    .fillna(0)

# At this point, the lineage is getting long — checkpoint to truncate
df = df.checkpoint()  # Materializes to disk and truncates lineage

# Continue processing with a clean lineage
df = df.withColumn(
    "user_tier",
    when(col("purchase") >= 100, "Gold")
    .when(col("purchase") >= 40, "Silver")
    .otherwise("Bronze")
)

df.show(truncate=False)
```

### Why checkpoint() Here?

```
Without checkpoint — lineage grows with every transformation:
  read → filter → withColumn → groupBy → agg → pivot → fillna → withColumn

  If a partition is lost, Spark must recompute from the BEGINNING.
  With very deep lineage (100+ stages), this causes:
  - StackOverflowError from serializing the DAG
  - Very slow recovery on failure

With checkpoint — lineage is truncated:
  checkpoint_file → withColumn

  If a partition is lost, Spark reads from the checkpoint file.
  Fast recovery, clean DAG.
```

---

## Method 3: Eager vs Lazy Checkpoint

```python
# Lazy checkpoint (default) — materializes on first action
df_lazy = df.checkpoint(eager=False)
# Nothing written yet — waits for an action
df_lazy.show()  # NOW it writes to checkpoint dir

# Eager checkpoint — materializes immediately
df_eager = df.checkpoint(eager=True)
# Data is written to checkpoint dir RIGHT NOW
# No need for a separate action to trigger it
```

---

## Method 4: localCheckpoint() — Non-Reliable Storage

```python
# localCheckpoint: Saves to local executor disk (NOT HDFS/S3)
# Faster than checkpoint() but NOT fault-tolerant across executor failures
df_local = df.localCheckpoint()

# Use when:
# 1. You need lineage truncation for performance
# 2. You don't need fault tolerance (e.g., batch job you can restart)
# 3. You want faster checkpointing (no HDFS write)
```

---

## Complete Comparison: cache vs persist vs checkpoint

| Feature | cache() | persist(level) | checkpoint() | localCheckpoint() |
|---------|---------|----------------|--------------|-------------------|
| Storage | Memory + Disk | Configurable | Reliable FS (HDFS/S3) | Local executor disk |
| Lineage | Preserved | Preserved | **Truncated** | **Truncated** |
| Fault tolerance | Recompute from lineage | Recompute from lineage | Read from checkpoint | **Not fault-tolerant** |
| Speed | Fast (in-memory) | Configurable | Slow (writes to HDFS) | Medium (local disk) |
| Use case | Reuse DataFrame 2+ times | Control storage precisely | Break long lineage | Break lineage, no HA needed |
| Lazy? | Yes | Yes | Yes (default) | Yes (default) |
| Cleanup | unpersist() | unpersist() | Manual delete | Automatic on executor loss |

---

## Method 5: Combining persist() and checkpoint()

```python
# Best practice for iterative ML algorithms (e.g., graph processing)
spark.sparkContext.setCheckpointDir("/tmp/checkpoints")

# Initial DataFrame
current = events_df.groupBy("user_id") \
    .agg(count("*").alias("event_count"))

for i in range(10):  # Iterative processing
    # Transform
    current = current.withColumn("event_count", col("event_count") + 1)

    # Every N iterations, checkpoint to prevent lineage explosion
    if i % 3 == 0:
        current = current.checkpoint()  # Truncate lineage
    else:
        current = current.persist()  # Cache intermediate result
        current.count()  # Materialize

current.show()
```

### Why Combine?
- **persist()** on every iteration prevents recomputation but lineage still grows.
- **checkpoint()** every N iterations truncates the lineage to prevent StackOverflow.
- This pattern is used in Spark MLlib (e.g., ALS, PageRank) and GraphX internally.

---

## Anti-Patterns to Avoid

```python
# ANTI-PATTERN 1: Caching a DataFrame used only once
df = spark.read.parquet("/data/large")
df.cache()  # Wastes memory — used only once below
result = df.groupBy("col").count()
# Fix: Don't cache single-use DataFrames

# ANTI-PATTERN 2: Forgetting to materialize cache
df = spark.read.parquet("/data/large").cache()
# df.count()  <-- MISSING! Cache is lazy, never materialized
result1 = df.groupBy("a").count()  # Computes AND caches
result2 = df.groupBy("b").count()  # Reads from cache
# Problem: result1 pays the caching cost unexpectedly

# ANTI-PATTERN 3: Never unpersisting
for date in date_list:
    df = spark.read.parquet(f"/data/{date}").cache()
    df.count()
    process(df)
    # df.unpersist()  <-- MISSING! Memory fills up
# Fix: Always unpersist when done

# ANTI-PATTERN 4: Checkpointing without setting directory
# spark.sparkContext.setCheckpointDir(...)  <-- MISSING
df.checkpoint()  # Throws error: checkpoint directory not set
```

---

## Key Interview Talking Points

1. **cache() vs persist():** "cache() is just persist(MEMORY_AND_DISK). persist() lets you choose the storage level — MEMORY_ONLY, DISK_ONLY, MEMORY_ONLY_SER for serialized format, etc."

2. **When to checkpoint:** "Use checkpoint when your DAG lineage becomes very deep — typically in iterative algorithms like PageRank or ALS. The lineage graph can cause StackOverflowError during serialization, and recovery becomes extremely slow."

3. **Lineage truncation trade-off:** "checkpoint() writes to reliable storage and truncates lineage. This means faster recovery (just read from disk) but you lose the ability to recompute from source. persist() keeps lineage — slower recovery but more flexible."

4. **Checkpoint directory requirement:** "checkpoint() requires a reliable distributed filesystem (HDFS, S3, DBFS). localCheckpoint() uses local disk — faster but not fault-tolerant."

5. **Materialization is lazy:** "Both cache() and checkpoint() are lazy transformations. You must trigger an action (count(), show(), write()) to actually materialize the data. A common mistake is assuming cache() immediately stores the data."

6. **Real-world pattern:** "In production ETL pipelines, I persist intermediate DataFrames that feed multiple downstream reports. For long-running iterative jobs (graph algorithms, ML training loops), I checkpoint every N iterations to keep the DAG manageable."
