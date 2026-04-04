# PySpark Implementation: Shuffle Optimization

## Problem Statement

**Shuffles** are one of the most expensive operations in Spark — they involve writing data to disk, transferring it across the network, and reading it back. Understanding when shuffles occur and how to minimize them is a key skill for senior data engineers and a frequent interview topic.

### Operations That Cause Shuffles

- `join()` (except broadcast joins)
- `groupBy()` + aggregation
- `repartition()`
- `distinct()`
- `orderBy()` / `sort()`
- Window functions with `partitionBy`

---

## Sample Data

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, broadcast, count, sum as spark_sum

spark = SparkSession.builder \
    .appName("ShuffleOptimization") \
    .config("spark.sql.shuffle.partitions", "200") \
    .config("spark.sql.adaptive.enabled", "true") \
    .getOrCreate()

# Large transactions table
transactions = spark.createDataFrame([
    (1, "C001", 100.0, "2024-01-01"),
    (2, "C001", 200.0, "2024-01-02"),
    (3, "C002", 150.0, "2024-01-01"),
    (4, "C003", 300.0, "2024-01-03"),
    (5, "C002", 250.0, "2024-01-02"),
], ["txn_id", "customer_id", "amount", "txn_date"])

# Small lookup table
customers = spark.createDataFrame([
    ("C001", "Alice", "Gold"),
    ("C002", "Bob", "Silver"),
    ("C003", "Charlie", "Bronze"),
], ["customer_id", "name", "tier"])
```

---

## Method 1: Broadcast Joins (Eliminate Shuffle)

```python
# BAD: Sort-merge join — shuffles both tables
result_bad = transactions.join(customers, "customer_id")
result_bad.explain()
# Physical plan shows Exchange (shuffle) on both sides

# GOOD: Broadcast join — no shuffle, small table sent to all executors
result_good = transactions.join(broadcast(customers), "customer_id")
result_good.explain()
# Physical plan shows BroadcastHashJoin — no Exchange

# Configure auto-broadcast threshold (default 10MB)
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "50m")  # 50 MB
# Spark will auto-broadcast tables smaller than this threshold
```

---

## Method 2: Tune Shuffle Partitions

```python
# Default: 200 shuffle partitions — often too many for small data, too few for big data

# For small datasets (< 1 GB)
spark.conf.set("spark.sql.shuffle.partitions", "20")

# For large datasets (100+ GB)
spark.conf.set("spark.sql.shuffle.partitions", "1000")

# BEST: Use AQE to auto-tune
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.initialPartitionNum", "500")
spark.conf.set("spark.sql.adaptive.advisoryPartitionSizeInBytes", "128m")

# Rule of thumb: target 100-200 MB per partition after shuffle
# total_shuffle_data / target_partition_size = num_partitions
# Example: 50 GB shuffle → 50000 MB / 200 MB = 250 partitions
```

---

## Method 3: Pre-Partition to Avoid Repeated Shuffles

```python
# If you join/groupBy on the same key multiple times, repartition once upfront

# BAD: Two separate shuffles
agg1 = transactions.groupBy("customer_id").agg(spark_sum("amount"))
agg2 = transactions.groupBy("customer_id").agg(count("*"))

# GOOD: Repartition once, reuse
txn_partitioned = transactions.repartition("customer_id").cache()
agg1 = txn_partitioned.groupBy("customer_id").agg(spark_sum("amount"))
agg2 = txn_partitioned.groupBy("customer_id").agg(count("*"))
# Second groupBy reuses existing partitioning — no additional shuffle
```

---

## Method 4: Bucketing (Pre-Shuffle at Write Time)

```python
# Write bucketed table — data is pre-shuffled on disk
transactions.write \
    .bucketBy(16, "customer_id") \
    .sortBy("customer_id") \
    .saveAsTable("bucketed_transactions")

customers.write \
    .bucketBy(16, "customer_id") \
    .sortBy("customer_id") \
    .saveAsTable("bucketed_customers")

# Join bucketed tables — NO shuffle at query time
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "-1")  # disable broadcast to test
bucketed_txn = spark.table("bucketed_transactions")
bucketed_cust = spark.table("bucketed_customers")
result = bucketed_txn.join(bucketed_cust, "customer_id")
result.explain()
# Shows SortMergeJoin WITHOUT Exchange nodes
```

---

## Method 5: Map-Side Aggregation (Reduce Shuffle Volume)

```python
# Spark already does partial (map-side) aggregation for simple aggs.
# But you can help by reducing data BEFORE the shuffle:

# BAD: Shuffle all columns, then aggregate
result = transactions.groupBy("customer_id").agg(spark_sum("amount"))

# BETTER: Select only needed columns first (less data shuffled)
result = transactions.select("customer_id", "amount") \
    .groupBy("customer_id").agg(spark_sum("amount"))
```

---

## Method 6: Identify Shuffles via explain()

```python
# Use explain() to find shuffle operations
transactions.join(customers, "customer_id").explain(True)

# Look for these in the physical plan:
# - Exchange hashpartitioning  → shuffle happening
# - Exchange roundrobin        → repartition shuffle
# - Exchange SinglePartition   → coalesce to 1 partition
# - BroadcastExchange          → broadcast (good, no shuffle)

# Extended explain shows more details
transactions.join(customers, "customer_id").explain("formatted")
```

---

## Method 7: AQE (Adaptive Query Execution)

```python
spark.conf.set("spark.sql.adaptive.enabled", "true")

# Key AQE features that reduce shuffle overhead:
# 1. Coalesce shuffle partitions — merges small partitions
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")

# 2. Convert sort-merge join to broadcast join at runtime
spark.conf.set("spark.sql.adaptive.localShuffleReader.enabled", "true")

# 3. Handle skewed joins by splitting skewed partitions
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionFactor", "5")
spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes", "256m")
```

---

## Key Takeaways

| Technique | When to Use | Shuffle Impact |
|-----------|-------------|----------------|
| Broadcast join | Small table < 100-200 MB | Eliminates shuffle |
| Bucketing | Repeated joins on same key | Pre-shuffles at write time |
| Pre-repartition + cache | Multiple operations on same key | One shuffle instead of many |
| Reduce columns before shuffle | Always | Less data transferred |
| Tune shuffle partitions | Always | Right-sized partitions |
| AQE | Spark 3.0+ (enable by default) | Auto-optimizes at runtime |

## Interview Tips

1. **Know what causes shuffles** — joins, groupBy, distinct, repartition, sort
2. **First optimization**: broadcast joins for small tables
3. **Second optimization**: tune `spark.sql.shuffle.partitions` (or use AQE)
4. **Explain the cost**: shuffles write to disk + network transfer + read back — O(data size)
5. **AQE is the modern answer** — always enable it in Spark 3.0+
6. **Bucketing** is the advanced answer for repeated join patterns
