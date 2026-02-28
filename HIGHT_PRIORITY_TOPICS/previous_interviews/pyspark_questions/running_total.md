# PySpark Implementation: Running Total (Cumulative Sum)

## Problem Statement 

Given an orders dataset, compute a **running (cumulative) total** of amounts for a specific customer, where the running total for each row includes all amounts from orders on or before that row's date. Rows on the same date should share the same running total. This tests your ability to use window functions with `rowsBetween` frame specifications.

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

---

## PySpark Code Solution

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

---

## Step-by-Step Explanation with Intermediate DataFrames

### Step 1: Aggregate Daily Totals

- **What happens:** Groups by `order_date` and sums all amounts for that date. This is necessary because multiple orders on the same date should all share the same cumulative total.
- **Why aggregate first?** If we computed a running sum directly on individual rows, rows on the same date would get different running totals depending on their processing order. Aggregating first ensures date-level consistency.
- **Output (daily_totals):**

  | order_date | daily_total |
  |------------|-------------|
  | 01-Aug-25  | 100         |
  | 02-Aug-25  | 350         |
  | 13-Aug-25  | 1050        |

### Step 2: Compute Running Total

- **What happens:** A window ordered by `order_date` with frame `unboundedPreceding` to `currentRow` computes the cumulative sum of `daily_total`. Each row's running total = sum of all daily totals up to and including that date.
- **Output (daily_running):**

  | order_date | daily_total | running_total |
  |------------|-------------|---------------|
  | 01-Aug-25  | 100         | 100           |
  | 02-Aug-25  | 350         | 450           |
  | 13-Aug-25  | 1050        | 1500          |

  - Aug 1: 100
  - Aug 2: 100 + 350 = 450
  - Aug 13: 100 + 350 + 1050 = 1500

### Step 3: Join Back to Original Rows

- **What happens:** Left-joins the running totals back to the original filtered DataFrame on `order_date`. This replicates the running total for every row that shares the same date.
- **Output (result):**

  | customer_id | order_date | amount | running_total |
  |-------------|------------|--------|---------------|
  | 12345       | 01-Aug-25  | 100    | 100           |
  | 12345       | 02-Aug-25  | 200    | 450           |
  | 12345       | 02-Aug-25  | 150    | 450           |
  | 12345       | 13-Aug-25  | 250    | 1500          |
  | 12345       | 13-Aug-25  | 500    | 1500          |
  | 12345       | 13-Aug-25  | 300    | 1500          |

---

## Alternative: Using rangeBetween (No Pre-Aggregation)

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

---

## Key Interview Talking Points

1. **rowsBetween vs rangeBetween:** `rowsBetween` treats each physical row independently (same-date rows get different totals). `rangeBetween` treats rows with equal values as peers (same-date rows get identical totals). The SQL `<=` semantics match `rangeBetween`.

2. **Why aggregate + join?** The main solution aggregates daily totals first to avoid the rowsBetween ordering issue. This is the safest approach when you can't guarantee date column type. The alternative with `rangeBetween` is cleaner but requires a proper date/numeric column.

3. **Multi-customer extension:** Add `partitionBy("customer_id")` to the window spec. The current solution filters for one customer, but partitioning scales to all customers without filtering.

4. **Performance:** The aggregate + join approach triggers two shuffles (groupBy + join). The `rangeBetween` approach needs only one shuffle (window). For large datasets, the single-pass window approach is preferable.
