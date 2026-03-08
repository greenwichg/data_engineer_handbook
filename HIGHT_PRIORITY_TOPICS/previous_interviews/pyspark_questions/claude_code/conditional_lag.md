# PySpark Implementation: Conditional Lag (Lookback with Filter)

## Problem Statement
Given a table of order events with different statuses, for each row, find the most recent **previous** row that matches a specific condition. For example: "For each order event, find the most recent previous event where status was 'DELIVERED'." Standard `lag()` only looks back a fixed number of rows — this pattern requires a conditional lookback.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("ConditionalLag").getOrCreate()

data = [
    ("C001", "2025-01-01", "PLACED", 100),
    ("C001", "2025-01-03", "SHIPPED", 100),
    ("C001", "2025-01-05", "DELIVERED", 100),
    ("C001", "2025-01-08", "PLACED", 200),
    ("C001", "2025-01-10", "SHIPPED", 200),
    ("C001", "2025-01-12", "PLACED", 150),
    ("C001", "2025-01-14", "DELIVERED", 200),
    ("C001", "2025-01-16", "SHIPPED", 150),
    ("C001", "2025-01-18", "DELIVERED", 150),
]

columns = ["customer_id", "event_date", "status", "amount"]
df = spark.createDataFrame(data, columns)
df = df.withColumn("event_date", F.to_date("event_date"))
df.show()
```

```
+-----------+----------+---------+------+
|customer_id|event_date|   status|amount|
+-----------+----------+---------+------+
|       C001|2025-01-01|   PLACED|   100|
|       C001|2025-01-03|  SHIPPED|   100|
|       C001|2025-01-05|DELIVERED|   100|
|       C001|2025-01-08|   PLACED|   200|
|       C001|2025-01-10|  SHIPPED|   200|
|       C001|2025-01-12|   PLACED|   150|
|       C001|2025-01-14|DELIVERED|   200|
|       C001|2025-01-16|  SHIPPED|   150|
|       C001|2025-01-18|DELIVERED|   150|
+-----------+----------+---------+------+
```

### Expected Output
For each row, find the most recent previous DELIVERED event's date:
```
+-----------+----------+---------+------+-------------------+
|customer_id|event_date|   status|amount|last_delivered_date|
+-----------+----------+---------+------+-------------------+
|       C001|2025-01-01|   PLACED|   100|               null|
|       C001|2025-01-03|  SHIPPED|   100|               null|
|       C001|2025-01-05|DELIVERED|   100|               null|
|       C001|2025-01-08|   PLACED|   200|         2025-01-05|
|       C001|2025-01-10|  SHIPPED|   200|         2025-01-05|
|       C001|2025-01-12|   PLACED|   150|         2025-01-05|
|       C001|2025-01-14|DELIVERED|   200|         2025-01-05|
|       C001|2025-01-16|  SHIPPED|   150|         2025-01-14|
|       C001|2025-01-18|DELIVERED|   150|         2025-01-14|
+-----------+----------+---------+------+-------------------+
```

---

## Method 1: last() with ignorenulls Over Unbounded Window (Recommended)

```python
# Step 1: Create a column that is non-null only when condition is met
df_with_flag = df.withColumn(
    "delivered_date",
    F.when(F.col("status") == "DELIVERED", F.col("event_date"))
)

# Step 2: Use lag to shift by 1 (we want PREVIOUS delivered, not current)
window_ordered = Window.partitionBy("customer_id").orderBy("event_date")

df_shifted = df_with_flag.withColumn(
    "prev_delivered_date",
    F.lag("delivered_date").over(window_ordered)
)

# Step 3: Use last() with ignorenulls to carry forward the most recent non-null value
window_unbounded = (
    Window.partitionBy("customer_id")
    .orderBy("event_date")
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)
)

result = df_shifted.withColumn(
    "last_delivered_date",
    F.last("prev_delivered_date", ignorenulls=True).over(window_unbounded)
).drop("delivered_date", "prev_delivered_date")

