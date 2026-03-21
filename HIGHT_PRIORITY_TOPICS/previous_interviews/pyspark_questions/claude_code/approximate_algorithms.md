# PySpark Implementation: Approximate Algorithms

## Problem Statement 

In large-scale data processing, exact computations like `COUNT(DISTINCT ...)` or precise percentile calculations can be extremely expensive. PySpark provides approximate algorithms that trade a small amount of accuracy for significant performance gains. This is a common interview topic for data engineering roles, especially when discussing optimization strategies for petabyte-scale datasets.

Given a large dataset of web events, demonstrate how to use `approx_count_distinct`, `approx_percentile` (also known as `percentile_approx`), and explain the underlying HyperLogLog algorithm concept. Compare approximate results with exact results to show the accuracy tradeoff.

### Sample Data

```
+--------+------------+-----------+----------+
|user_id | page_url   | duration_s| event_dt |
+--------+------------+-----------+----------+
| u001   | /home      |  12       |2024-01-01|
| u002   | /products  |  45       |2024-01-01|
| u003   | /home      |   8       |2024-01-01|
| u001   | /products  |  30       |2024-01-02|
| u004   | /checkout  |  60       |2024-01-02|
| u002   | /home      |  15       |2024-01-02|
| u005   | /products  |  22       |2024-01-03|
| u003   | /checkout  |  55       |2024-01-03|
| u001   | /home      |   5       |2024-01-03|
| u006   | /products  |  40       |2024-01-03|
| u004   | /home      |  10       |2024-01-04|
| u007   | /checkout  |  70       |2024-01-04|
| u002   | /products  |  35       |2024-01-04|
| u008   | /home      |  18       |2024-01-04|
| u005   | /checkout  |  48       |2024-01-05|
| u009   | /products  |  25       |2024-01-05|
| u010   | /home      |  20       |2024-01-05|
| u001   | /checkout  |  65       |2024-01-05|
+--------+------------+-----------+----------+
```

### Expected Output

**Approximate vs Exact Distinct Counts:**

| page_url   | exact_distinct_users | approx_distinct_users |
|------------|---------------------:|----------------------:|
| /home      | 6                    | ~6                    |
| /products  | 5                    | ~5                    |
| /checkout  | 4                    | ~4                    |

**Approximate Percentiles of Duration:**

| page_url   | approx_p50 | approx_p90 | approx_p99 |
|------------|------------|------------|------------|
| /home      | ~12        | ~18        | ~20        |
| /products  | ~30        | ~40        | ~45        |
| /checkout  | ~55        | ~65        | ~70        |

---

## Method 1: Using approx_count_distinct and percentile_approx (DataFrame API)

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

# Initialize SparkSession
spark = SparkSession.builder \
    .appName("ApproximateAlgorithms") \
    .master("local[*]") \
    .getOrCreate()

# Create sample data
data = [
    ("u001", "/home",      12, "2024-01-01"),
    ("u002", "/products",  45, "2024-01-01"),
    ("u003", "/home",       8, "2024-01-01"),
    ("u001", "/products",  30, "2024-01-02"),
    ("u004", "/checkout",  60, "2024-01-02"),
    ("u002", "/home",      15, "2024-01-02"),
    ("u005", "/products",  22, "2024-01-03"),
    ("u003", "/checkout",  55, "2024-01-03"),
    ("u001", "/home",       5, "2024-01-03"),
    ("u006", "/products",  40, "2024-01-03"),
    ("u004", "/home",      10, "2024-01-04"),
    ("u007", "/checkout",  70, "2024-01-04"),
    ("u002", "/products",  35, "2024-01-04"),
    ("u008", "/home",      18, "2024-01-04"),
    ("u005", "/checkout",  48, "2024-01-05"),
    ("u009", "/products",  25, "2024-01-05"),
    ("u010", "/home",      20, "2024-01-05"),
    ("u001", "/checkout",  65, "2024-01-05"),
]

columns = ["user_id", "page_url", "duration_s", "event_dt"]
df = spark.createDataFrame(data, columns)

# --- Approximate Distinct Count ---
# approx_count_distinct uses HyperLogLog under the hood
# The second argument (rsd) controls relative standard deviation (default 0.05)

exact_vs_approx = df.groupBy("page_url").agg(
    F.countDistinct("user_id").alias("exact_distinct_users"),
    F.approx_count_distinct("user_id").alias("approx_distinct_users_default"),
    F.approx_count_distinct("user_id", 0.01).alias("approx_distinct_users_precise"),
    F.approx_count_distinct("user_id", 0.1).alias("approx_distinct_users_rough"),
)

print("=== Exact vs Approximate Distinct Counts ===")
exact_vs_approx.show()

