# PySpark Implementation: Custom Partitioning Strategies for Skewed Data

## Problem Statement

Given a dataset with **uneven key distribution** (data skew), demonstrate how to implement custom partitioning strategies to achieve balanced data distribution across partitions. Show how to control which data goes to which partition, handle hot keys, and optimize downstream operations like joins and writes.

This question tests deep understanding of Spark's shuffle mechanism, partition management, and performance tuning for real-world skewed datasets.

### Sample Data

**Sales Transactions (skewed — store S001 dominates):**
```
txn_id   store_id  product   amount   txn_date
T001     S001      Laptop    999.99   2025-01-15
T002     S001      Mouse     29.99    2025-01-15
T003     S001      Keyboard  79.99    2025-01-16
T004     S001      Monitor   349.99   2025-01-16
T005     S001      Laptop    999.99   2025-01-17
T006     S002      Mouse     29.99    2025-01-15
T007     S003      Keyboard  79.99    2025-01-16
T008     S001      Headset   149.99   2025-01-17
T009     S002      Laptop    999.99   2025-01-17
T010     S001      Mouse     29.99    2025-01-18
```

### The Problem

Default hash partitioning on `store_id` sends 7 of 10 records to the same partition (S001). This creates:
- One overloaded partition doing most of the work
- Other partitions sitting idle
- Slow overall job execution

---

## Method 1: Composite Key Partitioning

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, concat, lit, spark_partition_id, count,
    floor, rand, hash as spark_hash, abs as spark_abs
)

# Initialize Spark session
spark = SparkSession.builder.appName("CustomPartitioning").getOrCreate()

# Sales data (skewed toward S001)
sales_data = [
    ("T001", "S001", "Laptop",   999.99, "2025-01-15"),
    ("T002", "S001", "Mouse",     29.99, "2025-01-15"),
    ("T003", "S001", "Keyboard",  79.99, "2025-01-16"),
    ("T004", "S001", "Monitor",  349.99, "2025-01-16"),
    ("T005", "S001", "Laptop",   999.99, "2025-01-17"),
    ("T006", "S002", "Mouse",     29.99, "2025-01-15"),
    ("T007", "S003", "Keyboard",  79.99, "2025-01-16"),
    ("T008", "S001", "Headset",  149.99, "2025-01-17"),
    ("T009", "S002", "Laptop",   999.99, "2025-01-17"),
    ("T010", "S001", "Mouse",     29.99, "2025-01-18"),
]
sales_df = spark.createDataFrame(sales_data, ["txn_id", "store_id", "product", "amount", "txn_date"])

# Step 1: Check current skew
print("=== Key Distribution (Skew Check) ===")
sales_df.groupBy("store_id").agg(count("*").alias("record_count")).show()

# Step 2: Repartition by composite key (store_id + txn_date)
# This spreads S001 records across multiple partitions based on date
sales_composite = sales_df.repartition(4, "store_id", "txn_date")

# Step 3: Verify new partition distribution
print("=== After Composite Key Partitioning ===")
sales_composite.withColumn("partition_id", spark_partition_id()) \
    .groupBy("partition_id") \
    .agg(count("*").alias("record_count")) \
    .orderBy("partition_id") \
    .show()
```

### Step-by-Step Explanation

#### Step 1: Skew Check Output
```
+--------+------------+
|store_id|record_count|
+--------+------------+
|    S001|           7|  <-- 70% of data
|    S002|           2|
|    S003|           1|
+--------+------------+
```

#### Step 2: Composite Key
- Instead of partitioning on `store_id` alone, we use `(store_id, txn_date)`.
- S001 records are now distributed across multiple partitions because they have different dates.
- S001+2025-01-15, S001+2025-01-16, S001+2025-01-17, S001+2025-01-18 each hash to potentially different partitions.

#### Step 3: Balanced Distribution
```
+------------+------------+
|partition_id|record_count|
+------------+------------+
|           0|           3|
|           1|           2|
|           2|           3|
|           3|           2|
+------------+------------+
```

---

## Method 2: RDD-Level Custom Partitioner

```python
from pyspark.sql.functions import col

