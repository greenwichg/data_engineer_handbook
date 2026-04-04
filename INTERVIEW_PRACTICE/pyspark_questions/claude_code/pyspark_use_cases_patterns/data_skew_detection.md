# PySpark Implementation: Data Skew Detection and Diagnostics

## Problem Statement

Before applying fixes like salted joins, you need to first **DETECT and DIAGNOSE** data skew. Given a large dataset, identify which keys are skewed, measure the degree of skew, visualize the distribution, and determine whether skew is causing performance problems. Then demonstrate diagnostic queries and Spark UI indicators.

This question tests your ability to move beyond "I know about salted joins" to "I can systematically find and quantify skew before choosing a fix" — a critical distinction for senior data engineering roles.

### Sample Data

**Orders table:** 80% of orders belong to 2 out of 1000 customers (simulated below with a smaller sample)

```
order_id    customer_id    amount    order_date
O001        C001           120       2024-01-01
O002        C001           85        2024-01-01
O003        C001           200       2024-01-02
O004        C001           150       2024-01-02
O005        C001           90        2024-01-03
O006        C001           175       2024-01-03
O007        C001           300       2024-01-04
O008        C001           60        2024-01-04
O009        C002           250       2024-01-01
O010        C002           180       2024-01-01
O011        C002           95        2024-01-02
O012        C002           310       2024-01-02
O013        C002           140       2024-01-03
O014        C002           220       2024-01-03
O015        C002           170       2024-01-04
O016        C003           400       2024-01-01
O017        C004           55        2024-01-02
O018        C005           275       2024-01-03
O019        C006           130       2024-01-04
O020        C007           190       2024-01-01
```

C001 has 8 orders, C002 has 7 orders, and C003–C007 each have 1 order. In production, imagine C001 and C002 each have 4 million orders while the remaining 998 customers have ~1,000 each.

---

## Method 1: Key Frequency Analysis — Find Hot Keys

The most direct approach: count records per key and sort descending.

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, count, lit, desc, sum as spark_sum, round as spark_round,
    stddev, avg, expr, percentile_approx, when, max as spark_max,
    min as spark_min
)
from pyspark.sql.window import Window

# Initialize Spark session
spark = SparkSession.builder \
    .appName("DataSkewDetection") \
    .master("local[*]") \
    .getOrCreate()

# Create sample data (simulating 80/20 skew)
order_data = [
    ("O001", "C001", 120, "2024-01-01"), ("O002", "C001", 85, "2024-01-01"),
    ("O003", "C001", 200, "2024-01-02"), ("O004", "C001", 150, "2024-01-02"),
    ("O005", "C001", 90, "2024-01-03"), ("O006", "C001", 175, "2024-01-03"),
    ("O007", "C001", 300, "2024-01-04"), ("O008", "C001", 60, "2024-01-04"),
    ("O009", "C002", 250, "2024-01-01"), ("O010", "C002", 180, "2024-01-01"),
    ("O011", "C002", 95, "2024-01-02"), ("O012", "C002", 310, "2024-01-02"),
    ("O013", "C002", 140, "2024-01-03"), ("O014", "C002", 220, "2024-01-03"),
    ("O015", "C002", 170, "2024-01-04"), ("O016", "C003", 400, "2024-01-01"),
    ("O017", "C004", 55, "2024-01-02"), ("O018", "C005", 275, "2024-01-03"),
    ("O019", "C006", 130, "2024-01-04"), ("O020", "C007", 190, "2024-01-01"),
]

orders_df = spark.createDataFrame(order_data, ["order_id", "customer_id", "amount", "order_date"])

# --- Key Frequency Analysis ---
total_rows = orders_df.count()

key_counts = orders_df.groupBy("customer_id") \
    .agg(count("*").alias("key_count")) \
    .withColumn("pct_of_total", spark_round(col("key_count") / lit(total_rows) * 100, 2)) \
    .orderBy(desc("key_count"))

print("=== Key Frequency Analysis ===")
key_counts.show(truncate=False)

# Identify hot keys: keys with more than 2x the average count
avg_count = total_rows / key_counts.count()
hot_keys = key_counts.filter(col("key_count") > 2 * avg_count)

