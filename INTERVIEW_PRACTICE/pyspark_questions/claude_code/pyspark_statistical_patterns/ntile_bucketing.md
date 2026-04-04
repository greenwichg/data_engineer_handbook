# PySpark Implementation: NTILE & Percentile Bucketing

## Problem Statement 

Given a dataset of customer purchases, **divide customers into equal-sized groups (quartiles, deciles, etc.)** based on their total spending. This is used for customer segmentation, ABC classification, and percentile-based reporting. The key function is `ntile(N)`, a window function that distributes rows into N approximately equal buckets.

### Sample Data

```
customer_id  total_spend
C001         15000
C002         8500
C003         42000
C004         3200
C005         28000
C006         1100
C007         19500
C008         6700
C009         55000
C010         750
C011         11000
C012         35000
```

### Expected Output (Quartiles — ntile(4))

| customer_id | total_spend | quartile | segment     |
|------------|------------|----------|-------------|
| C009       | 55000      | 1        | Top 25%     |
| C003       | 42000      | 1        | Top 25%     |
| C012       | 35000      | 1        | Top 25%     |
| C005       | 28000      | 2        | 25-50%      |
| C007       | 19500      | 2        | 25-50%      |
| C001       | 15000      | 2        | 25-50%      |
| C011       | 11000      | 3        | 50-75%      |
| C002       | 8500       | 3        | 50-75%      |
| C008       | 6700       | 3        | 50-75%      |
| C004       | 3200       | 4        | Bottom 25%  |
| C006       | 1100       | 4        | Bottom 25%  |
| C010       | 750        | 4        | Bottom 25%  |

---

## Method 1: ntile() Window Function

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, ntile, when, sum as spark_sum, count, \
    avg, min as spark_min, max as spark_max, round as spark_round, \
    percent_rank, percentile_approx
from pyspark.sql.window import Window

# Initialize Spark session
spark = SparkSession.builder.appName("NtileBucketing").getOrCreate()

# Sample data
data = [
    ("C001", 15000), ("C002", 8500), ("C003", 42000), ("C004", 3200),
    ("C005", 28000), ("C006", 1100), ("C007", 19500), ("C008", 6700),
    ("C009", 55000), ("C010", 750), ("C011", 11000), ("C012", 35000)
]
df = spark.createDataFrame(data, ["customer_id", "total_spend"])

# Quartiles: divide into 4 equal groups
window_spend = Window.orderBy(col("total_spend").desc())

df_quartile = df.withColumn(
    "quartile", ntile(4).over(window_spend)
)

# Add segment labels
df_segmented = df_quartile.withColumn(
    "segment",
    when(col("quartile") == 1, "Top 25%")
    .when(col("quartile") == 2, "25-50%")
    .when(col("quartile") == 3, "50-75%")
    .otherwise("Bottom 25%")
)

df_segmented.orderBy("quartile", col("total_spend").desc()).show(truncate=False)
```

### How ntile(N) Works

`ntile(N)` assigns bucket numbers 1 through N to rows in the window, distributing as evenly as possible:
- 12 rows ÷ 4 buckets = 3 rows per bucket (exact fit)
- 10 rows ÷ 4 buckets = 3, 3, 2, 2 (earlier buckets get extras)
- 7 rows ÷ 3 buckets = 3, 2, 2

**Ordering matters:** `ntile` assigns based on the window's `orderBy`. Desc = bucket 1 is highest. Asc = bucket 1 is lowest.

---

## Method 2: Deciles (ntile(10)) for Finer Segmentation

```python
# Deciles: divide into 10 equal groups
df_decile = df.withColumn(
    "decile", ntile(10).over(window_spend)
)

df_decile.orderBy("decile", col("total_spend").desc()).show(truncate=False)
```

- **Output (partial):**

  | customer_id | total_spend | decile |
  |------------|------------|--------|
  | C009       | 55000      | 1      |
  | C003       | 42000      | 2      |
  | C012       | 35000      | 3      |
  | ...        | ...        | ...    |
  | C010       | 750        | 10     |

---

## Method 3: percent_rank() for True Percentiles

```python
# percent_rank gives the exact percentile position (0.0 to 1.0)
df_pctrank = df.withColumn(
    "pct_rank", spark_round(percent_rank().over(window_spend), 3)
).withColumn(
    "percentile", spark_round((1 - col("pct_rank")) * 100, 1)
)

df_pctrank.orderBy(col("total_spend").desc()).show(truncate=False)
```

- **Output:**

  | customer_id | total_spend | pct_rank | percentile |
  |------------|------------|----------|-----------|
  | C009       | 55000      | 0.000    | 100.0     |
  | C003       | 42000      | 0.091    | 90.9      |
  | C012       | 35000      | 0.182    | 81.8      |
  | C005       | 28000      | 0.273    | 72.7      |
  | ...        | ...        | ...      | ...       |
  | C010       | 750        | 1.000    | 0.0       |

**Difference from ntile:**
- `ntile(4)` → integer bucket (1, 2, 3, 4)
- `percent_rank()` → continuous value (0.0 to 1.0)

Use `ntile` for equal-sized groups, `percent_rank` for exact positioning.

---

## Method 4: Custom Buckets (Not Equal-Sized)

```python
# Sometimes you need custom thresholds, not equal counts
df_custom = df.withColumn(
    "tier",
    when(col("total_spend") >= 30000, "Platinum")
    .when(col("total_spend") >= 10000, "Gold")
    .when(col("total_spend") >= 5000, "Silver")
    .otherwise("Bronze")
)

