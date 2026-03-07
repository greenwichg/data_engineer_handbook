# PySpark Implementation: Cumulative Window Aggregations

## Problem Statement

Cumulative (running) aggregations use window frames like `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` to compute running totals, running averages, running min/max, and other cumulative metrics. These are essential for financial reporting, time-series analysis, and KPI dashboards. This is a very common interview topic that tests understanding of window functions and frame specifications in PySpark.

### Sample Data

```
date       | department  | revenue
2024-01-01 | Sales       | 1000
2024-01-02 | Sales       | 1500
2024-01-03 | Sales       | 800
2024-01-04 | Sales       | 2000
2024-01-05 | Sales       | 1200
2024-01-01 | Marketing   | 500
2024-01-02 | Marketing   | 700
2024-01-03 | Marketing   | 600
2024-01-04 | Marketing   | 900
2024-01-05 | Marketing   | 800
```

### Expected Output (Running Total by Department)

| date       | department | revenue | running_total | running_avg | running_min | running_max |
|------------|-----------|---------|---------------|-------------|-------------|-------------|
| 2024-01-01 | Sales     | 1000    | 1000          | 1000.0      | 1000        | 1000        |
| 2024-01-02 | Sales     | 1500    | 2500          | 1250.0      | 1000        | 1500        |
| 2024-01-03 | Sales     | 800     | 3300          | 1100.0      | 800         | 1500        |
| 2024-01-04 | Sales     | 2000    | 5300          | 1325.0      | 800         | 2000        |
| 2024-01-05 | Sales     | 1200    | 6500          | 1300.0      | 800         | 2000        |

---

## Method 1: Basic Cumulative Aggregations

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, sum as spark_sum, avg as spark_avg,
    min as spark_min, max as spark_max, count,
    row_number, round as spark_round
)
from pyspark.sql.window import Window

# Initialize SparkSession
spark = SparkSession.builder \
    .appName("CumulativeWindowAggregations") \
    .master("local[*]") \
    .getOrCreate()

# Create sample data
data = [
    ("2024-01-01", "Sales",     1000),
    ("2024-01-02", "Sales",     1500),
    ("2024-01-03", "Sales",     800),
    ("2024-01-04", "Sales",     2000),
    ("2024-01-05", "Sales",     1200),
    ("2024-01-01", "Marketing", 500),
    ("2024-01-02", "Marketing", 700),
    ("2024-01-03", "Marketing", 600),
    ("2024-01-04", "Marketing", 900),
    ("2024-01-05", "Marketing", 800),
]

df = spark.createDataFrame(data, ["date", "department", "revenue"])

# Define cumulative window: all rows from start to current row within each department
cumulative_window = Window.partitionBy("department") \
    .orderBy("date") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

# Apply various cumulative aggregations
result = df.withColumn(
    "running_total", spark_sum("revenue").over(cumulative_window)
).withColumn(
    "running_avg", spark_round(spark_avg("revenue").over(cumulative_window), 2)
).withColumn(
    "running_min", spark_min("revenue").over(cumulative_window)
).withColumn(
    "running_max", spark_max("revenue").over(cumulative_window)
).withColumn(
    "running_count", count("revenue").over(cumulative_window)
).orderBy("department", "date")

print("=== Cumulative Aggregations by Department ===")
result.show(truncate=False)

spark.stop()
```

## Method 2: Cumulative Percentage and Contribution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, sum as spark_sum, round as spark_round, last
)
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("CumulativePercentage") \
    .master("local[*]") \
    .getOrCreate()

data = [
    ("2024-01-01", "Sales",     1000),
    ("2024-01-02", "Sales",     1500),
    ("2024-01-03", "Sales",     800),
    ("2024-01-04", "Sales",     2000),
    ("2024-01-05", "Sales",     1200),
    ("2024-01-01", "Marketing", 500),
    ("2024-01-02", "Marketing", 700),
    ("2024-01-03", "Marketing", 600),
    ("2024-01-04", "Marketing", 900),
    ("2024-01-05", "Marketing", 800),
]

df = spark.createDataFrame(data, ["date", "department", "revenue"])

# Cumulative window
cum_window = Window.partitionBy("department") \
    .orderBy("date") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

# Total window (all rows in partition, no frame restriction)
total_window = Window.partitionBy("department") \
    .orderBy("date") \
    .rowsBetween(Window.unboundedPreceding, Window.unboundedFollowing)

result = df.withColumn(
    "running_total", spark_sum("revenue").over(cum_window)
).withColumn(
    "dept_total", spark_sum("revenue").over(total_window)
).withColumn(
    "cumulative_pct",
    spark_round(
        spark_sum("revenue").over(cum_window) /
        spark_sum("revenue").over(total_window) * 100, 2
    )
).withColumn(
    "daily_contribution_pct",
    spark_round(col("revenue") / col("dept_total") * 100, 2)
).orderBy("department", "date")

print("=== Cumulative Percentage ===")
result.show(truncate=False)

spark.stop()
```

## Method 3: ROWS vs RANGE Frame Differences

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum as spark_sum, to_date
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("RowsVsRange") \
    .master("local[*]") \
    .getOrCreate()

