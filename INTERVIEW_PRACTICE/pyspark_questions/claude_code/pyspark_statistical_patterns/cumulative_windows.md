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

## Method 6: Same-Date Running Totals (Aggregate + Join Approach)

When multiple rows share the same date and all same-date rows must have identical running totals, pre-aggregate daily totals before computing the cumulative sum, then join back.

### Sample Data

```
customer_id  order_date  amount
12345        01-Aug-25   100
12345        02-Aug-25   200
12345        02-Aug-25   150
12345        13-Aug-25   250
12345        13-Aug-25   500
12345        13-Aug-25   300
```

### Expected Output

| customer_id | order_date | amount | running_total |
|-------------|------------|--------|---------------|
| 12345       | 01-Aug-25  | 100    | 100           |
| 12345       | 02-Aug-25  | 200    | 450           |
| 12345       | 02-Aug-25  | 150    | 450           |
| 12345       | 13-Aug-25  | 250    | 1500          |
| 12345       | 13-Aug-25  | 500    | 1500          |
| 12345       | 13-Aug-25  | 300    | 1500          |

Note: All rows on the same date share the same running total (100 + 200 + 150 = 450 for Aug 2; 450 + 250 + 500 + 300 = 1500 for Aug 13).

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import sum as spark_sum, col
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("RunningTotal").getOrCreate()

data = [
    ("12345", "01-Aug-25", 100),
    ("12345", "02-Aug-25", 200),
    ("12345", "02-Aug-25", 150),
    ("12345", "13-Aug-25", 250),
    ("12345", "13-Aug-25", 500),
    ("12345", "13-Aug-25", 300)
]

columns = ["customer_id", "order_date", "amount"]
df = spark.createDataFrame(data, columns)

# Filter for the specific customer
df_filtered = df.filter(col("customer_id") == "12345")

# Step 1: Aggregate daily totals (sum per date)
daily_totals = df_filtered.groupBy("order_date").agg(
    spark_sum("amount").alias("daily_total")
)

# Step 2: Compute running total on daily aggregated data
window_spec = Window.orderBy("order_date").rowsBetween(
    Window.unboundedPreceding, Window.currentRow
)
daily_running = daily_totals.withColumn(
    "running_total", spark_sum("daily_total").over(window_spec)
)

# Step 3: Join running totals back to original rows
result = df_filtered.join(daily_running, on="order_date", how="left") \
    .select("customer_id", "order_date", "amount", "running_total")

result.show()
```

### Step-by-Step Explanation with Intermediate DataFrames

**Step 1: Aggregate Daily Totals**

Groups by `order_date` and sums all amounts for that date. This is necessary because multiple orders on the same date should all share the same cumulative total. If we computed a running sum directly on individual rows, rows on the same date would get different running totals depending on their processing order.

| order_date | daily_total |
|------------|-------------|
| 01-Aug-25  | 100         |
| 02-Aug-25  | 350         |
| 13-Aug-25  | 1050        |

**Step 2: Compute Running Total**

A window ordered by `order_date` with frame `unboundedPreceding` to `currentRow` computes the cumulative sum of `daily_total`.

| order_date | daily_total | running_total |
|------------|-------------|---------------|
| 01-Aug-25  | 100         | 100           |
| 02-Aug-25  | 350         | 450           |
| 13-Aug-25  | 1050        | 1500          |

**Step 3: Join Back to Original Rows**

Left-joins the running totals back to the original filtered DataFrame on `order_date`. This replicates the running total for every row that shares the same date.

### Alternative: Using rangeBetween (No Pre-Aggregation)

```python
from pyspark.sql.functions import to_date, unix_timestamp

# Convert to proper date for rangeBetween to work
df_with_date = df_filtered.withColumn(
    "order_date_parsed", to_date(col("order_date"), "dd-MMM-yy")
)

# rangeBetween on dates: all rows with the same or earlier date get the same total
window_range = Window.orderBy("order_date_parsed").rangeBetween(
    Window.unboundedPreceding, Window.currentRow
)

result_alt = df_with_date.withColumn(
    "running_total", spark_sum("amount").over(window_range)
).select("customer_id", "order_date", "amount", "running_total")

result_alt.show()
```

**Key difference:** `rangeBetween` groups rows with identical `order_date` values together in the window frame, so all same-date rows get the same running total — no pre-aggregation or join needed. However, it requires a numeric or date-type ordering column.

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
- **Why aggregate + join for same-date totals?** The aggregate-then-join approach avoids the `rowsBetween` ordering issue where same-date rows get different totals. This is the safest approach when you cannot guarantee the date column type. The `rangeBetween` alternative is cleaner but requires a proper date/numeric column.
- **Multi-customer extension:** Add `partitionBy("customer_id")` to the window spec. A single-customer filter works for demos, but partitioning scales to all customers without filtering.
- **Performance of aggregate + join vs rangeBetween:** The aggregate + join approach triggers two shuffles (groupBy + join). The `rangeBetween` approach needs only one shuffle (window). For large datasets, the single-pass window approach is preferable.
