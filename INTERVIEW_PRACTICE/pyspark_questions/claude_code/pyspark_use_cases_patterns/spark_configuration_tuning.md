# PySpark Implementation: Spark Configuration and Performance Tuning

## Problem Statement

Given a PySpark job that is running slowly or failing with OOM errors, demonstrate how to diagnose and fix performance issues through Spark configuration tuning. Cover the most critical configuration parameters, memory management, shuffle optimization, and Adaptive Query Execution (AQE). This is one of the most frequently asked topics in senior data engineering interviews — every performance round will touch on Spark tuning.

### Sample Data

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder.appName("SparkTuning").getOrCreate()

# Large orders table (~100M rows in production)
orders_data = [
    ("O001", "P001", 2, "C100", "2025-01-15"),
    ("O002", "P002", 1, "C101", "2025-01-15"),
    ("O003", "P001", 5, "C102", "2025-01-16"),
    ("O004", "P003", 3, "C100", "2025-01-16"),
    ("O005", "P002", 1, "C103", "2025-01-17"),
]
orders = spark.createDataFrame(orders_data, ["order_id", "product_id", "quantity", "customer_id", "order_date"])

# Small products lookup table (~10K rows)
products_data = [
    ("P001", "Laptop", 1200.00, "Electronics"),
    ("P002", "Phone", 800.00, "Electronics"),
    ("P003", "Desk", 350.00, "Furniture"),
]
products = spark.createDataFrame(products_data, ["product_id", "product_name", "price", "category"])
```

---

## Method 1: Shuffle Partition Tuning

The default `spark.sql.shuffle.partitions` is **200**, which is wrong for most workloads.

```python
# ❌ Problem: Default 200 partitions for a 10GB dataset = 50MB per partition (OK)
# ❌ Problem: Default 200 partitions for a 100MB dataset = 0.5MB per partition (too many small tasks!)
# ❌ Problem: Default 200 partitions for a 1TB dataset = 5GB per partition (too large, spill to disk!)

# Check current setting
print(spark.conf.get("spark.sql.shuffle.partitions"))  # 200

# ✅ Rule of thumb: aim for 128MB-256MB per partition after shuffle
# Formula: num_partitions = total_shuffle_data_size / target_partition_size

# For a 10GB shuffle:
spark.conf.set("spark.sql.shuffle.partitions", "80")   # ~125MB per partition

# For a 100MB shuffle:
spark.conf.set("spark.sql.shuffle.partitions", "4")    # ~25MB per partition

# For a 1TB shuffle:
spark.conf.set("spark.sql.shuffle.partitions", "4000") # ~250MB per partition
```

### How to Measure Shuffle Size

```python
# Run the job, then check Spark UI → Stages → Shuffle Write column
# Or use explain to see Exchange nodes (each Exchange = a shuffle)

joined = orders.join(products, "product_id")
joined.explain(True)
# Look for "Exchange" nodes in the physical plan -- each one is a shuffle
```

### Let AQE Handle It Automatically (Spark 3.0+)

```python
# AQE can coalesce small partitions automatically
spark.conf.set("spark.sql.adaptive.enabled", "true")                         # Enable AQE
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")      # Auto-coalesce
spark.conf.set("spark.sql.adaptive.coalescePartitions.initialPartitionNum", "400")  # Start high
spark.conf.set("spark.sql.adaptive.advisoryPartitionSizeInBytes", "128MB")   # Target size
# AQE will start with 400 partitions and coalesce down to the right number
```

---

## Method 2: Memory Tuning

```
Executor Memory Layout:
+----------------------------------------------------------+
|                    spark.executor.memory (e.g., 8g)      |
|                                                          |
|  +----------------------------------------------------+  |
|  |          Unified Memory (spark.memory.fraction=0.6) |  |
|  |                                                     |  |
|  |  +---------------------+  +----------------------+ |  |
|  |  |  Execution Memory   |  |  Storage Memory      | |  |
|  |  |  (shuffles, joins,  |  |  (cached DataFrames, | |  |
|  |  |   sorts, aggs)      |  |   broadcast vars)    | |  |
|  |  +---------------------+  +----------------------+ |  |
|  |     Can borrow from each other dynamically          |  |
|  +----------------------------------------------------+  |
|                                                          |
|  +----------------------------------------------------+  |
|  |  User Memory (1 - spark.memory.fraction = 0.4)     |  |
|  |  (UDFs, internal metadata, RDD dependencies)        |  |
|  +----------------------------------------------------+  |
|                                                          |
|  +----------------------------------------------------+  |
|  |  Reserved Memory (300MB fixed)                      |  |
|  +----------------------------------------------------+  |
+----------------------------------------------------------+

