# PySpark Implementation: cache() vs persist() vs checkpoint()

## Problem Statement

PySpark uses lazy evaluation, meaning transformations are recomputed every time an action is called. When a DataFrame is reused multiple times, this can be extremely wasteful. `cache()`, `persist()`, and `checkpoint()` are the three mechanisms to avoid recomputation, but they differ significantly in storage behavior and lineage handling.

| Feature | `cache()` | `persist()` | `checkpoint()` |
|---|---|---|---|
| Storage Level | MEMORY_AND_DISK only | Configurable | DISK (reliable) or local |
| Lineage | Preserved | Preserved | **Truncated** |
| Fault Recovery | Recompute from lineage | Recompute from lineage | Read from checkpoint files |
| Primary Use | Quick reuse | Fine-tuned storage control | Break long lineage chains |

**Key Gotcha:** `cache()` is just `persist(StorageLevel.MEMORY_AND_DISK)`. They are functionally identical except `persist()` lets you choose the storage level. `checkpoint()` is fundamentally different because it breaks the lineage graph.

---

## Setup

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark import StorageLevel
import time

spark = SparkSession.builder \
    .appName("cache vs persist vs checkpoint") \
    .master("local[*]") \
    .config("spark.sql.shuffle.partitions", "8") \
    .getOrCreate()

spark.sparkContext.setLogLevel("WARN")

# Required for reliable checkpoint
spark.sparkContext.setCheckpointDir("/tmp/spark_checkpoints")
```

---

## Part 1: cache() Basics

### Sample Data

```python
# Create a moderately complex DataFrame
df_base = spark.range(1_000_000).withColumn(
    "group", (F.col("id") % 100).cast("string")
).withColumn(
    "value", F.rand() * 1000
).withColumn(
    "category", F.when(F.col("id") % 3 == 0, "A")
                 .when(F.col("id") % 3 == 1, "B")
                 .otherwise("C")
)

# Without caching: each action recomputes from scratch
start = time.time()
count1 = df_base.filter(F.col("value") > 500).count()
time1 = time.time() - start

start = time.time()
count2 = df_base.filter(F.col("value") > 500).count()
time2 = time.time() - start

print(f"First computation:  {time1:.3f}s, count={count1}")
print(f"Second computation: {time2:.3f}s, count={count2}")
print("Both take similar time because df_base is recomputed each time.")
```

### Caching the DataFrame

```python
# Cache the DataFrame
df_cached = df_base.cache()

# First action triggers computation AND caching
start = time.time()
count1 = df_cached.filter(F.col("value") > 500).count()
time1 = time.time() - start

# Second action reads from cache
start = time.time()
count2 = df_cached.filter(F.col("value") > 500).count()
time2 = time.time() - start

print(f"First computation (+ caching):  {time1:.3f}s")
print(f"Second computation (from cache): {time2:.3f}s")
print(f"Speedup: {time1 / time2:.1f}x")
```

### Expected Output (Approximate)

```
First computation (+ caching):  2.145s
Second computation (from cache): 0.312s
Speedup: 6.9x
```

### Important: cache() is lazy

```python
# This does NOT trigger caching immediately
df_lazy_cache = df_base.cache()

# You can verify nothing is cached yet via the Spark UI
# Caching happens only when the first ACTION is triggered:
df_lazy_cache.count()  # NOW the data is cached
```

---

## Part 2: persist() with Storage Levels

### Available Storage Levels

```python
# All available StorageLevel options
storage_levels = {
    "MEMORY_ONLY":       StorageLevel.MEMORY_ONLY,
    "MEMORY_AND_DISK":   StorageLevel.MEMORY_AND_DISK,
    "MEMORY_ONLY_SER":   StorageLevel.MEMORY_ONLY_SER,     # Serialized (Java)
    "MEMORY_AND_DISK_SER": StorageLevel.MEMORY_AND_DISK_SER,
    "DISK_ONLY":         StorageLevel.DISK_ONLY,
    "OFF_HEAP":          StorageLevel.OFF_HEAP,
    # Replicated variants (for fault tolerance):
    "MEMORY_ONLY_2":     StorageLevel.MEMORY_ONLY_2,        # 2 replicas
    "MEMORY_AND_DISK_2": StorageLevel.MEMORY_AND_DISK_2,
}