# For complete control, drop to RDD and use a custom partitioner
NUM_PARTITIONS = 4

# Convert DataFrame to RDD of (key, row) pairs
sales_rdd = sales_df.rdd.map(lambda row: (row["store_id"], row))

# Define custom partitioner function
def custom_partitioner(key):
    """
    Custom logic: spread hot key S001 across partitions 0-2,
    everything else goes to partition 3.
    """
    if key == "S001":
        # Distribute S001 across partitions 0, 1, 2 using hash of full row
        return hash(key) % 3  # Partitions 0-2
    else:
        return 3  # All others to partition 3

# Apply custom partitioner
sales_partitioned_rdd = sales_rdd.partitionBy(NUM_PARTITIONS, custom_partitioner)

# Verify partition distribution
for i in range(NUM_PARTITIONS):
    partition_count = sales_partitioned_rdd.mapPartitionsWithIndex(
        lambda idx, it: [(idx, sum(1 for _ in it))]
    ).filter(lambda x: x[0] == i).collect()
    print(f"Partition {i}: {partition_count[0][1] if partition_count else 0} records")

# Convert back to DataFrame
sales_repart_df = sales_partitioned_rdd.map(lambda x: x[1]).toDF(sales_df.schema)
sales_repart_df.show()
```

### When to Use RDD Partitioner
- When you need complete control over which records go to which partition.
- When hash-based or range-based partitioning does not solve your skew problem.
- Trade-off: Dropping to RDD loses Catalyst optimizer benefits.

---

## Method 3: Salted Repartitioning for Hot Keys

```python
from pyspark.sql.functions import when, floor, rand, concat, lit

NUM_SALT_BUCKETS = 3

# Step 1: Identify hot keys (keys with disproportionate share of data)
key_counts = sales_df.groupBy("store_id").count()
total_count = sales_df.count()
hot_keys = key_counts.filter(col("count") > total_count * 0.3) \
    .select("store_id").rdd.flatMap(lambda x: x).collect()

print(f"Hot keys: {hot_keys}")  # ['S001']

# Step 2: Add salt column only for hot keys
sales_salted = sales_df.withColumn(
    "partition_key",
    when(
        col("store_id").isin(hot_keys),
        concat(col("store_id"), lit("_"), floor(rand() * NUM_SALT_BUCKETS).cast("int"))
    ).otherwise(col("store_id"))
)

# Step 3: Repartition on the salted key
sales_balanced = sales_salted.repartition(4, "partition_key")

# Verify distribution
print("=== After Salted Repartitioning ===")
sales_balanced.withColumn("partition_id", spark_partition_id()) \
    .groupBy("partition_id") \
    .agg(count("*").alias("record_count")) \
    .orderBy("partition_id") \
    .show()

# Show the salted keys
sales_salted.select("txn_id", "store_id", "partition_key").show()
```

### Output (partition_key column)
```
+------+--------+-------------+
|txn_id|store_id|partition_key|
+------+--------+-------------+
|  T001|    S001|      S001_0 |
|  T002|    S001|      S001_2 |
|  T003|    S001|      S001_1 |
|  T004|    S001|      S001_0 |
|  T005|    S001|      S001_2 |
|  T006|    S002|        S002 |
|  T007|    S003|        S003 |
|  T008|    S001|      S001_1 |
|  T009|    S002|        S002 |
|  T010|    S001|      S001_0 |
+------+--------+-------------+
```

---

## Method 4: repartitionByRange for Ordered Data

```python
# repartitionByRange: Distributes data into partitions based on value ranges
# Great for time-series data or numeric ranges

sales_ranged = sales_df.repartitionByRange(4, "txn_date")

# Partitions will contain date ranges:
# Partition 0: 2025-01-15
# Partition 1: 2025-01-16
# Partition 2: 2025-01-17
# Partition 3: 2025-01-18

