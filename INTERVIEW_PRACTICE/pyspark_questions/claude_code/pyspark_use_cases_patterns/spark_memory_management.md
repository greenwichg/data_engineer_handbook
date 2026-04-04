# PySpark Implementation: Spark Memory Management

## Problem Statement

Understanding Spark's memory management is critical for debugging **OutOfMemoryError**, optimizing performance, and right-sizing cluster resources. Interviewers frequently ask about the memory model, how to diagnose OOM issues, and how to tune memory settings for production workloads.

---

## Spark Executor Memory Layout

```
Total Executor Memory = spark.executor.memory + spark.executor.memoryOverhead
                      = (Heap Memory)         + (Off-Heap: overhead, PySpark, etc.)

Heap Memory (spark.executor.memory) breakdown:
┌─────────────────────────────────────────────────┐
│  Reserved Memory (300 MB fixed)                 │
├─────────────────────────────────────────────────┤
│  User Memory (1 - spark.memory.fraction)        │
│  - UDFs, internal metadata, RDD dependencies    │
├─────────────────────────────────────────────────┤
│  Unified Memory (spark.memory.fraction = 0.6)   │
│  ┌───────────────────┬─────────────────────┐    │
│  │ Storage Memory    │ Execution Memory    │    │
│  │ (cached data,     │ (shuffles, joins,   │    │
│  │  broadcasts)      │  sorts, aggregations│    │
│  │                   │                     │    │
│  │  ◄── boundary can shift dynamically ──► │    │
│  └───────────────────┴─────────────────────┘    │
└─────────────────────────────────────────────────┘
```

### Key Formulas

```
Usable Memory = (spark.executor.memory - 300MB Reserved)
Unified Memory = Usable Memory × spark.memory.fraction (default 0.6)
Storage Memory = Unified Memory × spark.memory.storageFraction (default 0.5)
Execution Memory = Unified Memory × (1 - spark.memory.storageFraction)
User Memory = Usable Memory × (1 - spark.memory.fraction) = 40%
```

---

## Method 1: Diagnosing Memory Usage

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("MemoryManagement") \
    .config("spark.executor.memory", "4g") \
    .config("spark.executor.memoryOverhead", "1g") \
    .config("spark.driver.memory", "2g") \
    .config("spark.memory.fraction", "0.6") \
    .config("spark.memory.storageFraction", "0.5") \
    .getOrCreate()

# Check current memory settings
print(f"Executor Memory: {spark.conf.get('spark.executor.memory')}")
print(f"Memory Overhead: {spark.conf.get('spark.executor.memoryOverhead', '10% of executor memory')}")
print(f"Memory Fraction: {spark.conf.get('spark.memory.fraction')}")
print(f"Storage Fraction: {spark.conf.get('spark.memory.storageFraction')}")

# Calculate actual memory breakdown for 4GB executor
executor_mem_mb = 4096
reserved = 300
usable = executor_mem_mb - reserved  # 3796 MB
unified = usable * 0.6               # 2277.6 MB
storage = unified * 0.5              # 1138.8 MB
execution = unified * 0.5            # 1138.8 MB
user_mem = usable * 0.4              # 1518.4 MB

print(f"\n--- Memory Breakdown for 4GB Executor ---")
print(f"Reserved:  {reserved} MB")
print(f"User:      {user_mem:.0f} MB")
print(f"Storage:   {storage:.0f} MB")
print(f"Execution: {execution:.0f} MB")
print(f"Unified:   {unified:.0f} MB")
```

---

## Method 2: Common OOM Scenarios and Fixes

### Scenario 1: Driver OOM during collect()

```python
# BAD - collecting large dataset to driver
all_data = large_df.collect()  # OOM if data > driver memory

# FIX 1: Increase driver memory
# spark.driver.memory = 8g

# FIX 2: Limit what you collect
sample = large_df.limit(1000).collect()

# FIX 3: Use toPandas() with Arrow (more memory-efficient)
spark.conf.set("spark.sql.execution.arrow.pyspark.enabled", "true")
pdf = large_df.limit(10000).toPandas()

# FIX 4: Write to storage instead of collecting
large_df.write.parquet("/output/path")
```

### Scenario 2: Executor OOM during joins/shuffles

```python
from pyspark.sql.functions import broadcast