# Data with duplicate dates to show ROWS vs RANGE difference
data = [
    ("2024-01-01", "Sales", 1000),
    ("2024-01-01", "Sales", 500),   # Same date as above
    ("2024-01-02", "Sales", 1500),
    ("2024-01-03", "Sales", 800),
    ("2024-01-03", "Sales", 300),   # Same date as above
    ("2024-01-04", "Sales", 2000),
]

df = spark.createDataFrame(data, ["date", "department", "revenue"])

# ROWS BETWEEN: counts physical rows regardless of ties
rows_window = Window.partitionBy("department") \
    .orderBy("date") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

# RANGE BETWEEN: treats ties (same order value) as a single group
# All rows with the same date get the same cumulative sum
range_window = Window.partitionBy("department") \
    .orderBy("date") \
    .rangeBetween(Window.unboundedPreceding, Window.currentRow)

result = df.withColumn(
    "cum_sum_rows", spark_sum("revenue").over(rows_window)
).withColumn(
    "cum_sum_range", spark_sum("revenue").over(range_window)
).orderBy("date", "revenue")

print("=== ROWS vs RANGE with duplicate dates ===")
print("ROWS: each physical row gets a distinct cumulative sum")
print("RANGE: all rows with the same date get the same cumulative sum")
result.show(truncate=False)

spark.stop()
```

## Method 4: Cumulative Distinct Count and Product

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, collect_set, size, sum as spark_sum,
    exp, log as spark_log, round as spark_round
)
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("CumulativeDistinctAndProduct") \
    .master("local[*]") \
    .getOrCreate()

data = [
    ("2024-01-01", "user_A", 2),
    ("2024-01-01", "user_B", 3),
    ("2024-01-02", "user_A", 5),
    ("2024-01-02", "user_C", 4),
    ("2024-01-03", "user_B", 1),
    ("2024-01-03", "user_D", 6),
    ("2024-01-04", "user_A", 2),
    ("2024-01-04", "user_E", 3),
]

df = spark.createDataFrame(data, ["date", "user_id", "value"])

cum_window = Window.orderBy("date") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

# Cumulative distinct count using collect_set
result = df.withColumn(
    "cum_users", collect_set("user_id").over(cum_window)
).withColumn(
    "cum_distinct_users", size("cum_users")
).withColumn(
    "cum_sum", spark_sum("value").over(cum_window)
).withColumn(
    # Cumulative product using exp(sum(log(x)))
    "cum_product",
    spark_round(
        exp(spark_sum(spark_log(col("value").cast("double"))).over(cum_window)),
        2
    )
).orderBy("date")

print("=== Cumulative Distinct Count and Product ===")
result.select("date", "user_id", "value",
              "cum_distinct_users", "cum_sum", "cum_product").show(truncate=False)

spark.stop()
```

## Method 5: Using Spark SQL

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("CumulativeSQL") \
    .master("local[*]") \
    .getOrCreate()

data = [
    ("2024-01-01", "Sales", 1000),
    ("2024-01-02", "Sales", 1500),
    ("2024-01-03", "Sales", 800),
    ("2024-01-04", "Sales", 2000),
    ("2024-01-05", "Sales", 1200),
]

df = spark.createDataFrame(data, ["date", "department", "revenue"])
df.createOrReplaceTempView("daily_revenue")

result = spark.sql("""
    SELECT
        date,
        department,
        revenue,
        SUM(revenue) OVER (
            PARTITION BY department
            ORDER BY date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_total,
        AVG(revenue) OVER (
            PARTITION BY department
            ORDER BY date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_avg,
        -- Cumulative percentage of department total
        ROUND(
            SUM(revenue) OVER (
                PARTITION BY department
                ORDER BY date
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) * 100.0 /
            SUM(revenue) OVER (
                PARTITION BY department
            ),
            2
        ) AS cumulative_pct
    FROM daily_revenue
    ORDER BY department, date
""")

result.show(truncate=False)

spark.stop()
```

## Key Concepts

- **Window frame specification**: `rowsBetween(Window.unboundedPreceding, Window.currentRow)` defines a cumulative frame from the first row to the current row within each partition.
- **ROWS vs RANGE**: `ROWS` counts physical rows; `RANGE` groups rows with the same order key value. Default behavior for `sum().over(Window.orderBy(...))` without explicit frame is `RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`.
- **Cumulative product**: PySpark does not have a native cumulative product function. Use the mathematical identity: `product(x_i) = exp(sum(log(x_i)))`. Only works for positive values.
- **Cumulative distinct count**: Use `collect_set` over a cumulative window, then `size` to count unique elements. Be cautious with memory for high-cardinality columns.
- **Performance**: Cumulative windows require sorting within each partition. Ensure partitions are reasonably sized to avoid memory issues.

## Interview Tips

- Always specify the frame explicitly (`rowsBetween` or `rangeBetween`) to avoid relying on default behavior, which varies between `ROWS` and `RANGE` depending on whether `orderBy` is present.
- Demonstrate awareness that window functions do not reduce row count; they add computed columns to each row.
- Mention that cumulative aggregations are commonly used for YTD (year-to-date) calculations, account balance tracking, and progressive quota attainment.
