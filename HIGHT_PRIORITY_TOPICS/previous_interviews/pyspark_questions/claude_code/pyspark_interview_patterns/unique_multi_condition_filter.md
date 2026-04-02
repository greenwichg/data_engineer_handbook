# PySpark Implementation: Investments in 2016 (Multi-Condition Filtering)

## Problem Statement

Given an `Insurance` table with `pid`, `tiv_2015`, `tiv_2016`, `lat`, and `lon`, find the sum of `tiv_2016` for policyholders who: (1) have the **same `tiv_2015` value** as at least one other policyholder, AND (2) are **not located at the same (lat, lon)** as any other policyholder. This is **LeetCode 585 — Investments in 2016**.

### Sample Data

```
pid  tiv_2015  tiv_2016  lat    lon
1    10        5         10.0   10.0
2    20        15        20.0   20.0
3    10        30        20.0   20.0
4    10        40        40.0   40.0
```

### Expected Output

| tiv_2016 |
|----------|
| 45.00    |

**Explanation:**
- Condition 1 (tiv_2015 shared): pid 1, 3, 4 all have tiv_2015=10. pid 2 has tiv_2015=20 (unique) → excluded.
- Condition 2 (unique location): pid 2 and 3 share (20,20) → both excluded from location check.
- After both: pid 1 (unique location ✓, shared tiv ✓) and pid 4 (unique location ✓, shared tiv ✓). Sum = 5 + 40 = 45.

---

## Method 1: Window Functions for Both Conditions (DataFrame API)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, sum as spark_sum, round as spark_round
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("Investments2016").getOrCreate()

data = [
    (1, 10, 5, 10.0, 10.0),
    (2, 20, 15, 20.0, 20.0),
    (3, 10, 30, 20.0, 20.0),
    (4, 10, 40, 40.0, 40.0)
]

columns = ["pid", "tiv_2015", "tiv_2016", "lat", "lon"]
df = spark.createDataFrame(data, columns)

# Count how many share same tiv_2015
w_tiv = Window.partitionBy("tiv_2015")
# Count how many share same location
w_loc = Window.partitionBy("lat", "lon")

result = df.withColumn("tiv_count", count("*").over(w_tiv)) \
    .withColumn("loc_count", count("*").over(w_loc)) \
    .filter((col("tiv_count") > 1) & (col("loc_count") == 1)) \
    .agg(spark_round(spark_sum("tiv_2016"), 2).alias("tiv_2016"))

result.show()
```

### Step-by-Step Explanation

#### Step 1: Count duplicates for tiv_2015
- **What happens:** Window count by tiv_2015 shows how many policyholders share the same 2015 value.

  | pid | tiv_2015 | tiv_2016 | lat  | lon  | tiv_count |
  |-----|----------|----------|------|------|-----------|
  | 1   | 10       | 5        | 10.0 | 10.0 | 3         |
  | 2   | 20       | 15       | 20.0 | 20.0 | 1         |
  | 3   | 10       | 30       | 20.0 | 20.0 | 3         |
  | 4   | 10       | 40       | 40.0 | 40.0 | 3         |

#### Step 2: Count duplicates for (lat, lon)

  | pid | lat  | lon  | loc_count |
  |-----|------|------|-----------|
  | 1   | 10.0 | 10.0 | 1         |
  | 2   | 20.0 | 20.0 | 2         |
  | 3   | 20.0 | 20.0 | 2         |
  | 4   | 40.0 | 40.0 | 1         |

#### Step 3: Filter: tiv_count > 1 AND loc_count == 1
- pid 1: tiv_count=3 ✓, loc_count=1 ✓ → included
- pid 2: tiv_count=1 ✗ → excluded
- pid 3: tiv_count=3 ✓, loc_count=2 ✗ → excluded
- pid 4: tiv_count=3 ✓, loc_count=1 ✓ → included

#### Step 4: Sum tiv_2016 = 5 + 40 = 45.00

---

## Method 2: Using GroupBy + Having + Joins

```python
from pyspark.sql.functions import col, count, sum as spark_sum, round as spark_round

# Find tiv_2015 values that appear more than once
shared_tiv = df.groupBy("tiv_2015") \
    .agg(count("*").alias("cnt")) \
    .filter(col("cnt") > 1) \
    .select("tiv_2015")

# Find unique locations
unique_loc = df.groupBy("lat", "lon") \
    .agg(count("*").alias("cnt")) \
    .filter(col("cnt") == 1) \
    .select("lat", "lon")

# Semi join both conditions
result = df.join(shared_tiv, on="tiv_2015", how="left_semi") \
    .join(unique_loc, on=["lat", "lon"], how="left_semi") \
    .agg(spark_round(spark_sum("tiv_2016"), 2).alias("tiv_2016"))

result.show()
```

---

## Method 3: Spark SQL

```python
df.createOrReplaceTempView("insurance")

result = spark.sql("""
    SELECT ROUND(SUM(tiv_2016), 2) AS tiv_2016
    FROM insurance
    WHERE tiv_2015 IN (
        SELECT tiv_2015
        FROM insurance
        GROUP BY tiv_2015
        HAVING COUNT(*) > 1
    )
    AND (lat, lon) IN (
        SELECT lat, lon
        FROM insurance
        GROUP BY lat, lon
        HAVING COUNT(*) = 1
    )
""")

result.show()
```

---

## Edge Cases to Discuss

| Edge Case | What Happens | How to Handle |
|-----------|-------------|---------------|
| All same tiv_2015 | Condition 1 met for everyone | Only location uniqueness filters |
| All unique locations | Condition 2 met for everyone | Only tiv_2015 duplication filters |
| No rows match both conditions | SUM is NULL | Use COALESCE(SUM(...), 0) |
| Float precision in lat/lon | Comparison may fail | Round to fixed decimal places |

## Key Interview Talking Points

1. **Window count vs. GROUP BY + semi-join:**
   - Window approach is a single scan — more efficient.
   - Semi-join approach is more readable and modular.

2. **"Duplicate in X but unique in Y" pattern:**
   - This is a multi-condition filtering pattern. Appears in data quality checks, fraud detection, and deduplication logic.

3. **IN with tuple (lat, lon):**
   - Some SQL dialects support `WHERE (lat, lon) IN (subquery)`. Spark SQL supports this.
   - In DataFrame API, use a join on both columns.

4. **Follow-up: "What if location is approximate?"**
   - Round lat/lon to a fixed precision, or use a distance threshold instead of exact match.