# --- Approximate Percentiles ---
# percentile_approx computes approximate percentiles using the t-digest algorithm
# Arguments: column, percentage (or array of percentages), accuracy (default 10000)

percentile_results = df.groupBy("page_url").agg(
    F.percentile_approx("duration_s", 0.5).alias("approx_median"),
    F.percentile_approx("duration_s", 0.9).alias("approx_p90"),
    F.percentile_approx("duration_s", 0.99).alias("approx_p99"),
    # You can pass an array of percentiles at once
    F.percentile_approx("duration_s", F.array(F.lit(0.25), F.lit(0.5), F.lit(0.75))).alias("approx_quartiles"),
)

print("=== Approximate Percentiles by Page ===")
percentile_results.show(truncate=False)

# --- Control accuracy with the third parameter ---
# Higher accuracy = more precise but more memory
percentile_accuracy = df.groupBy("page_url").agg(
    F.percentile_approx("duration_s", 0.5, 100).alias("approx_p50_low_acc"),
    F.percentile_approx("duration_s", 0.5, 10000).alias("approx_p50_high_acc"),
)

print("=== Percentile Accuracy Comparison ===")
percentile_accuracy.show()
```

## Method 2: Using Spark SQL with Approximate Functions

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("ApproximateAlgorithmsSQL") \
    .master("local[*]") \
    .getOrCreate()

# Create sample data
data = [
    ("u001", "/home",      12, "2024-01-01"),
    ("u002", "/products",  45, "2024-01-01"),
    ("u003", "/home",       8, "2024-01-01"),
    ("u001", "/products",  30, "2024-01-02"),
    ("u004", "/checkout",  60, "2024-01-02"),
    ("u002", "/home",      15, "2024-01-02"),
    ("u005", "/products",  22, "2024-01-03"),
    ("u003", "/checkout",  55, "2024-01-03"),
    ("u001", "/home",       5, "2024-01-03"),
    ("u006", "/products",  40, "2024-01-03"),
    ("u004", "/home",      10, "2024-01-04"),
    ("u007", "/checkout",  70, "2024-01-04"),
    ("u002", "/products",  35, "2024-01-04"),
    ("u008", "/home",      18, "2024-01-04"),
    ("u005", "/checkout",  48, "2024-01-05"),
    ("u009", "/products",  25, "2024-01-05"),
    ("u010", "/home",      20, "2024-01-05"),
    ("u001", "/checkout",  65, "2024-01-05"),
]

columns = ["user_id", "page_url", "duration_s", "event_dt"]
df = spark.createDataFrame(data, columns)
df.createOrReplaceTempView("web_events")

# Approximate distinct count in SQL
spark.sql("""
    SELECT
        page_url,
        COUNT(DISTINCT user_id)              AS exact_distinct,
        APPROX_COUNT_DISTINCT(user_id)       AS approx_distinct
    FROM web_events
    GROUP BY page_url
    ORDER BY page_url
""").show()

# Approximate percentiles in SQL
spark.sql("""
    SELECT
        page_url,
        PERCENTILE_APPROX(duration_s, 0.5)   AS median_duration,
        PERCENTILE_APPROX(duration_s, 0.9)   AS p90_duration,
        PERCENTILE_APPROX(duration_s, 0.99)  AS p99_duration
    FROM web_events
    GROUP BY page_url
    ORDER BY page_url
""").show()

# Daily approximate distinct users - common analytics query
spark.sql("""
    SELECT
        event_dt,
        APPROX_COUNT_DISTINCT(user_id)       AS approx_daily_users,
        COUNT(*)                              AS total_events
    FROM web_events
    GROUP BY event_dt
    ORDER BY event_dt
""").show()
```

## Method 3: Simulating HyperLogLog Concept with Large-Scale Data

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
import time

spark = SparkSession.builder \
    .appName("HLLPerformanceComparison") \
    .master("local[*]") \
    .getOrCreate()

# Generate a larger dataset to see the performance difference
# In production, this would be millions or billions of rows
large_df = spark.range(0, 1000000).select(
    (F.col("id") % 100000).alias("user_id"),
    (F.col("id") % 50).alias("category"),
    (F.rand() * 1000).alias("value")
)

large_df.cache()
large_df.count()  # Force cache materialization

# Time exact distinct count
start = time.time()
exact_result = large_df.groupBy("category").agg(
    F.countDistinct("user_id").alias("exact_count")
)
exact_result.collect()
exact_time = time.time() - start

# Time approximate distinct count
start = time.time()
approx_result = large_df.groupBy("category").agg(
    F.approx_count_distinct("user_id").alias("approx_count")
)
approx_result.collect()
approx_time = time.time() - start

print(f"Exact distinct count time:  {exact_time:.3f}s")
print(f"Approx distinct count time: {approx_time:.3f}s")
print(f"Speedup: {exact_time / approx_time:.2f}x")