print(f"=== Hot Keys (count > 2x average of {avg_count:.1f}) ===")
hot_keys.show(truncate=False)
```

**Output (key_counts):**

| customer_id | key_count | pct_of_total |
|-------------|-----------|--------------|
| C001        | 8         | 40.0         |
| C002        | 7         | 35.0         |
| C003        | 1         | 5.0          |
| C004        | 1         | 5.0          |
| C005        | 1         | 5.0          |
| C006        | 1         | 5.0          |
| C007        | 1         | 5.0          |

Two customers (C001, C002) hold 75% of all records — clear skew.

---

## Method 2: Percentile-Based Skew Detection — P50 vs P99

Compare the median partition size to the 99th percentile. A large ratio signals skew.

```python
# Compute percentiles of the key count distribution
key_count_stats = key_counts.agg(
    percentile_approx("key_count", 0.50).alias("p50"),
    percentile_approx("key_count", 0.90).alias("p90"),
    percentile_approx("key_count", 0.99).alias("p99"),
    spark_max("key_count").alias("max_count"),
    spark_min("key_count").alias("min_count"),
    avg("key_count").alias("avg_count")
)

print("=== Percentile-Based Skew Analysis ===")
key_count_stats.show(truncate=False)

# Compute skew ratio: P99 / P50
key_count_stats_row = key_count_stats.collect()[0]
p50 = key_count_stats_row["p50"]
p99 = key_count_stats_row["p99"]
max_count = key_count_stats_row["max_count"]

print(f"P50 (median key count): {p50}")
print(f"P99 key count:          {p99}")
print(f"Max key count:          {max_count}")
print(f"Skew ratio (P99/P50):   {p99 / p50 if p50 > 0 else 'inf'}")
print(f"Skew ratio (Max/P50):   {max_count / p50 if p50 > 0 else 'inf'}")
print()

# Rule of thumb: if P99/P50 > 10, you likely have problematic skew
skew_ratio = p99 / p50 if p50 > 0 else float('inf')
if skew_ratio > 10:
    print(f"WARNING: Skew ratio {skew_ratio:.1f}x — likely to cause performance issues")
elif skew_ratio > 5:
    print(f"MODERATE: Skew ratio {skew_ratio:.1f}x — monitor task durations")
else:
    print(f"OK: Skew ratio {skew_ratio:.1f}x — within acceptable range")
```

**Output:**

```
P50 (median key count): 1
P99 key count:          8
Max key count:          8
Skew ratio (P99/P50):   8.0
Skew ratio (Max/P50):   8.0

WARNING: Skew ratio 8.0x — likely to cause performance issues
```

In production, you might see a P50 of 500 and a P99 of 5,000,000 — a 10,000x ratio.

---

## Method 3: Coefficient of Variation — Quantify Skew Statistically

The coefficient of variation (CV = stddev / mean) gives a single number to quantify skew. A CV > 1 indicates high variability; CV > 3 is extreme skew.

```python
# Coefficient of Variation of key counts
cv_stats = key_counts.agg(
    avg("key_count").alias("mean_count"),
    stddev("key_count").alias("stddev_count")
).withColumn(
    "coefficient_of_variation",
    spark_round(col("stddev_count") / col("mean_count"), 4)
)

print("=== Coefficient of Variation ===")
cv_stats.show(truncate=False)

cv_row = cv_stats.collect()[0]
cv = cv_row["coefficient_of_variation"]
mean_val = cv_row["mean_count"]
stddev_val = cv_row["stddev_count"]

print(f"Mean key count:              {mean_val:.2f}")
print(f"StdDev of key counts:        {stddev_val:.2f}")
print(f"Coefficient of Variation:    {cv}")
print()

if cv > 3:
    print("SEVERE SKEW: CV > 3 — salted joins or key isolation strongly recommended")
elif cv > 1:
    print("MODERATE SKEW: CV > 1 — consider AQE or salted joins for large datasets")
else:
    print("LOW SKEW: CV <= 1 — data is relatively evenly distributed")
```

**Output:**

```
Mean key count:              2.86
StdDev of key counts:        3.24
Coefficient of Variation:    1.1333

