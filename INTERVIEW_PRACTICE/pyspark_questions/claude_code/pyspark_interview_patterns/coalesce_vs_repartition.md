# PySpark Implementation: coalesce() vs repartition()

## Problem Statement

Controlling the number of partitions in a PySpark DataFrame is critical for performance tuning. Two operations exist for changing partition counts: `coalesce()` and `repartition()`. They behave very differently under the hood, and choosing the wrong one can cause significant performance problems.

| Feature | `coalesce(n)` | `repartition(n)` |
|---|---|---|
| Can increase partitions? | **No** (only decrease) | Yes |
| Can decrease partitions? | Yes | Yes |
| Triggers shuffle? | **No** (narrow dependency) | **Yes** (wide dependency) |
| Data distribution | Uneven (merges existing) | Even (full redistribution) |
| Repartition by column? | **No** | Yes |

**Key Gotcha:** `coalesce()` avoids a shuffle but produces uneven partition sizes because it simply merges adjacent partitions. `repartition()` does a full shuffle but produces evenly distributed partitions. For writing output files, uneven partitions from `coalesce()` can produce files of wildly different sizes.

---

## Setup

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("coalesce vs repartition") \
    .master("local[*]") \
    .config("spark.sql.shuffle.partitions", "200") \
    .getOrCreate()

spark.sparkContext.setLogLevel("WARN")
```

---

## Part 1: Basic Partition Behavior

### Sample Data

```python
# Create a DataFrame with a known number of partitions
df = spark.range(1_000_000)
print(f"Default partitions: {df.rdd.getNumPartitions()}")

# After a shuffle operation (groupBy, join, etc.)
df_shuffled = df.groupBy((F.col("id") % 10).alias("group")).count()
print(f"After shuffle: {df_shuffled.rdd.getNumPartitions()}")
# This will be 200 (from spark.sql.shuffle.partitions)
```

### Expected Output

```
Default partitions: 8    (depends on cores)
After shuffle: 200
```

---

## Part 2: coalesce() -- Reducing Partitions Without Shuffle

### How coalesce Works

```python
df = spark.range(1_000_000).repartition(12)
print(f"Starting partitions: {df.rdd.getNumPartitions()}")

# Coalesce to fewer partitions
df_coalesced = df.coalesce(4)
print(f"After coalesce(4): {df_coalesced.rdd.getNumPartitions()}")

# Check partition sizes -- they will be UNEVEN
partition_sizes = df_coalesced.withColumn(
    "partition_id", F.spark_partition_id()
).groupBy("partition_id").count().orderBy("partition_id")

partition_sizes.show()
```

### Expected Output

```
Starting partitions: 12
After coalesce(4): 4

+------------+------+
|partition_id|count |
+------------+------+
|0           |250000|
|1           |250000|
|2           |250000|
|3           |250000|
+------------+------+
```

**Note:** In this case with `range` the distribution may be even, but with real-world data after filters and joins, coalesce typically produces uneven partitions.

### coalesce Cannot Increase Partitions

```python
df_small = spark.range(100).coalesce(2)
print(f"Starting: {df_small.rdd.getNumPartitions()}")

# Attempting to increase partitions with coalesce
df_attempt = df_small.coalesce(10)
print(f"After coalesce(10): {df_attempt.rdd.getNumPartitions()}")
# Still 2! coalesce ignores requests to increase.
```

### Expected Output

```
Starting: 2
After coalesce(10): 2
```

---

## Part 3: repartition() -- Full Shuffle Redistribution

### Even Distribution

```python
df = spark.range(1_000_000)

# Repartition to exact number with full shuffle
df_repart = df.repartition(5)
print(f"Partitions: {df_repart.rdd.getNumPartitions()}")

# Check partition sizes -- they will be EVEN (approximately)
df_repart.withColumn(
    "partition_id", F.spark_partition_id()
).groupBy("partition_id").count().orderBy("partition_id").show()
```

### Expected Output

```
Partitions: 5

+------------+------+
|partition_id|count |
+------------+------+
|0           |200000|
|1           |200000|
|2           |200000|
|3           |200000|
|4           |200000|
+------------+------+
```

### Repartition Can Increase or Decrease

```python
df = spark.range(100).coalesce(2)
print(f"Starting: {df.rdd.getNumPartitions()}")