Overhead (spark.executor.memoryOverhead, default max(384MB, 0.1*memory)):
  - Off-heap memory for JVM internals, PySpark interop, network buffers
```

### Key Memory Configurations

```python
# Executor memory (total heap per executor)
spark.conf.set("spark.executor.memory", "8g")

# Driver memory (for collect(), broadcast variables)
spark.conf.set("spark.driver.memory", "4g")

# Off-heap overhead (increase for PySpark UDFs or large broadcasts)
spark.conf.set("spark.executor.memoryOverhead", "2g")

# Memory fraction for execution + storage (default 0.6)
spark.conf.set("spark.memory.fraction", "0.6")

# Storage fraction within unified memory (default 0.5)
# Lower this if you don't cache much but do heavy shuffles
spark.conf.set("spark.memory.storageFraction", "0.3")
```

### Common OOM Scenarios and Fixes

```python
# Scenario 1: Driver OOM during collect()
# ❌ df.collect()  -- pulls all data to driver
# ✅ df.limit(1000).collect()  -- limit first
# ✅ df.write.parquet("output/")  -- write instead of collect

# Scenario 2: Executor OOM during join
# ❌ Large table join large table with skewed keys
# ✅ Increase executor memory
spark.conf.set("spark.executor.memory", "16g")
# ✅ Or increase shuffle partitions to reduce per-partition size
spark.conf.set("spark.sql.shuffle.partitions", "2000")
# ✅ Or broadcast the smaller table
from pyspark.sql.functions import broadcast
result = orders.join(broadcast(products), "product_id")

# Scenario 3: Executor OOM during groupBy with high cardinality
# ✅ Increase memory + partitions
# ✅ Use approximate aggregations if precision allows
```

---

## Method 3: Adaptive Query Execution (AQE)

AQE re-optimizes the query plan at runtime based on actual data statistics.

```python
# Enable AQE (default True in Spark 3.2+, but verify)
spark.conf.set("spark.sql.adaptive.enabled", "true")

# Feature 1: Auto-coalesce shuffle partitions
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
# Merges small partitions after shuffle to reduce task overhead

# Feature 2: Skew join optimization
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes", "256MB")
spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionFactor", "5")
# Splits skewed partitions and replicates the other side

# Feature 3: Convert SortMergeJoin to BroadcastHashJoin at runtime
spark.conf.set("spark.sql.adaptive.localShuffleReader.enabled", "true")
# If AQE discovers one side is small after filtering, it broadcasts it
```

### Verifying AQE is Working

```python
# Run a query and check the physical plan
result = orders.join(products, "product_id").groupBy("category").count()
result.explain(True)

# In Spark UI → SQL tab → look for:
# - "AdaptiveSparkPlan" at the top = AQE is active
# - "CustomShuffleReader" = coalescing happened
# - "BroadcastHashJoin" where you expected SortMergeJoin = runtime conversion
```

---

## Method 4: Join Optimization Configs

```python
# Auto-broadcast threshold (default 10MB)
# Tables smaller than this are automatically broadcast
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "50MB")  # Increase for larger lookups