# BAD - large shuffle join with skewed data
result = large_df.join(another_large_df, "key")

# FIX 1: Broadcast small table
result = large_df.join(broadcast(small_df), "key")

# FIX 2: Increase executor memory
# spark.executor.memory = 8g

# FIX 3: Increase shuffle partitions to reduce per-partition size
spark.conf.set("spark.sql.shuffle.partitions", "400")

# FIX 4: Enable AQE for automatic optimization
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
```

### Scenario 3: OOM from caching too much data

```python
# BAD - caching multiple large DataFrames
df1.cache()
df2.cache()
df3.cache()

# FIX: Unpersist when no longer needed
df1.cache()
# ... use df1 ...
df1.unpersist()

# FIX: Use MEMORY_AND_DISK to spill to disk
from pyspark import StorageLevel
df1.persist(StorageLevel.MEMORY_AND_DISK)
```

---

## Method 3: Memory Tuning for Production

```python
spark = SparkSession.builder \
    .appName("ProductionJob") \
    .config("spark.executor.memory", "8g") \
    .config("spark.executor.memoryOverhead", "2g") \
    .config("spark.driver.memory", "4g") \
    .config("spark.driver.memoryOverhead", "1g") \
    .config("spark.memory.fraction", "0.6") \
    .config("spark.memory.storageFraction", "0.5") \
    .config("spark.sql.shuffle.partitions", "200") \
    .config("spark.sql.adaptive.enabled", "true") \
    .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
    .config("spark.sql.autoBroadcastJoinThreshold", "50m") \
    .config("spark.serializer", "org.apache.spark.serializer.KryoSerializer") \
    .getOrCreate()
```

### Right-Sizing Executors

```
Rule of thumb for YARN:
- Executor cores: 3-5 per executor (avoid >5 due to HDFS throughput)
- Executor memory: 2-8 GB per core
- Leave 1 core + 1 GB per node for OS/YARN

Example: Node with 16 cores, 64 GB RAM
  - Executors per node: 3 (5 cores each, 1 reserved)
  - Memory per executor: (64 - 1) / 3 ≈ 21 GB
  - Set spark.executor.memory = 17g (leave ~4g for overhead)
  - Set spark.executor.memoryOverhead = 4g
```

---

## Method 4: Monitoring and Debugging

```python
# Check storage memory usage via Spark UI programmatically
# In Spark UI: Storage tab shows cached RDD/DataFrame memory usage
# Executors tab shows memory usage per executor

# Check if data is spilling to disk (bad for performance)
# In Spark UI: Stages tab -> look for "Spill (Memory)" and "Spill (Disk)"

# Force garbage collection analysis
# spark.executor.extraJavaOptions = -verbose:gc -XX:+PrintGCDetails

# Check partition sizes (too large = OOM, too small = overhead)
df = spark.read.parquet("/data/path")
print(f"Partitions: {df.rdd.getNumPartitions()}")

# Estimate DataFrame size in memory
df.cache()
df.count()  # trigger caching
# Check Spark UI -> Storage tab for cached size
df.unpersist()
```

---

## Key Takeaways

| Issue | Symptom | Fix |
|-------|---------|-----|
| Driver OOM | `collect()`, `toPandas()` fails | Increase driver memory, limit data |
| Executor OOM during shuffle | Stage fails with OOM | More partitions, broadcast joins, more memory |
| Executor OOM during cache | Storage eviction, slow performance | Unpersist unused, use MEMORY_AND_DISK |
| Container killed by YARN | "Container killed by YARN for exceeding memory limits" | Increase `memoryOverhead` |
| GC overhead | Tasks slow, GC time >10% | Increase memory, reduce data per partition |

## Interview Tips

1. **Know the memory layout** — draw the diagram showing Reserved → User → Unified (Storage + Execution)
2. **Unified memory** means storage and execution can borrow from each other; execution can evict cached data but not vice versa
3. **memoryOverhead** is for off-heap: PySpark worker, network buffers, internal overhead — increase this for PySpark jobs
4. **First step for OOM**: check Spark UI for spills, partition sizes, and which stage fails
5. **PySpark uses more memory** than Scala Spark due to Python worker processes — always set higher memoryOverhead