# Summary per tier
tier_summary = df_custom.groupBy("tier").agg(
    count("*").alias("customer_count"),
    spark_sum("total_spend").alias("total_revenue"),
    spark_round(avg("total_spend"), 0).alias("avg_spend"),
    spark_min("total_spend").alias("min_spend"),
    spark_max("total_spend").alias("max_spend")
).orderBy(col("total_revenue").desc())

tier_summary.show(truncate=False)
```

- **Output:**

  | tier     | customer_count | total_revenue | avg_spend | min_spend | max_spend |
  |----------|---------------|--------------|-----------|-----------|-----------|
  | Platinum | 3             | 132000       | 44000     | 35000     | 55000     |
  | Gold     | 3             | 45500        | 15167     | 11000     | 19500     |
  | Silver   | 2             | 15200        | 7600      | 6700      | 8500      |
  | Bronze   | 4             | 5250         | 1313      | 750       | 3200      |

**ntile vs custom buckets:**
- `ntile(4)` → always 3 customers per group (equal count)
- Custom thresholds → unequal groups based on business rules

---

## Method 5: ABC / Pareto Classification Using ntile

```python
# ABC analysis: Top 20% of customers (A), next 30% (B), bottom 50% (C)
# Use ntile(10) and map deciles to ABC

df_abc = df.withColumn(
    "decile", ntile(10).over(window_spend)
).withColumn(
    "abc_class",
    when(col("decile") <= 2, "A")      # Top 20%
    .when(col("decile") <= 5, "B")     # Next 30%
    .otherwise("C")                     # Bottom 50%
)

# ABC summary
abc_summary = df_abc.groupBy("abc_class").agg(
    count("*").alias("count"),
    spark_sum("total_spend").alias("total_revenue"),
    spark_round(avg("total_spend"), 0).alias("avg_spend")
).withColumn(
    "revenue_pct",
    spark_round(col("total_revenue") / df.agg(spark_sum("total_spend")).collect()[0][0] * 100, 1)
).orderBy("abc_class")

abc_summary.show(truncate=False)
```

---

## Method 6: Using SQL

```python
df.createOrReplaceTempView("customers")

# Quartile bucketing
spark.sql("""
    SELECT
        customer_id,
        total_spend,
        NTILE(4) OVER (ORDER BY total_spend DESC) AS quartile,
        PERCENT_RANK() OVER (ORDER BY total_spend DESC) AS pct_rank,
        CASE NTILE(4) OVER (ORDER BY total_spend DESC)
            WHEN 1 THEN 'Top 25%'
            WHEN 2 THEN '25-50%'
            WHEN 3 THEN '50-75%'
            ELSE 'Bottom 25%'
        END AS segment
    FROM customers
    ORDER BY total_spend DESC
""").show(truncate=False)
```

---

## Practical Application: Salary Band Analysis

```python
# Divide employees into salary bands and analyze
salary_data = [
    ("E001", "Engineering", 120000), ("E002", "Engineering", 95000),
    ("E003", "Marketing", 85000), ("E004", "Engineering", 140000),
    ("E005", "Marketing", 72000), ("E006", "Sales", 110000),
    ("E007", "Sales", 65000), ("E008", "Engineering", 155000),
    ("E009", "Marketing", 90000), ("E010", "Sales", 88000),
    ("E011", "Engineering", 105000), ("E012", "Sales", 78000)
]
salary_df = spark.createDataFrame(salary_data, ["emp_id", "dept", "salary"])

# Quartiles WITHIN each department
window_dept = Window.partitionBy("dept").orderBy(col("salary").desc())

salary_banded = salary_df.withColumn(
    "dept_quartile", ntile(4).over(window_dept)
).withColumn(
    "dept_pct_rank", spark_round(percent_rank().over(window_dept), 2)
)

salary_banded.orderBy("dept", "dept_quartile").show(truncate=False)
```

**Key:** `partitionBy("dept")` makes ntile operate within each department independently. Engineering's top 25% is different from Marketing's top 25%.

---

## ntile vs dense_rank vs row_number vs percent_rank

| Function | Output | Ties Handling | Use Case |
|----------|--------|---------------|----------|
| `ntile(N)` | 1 to N | Distributed evenly | Equal-sized buckets |
| `dense_rank()` | 1, 2, 3... (no gaps) | Same rank for ties | Ranking with ties |
| `row_number()` | 1, 2, 3... (unique) | Arbitrary tiebreak | Unique ordering |
| `percent_rank()` | 0.0 to 1.0 | Same value for ties | Exact percentile position |
| `cume_dist()` | 0.0 to 1.0 | Includes current row | Cumulative distribution |

---

## Key Interview Talking Points

1. **ntile(N) creates N equal-sized groups:** It's the simplest way to create quartiles (4), deciles (10), or percentiles (100). Ordering determines what "top" means.

2. **ntile vs percent_rank:** `ntile` gives integer buckets (good for segmentation). `percent_rank` gives continuous values (good for exact positioning). Use `ntile` when you need "which group am I in?" and `percent_rank` when you need "what percentile am I at?"

3. **Uneven distribution:** If 12 rows ÷ 5 buckets, ntile gives 3, 3, 2, 2, 2. Earlier buckets get more. For exact equal-sized buckets on large datasets this is negligible, but on small data it's noticeable.

4. **partitionBy for per-group bucketing:** `ntile(4).over(Window.partitionBy("dept").orderBy("salary"))` gives quartiles within each department. Without `partitionBy`, it gives quartiles across the entire company.

5. **Common interview applications:**
   - Customer segmentation (RFM: Recency, Frequency, Monetary)
   - Salary band analysis
   - ABC inventory classification
   - Performance review bucketing (top/middle/bottom performers)
   - Risk scoring (credit risk deciles)