sales_ranged.withColumn("partition_id", spark_partition_id()) \
    .select("txn_id", "store_id", "txn_date", "partition_id") \
    .orderBy("txn_date", "txn_id") \
    .show()

# Advantage: Range queries on txn_date can skip entire partitions (partition pruning)
```

---

## Method 5: Writing with Controlled Partitioning

```python
# Problem: Default write creates uneven file sizes due to skew
# Solution: Repartition before writing

# Option A: Even files by repartitioning
sales_df.repartition(4) \
    .write.mode("overwrite") \
    .parquet("/output/even_files")

# Option B: Partition by column with max records per file
sales_df.write \
    .option("maxRecordsPerFile", 3) \
    .partitionBy("store_id") \
    .mode("overwrite") \
    .parquet("/output/controlled_files")
# S001 gets split into multiple files (3 records each)
# S002 and S003 get 1 file each

# Option C: Repartition within each partition directory
sales_df.repartition("store_id") \
    .sortWithinPartitions("txn_date") \
    .write.mode("overwrite") \
    .partitionBy("store_id") \
    .parquet("/output/sorted_within")
```

---

## Diagnosing Skew in the Spark UI

```python
# Check partition sizes programmatically
def check_partition_skew(df, label="DataFrame"):
    """Print partition size distribution to detect skew."""
    partition_counts = df.withColumn("pid", spark_partition_id()) \
        .groupBy("pid") \
        .agg(count("*").alias("cnt")) \
        .orderBy("cnt")

    stats = partition_counts.agg(
        {"cnt": "min", "cnt": "max", "cnt": "avg"}
    ).collect()[0]

    print(f"\n=== {label} Partition Skew ===")
    print(f"Min partition size: {stats[0]}")
    print(f"Max partition size: {stats[1]}")
    print(f"Avg partition size: {stats[2]:.1f}")
    print(f"Skew ratio (max/avg): {stats[1]/stats[2]:.2f}x")
    partition_counts.show()

# Usage
check_partition_skew(sales_df.repartition(4, "store_id"), "Hash on store_id")
check_partition_skew(sales_df.repartition(4, "store_id", "txn_date"), "Composite key")
```

---

## Strategy Decision Guide

| Skew Scenario | Best Strategy | Why |
|---------------|--------------|-----|
| One key has 80%+ of data | Salted partitioning | Splits hot key across N buckets |
| Time-series data, queries by date range | repartitionByRange | Enables partition pruning |
| Multiple columns provide natural spread | Composite key partitioning | Simple, no data replication |
| Need exact control over placement | RDD custom partitioner | Full control (but loses Catalyst) |
| Writing files, one partition is huge | maxRecordsPerFile | Splits large partitions into multiple files |
| Skew discovered at runtime | AQE (Spark 3.0+) | Automatic, no code changes |

---

## Key Interview Talking Points

1. **What causes data skew?** "Uneven distribution of join/group keys. In real data, some keys are 'hot' — a major retailer in a sales table, a celebrity in a social media table. Hash partitioning sends all records with the same key to the same partition."

2. **Composite key partitioning:** "The simplest fix — partition on (key, secondary_column) instead of just key. Works when the hot key naturally has variety in a second column like date or product category."

3. **Salting vs composite key:** "Salting adds a random suffix to the key and is needed when there is no natural secondary column to spread the data. The downside is you must replicate the lookup table for joins."

4. **repartitionByRange vs repartition:** "repartition uses hash partitioning (even distribution but random order). repartitionByRange creates sorted ranges — useful for time-series data where downstream queries filter on the range column."

5. **maxRecordsPerFile:** "A Spark write option that caps the number of records per output file. If one partition has 1 million records and you set maxRecordsPerFile to 100000, Spark writes 10 files for that partition. Solves the small-file problem for non-skewed partitions while splitting large ones."

6. **Detecting skew:** "In the Spark UI, look for tasks in a stage where one task takes much longer than others. Programmatically, check partition sizes using spark_partition_id() and look for a high max/avg ratio."
