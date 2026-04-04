# PySpark Implementation: Expand Date Ranges into Individual Rows

## Problem Statement 

Given a dataset of user subscriptions with a **start_date** and **end_date**, expand each row into **one row per day** within that range. This is the date-range version of the `quantity_explode` pattern — instead of repeating a row N times based on a number, you generate all dates between two boundaries.

### Sample Data

```
user_id  plan       start_date   end_date
U001     Premium    2025-01-01   2025-01-05
U002     Basic      2025-01-03   2025-01-04
U003     Premium    2025-01-10   2025-01-10
```

### Expected Output

| user_id | plan    | active_date |
|---------|---------|-------------|
| U001    | Premium | 2025-01-01  |
| U001    | Premium | 2025-01-02  |
| U001    | Premium | 2025-01-03  |
| U001    | Premium | 2025-01-04  |
| U001    | Premium | 2025-01-05  |
| U002    | Basic   | 2025-01-03  |
| U002    | Basic   | 2025-01-04  |
| U003    | Premium | 2025-01-10  |

---

## Method 1: sequence() + explode() (Recommended)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_date, explode, sequence, expr

# Initialize Spark session
spark = SparkSession.builder.appName("ExpandDateRanges").getOrCreate()

# Sample data
data = [
    ("U001", "Premium", "2025-01-01", "2025-01-05"),
    ("U002", "Basic", "2025-01-03", "2025-01-04"),
    ("U003", "Premium", "2025-01-10", "2025-01-10")
]
columns = ["user_id", "plan", "start_date", "end_date"]
df = spark.createDataFrame(data, columns)
df = df.withColumn("start_date", to_date("start_date")) \
       .withColumn("end_date", to_date("end_date"))

# Step 1: Generate array of all dates in the range
df_with_dates = df.withColumn(
    "date_array",
    sequence(col("start_date"), col("end_date"))
)

# Step 2: Explode the array into individual rows
expanded = df_with_dates.withColumn(
    "active_date", explode(col("date_array"))
).select("user_id", "plan", "active_date")

expanded.show(truncate=False)
```

### Step-by-Step Explanation

#### Step 1: sequence() generates an array of dates

| user_id | plan    | start_date | end_date   | date_array                                            |
|---------|---------|------------|------------|-------------------------------------------------------|
| U001    | Premium | 2025-01-01 | 2025-01-05 | [2025-01-01, 2025-01-02, 2025-01-03, 2025-01-04, 2025-01-05] |
| U002    | Basic   | 2025-01-03 | 2025-01-04 | [2025-01-03, 2025-01-04]                              |
| U003    | Premium | 2025-01-10 | 2025-01-10 | [2025-01-10]                                          |

`sequence(start, end)` produces every date from start to end inclusive. Default step is 1 day for date types.

#### Step 2: explode() turns each array element into its own row

The array `[2025-01-01, ..., 2025-01-05]` becomes 5 rows. Other columns (`user_id`, `plan`) are duplicated for each.

**Comparison to quantity_explode:**
| Pattern | Array Creation | Explode |
|---------|---------------|---------|
| quantity_explode | `array_repeat(lit(1), qty)` | `explode(array)` |
| date range expand | `sequence(start, end)` | `explode(array)` |

Same idea — create an array, explode it. Different source for the array.

---

## Method 2: Custom Step Intervals

```python
# Generate dates every 2 days instead of every day
df_every_2_days = df.withColumn(
    "date_array",
    sequence(col("start_date"), col("end_date"), expr("interval 2 days"))
).withColumn(
    "active_date", explode(col("date_array"))
).select("user_id", "plan", "active_date")

df_every_2_days.show(truncate=False)
```

- **Output for U001:**

  | user_id | plan    | active_date |
  |---------|---------|-------------|
  | U001    | Premium | 2025-01-01  |
  | U001    | Premium | 2025-01-03  |
  | U001    | Premium | 2025-01-05  |

---

## Method 3: Monthly Expansion

```python
# Expand month ranges — one row per month
monthly_data = [
    ("U001", "2025-01-01", "2025-04-01"),
    ("U002", "2025-03-01", "2025-05-01")
]
monthly_df = spark.createDataFrame(monthly_data, ["user_id", "start_month", "end_month"])
monthly_df = monthly_df.withColumn("start_month", to_date("start_month")) \
                       .withColumn("end_month", to_date("end_month"))

