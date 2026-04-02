# PySpark Implementation: Multi-Level Aggregation

## Problem Statement

A common interview scenario involves computing aggregations at multiple granularity levels (e.g., daily, weekly, monthly, yearly) in a single pass or efficiently combining them. This is essential in building analytics dashboards and data warehouses where you need metrics at different time granularities. Interviewers test this to assess your understanding of grouping sets, rollup, cube, and efficient aggregation strategies.

Given a dataset of retail sales transactions, compute revenue totals at daily, weekly, monthly, and overall levels, and combine them into a unified result.

### Sample Data

```
+--------+----------+----------+--------+-----+
|store_id|product_id| sale_date| revenue| qty |
+--------+----------+----------+--------+-----+
| S001   | P01      |2024-01-05|  100.00|   2 |
| S001   | P02      |2024-01-05|   50.00|   1 |
| S001   | P01      |2024-01-12|  200.00|   4 |
| S001   | P02      |2024-01-20|   75.00|   3 |
| S001   | P01      |2024-02-03|  150.00|   3 |
| S002   | P01      |2024-01-08|  120.00|   2 |
| S002   | P02      |2024-01-15|   60.00|   2 |
| S002   | P01      |2024-02-10|  180.00|   4 |
| S002   | P02      |2024-02-14|   90.00|   3 |
+--------+----------+----------+--------+-----+
```

### Expected Output

**Multi-level aggregation result:**

| store_id | level    | period     | total_revenue | total_qty |
|----------|----------|------------|---------------|-----------|
| S001     | daily    | 2024-01-05 | 150.00        | 3         |
| S001     | daily    | 2024-01-12 | 200.00        | 4         |
| S001     | daily    | 2024-01-20 | 75.00         | 3         |
| S001     | weekly   | 2024-W01   | 150.00        | 3         |
| S001     | weekly   | 2024-W02   | 200.00        | 4         |
| S001     | monthly  | 2024-01    | 425.00        | 10        |
| S001     | monthly  | 2024-02    | 150.00        | 3         |
| S001     | overall  | ALL        | 575.00        | 13        |

---

## Method 1: Union of Multiple Aggregation Levels

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from functools import reduce

spark = SparkSession.builder \
    .appName("MultiLevelAggregation") \
    .master("local[*]") \
    .getOrCreate()

data = [
    ("S001", "P01", "2024-01-05", 100.00, 2),
    ("S001", "P02", "2024-01-05",  50.00, 1),
    ("S001", "P01", "2024-01-12", 200.00, 4),
    ("S001", "P02", "2024-01-20",  75.00, 3),
    ("S001", "P01", "2024-02-03", 150.00, 3),
    ("S002", "P01", "2024-01-08", 120.00, 2),
    ("S002", "P02", "2024-01-15",  60.00, 2),
    ("S002", "P01", "2024-02-10", 180.00, 4),
    ("S002", "P02", "2024-02-14",  90.00, 3),
]

columns = ["store_id", "product_id", "sale_date", "revenue", "qty"]
df = spark.createDataFrame(data, columns)

# Add time dimension columns
df = df.withColumn("sale_date", F.to_date("sale_date")) \
       .withColumn("week", F.date_format("sale_date", "yyyy-'W'ww")) \
       .withColumn("month", F.date_format("sale_date", "yyyy-MM")) \
       .withColumn("year", F.date_format("sale_date", "yyyy"))

# Define aggregation expressions
agg_exprs = [
    F.sum("revenue").alias("total_revenue"),
    F.sum("qty").alias("total_qty"),
    F.count("*").alias("txn_count"),
    F.avg("revenue").alias("avg_revenue"),
]

# Daily level
daily = df.groupBy("store_id", F.col("sale_date").cast("string").alias("period")) \
    .agg(*agg_exprs) \
    .withColumn("level", F.lit("daily"))

# Weekly level
weekly = df.groupBy("store_id", F.col("week").alias("period")) \
    .agg(*agg_exprs) \
    .withColumn("level", F.lit("weekly"))

# Monthly level
monthly = df.groupBy("store_id", F.col("month").alias("period")) \
    .agg(*agg_exprs) \
    .withColumn("level", F.lit("monthly"))

# Overall level per store
overall = df.groupBy("store_id") \
    .agg(*agg_exprs) \
    .withColumn("period", F.lit("ALL")) \
    .withColumn("level", F.lit("overall"))

# Union all levels together
result = reduce(lambda a, b: a.unionByName(b),
                [daily, weekly, monthly, overall])

result = result.select("store_id", "level", "period",
                       "total_revenue", "total_qty", "txn_count", "avg_revenue")