df_more = df.repartition(10)
print(f"After repartition(10): {df_more.rdd.getNumPartitions()}")

df_less = df.repartition(1)
print(f"After repartition(1): {df_less.rdd.getNumPartitions()}")
```

### Expected Output

```
Starting: 2
After repartition(10): 10
After repartition(1): 1
```

---

## Part 4: repartition() by Column

### Sample Data

```python
data = [
    ("2024-01-01", "US", 100),
    ("2024-01-01", "UK", 200),
    ("2024-01-02", "US", 150),
    ("2024-01-02", "UK", 250),
    ("2024-01-01", "US", 120),
    ("2024-01-02", "US", 180),
    ("2024-01-01", "UK", 90),
    ("2024-01-02", "UK", 300),
]

df = spark.createDataFrame(data, ["date", "country", "revenue"])
```

### Repartition by Column (hash partitioning)

```python
# Repartition by country -- all rows for the same country end up in the same partition
df_by_country = df.repartition("country")
print(f"Partitions: {df_by_country.rdd.getNumPartitions()}")

# Verify: check which partition each country lands in
df_by_country.withColumn(
    "partition_id", F.spark_partition_id()
).select("country", "partition_id").distinct().show()
```

### Expected Output

```
Partitions: 200

+-------+------------+
|country|partition_id|
+-------+------------+
|US     |42          |
|UK     |117         |
+-------+------------+
```

### Repartition by Column with Specified Count

```python
# Control both column and partition count
df_by_country_4 = df.repartition(4, "country")
print(f"Partitions: {df_by_country_4.rdd.getNumPartitions()}")

df_by_country_4.withColumn(
    "partition_id", F.spark_partition_id()
).select("country", "partition_id").distinct().show()
```

### Repartition by Multiple Columns

```python
# Repartition by both date and country
df_by_both = df.repartition(4, "date", "country")

df_by_both.withColumn(
    "partition_id", F.spark_partition_id()
).select("date", "country", "partition_id").distinct().orderBy("date", "country").show()
```

### Why Repartition by Column?

```python
"""
Use repartition(col) when:

1. BEFORE A JOIN: Repartition both DataFrames by the join key.
   This ensures matching keys are co-located, avoiding shuffles during the join.

   df_left = df_left.repartition("join_key")
   df_right = df_right.repartition("join_key")
   result = df_left.join(df_right, "join_key")

2. BEFORE WRITING PARTITIONED OUTPUT:
   df.repartition("date").write.partitionBy("date").parquet("/output")
   This ensures one file per partition value (no small files).

3. BEFORE WINDOW FUNCTIONS:
   Repartition by the partitionBy column to reduce shuffle overhead.
"""
```

---

## Part 5: Narrow vs Wide Dependencies

### Conceptual Explanation

```python
"""
NARROW DEPENDENCY (coalesce):
  Partition 1 ─┐
  Partition 2 ─┤──> New Partition A
  Partition 3 ─┘
  Partition 4 ─┐
  Partition 5 ─┤──> New Partition B
  Partition 6 ─┘

  - Each child partition depends on a subset of parent partitions
  - No data exchange between executors needed
  - Merges adjacent partitions in-place
  - FAST but UNEVEN

WIDE DEPENDENCY (repartition):
  Partition 1 ─┬─> New Partition A (hash-based)
  Partition 2 ─┤─> New Partition B (hash-based)
  Partition 3 ─┤─> ...
  Partition 4 ─┤
  Partition 5 ─┤
  Partition 6 ─┘

  - Each child partition may depend on ALL parent partitions
  - Data is shuffled across the network (expensive)
  - Uses hash partitioning for even distribution
  - SLOW but EVEN
"""
```

### Visualizing with Execution Plans

```python
df = spark.range(1_000_000).repartition(12)

# coalesce -- no Exchange (shuffle) stage
print("=== coalesce plan ===")
df.coalesce(4).explain()