for name, level in storage_levels.items():
    print(f"{name:25s} -> useDisk={level.useDisk}, "
          f"useMemory={level.useMemory}, "
          f"useOffHeap={level.useOffHeap}, "
          f"deserialized={level.deserialized}, "
          f"replication={level.replication}")
```

### Expected Output

```
MEMORY_ONLY               -> useDisk=False, useMemory=True,  useOffHeap=False, deserialized=True,  replication=1
MEMORY_AND_DISK           -> useDisk=True,  useMemory=True,  useOffHeap=False, deserialized=True,  replication=1
MEMORY_ONLY_SER           -> useDisk=False, useMemory=True,  useOffHeap=False, deserialized=False, replication=1
MEMORY_AND_DISK_SER       -> useDisk=True,  useMemory=True,  useOffHeap=False, deserialized=False, replication=1
DISK_ONLY                 -> useDisk=True,  useMemory=False, useOffHeap=False, deserialized=True,  replication=1
OFF_HEAP                  -> useDisk=False, useMemory=True,  useOffHeap=True,  deserialized=False, replication=1
MEMORY_ONLY_2             -> useDisk=False, useMemory=True,  useOffHeap=False, deserialized=True,  replication=2
MEMORY_AND_DISK_2         -> useDisk=True,  useMemory=True,  useOffHeap=False, deserialized=True,  replication=2
```

### Using persist() with Different Levels

```python
# MEMORY_ONLY: Fast but data evicted if memory is full (partitions recomputed)
df_mem = df_base.persist(StorageLevel.MEMORY_ONLY)
df_mem.count()  # trigger

# DISK_ONLY: Slow reads but handles large datasets
df_disk = df_base.persist(StorageLevel.DISK_ONLY)
df_disk.count()  # trigger

# MEMORY_AND_DISK: Best of both -- overflow to disk when memory is full
df_mem_disk = df_base.persist(StorageLevel.MEMORY_AND_DISK)
df_mem_disk.count()  # trigger

# MEMORY_ONLY_SER: Serialized in memory -- less memory, more CPU
df_ser = df_base.persist(StorageLevel.MEMORY_ONLY_SER)
df_ser.count()  # trigger
```

### When to Use Each Level

```python
"""
Decision guide:

1. MEMORY_AND_DISK (default / cache())
   - Best general-purpose choice
   - Data stays in memory; overflows to disk
   - Use when: You have enough memory for most of the data

2. MEMORY_ONLY
   - Fastest reads
   - Evicted partitions are recomputed (not spilled to disk)
   - Use when: Recomputation is cheap AND you need maximum speed

3. DISK_ONLY
   - Slowest reads but most memory-efficient
   - Use when: Dataset is very large and memory is constrained

4. MEMORY_ONLY_SER / MEMORY_AND_DISK_SER
   - Serialized format uses less memory (~2-5x less)
   - But requires deserialization on read (CPU cost)
   - Use when: Memory is tight but you want to keep data in memory

5. *_2 variants (replicated)
   - Stores 2 copies across the cluster
   - Use when: Fast fault recovery is critical (rare in practice)
"""
```

---

## Part 3: unpersist() -- Releasing Cached Data

```python
# Always unpersist when done to free memory
df_cached = df_base.cache()
df_cached.count()  # trigger caching

# Check if cached
print(f"Is cached: {df_cached.is_cached}")

# Release the cache
df_cached.unpersist()
print(f"Is cached after unpersist: {df_cached.is_cached}")

# Blocking unpersist -- waits for all blocks to be removed
df_cached2 = df_base.cache()
df_cached2.count()
df_cached2.unpersist(blocking=True)  # waits until fully uncached