# Disable auto-broadcast (force SortMergeJoin for testing)
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "-1")

# Force broadcast with hint (overrides threshold)
from pyspark.sql.functions import broadcast
result = orders.join(broadcast(products), "product_id")

# Verify join strategy in plan
result.explain()
# Look for: BroadcastHashJoin vs SortMergeJoin vs ShuffledHashJoin
```

### Join Strategy Selection Guide

```
Decision Tree:
                    One side < broadcast threshold?
                           /              \
                         Yes               No
                          |                 |
                  BroadcastHashJoin     Both sides sortable?
                  (no shuffle!)           /          \
                                        Yes           No
                                         |             |
                                  SortMergeJoin   ShuffledHashJoin
                                  (2 shuffles)    (1 shuffle, needs
                                                   memory for hash table)
```

---

## Method 5: Serialization

```python
# Default: Java serialization (slow but compatible)
# Kryo: 2-10x faster, more compact, but requires registration for best performance

spark.conf.set("spark.serializer", "org.apache.spark.serializer.KryoSerializer")
spark.conf.set("spark.kryo.registrationRequired", "false")  # Don't fail on unregistered classes

# Register custom classes for best Kryo performance
# spark.conf.set("spark.kryo.classesToRegister", "com.myapp.MyClass1,com.myapp.MyClass2")

# When to use Kryo:
# - Always for production jobs (default in Databricks)
# - Significant improvement for RDD-based operations
# - Less impact for DataFrame/SQL operations (Tungsten handles internal serialization)
```

---

## Method 6: Dynamic Allocation

```python
# Dynamic allocation scales executors up/down based on workload
spark.conf.set("spark.dynamicAllocation.enabled", "true")
spark.conf.set("spark.dynamicAllocation.minExecutors", "2")
spark.conf.set("spark.dynamicAllocation.maxExecutors", "100")
spark.conf.set("spark.dynamicAllocation.initialExecutors", "10")

# How fast to scale
spark.conf.set("spark.dynamicAllocation.schedulerBacklogTimeout", "1s")     # Add executors after 1s of pending tasks
spark.conf.set("spark.dynamicAllocation.executorIdleTimeout", "60s")        # Remove idle executors after 60s
spark.conf.set("spark.dynamicAllocation.cachedExecutorIdleTimeout", "600s") # Keep executors with cached data longer
```

---

## Method 7: Executor Sizing Rules of Thumb

```
Sizing Guide (for YARN/Kubernetes):

  TOTAL CLUSTER: 100 cores, 400GB RAM

  ❌ BAD: 1 executor with 100 cores and 400GB RAM
     - GC pauses on 400GB heap are brutal
     - Single point of failure

  ❌ BAD: 100 executors with 1 core and 4GB RAM
     - No parallelism within executor (can't run concurrent tasks)
     - Broadcast variables replicated 100 times

  ✅ GOOD: 20 executors with 5 cores and 20GB RAM
     - 5 concurrent tasks per executor
     - Reasonable GC overhead
     - Good broadcast efficiency

  Rules:
  1. Executor cores: 3-5 (sweet spot, HDFS throughput degrades beyond 5)
  2. Executor memory: 15-30GB (avoid >40GB due to GC)
  3. Leave 1 core + 1GB per node for OS/YARN overhead
  4. Driver: same or smaller than executor (unless large collects/broadcasts)
  5. Memory overhead: 10% of executor memory (more for PySpark)
```

---

## Practical Tuning Session: Diagnosis → Fix → Verify

```python
# Step 1: Run the slow job
result = (
    orders
    .join(products, "product_id")
    .groupBy("category", "order_date")
    .agg(F.sum(F.col("quantity") * F.col("price")).alias("revenue"))
)
result.write.mode("overwrite").parquet("/tmp/revenue")

# Step 2: Check the execution plan
result.explain("formatted")
# Look for:
# - Exchange (shuffle) nodes: how many shuffles?
# - SortMergeJoin vs BroadcastHashJoin: is small table being broadcast?
# - FileScan: is predicate pushdown happening?

# Step 3: Check Spark UI
# - Stages tab: which stage is slowest?
# - Tasks within stage: is one task much slower than others? (skew!)
# - Shuffle Read/Write: how much data is being shuffled?
# - Spill (Memory) and Spill (Disk): any spilling?

# Step 4: Apply fixes
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "50MB")  # Products table is small
spark.conf.set("spark.sql.shuffle.partitions", "40")             # Right-size for data volume