# repartition -- shows Exchange (shuffle) stage
print("\n=== repartition plan ===")
df.repartition(4).explain()
```

### Expected Output

```
=== coalesce plan ===
== Physical Plan ==
Coalesce 4
+- Exchange RoundRobinPartitioning(12), ...
   +- Range (0, 1000000, step=1, splits=8)

=== repartition plan ===
== Physical Plan ==
Exchange RoundRobinPartitioning(4), ...
+- Exchange RoundRobinPartitioning(12), ...
   +- Range (0, 1000000, step=1, splits=8)
```

---

## Part 6: Performance Comparison

```python
import time

df_large = spark.range(10_000_000).withColumn(
    "group", (F.col("id") % 1000).cast("string")
).withColumn(
    "value", F.rand()
)

# Force materialization
df_large = df_large.repartition(100)
df_large.cache()
df_large.count()

# Benchmark coalesce
start = time.time()
df_large.coalesce(10).write.mode("overwrite").parquet("/tmp/coalesce_test")
coalesce_time = time.time() - start

# Benchmark repartition
start = time.time()
df_large.repartition(10).write.mode("overwrite").parquet("/tmp/repartition_test")
repartition_time = time.time() - start

print(f"coalesce(10):    {coalesce_time:.3f}s")
print(f"repartition(10): {repartition_time:.3f}s")

# Check file sizes
import subprocess
result_c = subprocess.run(["du", "-sh", "/tmp/coalesce_test"], capture_output=True, text=True)
result_r = subprocess.run(["du", "-sh", "/tmp/repartition_test"], capture_output=True, text=True)
print(f"coalesce output size:    {result_c.stdout.strip()}")
print(f"repartition output size: {result_r.stdout.strip()}")

df_large.unpersist()
```

---

## Part 7: Common Interview Scenarios

### Scenario 1: Reducing Partitions Before Writing (Most Common)

```python
# After a groupBy, you have 200 partitions but want fewer output files
df_grouped = spark.range(1_000_000).groupBy(
    (F.col("id") % 50).alias("group")
).agg(F.count("*").alias("cnt"))

print(f"Partitions after groupBy: {df_grouped.rdd.getNumPartitions()}")
# 200 partitions -> 200 tiny files if you write directly

# Use coalesce to reduce (no shuffle since we're reducing)
df_grouped.coalesce(10).write.mode("overwrite").parquet("/tmp/output_10_files")

# Verify file count
import os
files = [f for f in os.listdir("/tmp/output_10_files") if f.endswith(".parquet")]
print(f"Output files: {len(files)}")
```

### Scenario 2: Why NOT to Use coalesce Before a Join

```python
"""
BAD PATTERN:
  df_big = spark.read.parquet("big_data")  # 1000 partitions
  df_small = spark.read.parquet("small_data")  # 100 partitions
  
  # DON'T DO THIS: coalesce(1) before join creates a bottleneck
  result = df_big.coalesce(1).join(df_small, "key")

GOOD PATTERN:
  # Repartition by join key for co-location
  result = df_big.repartition("key").join(df_small.repartition("key"), "key")
  # Then coalesce AFTER the join for output
  result.coalesce(10).write.parquet("output")
"""
```

### Scenario 3: The "1 partition" Interview Question

```python
"""
INTERVIEW QUESTION: "How do you write a DataFrame to a single file?"

Answer 1 (coalesce -- preferred for reducing):
  df.coalesce(1).write.parquet("/output")
  
Answer 2 (repartition -- if you need even distribution first):
  df.repartition(1).write.parquet("/output")

FOLLOW-UP: "What's the problem with this?"
- All data must fit in a single executor's memory
- No parallelism -- one task writes everything
- For large datasets, this will fail with OOM

BETTER ANSWER for large datasets:
  df.coalesce(10).write.parquet("/output")  # 10 manageable files
"""
```

### Scenario 4: Partition Skew

```python
# Demonstrate skew with repartition by column
skewed_data = [(1, "US")] * 900 + [(2, "UK")] * 100

df_skewed = spark.createDataFrame(skewed_data, ["id", "country"])