result.show()
```

### Step-by-Step Explanation

#### Step 1: Create conditional column
- **What happens:** Sets `delivered_date` to the event_date only when status is DELIVERED, null otherwise.
- **Output:**

  | event_date | status    | delivered_date |
  |------------|-----------|----------------|
  | 2025-01-01 | PLACED    | null           |
  | 2025-01-03 | SHIPPED   | null           |
  | 2025-01-05 | DELIVERED | 2025-01-05     |
  | 2025-01-08 | PLACED    | null           |
  | ...        | ...       | ...            |

#### Step 2: Shift with lag()
- **Why lag?** We want the **previous** DELIVERED date, not the current row's. Without lag, a DELIVERED row would see itself.

#### Step 3: last(ignorenulls=True) carries forward
- **What happens:** Scans from the start of the partition to the current row, picking the last non-null value. This effectively "fills forward" the most recent delivered date.

---

## Method 2: Self-Join Approach

```python
# Step 1: Get only DELIVERED events
delivered_events = (
    df.filter(F.col("status") == "DELIVERED")
    .select(
        F.col("customer_id").alias("d_customer"),
        F.col("event_date").alias("delivered_date"),
    )
)

# Step 2: Join each row with all previous DELIVERED events
joined = df.join(
    delivered_events,
    (df.customer_id == delivered_events.d_customer)
    & (delivered_events.delivered_date < df.event_date),
    how="left",
)

# Step 3: Keep only the most recent (max) delivered date per original row
result_join = (
    joined.groupBy("customer_id", "event_date", "status", "amount")
    .agg(F.max("delivered_date").alias("last_delivered_date"))
    .orderBy("customer_id", "event_date")
)
result_join.show()
```

- **Downside:** The self-join can produce many intermediate rows. Less efficient than the window approach for large datasets.

---

## Method 3: Spark SQL

```python
df.createOrReplaceTempView("order_events")

result_sql = spark.sql("""
    SELECT
        customer_id,
        event_date,
        status,
        amount,
        MAX(CASE WHEN status = 'DELIVERED' THEN event_date END)
            OVER (
                PARTITION BY customer_id
                ORDER BY event_date
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            ) AS last_delivered_date
    FROM order_events
    ORDER BY customer_id, event_date
""")
result_sql.show()
```

- **Key insight:** `ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING` excludes the current row, so a DELIVERED row won't reference itself.

---

## Variation: Days Since Last Delivered

```python
result_with_gap = result.withColumn(
    "days_since_delivered",
    F.datediff(F.col("event_date"), F.col("last_delivered_date"))
)
result_with_gap.show()
```

## Variation: Carry Forward Any Column from the Conditional Row

```python
# Carry forward the amount from the last DELIVERED event
df_amount_flag = df.withColumn(
    "delivered_amount",
    F.when(F.col("status") == "DELIVERED", F.col("amount"))
)

window_lag = Window.partitionBy("customer_id").orderBy("event_date")
window_fill = (
    Window.partitionBy("customer_id")
    .orderBy("event_date")
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)
)

result_amount = (
    df_amount_flag
    .withColumn("prev_del_amount", F.lag("delivered_amount").over(window_lag))
    .withColumn(
        "last_delivered_amount",
        F.last("prev_del_amount", ignorenulls=True).over(window_fill),
    )
    .drop("delivered_amount", "prev_del_amount")
)
result_amount.show()
```

---

## Comparison of Methods

| Method | Performance | Readability | Handles Multiple Columns? |
|--------|-------------|-------------|---------------------------|
| last(ignorenulls) window | Best — single pass | Moderate | One column at a time |
| Self-join | Slower — join explosion | Clear logic | Yes — join brings all columns |
| SQL MAX + CASE | Best — single pass | Cleanest | One column at a time |

## Key Interview Talking Points

1. **`last(col, ignorenulls=True)`** is the PySpark-specific trick that makes this work. It skips nulls and picks the most recent non-null value in the window.
2. **`ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING`** in SQL excludes the current row — critical when you want "previous" not "current or previous."
3. Standard `lag(n)` only looks back a fixed number of rows. This pattern handles variable lookback distances.
4. The self-join approach is more intuitive but generates O(n²) intermediate rows per partition in the worst case.
5. This pattern is commonly used for: "days since last purchase", "time since last login", "previous successful payment date", "last known good value."