# Generate one row per month
monthly_expanded = monthly_df.withColumn(
    "month_array",
    sequence(col("start_month"), col("end_month"), expr("interval 1 month"))
).withColumn(
    "active_month", explode(col("month_array"))
).select("user_id", "active_month")

monthly_expanded.show(truncate=False)
```

- **Output:**

  | user_id | active_month |
  |---------|-------------|
  | U001    | 2025-01-01  |
  | U001    | 2025-02-01  |
  | U001    | 2025-03-01  |
  | U001    | 2025-04-01  |
  | U002    | 2025-03-01  |
  | U002    | 2025-04-01  |
  | U002    | 2025-05-01  |

---

## Method 4: Using SQL

```python
df.createOrReplaceTempView("subscriptions")

spark.sql("""
    SELECT
        user_id,
        plan,
        active_date
    FROM subscriptions
    LATERAL VIEW explode(sequence(start_date, end_date)) dates AS active_date
    ORDER BY user_id, active_date
""").show(truncate=False)
```

---

## Practical Application: Calculate Daily Revenue from Subscriptions

```python
from pyspark.sql.functions import datediff, round as spark_round

# Add pricing and calculate per-day cost
pricing_data = [
    ("U001", "Premium", "2025-01-01", "2025-01-05", 50.00),
    ("U002", "Basic", "2025-01-03", "2025-01-04", 20.00),
    ("U003", "Premium", "2025-01-10", "2025-01-10", 10.00)
]
pricing_df = spark.createDataFrame(
    pricing_data, ["user_id", "plan", "start_date", "end_date", "total_cost"]
)
pricing_df = pricing_df.withColumn("start_date", to_date("start_date")) \
                       .withColumn("end_date", to_date("end_date"))

# Expand and assign daily cost
daily_revenue = pricing_df.withColumn(
    "days_in_plan", datediff(col("end_date"), col("start_date")) + 1
).withColumn(
    "daily_cost", spark_round(col("total_cost") / col("days_in_plan"), 2)
).withColumn(
    "active_date", explode(sequence(col("start_date"), col("end_date")))
).select("user_id", "plan", "active_date", "daily_cost")

daily_revenue.show(truncate=False)

# Now you can aggregate revenue by date
from pyspark.sql.functions import sum as spark_sum

daily_revenue.groupBy("active_date").agg(
    spark_sum("daily_cost").alias("total_revenue")
).orderBy("active_date").show(truncate=False)
```

---

## Edge Cases to Handle

```python
from pyspark.sql.functions import when

# Handle null dates, end < start, or very large ranges
safe_expanded = df.filter(
    col("start_date").isNotNull() &
    col("end_date").isNotNull() &
    (col("end_date") >= col("start_date")) &
    (datediff(col("end_date"), col("start_date")) <= 365)  # Safety limit
).withColumn(
    "active_date", explode(sequence(col("start_date"), col("end_date")))
).select("user_id", "plan", "active_date")

safe_expanded.show(truncate=False)
```

---

## Key Interview Talking Points

1. **`sequence()` is the date version of `array_repeat()`:** Both create arrays for exploding. `sequence` generates a range, `array_repeat` repeats a constant value.

2. **Memory warning:** Expanding a 10-year date range produces 3,650 rows per input row. Always sanity-check the range size before exploding. Add a filter like `datediff <= 365` to prevent OOM.

3. **Use cases in data engineering:**
   - Daily active subscription counts from start/end ranges
   - Revenue recognition (allocate contract value to daily/monthly)
   - Calendar table generation for joining
   - SLA uptime calculation per day
   - Hotel room occupancy from booking ranges

4. **`LATERAL VIEW` in SQL:** The SQL equivalent of `explode` is `LATERAL VIEW explode(...)`. This is Hive-compatible syntax and commonly seen in data warehouse queries.

5. **Interval options for `sequence()`:**
   - Daily: `sequence(start, end)` (default)
   - Hourly: `sequence(start, end, expr("interval 1 hour"))` (use timestamps)
   - Weekly: `sequence(start, end, expr("interval 7 days"))`
   - Monthly: `sequence(start, end, expr("interval 1 month"))`