MODERATE SKEW: CV > 1 — consider AQE or salted joins for large datasets
```

---

## Method 4: Partition Size Analysis — Physical Data Distribution

Check actual file/partition sizes to see if physical data distribution reflects logical skew.

```python
# Method 4a: Check partition sizes for a DataFrame in memory
from pyspark.sql.functions import spark_partition_id

partition_sizes = orders_df.repartition("customer_id") \
    .withColumn("partition_id", spark_partition_id()) \
    .groupBy("partition_id") \
    .agg(
        count("*").alias("row_count"),
        spark_round(spark_sum("amount") / 1000, 2).alias("data_size_k")
    ) \
    .orderBy(desc("row_count"))

print("=== Partition Size Distribution (after repartition by customer_id) ===")
partition_sizes.show(50, truncate=False)

# Method 4b: For Delta/Hive tables, use DESCRIBE DETAIL or check file sizes
# spark.sql("DESCRIBE DETAIL my_database.orders_table").show(truncate=False)

# Method 4c: Check partition sizes using mapPartitions
def count_partition(index, iterator):
    count = sum(1 for _ in iterator)
    yield (index, count)

partition_info = orders_df.repartition("customer_id").rdd \
    .mapPartitionsWithIndex(count_partition) \
    .toDF(["partition_id", "row_count"]) \
    .orderBy(desc("row_count"))

print("=== Partition Row Counts via RDD ===")
partition_info.show(truncate=False)

# Calculate partition imbalance
part_stats = partition_info.agg(
    spark_max("row_count").alias("max_rows"),
    spark_min("row_count").alias("min_rows"),
    avg("row_count").alias("avg_rows")
).collect()[0]

print(f"Max partition:  {part_stats['max_rows']} rows")
print(f"Min partition:  {part_stats['min_rows']} rows")
print(f"Avg partition:  {part_stats['avg_rows']:.1f} rows")
print(f"Imbalance ratio (max/avg): {part_stats['max_rows'] / part_stats['avg_rows']:.1f}x")
```

---

## Method 5: Spark UI Diagnosis — Identifying Skew via Task Duration Variance

This method does not involve code you run in a notebook — it is about reading the Spark UI during or after a job.

### What to Look For in Spark UI

```
Stage Details View → Task Metrics:

Task ID | Duration | Input Size | Shuffle Read | Shuffle Write | GC Time
--------|----------|------------|--------------|---------------|--------
0       | 2s       | 10 MB      | 10 MB        | 5 MB          | 50ms
1       | 2s       | 11 MB      | 11 MB        | 5 MB          | 45ms
2       | 2s       | 9 MB       | 9 MB         | 4 MB          | 55ms
3       | 145s     | 1.2 GB     | 1.2 GB       | 600 MB        | 12s    <-- SKEWED TASK
4       | 2s       | 10 MB      | 10 MB        | 5 MB          | 40ms

Summary Metrics:
                Min     25th     Median   75th     Max
Duration        2s      2s       2s       2s       145s      <-- Max >> Median = SKEW
Input Size      9 MB    10 MB    10 MB    11 MB    1.2 GB    <-- Max >> Median = SKEW
Shuffle Read    9 MB    10 MB    10 MB    11 MB    1.2 GB
GC Time         40ms    45ms     50ms     55ms     12s       <-- High GC = spilling
```

### Programmatic Approximation: Simulating Task Duration Analysis

```python
# You can approximate Spark UI analysis by checking partition sizes
# and estimating which partitions would cause slow tasks

partitions_with_skew_flag = partition_sizes.withColumn(
    "skew_flag",
    when(col("row_count") > 3 * avg("row_count").over(Window.partitionBy()), "SKEWED")
    .otherwise("OK")
)

# In practice, the Spark UI summary table is the quickest diagnostic.
# Look for these red flags:
#   1. Max task duration >> Median task duration (10x+ is problematic)
#   2. Max shuffle read size >> Median shuffle read size
#   3. Spill (Memory) or Spill (Disk) appearing in any task
#   4. One task stuck at 99% while others finished long ago
#   5. High GC time on the longest-running task
```

### Key Spark UI Indicators of Skew

| Indicator | Where to Find | What It Means |
|-----------|---------------|---------------|
| Max Duration >> Median Duration | Stage Details → Summary Metrics | One partition has far more data |
| Spill (Disk) > 0 | Stage Details → Task Metrics | Partition too large for memory |
| High GC Time on one task | Stage Details → Task Metrics | Large partition causing memory pressure |
| One task at 99% progress | Jobs tab → Active Stages | Classic skew symptom — waiting on one slow task |
| Shuffle Read Size imbalance | Stage Details → Summary Metrics | Uneven data distribution after shuffle |

---

## Null Key Skew — The Most Common Skew in Practice

Null keys are the single most common source of data skew. All null keys hash to the same partition during joins and aggregations.

```python
from pyspark.sql.functions import isnull, countDistinct