print("=== Multi-Level Aggregation Result ===")
result.orderBy("store_id", "level", "period").show(30, truncate=False)
```

## Method 2: Using ROLLUP for Hierarchical Aggregation

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("MultiLevelRollup") \
    .master("local[*]") \
    .getOrCreate()

data = [
    ("S001", "P01", "2024-01-05", 100.00, 2),
    ("S001", "P02", "2024-01-05",  50.00, 1),
    ("S001", "P01", "2024-01-12", 200.00, 4),
    ("S001", "P02", "2024-01-20",  75.00, 3),
    ("S001", "P01", "2024-02-03", 150.00, 3),
    ("S002", "P01", "2024-01-08", 120.00, 2),
    ("S002", "P02", "2024-01-15",  60.00, 2),
    ("S002", "P01", "2024-02-10", 180.00, 4),
    ("S002", "P02", "2024-02-14",  90.00, 3),
]

columns = ["store_id", "product_id", "sale_date", "revenue", "qty"]
df = spark.createDataFrame(data, columns)

df = df.withColumn("sale_date", F.to_date("sale_date")) \
       .withColumn("month", F.date_format("sale_date", "yyyy-MM"))

# ROLLUP creates hierarchical subtotals
# rollup(store_id, month, sale_date) produces:
#   - (store_id, month, sale_date)  => daily level
#   - (store_id, month, NULL)       => monthly level
#   - (store_id, NULL, NULL)        => store level
#   - (NULL, NULL, NULL)            => grand total

rollup_result = df.rollup("store_id", "month", "sale_date").agg(
    F.sum("revenue").alias("total_revenue"),
    F.sum("qty").alias("total_qty"),
    F.count("*").alias("txn_count"),
)

# Add a level label based on which columns are null
rollup_result = rollup_result.withColumn("level",
    F.when(F.col("store_id").isNull(), "grand_total")
     .when(F.col("month").isNull(), "store_total")
     .when(F.col("sale_date").isNull(), "monthly")
     .otherwise("daily")
)

print("=== ROLLUP Multi-Level Aggregation ===")
rollup_result.orderBy(
    F.col("store_id").asc_nulls_last(),
    F.col("month").asc_nulls_last(),
    F.col("sale_date").asc_nulls_last()
).show(30, truncate=False)

# ============================================================
# CUBE for all possible combinations
# ============================================================

cube_result = df.cube("store_id", "month").agg(
    F.sum("revenue").alias("total_revenue"),
    F.sum("qty").alias("total_qty"),
)

cube_result = cube_result.withColumn("level",
    F.when(F.col("store_id").isNull() & F.col("month").isNull(), "grand_total")
     .when(F.col("store_id").isNull(), "month_total")
     .when(F.col("month").isNull(), "store_total")
     .otherwise("store_month")
)

print("=== CUBE Result ===")
cube_result.orderBy(
    F.col("store_id").asc_nulls_last(),
    F.col("month").asc_nulls_last()
).show(20, truncate=False)
```

## Method 3: Spark SQL with GROUPING SETS

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("MultiLevelGroupingSets") \
    .master("local[*]") \
    .getOrCreate()

data = [
    ("S001", "P01", "2024-01-05", 100.00, 2),
    ("S001", "P02", "2024-01-05",  50.00, 1),
    ("S001", "P01", "2024-01-12", 200.00, 4),
    ("S001", "P02", "2024-01-20",  75.00, 3),
    ("S001", "P01", "2024-02-03", 150.00, 3),
    ("S002", "P01", "2024-01-08", 120.00, 2),
    ("S002", "P02", "2024-01-15",  60.00, 2),
    ("S002", "P01", "2024-02-10", 180.00, 4),
    ("S002", "P02", "2024-02-14",  90.00, 3),
]

columns = ["store_id", "product_id", "sale_date", "revenue", "qty"]
df = spark.createDataFrame(data, columns)
df = df.withColumn("sale_date", F.to_date("sale_date")) \
       .withColumn("month", F.date_format("sale_date", "yyyy-MM"))
df.createOrReplaceTempView("sales")

# GROUPING SETS lets you specify exactly which combinations you want
result = spark.sql("""
    SELECT
        store_id,
        month,
        CAST(sale_date AS STRING) AS sale_date,
        SUM(revenue)   AS total_revenue,
        SUM(qty)        AS total_qty,
        COUNT(*)        AS txn_count,

        -- GROUPING() returns 1 if the column is aggregated (null due to grouping)
        CASE
            WHEN GROUPING(store_id) = 1 THEN 'grand_total'
            WHEN GROUPING(month) = 1 AND GROUPING(sale_date) = 1 THEN 'store_total'
            WHEN GROUPING(sale_date) = 1 THEN 'monthly'
            ELSE 'daily'
        END AS agg_level,

        -- GROUPING_ID returns a bitmask of which columns are aggregated
        GROUPING_ID(store_id, month, sale_date) AS grouping_id

    FROM sales
    GROUP BY GROUPING SETS (
        (store_id, month, sale_date),   -- daily detail
        (store_id, month),               -- monthly subtotal
        (store_id),                      -- store total
        ()                               -- grand total
    )
    ORDER BY store_id NULLS LAST, month NULLS LAST, sale_date NULLS LAST
""")

print("=== GROUPING SETS Result ===")
result.show(30, truncate=False)
```

## Key Concepts

| Concept | Description |
|---------|-------------|
| **ROLLUP** | Produces hierarchical subtotals: (A,B,C), (A,B), (A), () |
| **CUBE** | Produces all possible combinations: (A,B), (A), (B), () |
| **GROUPING SETS** | You specify exactly which grouping combinations you want |
| **GROUPING()** | Returns 1 if column is null due to aggregation, 0 otherwise |
| **GROUPING_ID()** | Returns bitmask identifying which columns are aggregated |
| **Union approach** | Most flexible; allows different agg logic per level but scans data multiple times |

## Interview Tips

1. **Union vs ROLLUP/CUBE**: The union approach scans data multiple times but is most flexible. ROLLUP/CUBE scan once but give fixed hierarchical patterns. GROUPING SETS is the best of both worlds.

2. **Distinguishing real NULLs from grouping NULLs**: Use the `GROUPING()` function. This is a classic follow-up question.

3. **Performance**: GROUPING SETS processes data in a single pass, making it much more efficient than multiple separate GROUP BY queries unioned together.

4. **Real-world use case**: Building fact tables at multiple granularities for OLAP cubes, dashboard summary tables, and reporting layers in a data warehouse.

5. **When to use each**: Use ROLLUP for drill-down hierarchies (year > month > day). Use CUBE when all dimension combinations matter. Use GROUPING SETS for custom combinations.