# Clear ALL cached DataFrames
spark.catalog.clearCache()
```

---

## Part 4: checkpoint() -- Breaking the Lineage

### Why Lineage Matters

```python
# Build a DataFrame with a long lineage chain
df_long = spark.range(100_000)
for i in range(20):
    df_long = df_long.withColumn(f"col_{i}", F.col("id") * (i + 1))
    df_long = df_long.filter(F.col(f"col_{i}") >= 0)  # adds to lineage

# The execution plan is now enormous
# df_long.explain(True)  # Would show a very deep plan

# With checkpoint, the lineage is truncated
df_checkpointed = df_long.checkpoint()
# df_checkpointed.explain(True)  # Shows a simple scan of checkpoint files
```

### Reliable Checkpoint

```python
# Reliable checkpoint: writes to a distributed file system (HDFS, S3, etc.)
# Must set checkpoint directory first:
spark.sparkContext.setCheckpointDir("/tmp/spark_checkpoints")

df_reliable = df_base.checkpoint()  # Default: reliable=True, eager=True
print(f"Count: {df_reliable.count()}")

# The data is now saved to /tmp/spark_checkpoints/
# The lineage is completely truncated
# If a partition fails, it reads from checkpoint files (no recomputation)
```

### Local Checkpoint

```python
# Local checkpoint: writes to local executor storage (not replicated)
# Faster than reliable checkpoint but data is lost if executor fails
df_local = df_base.localCheckpoint()
print(f"Count: {df_local.count()}")
```

### Eager vs Lazy Checkpoint

```python
# Eager checkpoint (default): triggers computation immediately
df_eager = df_base.checkpoint(eager=True)   # computes NOW

# Lazy checkpoint: defers computation until an action is called
df_lazy = df_base.checkpoint(eager=False)   # does NOT compute yet
df_lazy.count()  # NOW it computes and checkpoints
```

---

## Part 5: Practical Comparison

### Sample Data

```python
# Scenario: iterative algorithm (common in ML pipelines)
df = spark.range(100_000).withColumn("value", F.rand())

# Simulate an iterative process
def iterative_process(df, iterations, use_cache=False, use_checkpoint=False):
    start = time.time()
    for i in range(iterations):
        df = df.withColumn("value", F.col("value") * 0.99 + F.rand() * 0.01)
        
        if use_checkpoint and i % 5 == 4:
            # Checkpoint every 5 iterations to prevent lineage explosion
            df = df.checkpoint()
        elif use_cache and i % 5 == 4:
            df.cache()
            df.count()  # materialize
    
    result = df.count()
    elapsed = time.time() - start
    return elapsed

# Without any caching (lineage grows with each iteration)
t_none = iterative_process(df, 10, use_cache=False, use_checkpoint=False)

# With cache
t_cache = iterative_process(df, 10, use_cache=True, use_checkpoint=False)

# With checkpoint
t_checkpoint = iterative_process(df, 10, use_cache=False, use_checkpoint=True)

print(f"No caching:    {t_none:.3f}s")
print(f"With cache:    {t_cache:.3f}s")
print(f"With checkpoint: {t_checkpoint:.3f}s")
```

---

## Part 6: cache/persist vs checkpoint Decision Matrix

```python
"""
+-------------------+--------+---------+------------+
| Scenario          | cache  | persist | checkpoint |
+-------------------+--------+---------+------------+
| Reuse DF 2-3x     | YES    | YES     | No         |
| Memory constrained| No     | DISK    | No         |
| Long lineage chain| No     | No      | YES        |
| Iterative ML      | Maybe  | Maybe   | YES        |
| Streaming micro-  |        |         |            |
|   batch state     | No     | No      | YES        |
| Debugging /       |        |         |            |
|   intermediate    | YES    | YES     | No         |
| Fault tolerance   | No     | No      | YES        |
|   critical        |        |         |            |
+-------------------+--------+---------+------------+
"""
```

---

## Part 7: Common Pitfalls

### Pitfall 1: Caching too much

```python
# BAD: Caching everything wastes memory and causes evictions
df1 = spark.range(10_000_000).cache()
df2 = spark.range(10_000_000).cache()
df3 = spark.range(10_000_000).cache()
# Memory fills up, earlier caches get evicted, defeating the purpose