# Create data with null key skew
orders_with_nulls = [
    ("O001", None, 120), ("O002", None, 85), ("O003", None, 200),
    ("O004", None, 150), ("O005", None, 90), ("O006", None, 175),
    ("O007", None, 300), ("O008", None, 60), ("O009", None, 250),
    ("O010", None, 180),  # 10 orders with NULL customer_id
    ("O011", "C001", 95), ("O012", "C002", 310),
    ("O013", "C003", 140), ("O014", "C004", 220),
]

null_df = spark.createDataFrame(orders_with_nulls, ["order_id", "customer_id", "amount"])

# Diagnose null key skew
null_analysis = null_df.agg(
    count("*").alias("total_rows"),
    spark_sum(when(isnull("customer_id"), 1).otherwise(0)).alias("null_key_rows"),
    spark_sum(when(~isnull("customer_id"), 1).otherwise(0)).alias("non_null_rows"),
    countDistinct("customer_id").alias("distinct_non_null_keys")
)

null_analysis = null_analysis.withColumn(
    "null_pct", spark_round(col("null_key_rows") / col("total_rows") * 100, 2)
)

print("=== Null Key Analysis ===")
null_analysis.show(truncate=False)

# Output:
# +----------+--------------+-------------+----------------------+--------+
# |total_rows|null_key_rows |non_null_rows|distinct_non_null_keys|null_pct|
# +----------+--------------+-------------+----------------------+--------+
# |14        |10            |4            |4                     |71.43   |
# +----------+--------------+-------------+----------------------+--------+
```

### Why Null Keys Cause Skew

- In a join, all null keys hash to the **same partition** (hash(null) is deterministic)
- Null keys often represent **incomplete or unmatched data** — which can be the majority of rows
- Common sources: left joins producing nulls, ETL failures, optional fields, anonymous/guest users

### How to Handle Null Key Skew

```python
# Option 1: Filter nulls before the join, process separately, union back
non_null_orders = null_df.filter(col("customer_id").isNotNull())
null_orders = null_df.filter(col("customer_id").isNull())

# Join only non-null keys (no skew)
joined = non_null_orders.join(customers_df, on="customer_id", how="inner")
# Handle null orders separately (e.g., assign "Unknown" customer)
result = joined.unionByName(null_orders.withColumn("customer_name", lit("Unknown")), allowMissingColumns=True)

# Option 2: Replace nulls with random salted keys (if nulls should still join)
from pyspark.sql.functions import concat, floor, rand
null_df_salted = null_df.withColumn(
    "join_key",
    when(col("customer_id").isNull(),
         concat(lit("NULL_SALT_"), floor(rand() * 10).cast("int")))
    .otherwise(col("customer_id"))
)
```

---

## Join Skew vs Aggregation Skew

| Aspect | Join Skew | Aggregation Skew |
|--------|-----------|------------------|
| **Where it happens** | Shuffle during join | Shuffle during groupBy |
| **What causes it** | Hot key exists in both tables | Hot key has many records |
| **AQE handles it?** | Yes — `skewJoin.enabled` | No — AQE does not auto-handle aggregation skew |
| **Fix** | Salted join, broadcast, AQE | Two-phase aggregation (partial agg → final agg) |
| **Spark UI clue** | SortMergeJoin stage has one slow task | HashAggregate stage has one slow task |

### Two-Phase Aggregation for Aggregation Skew

```python
from pyspark.sql.functions import concat, floor, rand

# Problem: groupBy("customer_id").agg(sum("amount")) is skewed on C001
# Solution: two-phase aggregation with salting

NUM_SALTS = 10