# Repartition by country -- creates skew
df_by_country = df_skewed.repartition("country")
df_by_country.withColumn(
    "partition_id", F.spark_partition_id()
).groupBy("partition_id", "country").count().show()
```

### Expected Output

```
+------------+-------+-----+
|partition_id|country|count|
+------------+-------+-----+
|42          |US     |900  |
|117         |UK     |100  |
+------------+-------+-----+
```

**Skew problem:** Partition with "US" has 9x more data. The task processing it takes 9x longer, becoming a bottleneck.

### Scenario 5: Optimal Partition Count Heuristic

```python
"""
RULES OF THUMB:

1. Target partition size: 128MB - 256MB per partition
   total_size_MB / 200 = approximate number of partitions

2. Minimum: 2x the number of cores in your cluster
   e.g., 10 executors * 4 cores = 40 cores -> at least 80 partitions

3. Maximum: Don't exceed 100,000 partitions (scheduler overhead)

4. After filter that removes most data:
   df_filtered = df.filter(condition)  # might have many empty partitions
   df_filtered = df_filtered.coalesce(new_count)  # consolidate

5. Before writing output:
   - Target file size of 128MB - 1GB per file for optimal read performance
   - num_files = total_data_size / target_file_size
"""

# Helper to estimate partition count
def recommend_partitions(df, target_mb=200):
    """Estimate optimal partition count based on data size."""
    # Sample-based size estimation
    sample_count = 1000
    total_count = df.count()
    sample = df.limit(sample_count)
    
    # Rough size estimate per row (serialize a small sample)
    import sys
    sample_rows = sample.collect()
    avg_row_size = sum(sys.getsizeof(str(row)) for row in sample_rows) / len(sample_rows)
    
    total_size_mb = (avg_row_size * total_count) / (1024 * 1024)
    recommended = max(1, int(total_size_mb / target_mb))
    
    print(f"Estimated total size: {total_size_mb:.0f} MB")
    print(f"Recommended partitions ({target_mb}MB target): {recommended}")
    return recommended
```

---

## Part 8: getNumPartitions() and spark_partition_id()

```python
df = spark.range(100).repartition(5)

# Check partition count
print(f"Partition count: {df.rdd.getNumPartitions()}")

# See which rows are in which partition
df.withColumn("partition_id", F.spark_partition_id()).show(20)

# Count rows per partition
df.withColumn("partition_id", F.spark_partition_id()) \
  .groupBy("partition_id").count() \
  .orderBy("partition_id").show()
```

### Expected Output

```
Partition count: 5

+------------+-----+
|partition_id|count|
+------------+-----+
|0           |20   |
|1           |20   |
|2           |20   |
|3           |20   |
|4           |20   |
+------------+-----+
```

---

## Interview Tips

1. **The #1 interview question:** "What is the difference between coalesce and repartition?" Answer: coalesce avoids a shuffle (narrow dependency) but can only decrease partitions and produces uneven sizes. repartition does a full shuffle (wide dependency) but can increase or decrease and produces even sizes.

2. **When to use coalesce:** Reducing partitions before writing output files, after a filter that removed most data, when you do not need even distribution.

3. **When to use repartition:** Increasing partitions, repartitioning by column before a join, when even distribution is important for downstream processing.

4. **coalesce(1) vs repartition(1):** For small data, coalesce(1) is better (no shuffle). For large data, both are bad because they create a single-executor bottleneck.

5. **After a join or groupBy:** Spark uses `spark.sql.shuffle.partitions` (default 200) partitions. This is often too many for small datasets or too few for large ones. Adjust with `spark.conf.set("spark.sql.shuffle.partitions", "auto")` (Spark 3.0+ AQE) or set explicitly.

6. **Adaptive Query Execution (AQE):** In Spark 3.0+, enable `spark.sql.adaptive.enabled=true` and `spark.sql.adaptive.coalescePartitions.enabled=true`. AQE automatically coalesces small partitions after shuffles, reducing the need for manual partition management.

7. **File count = partition count** when writing. If you `coalesce(10).write.parquet(path)`, you get exactly 10 parquet files (assuming no partitionBy in the write).

8. **repartition by column before partitionBy write** is a best practice:
   ```python
   df.repartition("date").write.partitionBy("date").parquet(path)
   ```
   This ensures one file per date partition instead of up to 200 files per date.