# Compare accuracy
comparison = exact_result.join(approx_result, "category") \
    .withColumn("error_pct",
        F.abs(F.col("exact_count") - F.col("approx_count")) / F.col("exact_count") * 100
    )

print("\n=== Accuracy Comparison (sample of rows) ===")
comparison.orderBy("category").show(10)

print("\n=== Error Statistics ===")
comparison.agg(
    F.avg("error_pct").alias("avg_error_pct"),
    F.max("error_pct").alias("max_error_pct"),
    F.min("error_pct").alias("min_error_pct"),
).show()

large_df.unpersist()
```

## Method 4: Error Calculation Pattern (DataFrame API)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    countDistinct, approx_count_distinct, col, abs as spark_abs, round as spark_round
)

spark = SparkSession.builder.appName("ErrorCalculation").getOrCreate()

# Given a DataFrame `df` with columns: user_id, page_url
# Compute exact vs approximate counts with multiple rsd levels and calculate error %

comparison = df.groupBy("page_url").agg(
    countDistinct("user_id").alias("exact_distinct"),
    approx_count_distinct("user_id").alias("approx_default"),         # default rsd = 0.05
    approx_count_distinct("user_id", 0.01).alias("approx_precise"),   # tighter rsd
    approx_count_distinct("user_id", 0.20).alias("approx_fast"),      # looser rsd
)

# Add error percentage columns for each rsd level
result = comparison.withColumn(
    "error_default_pct",
    spark_round(
        spark_abs(col("exact_distinct") - col("approx_default")) / col("exact_distinct") * 100, 2
    )
).withColumn(
    "error_precise_pct",
    spark_round(
        spark_abs(col("exact_distinct") - col("approx_precise")) / col("exact_distinct") * 100, 2
    )
).withColumn(
    "error_fast_pct",
    spark_round(
        spark_abs(col("exact_distinct") - col("approx_fast")) / col("exact_distinct") * 100, 2
    )
)

result.orderBy(col("exact_distinct").desc()).show()
```

*Note: With small data the approximation is often exact. Error becomes visible at millions of rows.
At scale, `approx_fast` (rsd=0.20) may show errors up to ~20%, while `approx_precise` (rsd=0.01)
stays within ~1%.*

## Key Concepts

| Concept | Details |
|---------|---------|
| **approx_count_distinct** | Uses HyperLogLog algorithm; `rsd` parameter controls accuracy vs memory tradeoff |
| **HyperLogLog (HLL)** | Probabilistic data structure that estimates cardinality using fixed memory (~1.5 KB for millions of values) |
| **percentile_approx** | Uses t-digest algorithm; `accuracy` parameter (default 10000) controls precision |
| **Relative Standard Deviation (rsd)** | Lower rsd = more accurate but more memory; default is 0.05 (5%). Memory is proportional to `1 / (rsd^2)` |
| **When to use approximations** | Datasets with billions of rows where exact counts are too slow or memory-intensive |
| **Accuracy guarantee** | approx_count_distinct is within ~2% error for most practical datasets |

## Interview Tips

1. **Know when to use approximate vs exact**: If your dataset has billions of rows and you need a quick cardinality estimate (e.g., daily unique visitors), approximate is the way to go. For billing or compliance, use exact.

2. **Understand the tradeoff parameters**: Be ready to explain that `rsd=0.05` means roughly 5% relative standard deviation, and how decreasing it increases memory usage. The memory used is proportional to `1 / (relativeSD^2)`.

3. **HyperLogLog explanation**: At a high level, HLL hashes each element and counts leading zeros in the binary hash. More leading zeros statistically imply more distinct elements. It uses multiple "registers" to average out the estimate. It uses O(log log n) space.

4. **When to use exact `countDistinct()`**: Financial or compliance reporting where exact numbers are required; small to medium datasets where performance is not a concern; validating the accuracy of approximate methods.

5. **Real-world use cases**: Ad-tech (unique impressions), web analytics (unique visitors), IoT (unique device counts), cardinality estimation for query planning, and any COUNT DISTINCT on high-cardinality columns.

6. **Catalyst optimizer behavior**: `countDistinct` requires a full shuffle and deduplication, while `approx_count_distinct` uses a sketch-based partial aggregation that reduces shuffle volume dramatically.

7. **Composability limitation**: HLL sketches from `approx_count_distinct` cannot be merged across separate Spark jobs. For mergeable sketches, consider using the `spark-alchemy` library or DataSketches integration.

8. **Spark SQL equivalents**: `APPROX_COUNT_DISTINCT()` and `PERCENTILE_APPROX()` work the same way in SQL mode, which is useful in notebook environments.
