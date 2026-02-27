# PySpark Implementation: Repartition, Coalesce, and Caching

## Problem Statement

Demonstrate how to control **data distribution** across partitions and **caching strategies** in PySpark. Explain when to use `repartition()` vs `coalesce()`, how `persist()` and `cache()` work, and their impact on performance. These are fundamental Spark performance optimization questions asked in every senior data engineering interview.

---

## Part 1: Understanding Partitions

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, spark_partition_id, count

# Initialize Spark session
spark = SparkSession.builder.appName("PartitionCaching").getOrCreate()

# Create a sample DataFrame
data = [(i, f"user_{i}", i * 100) for i in range(1, 21)]
df = spark.createDataFrame(data, ["id", "name", "amount"])

# Check current number of partitions
print(f"Default partitions: {df.rdd.getNumPartitions()}")

# See which rows are in which partition
df.withColumn("partition_id", spark_partition_id()).show()
```

### Key Concept: Why Partitions Matter

```
Partitions = Parallelism units

  Partition 1 → Task 1 → Executor Core 1
  Partition 2 → Task 2 → Executor Core 2
  Partition 3 → Task 3 → Executor Core 3

More partitions = more parallelism (up to # of cores)
Too many = overhead from task scheduling
Too few = underutilized cores, OOM risk
```

---

## Part 2: repartition() — Full Shuffle Redistribution

```python
# repartition(N): Redistributes data across N partitions via full shuffle
df_repart = df.repartition(4)
print(f"After repartition(4): {df_repart.rdd.getNumPartitions()}")

# repartition with column: Hash-partitions by column values
df_repart_col = df.repartition(4, "name")
print(f"After repartition(4, 'name'): {df_repart_col.rdd.getNumPartitions()}")

# Verify distribution
df_repart.withColumn("partition_id", spark_partition_id()) \
    .groupBy("partition_id").count().show()
```

### When to Use repartition()

| Scenario | Example |
|----------|---------|
| **Increase** partitions | Small input, need more parallelism |
| **Even distribution** | After filter that skews data |
| **Pre-partition for join** | `repartition("join_key")` before join |
| **Before writing** | Control output file count |

```python
# Example: Before writing to ensure even file sizes
df.repartition(10).write.parquet("/output/path")
# Creates exactly 10 output files

# Partition by column for Hive-style partitioning
df.repartition("department").write.partitionBy("department").parquet("/output/path")
```

---

## Part 3: coalesce() — Reduce Partitions Without Full Shuffle

```python
# coalesce(N): Reduces partitions by merging (NO full shuffle)
df_coal = df.repartition(8)  # Start with 8 partitions
print(f"Before coalesce: {df_coal.rdd.getNumPartitions()}")  # 8

df_reduced = df_coal.coalesce(2)
print(f"After coalesce(2): {df_reduced.rdd.getNumPartitions()}")  # 2
```

### How coalesce Works Internally

```
Before coalesce(2) — 8 partitions:
  [P1] [P2] [P3] [P4] [P5] [P6] [P7] [P8]

After coalesce(2) — merges without shuffling:
  [P1+P2+P3+P4] [P5+P6+P7+P8]

Data just moves locally — much faster than repartition!
```

---

## Part 4: repartition vs coalesce — Complete Comparison

| Feature | repartition(N) | coalesce(N) |
|---------|---------------|-------------|
| Direction | Increase OR decrease | Decrease only |
| Shuffle | Full shuffle (expensive) | No full shuffle (cheap) |
| Distribution | Even (hash-based) | Uneven (merges existing) |
| Use case | Need more partitions or even distribution | Reduce partitions before write |
| Output files | Evenly sized | May be uneven |
| Performance | Slower | Faster |

### Common Patterns

```python
# PATTERN 1: After heavy filtering (data shrinks, too many empty partitions)
df_filtered = df.filter(col("amount") > 1500)  # Reduces data significantly
df_filtered = df_filtered.coalesce(2)  # Reduce partitions to match smaller data

# PATTERN 2: Before writing output files
# Want exactly 5 evenly-sized files
df.repartition(5).write.parquet("/output/even_files")

# Want at most 5 files (faster, but may be uneven)
df.coalesce(5).write.parquet("/output/merged_files")

# PATTERN 3: Repartition before join to optimize shuffle
df1 = df.repartition("join_key")
df2 = other_df.repartition("join_key")
result = df1.join(df2, on="join_key")  # No additional shuffle needed

# PATTERN 4: Write single file
df.coalesce(1).write.csv("/output/single_file")
```

---

## Part 5: cache() and persist()

```python
from pyspark import StorageLevel

# cache(): Stores DataFrame in memory (deserialized)
# Equivalent to persist(StorageLevel.MEMORY_AND_DISK)
df_cached = df.cache()

# Trigger materialization (cache is lazy!)
df_cached.count()  # Forces computation and caching

# Now subsequent operations on df_cached are fast
df_cached.filter(col("amount") > 500).show()   # Reads from cache
df_cached.groupBy("name").count().show()        # Reads from cache

# persist(): Same as cache but with configurable storage level
df_persisted = df.persist(StorageLevel.MEMORY_AND_DISK)
```

### Storage Levels

| Storage Level | Where | Serialized? | Replicated? | Use When |
|---------------|-------|-------------|-------------|----------|
| `MEMORY_ONLY` | RAM only | No | No | Enough memory, fast access |
| `MEMORY_AND_DISK` | RAM + disk fallback | No | No | Default (cache) — safe choice |
| `MEMORY_ONLY_SER` | RAM only | Yes (compact) | No | Memory constrained |
| `MEMORY_AND_DISK_SER` | RAM + disk | Yes | No | Memory constrained + safety |
| `DISK_ONLY` | Disk only | Yes | No | Very large DataFrames |
| `MEMORY_ONLY_2` | RAM only | No | Yes (2 copies) | Fault tolerance |

### When to Cache

```python
# GOOD: DataFrame used multiple times
df_base = spark.read.parquet("/data/large_table") \
    .filter(col("year") == 2025) \
    .cache()

# Used 3 times — caching saves re-reading and re-filtering
report1 = df_base.groupBy("department").sum("salary")
report2 = df_base.groupBy("location").avg("salary")
report3 = df_base.filter(col("department") == "Engineering").count()

# BAD: DataFrame used only once
df_single_use = spark.read.parquet("/data/table")
result = df_single_use.groupBy("col").count()
# Caching here wastes memory
```

---

## Part 6: unpersist() — Releasing Cache

```python
# Free cached memory when done
df_cached.unpersist()

# Check if DataFrame is cached
print(f"Is cached: {df_cached.is_cached}")

# Best practice: unpersist in try/finally
df = spark.read.parquet("/data/large").cache()
try:
    df.count()  # Materialize
    result1 = df.groupBy("col").count()
    result2 = df.filter(col("x") > 10)
finally:
    df.unpersist()
```

---

## Part 7: Checkpoint — Breaking Lineage

```python
# Set checkpoint directory
spark.sparkContext.setCheckpointDir("/tmp/checkpoints")

# checkpoint(): Saves to disk and breaks lineage
# Useful for iterative algorithms or very long lineage chains
df_complex = df.join(other_df, "key").filter(...).groupBy(...).agg(...)
df_checkpointed = df_complex.checkpoint()

# Now df_checkpointed has a clean lineage (reads from checkpoint)
# Prevents StackOverflow from very long DAG chains
```

### cache vs persist vs checkpoint

| Feature | cache/persist | checkpoint |
|---------|--------------|------------|
| Storage | Memory (+disk fallback) | Reliable storage (HDFS/S3) |
| Lineage | Preserved | Truncated |
| Recovery | Re-compute from lineage | Read from checkpoint |
| Use case | Repeated access | Very long lineage, iterative |
| Lazy? | Yes (needs action) | Yes (needs action) |

---

## Part 8: repartitionByRange() — Range-Based Partitioning

```python
# repartitionByRange: Distributes data based on value ranges
# Useful for range-based queries (date ranges, numeric ranges)

df_range = df.repartitionByRange(4, "amount")

# Partitions will contain ranges: [0-500], [500-1000], [1000-1500], [1500-2000]
df_range.withColumn("partition_id", spark_partition_id()) \
    .orderBy("amount") \
    .show()
```

---

## Decision Flowchart

```
Need to change partitions?
├── Increase partitions → repartition(N)
├── Decrease partitions
│   ├── Need even distribution? → repartition(N) (slower)
│   └── Uneven is OK? → coalesce(N) (faster)
├── Need to write N files → repartition(N) or coalesce(N)
└── Before a join → repartition("join_key")

Need to reuse a DataFrame?
├── Used 2+ times → cache() or persist()
├── Used once → don't cache
├── Very long lineage → checkpoint()
└── Done using → unpersist()
```

## Key Interview Talking Points

1. **repartition vs coalesce:** "repartition does a full shuffle to create N evenly sized partitions. coalesce only merges existing partitions without shuffle — faster but may create uneven partitions. Use repartition to increase, coalesce to decrease."

2. **Optimal partition count:** Rule of thumb: 2-4 partitions per CPU core. For 100 cores: 200-400 partitions. Each partition should be 128MB-256MB for optimal processing.

3. **cache is lazy:** Calling `.cache()` doesn't compute anything — it only marks the DataFrame for caching. The actual caching happens on the first **action** (`count()`, `show()`, `write()`).

4. **Memory pressure from caching:** Cached data competes with execution memory. Over-caching can cause spills and OOM errors. Only cache DataFrames that are reused.

5. **shuffle.partitions config:** `spark.sql.shuffle.partitions` (default 200) controls partition count after shuffles (joins, groupBy). Tune this based on data size.

6. **Small file problem:** Writing with too many partitions creates many small files. Use `coalesce()` before write, or use `spark.sql.files.maxRecordsPerFile` to control file size.