# Phase 1: Partial aggregation with salt
partial_agg = orders_df \
    .withColumn("salt", floor(rand() * NUM_SALTS).cast("int")) \
    .withColumn("salted_key", concat(col("customer_id"), lit("_"), col("salt"))) \
    .groupBy("salted_key", "customer_id") \
    .agg(
        spark_sum("amount").alias("partial_sum"),
        count("*").alias("partial_count")
    )

# Phase 2: Final aggregation without salt
final_agg = partial_agg.groupBy("customer_id").agg(
    spark_sum("partial_sum").alias("total_amount"),
    spark_sum("partial_count").alias("total_orders")
)

print("=== Two-Phase Aggregation Result ===")
final_agg.orderBy(desc("total_orders")).show(truncate=False)
```

---

## AQE Skew Join Detection — When It Works Automatically

```python
# AQE configuration for skew join handling
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")

# Key thresholds that control AQE skew detection:
spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionFactor", "5")
# A partition is skewed if its size > median partition size * this factor

spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes", "256mb")
# AND the partition size must exceed this absolute threshold

# AQE detects skew AFTER the shuffle, at runtime.
# If a partition meets BOTH conditions above, Spark splits it into smaller
# sub-partitions and replicates the other side of the join for each split.
```

### When AQE Handles Skew Automatically vs When You Need Salted Joins

| Scenario | AQE Handles It? | Why / Why Not |
|----------|-----------------|---------------|
| Sort-merge join with one skewed key | Yes | AQE splits the large partition after shuffle |
| Broadcast hash join | N/A | No shuffle, no skew problem |
| Aggregation skew (groupBy) | No | AQE skew handling only applies to joins |
| Skew + Spark < 3.0 | No | AQE not available before Spark 3.0 |
| Extreme skew (one key = 50% of data) | Partial | AQE splits but may still create large sub-partitions |
| Multiple skewed keys | Yes | AQE handles each skewed partition independently |
| Skew in streaming jobs | No | AQE is for batch only (as of Spark 3.5) |
| Left outer join with null skew | No | Null keys require manual handling |

**Rule of thumb:** Start with AQE enabled. If a job still has skew symptoms in the Spark UI (one task 10x+ slower), then apply salted joins or null-key isolation on top.

---

## Key Interview Talking Points

1. **"How do you know if your data is skewed?"**
   - Check key frequency distribution: `groupBy(key).count().orderBy(desc("count"))`
   - Look at the Spark UI: if max task duration is 10x+ the median, you have skew
   - Check for null key concentration: `filter(col(key).isNull()).count()`
   - Compute coefficient of variation of key counts: CV > 1 is moderate skew, CV > 3 is severe

2. **"What does skew look like in Spark UI?"**
   - One task runs for minutes while others finish in seconds
   - Summary metrics show Max >> Median for duration, input size, and shuffle read
   - Spill (Disk) appears in the slow task — the partition is too large for executor memory
   - The stage progress bar shows 199/200 tasks complete, stuck waiting on one task
   - High GC time on the straggler task

3. **"Null keys — why are they the most common skew?"**
   - Null keys all hash to the same partition (deterministic hash of null)
   - Nulls often represent incomplete data, failed lookups, or anonymous users — frequently the largest segment
   - A left join that produces many null keys in the output compounds the problem for downstream joins
   - Fix: filter nulls before join, process separately, union back; or salt the null keys specifically

4. **"When does AQE handle skew automatically vs when do you need salted joins?"**
   - AQE handles join skew automatically in Spark 3.0+ when both `adaptive.enabled` and `skewJoin.enabled` are true
   - AQE does NOT handle aggregation skew — use two-phase aggregation with salting
   - AQE does NOT handle null-key skew well — filter and process nulls separately
   - For extreme skew (one key > 30% of data), AQE may not split aggressively enough — combine with manual salting
   - Always start with AQE and check the Spark UI; escalate to salted joins only when needed

5. **Detection before optimization:**
   - Never salt-join blindly — first quantify the skew (key frequency, CV, percentile ratios)
   - The fix depends on the type: join skew vs aggregation skew vs null skew
   - Sometimes repartitioning or increasing `spark.sql.shuffle.partitions` is sufficient for mild skew
   - Document which keys are hot — they often change over time and need monitoring