# GOOD: Only cache DataFrames used multiple times
df1 = spark.range(10_000_000)
df2 = df1.filter(F.col("id") > 5_000_000).cache()  # reused below
result1 = df2.groupBy((F.col("id") % 10).alias("group")).count()
result2 = df2.agg(F.sum("id"))
df2.unpersist()  # clean up when done
```

### Pitfall 2: Caching before a filter

```python
# BAD: Caches the full dataset, then filters
df_full = spark.range(10_000_000).cache()
df_filtered = df_full.filter(F.col("id") > 9_000_000)

# GOOD: Filter first, then cache the smaller result
df_filtered = spark.range(10_000_000).filter(F.col("id") > 9_000_000).cache()
```

### Pitfall 3: Not materializing the cache

```python
# BAD: cache() is lazy -- this does nothing useful
df = spark.range(1_000_000).cache()
# ... code continues without any action ...
# The data is NOT cached yet

# GOOD: Force materialization
df = spark.range(1_000_000).cache()
df.count()  # NOW it's cached
# or
df.foreach(lambda _: None)  # Alternative materialization
```

### Pitfall 4: Forgetting to unpersist

```python
# BAD: Memory leak -- cached data stays until the SparkSession ends
def process_batch(batch_id):
    df = spark.range(1_000_000).cache()
    df.count()
    result = df.agg(F.sum("id")).collect()
    # forgot to unpersist!
    return result

# GOOD: Always clean up
def process_batch_clean(batch_id):
    df = spark.range(1_000_000).cache()
    df.count()
    result = df.agg(F.sum("id")).collect()
    df.unpersist()  # free the memory
    return result
```

---

## Part 8: Monitoring Cache Usage

```python
# Check storage status via SparkContext
for rdd_info in spark.sparkContext._jsc.sc().getRDDStorageInfo():
    print(f"RDD: {rdd_info.name()}")
    print(f"  Partitions cached: {rdd_info.numCachedPartitions()}")
    print(f"  Memory used: {rdd_info.memSize() / 1024 / 1024:.1f} MB")
    print(f"  Disk used: {rdd_info.diskSize() / 1024 / 1024:.1f} MB")

# Check via Spark UI: http://localhost:4040/storage/
# Shows all cached RDDs/DataFrames with memory/disk usage

# Programmatic check
print(f"Is cached: {df_cached.is_cached}")
print(f"Storage level: {df_cached.storageLevel}")
```

---

## Key Takeaways

1. **`cache()` = `persist(StorageLevel.MEMORY_AND_DISK)`**. They are the same thing. `cache()` is just a convenience method.

2. **`cache()`/`persist()` preserve the lineage.** If cached data is evicted or a partition is lost, Spark can recompute it from the original transformations.

3. **`checkpoint()` truncates the lineage.** The DataFrame is materialized to disk and the execution plan starts fresh from the checkpoint files. This is essential for iterative algorithms and long pipelines.

4. **Always unpersist when done.** Cached data stays in memory until explicitly released or the SparkSession ends. Memory leaks from forgotten caches are a common production issue.

5. **Cache after filtering, not before.** Caching a large dataset and then filtering it wastes memory. Filter first, then cache the smaller result.

6. **`cache()` is lazy.** The data is not actually cached until an action (count, show, collect, etc.) is triggered.

7. **For interviews, know the tradeoffs:**
   - `cache()`: Simple, good for iterative development and moderate reuse
   - `persist(DISK_ONLY)`: When data is too large for memory
   - `checkpoint()`: When lineage is too long (iterative ML, complex DAGs)
   - `localCheckpoint()`: Faster than reliable checkpoint but not fault-tolerant

8. **Serialized storage levels** (`MEMORY_ONLY_SER`, `MEMORY_AND_DISK_SER`) use less memory but require CPU for deserialization. Good when you are memory-constrained but have CPU headroom.
