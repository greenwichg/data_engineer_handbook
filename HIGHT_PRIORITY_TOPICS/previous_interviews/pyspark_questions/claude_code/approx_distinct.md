# PySpark Implementation: Approximate vs Exact Distinct Counts

## Problem Statement
Given a large clickstream dataset containing user page visits, compare **exact** distinct user counts
(`countDistinct()`) against **approximate** distinct user counts (`approx_count_distinct()`) per page.
Demonstrate the accuracy vs performance tradeoff and explain when each approach is appropriate.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    countDistinct, approx_count_distinct, col, abs as spark_abs, round as spark_round
)

spark = SparkSession.builder.appName("ApproxDistinct").getOrCreate()

# Simulated clickstream data
data = [
    ("user_1", "home"),    ("user_2", "home"),    ("user_3", "home"),
    ("user_4", "home"),    ("user_5", "home"),    ("user_1", "home"),
    ("user_2", "home"),    ("user_6", "home"),    ("user_7", "home"),
    ("user_8", "home"),    ("user_9", "home"),    ("user_10", "home"),
    ("user_1", "product"), ("user_2", "product"), ("user_3", "product"),
    ("user_4", "product"), ("user_1", "product"), ("user_2", "product"),
    ("user_5", "product"), ("user_6", "product"),
    ("user_1", "cart"),    ("user_2", "cart"),     ("user_3", "cart"),
    ("user_1", "cart"),
    ("user_1", "checkout"),("user_2", "checkout"),
    ("user_1", "search"),  ("user_2", "search"),  ("user_3", "search"),
    ("user_4", "search"),  ("user_5", "search"),  ("user_6", "search"),
    ("user_7", "search"),  ("user_8", "search"),  ("user_9", "search"),
]

clickstream = spark.createDataFrame(data, ["user_id", "page"])
```

### Expected Output
| page     | exact_distinct | approx_distinct | pct_error |
|----------|---------------|-----------------|-----------|
| home     | 10            | 10              | 0.0       |
| product  | 6             | 6               | 0.0       |
| search   | 9             | 9               | 0.0       |
| cart     | 3             | 3               | 0.0       |
| checkout | 2             | 2               | 0.0       |

*Note: With small data the approximation is exact. Error becomes visible at millions of rows.*

---

## Method 1: Side-by-Side Comparison with Error Calculation (Recommended)
```python
from pyspark.sql.functions import countDistinct, approx_count_distinct, col, abs as spark_abs

# Compute both exact and approximate counts in a single aggregation
comparison = clickstream.groupBy("page").agg(
    countDistinct("user_id").alias("exact_distinct"),
    approx_count_distinct("user_id").alias("approx_default"),         # default rsd = 0.05
    approx_count_distinct("user_id", 0.01).alias("approx_precise"),   # tighter rsd
    approx_count_distinct("user_id", 0.20).alias("approx_fast"),      # looser rsd
)

# Add error percentage columns
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

### Step-by-Step Explanation

**Step 1 -- Raw clickstream data (first 6 rows):**

| user_id | page    |
|---------|---------|
| user_1  | home    |
| user_2  | home    |
| user_3  | home    |
| user_1  | home    |
| user_1  | product |
| user_2  | product |

**Step 2 -- After groupBy("page") with both aggregations:**

| page     | exact_distinct | approx_default | approx_precise | approx_fast |
|----------|---------------|----------------|----------------|-------------|
| home     | 10            | 10             | 10             | 10          |
| search   | 9             | 9              | 9              | 9           |
| product  | 6             | 6              | 6              | 6           |
| cart     | 3             | 3              | 3              | 3           |
| checkout | 2             | 2              | 2              | 2           |

**Step 3 -- With error percentage columns added:**

All error columns show 0.0% for this small dataset. At scale (millions of users), you would
see `approx_fast` (rsd=0.20) showing errors up to ~20%, while `approx_precise` (rsd=0.01)
stays within ~1%.

---

## Method 2: Performance Benchmarking Approach
```python
import time

# Generate a larger synthetic dataset for performance comparison
from pyspark.sql.functions import expr, rand, floor as spark_floor, concat, lit

large_clickstream = spark.range(0, 10_000_000).select(
    concat(lit("user_"), (rand() * 1_000_000).cast("int").cast("string")).alias("user_id"),
    expr("""
        CASE WHEN rand() < 0.3 THEN 'home'
             WHEN rand() < 0.5 THEN 'product'
             WHEN rand() < 0.7 THEN 'search'
             WHEN rand() < 0.9 THEN 'cart'
             ELSE 'checkout'
        END
    """).alias("page")
).cache()

large_clickstream.count()  # materialize cache

# Benchmark exact count
start = time.time()
exact_result = large_clickstream.groupBy("page").agg(
    countDistinct("user_id").alias("exact_count")
)
exact_result.collect()
exact_time = time.time() - start

# Benchmark approximate count
start = time.time()
approx_result = large_clickstream.groupBy("page").agg(
    approx_count_distinct("user_id", 0.05).alias("approx_count")
)
approx_result.collect()
approx_time = time.time() - start

print(f"Exact:       {exact_time:.2f}s")
print(f"Approximate: {approx_time:.2f}s")
print(f"Speedup:     {exact_time / approx_time:.1f}x")
```

---

## Key Interview Talking Points

1. **HyperLogLog algorithm**: `approx_count_distinct()` uses the HyperLogLog (HLL) algorithm
   internally. HLL works by hashing each element and tracking the maximum number of leading
   zeros observed, which statistically estimates cardinality using O(log log n) space.

2. **relativeSD parameter**: The second argument controls the relative standard deviation.
   Default is 0.05 (5% error). Lower values like 0.01 use more memory but are more precise.
   The memory used is proportional to `1 / (relativeSD^2)`.

3. **When to use approx_count_distinct()**:
   - Dashboards and analytics where exact counts are unnecessary
   - Datasets with billions of rows where exact counts are prohibitively slow
   - Real-time or near-real-time aggregation pipelines
   - Cardinality estimation for query planning

4. **When to use countDistinct()**:
   - Financial or compliance reporting where exact numbers are required
   - Small to medium datasets where performance is not a concern
   - Validating the accuracy of approximate methods

5. **Catalyst optimizer**: Both functions push down to different execution strategies.
   `countDistinct` requires a full shuffle and deduplication, while `approx_count_distinct`
   uses a sketch-based partial aggregation that reduces shuffle volume dramatically.

6. **Composability limitation**: HLL sketches from `approx_count_distinct` cannot be merged
   across separate Spark jobs. For mergeable sketches, consider using the
   `spark-alchemy` library or DataSketches integration.

7. **SQL equivalent**: Both functions work identically in Spark SQL:
   ```sql
   SELECT page,
          COUNT(DISTINCT user_id)              AS exact_count,
          APPROX_COUNT_DISTINCT(user_id, 0.05) AS approx_count
   FROM clickstream
   GROUP BY page
   ```