# Step 5: Verify improvement
result2 = (
    orders
    .join(broadcast(products), "product_id")  # Force broadcast
    .groupBy("category", "order_date")
    .agg(F.sum(F.col("quantity") * F.col("price")).alias("revenue"))
)
result2.explain("formatted")
# Verify: BroadcastHashJoin (no shuffle for join), only 1 Exchange (for groupBy)
```

---

## Configuration Quick Reference

| Config | Default | Recommended | When to Change |
|--------|---------|-------------|---------------|
| `spark.sql.shuffle.partitions` | 200 | Data-dependent | Always — 200 is rarely right |
| `spark.sql.adaptive.enabled` | true (3.2+) | true | Verify it's on |
| `spark.sql.autoBroadcastJoinThreshold` | 10MB | 10-100MB | When small tables aren't broadcast |
| `spark.executor.memory` | 1g | 8-20g | Almost always |
| `spark.executor.cores` | 1 | 3-5 | Almost always |
| `spark.driver.memory` | 1g | 2-8g | If driver OOM |
| `spark.executor.memoryOverhead` | max(384MB, 0.1×mem) | 10-20% of mem | PySpark UDFs, large broadcasts |
| `spark.memory.fraction` | 0.6 | 0.6-0.7 | Heavy shuffle workloads |
| `spark.serializer` | Java | Kryo | Always for production |
| `spark.dynamicAllocation.enabled` | false | true | Multi-tenant clusters |
| `spark.sql.files.maxPartitionBytes` | 128MB | 128-256MB | File scan parallelism |
| `spark.sql.adaptive.skewJoin.enabled` | true | true | Verify it's on |

---

## Key Interview Talking Points

1. **"200 is the magic wrong number"** — Default shuffle partitions is 200. Explain why it's wrong for both small and large datasets and how to calculate the right value.

2. **Always start with AQE** — Before manual tuning, enable AQE. It auto-coalesces partitions, handles skew joins, and converts join strategies at runtime.

3. **The broadcast threshold trick** — Know that the default 10MB threshold is conservative. Increasing it to 50-100MB can eliminate shuffles for medium-sized lookup tables.

4. **Memory layout matters** — Explain the unified memory model (execution + storage share a pool). Know that execution memory can evict storage but not vice versa.

5. **Executor sizing is about trade-offs** — Too few large executors = GC problems. Too many small executors = overhead and broadcast replication. Sweet spot: 3-5 cores, 15-20GB per executor.

6. **Spill is the red flag** — If Spark UI shows spill to disk, either increase memory or increase partition count to reduce per-task data size.

7. **Kryo for production** — Always use Kryo serializer in production. It's faster and more compact than Java serialization.

8. **Dynamic allocation for shared clusters** — Scales executors based on demand. Set min/max bounds to control cost.

---

## Interview Questions and Answers

### Q1: Your Spark job is running out of memory. Walk me through your debugging process.
**A:** (1) Check Spark UI to identify which stage fails — is it during a join, groupBy, or collect? (2) Check for data skew — if one task processes far more data than others, that's the bottleneck. (3) Check shuffle sizes — if shuffle write is very large, increase `spark.sql.shuffle.partitions` to reduce per-partition size. (4) Check for spill — if data spills to disk, increase `spark.executor.memory`. (5) Check if a broadcast join could eliminate a shuffle — if one table is small, broadcast it. (6) If it's a driver OOM, the problem is likely `collect()`, `toPandas()`, or a large broadcast variable — fix by writing to storage instead of collecting.

### Q2: What is the default value of `spark.sql.shuffle.partitions` and why is it usually wrong?
**A:** The default is 200. It's wrong because it doesn't adapt to data size. For a 100MB dataset, 200 partitions creates 500KB tasks with more scheduling overhead than actual work. For a 1TB dataset, 200 partitions creates 5GB tasks that spill to disk. The right number depends on data volume — aim for 128-256MB per partition after shuffle. AQE with `coalescePartitions.enabled` can handle this automatically by starting high and coalescing down.

### Q3: Explain Adaptive Query Execution and its three main features.
**A:** AQE re-optimizes the query plan at runtime using actual data statistics collected after each stage. Its three main features: (1) **Coalesce shuffle partitions** — merges small post-shuffle partitions to reduce task overhead. (2) **Skew join optimization** — detects and splits skewed partitions, replicating the smaller side to balance work. (3) **Runtime join strategy conversion** — if a table turns out to be small after filtering, AQE switches from SortMergeJoin to BroadcastHashJoin without a re-shuffle. AQE is enabled by default in Spark 3.2+.

### Q4: How do you size executors for a Spark job?
**A:** The sweet spot is 3-5 cores per executor with 15-20GB memory. More than 5 cores per executor degrades HDFS throughput. More than 40GB memory causes long GC pauses. Formula: for a cluster with N cores and M GB RAM across W worker nodes, leave 1 core + 1GB per node for OS overhead, then divide remaining resources into executors with 4-5 cores each. For PySpark, add extra `memoryOverhead` (15-20% of executor memory) for Python process interop.

### Q5: When would you use BroadcastHashJoin vs SortMergeJoin?
**A:** BroadcastHashJoin when one side is small enough to fit in executor memory (default threshold 10MB, adjustable). It eliminates the shuffle entirely — the small table is broadcast to all executors. SortMergeJoin when both sides are large — it requires sorting and shuffling both sides but handles unlimited data sizes. ShuffledHashJoin is a middle ground — shuffles both sides but builds a hash table on the smaller side instead of sorting. Use `broadcast()` hint to force broadcast when you know a table is small but Spark's statistics don't reflect it.

### Q6: What does "spill" mean in Spark UI and how do you fix it?
**A:** Spill occurs when a task's data exceeds available execution memory, forcing Spark to write intermediate results to disk and read them back. This is visible in Spark UI under "Spill (Memory)" and "Spill (Disk)" columns in the stage detail. To fix: (1) Increase `spark.executor.memory`, (2) increase `spark.sql.shuffle.partitions` to reduce per-task data size, (3) increase `spark.memory.fraction` to give more heap to execution, or (4) reduce the operation's memory footprint (e.g., use broadcast join instead of sort-merge join).

### Q7: What's the difference between `repartition()` and `coalesce()`?
**A:** `repartition(n)` does a full shuffle to create exactly n partitions with roughly equal sizes — use when increasing partitions or rebalancing skewed data. `coalesce(n)` reduces partitions without a shuffle by merging adjacent partitions — use only to decrease partition count (e.g., before writing to avoid small files). `coalesce` can create uneven partitions if the input is already skewed. Never use `coalesce` to increase partitions — it won't work.

### Q8: How do you handle the small file problem in Spark?
**A:** Small files (< 128MB) cause excessive task overhead and slow reads. Prevention: set `spark.sql.shuffle.partitions` appropriately before writing, or use `coalesce()` to reduce file count. Fix after writing: use Delta Lake's `OPTIMIZE` command to compact small files, or run a re-partitioning job. For reads, set `spark.sql.files.maxPartitionBytes` (default 128MB) — Spark will combine small files into single partitions. AQE's coalesce feature also helps by merging small shuffle partitions before writing.

---
