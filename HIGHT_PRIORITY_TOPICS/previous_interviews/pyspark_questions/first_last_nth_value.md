# PySpark Implementation: first_value, last_value, and nth_value

## Problem Statement 

Given a dataset of customer orders, retrieve the **first purchase**, **last purchase**, and **Nth purchase** for each customer **without using groupBy or self-joins**. These window functions let you pull a specific row's value across the entire partition while keeping all rows in the result — something `min`/`max` can't do for non-aggregate columns like product names.

### Sample Data

```
customer_id  order_date   product      amount
C001         2025-01-05   Laptop       1200
C001         2025-01-15   Mouse        50
C001         2025-02-10   Keyboard     150
C001         2025-03-20   Monitor      800
C002         2025-01-08   Phone        900
C002         2025-02-14   Case         30
C002         2025-03-01   Charger      45
C003         2025-01-20   Tablet       600
```

### Expected Output

| customer_id | order_date | product  | amount | first_product | last_product | second_product |
|------------|-----------|----------|--------|--------------|-------------|---------------|
| C001       | 2025-01-05 | Laptop   | 1200   | Laptop       | Monitor     | Mouse         |
| C001       | 2025-01-15 | Mouse    | 50     | Laptop       | Monitor     | Mouse         |
| C001       | 2025-02-10 | Keyboard | 150    | Laptop       | Monitor     | Mouse         |
| C001       | 2025-03-20 | Monitor  | 800    | Laptop       | Monitor     | Mouse         |

Every row shows the first, last, and second values for the entire customer partition.

---

## Method 1: first_value() and last_value()

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_date, first_value, last_value, nth_value
from pyspark.sql.window import Window

# Initialize Spark session
spark = SparkSession.builder.appName("FirstLastValue").getOrCreate()

# Sample data
data = [
    ("C001", "2025-01-05", "Laptop", 1200),
    ("C001", "2025-01-15", "Mouse", 50),
    ("C001", "2025-02-10", "Keyboard", 150),
    ("C001", "2025-03-20", "Monitor", 800),
    ("C002", "2025-01-08", "Phone", 900),
    ("C002", "2025-02-14", "Case", 30),
    ("C002", "2025-03-01", "Charger", 45),
    ("C003", "2025-01-20", "Tablet", 600)
]
columns = ["customer_id", "order_date", "product", "amount"]
df = spark.createDataFrame(data, columns)
df = df.withColumn("order_date", to_date("order_date"))

# CRITICAL: Use UNBOUNDED FOLLOWING to see the full partition
window_full = Window.partitionBy("customer_id").orderBy("order_date") \
    .rowsBetween(Window.unboundedPreceding, Window.unboundedFollowing)

# Get first and last values across the entire partition
df_result = df.withColumn(
    "first_product", first_value("product").over(window_full)
).withColumn(
    "last_product", last_value("product").over(window_full)
).withColumn(
    "first_amount", first_value("amount").over(window_full)
).withColumn(
    "last_amount", last_value("amount").over(window_full)
)

df_result.orderBy("customer_id", "order_date").show(truncate=False)
```

---

## THE CRITICAL GOTCHA: last_value Default Frame

```python
# ============================================================
# WARNING: THIS IS THE #1 INTERVIEW TRAP WITH last_value
# ============================================================

# DEFAULT window frame when using ORDER BY is:
#   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
# This means last_value only sees up to the current row!

# WRONG — gives "running last" not the actual last:
window_default = Window.partitionBy("customer_id").orderBy("order_date")

df.withColumn("last_product", last_value("product").over(window_default)) \
    .orderBy("customer_id", "order_date").show(truncate=False)
```

| order_date | product  | last_product (WRONG!) |
|-----------|----------|----------------------|
| 2025-01-05 | Laptop   | Laptop (sees row 1 only) |
| 2025-01-15 | Mouse    | Mouse (sees rows 1-2) |
| 2025-02-10 | Keyboard | Keyboard (sees rows 1-3) |
| 2025-03-20 | Monitor  | Monitor (sees all rows) |

```python
# CORRECT — extend frame to see the entire partition:
window_full = Window.partitionBy("customer_id").orderBy("order_date") \
    .rowsBetween(Window.unboundedPreceding, Window.unboundedFollowing)

df.withColumn("last_product", last_value("product").over(window_full)) \
    .orderBy("customer_id", "order_date").show(truncate=False)
```

| order_date | product  | last_product (CORRECT) |
|-----------|----------|----------------------|
| 2025-01-05 | Laptop   | Monitor |
| 2025-01-15 | Mouse    | Monitor |
| 2025-02-10 | Keyboard | Monitor |
| 2025-03-20 | Monitor  | Monitor |

**Always add `.rowsBetween(Window.unboundedPreceding, Window.unboundedFollowing)` when using `last_value`.**

---

## Method 2: nth_value() — Get the Nth Row's Value

```python
# Get the 2nd and 3rd purchase for each customer
df_nth = df.withColumn(
    "second_product", nth_value("product", 2).over(window_full)
).withColumn(
    "third_product", nth_value("product", 3).over(window_full)
).withColumn(
    "second_amount", nth_value("amount", 2).over(window_full)
)

df_nth.orderBy("customer_id", "order_date").show(truncate=False)
```

- **Output (partial):**

  | customer_id | product  | second_product | third_product |
  |------------|----------|---------------|--------------|
  | C001       | Laptop   | Mouse         | Keyboard     |
  | C001       | Mouse    | Mouse         | Keyboard     |
  | C001       | Keyboard | Mouse         | Keyboard     |
  | C001       | Monitor  | Mouse         | Keyboard     |
  | C002       | Phone    | Case          | Charger      |
  | C003       | Tablet   | null          | null         |

**Note:** C003 has only 1 order → `nth_value(2)` returns null.

---

## Method 3: first_value with ignorenulls

```python
# Data with some null products
null_data = [
    ("C001", "2025-01-05", None, 1200),
    ("C001", "2025-01-15", "Mouse", 50),
    ("C001", "2025-02-10", "Keyboard", 150),
    ("C001", "2025-03-20", None, 800)
]
null_df = spark.createDataFrame(null_data, columns)
null_df = null_df.withColumn("order_date", to_date("order_date"))

# first_value with ignorenulls — skip null values
null_df.withColumn(
    "first_with_nulls",
    first_value("product").over(window_full)
).withColumn(
    "first_skip_nulls",
    first_value("product", ignorenulls=True).over(window_full)
).withColumn(
    "last_skip_nulls",
    last_value("product", ignorenulls=True).over(window_full)
).orderBy("order_date").show(truncate=False)
```

| order_date | product  | first_with_nulls | first_skip_nulls | last_skip_nulls |
|-----------|----------|-----------------|-----------------|----------------|
| 2025-01-05 | null     | null            | Mouse           | Keyboard       |
| 2025-01-15 | Mouse    | null            | Mouse           | Keyboard       |
| 2025-02-10 | Keyboard | null            | Mouse           | Keyboard       |
| 2025-03-20 | null     | null            | Mouse           | Keyboard       |

**Use case:** Forward-fill or backward-fill missing values by skipping nulls.

---

## Method 4: Practical — First vs Last Purchase Comparison

```python
from pyspark.sql.functions import datediff, row_number, round as spark_round

# Build a per-customer summary without groupBy
window_rn = Window.partitionBy("customer_id").orderBy("order_date")

customer_journey = df.withColumn(
    "first_product", first_value("product").over(window_full)
).withColumn(
    "first_amount", first_value("amount").over(window_full)
).withColumn(
    "first_date", first_value("order_date").over(window_full)
).withColumn(
    "last_product", last_value("product").over(window_full)
).withColumn(
    "last_amount", last_value("amount").over(window_full)
).withColumn(
    "last_date", last_value("order_date").over(window_full)
).withColumn(
    "purchase_number", row_number().over(window_rn)
)

# Get one row per customer (first purchase row only)
summary = customer_journey.filter(col("purchase_number") == 1).select(
    "customer_id",
    "first_product", "first_amount", "first_date",
    "last_product", "last_amount", "last_date",
    datediff("last_date", "first_date").alias("days_as_customer"),
    (col("last_amount") - col("first_amount")).alias("amount_change")
)

summary.show(truncate=False)
```

- **Output:**

  | customer_id | first_product | first_amount | last_product | last_amount | days_as_customer | amount_change |
  |------------|--------------|-------------|-------------|------------|-----------------|--------------|
  | C001       | Laptop       | 1200        | Monitor     | 800        | 74              | -400         |
  | C002       | Phone        | 900         | Charger     | 45         | 52              | -855         |
  | C003       | Tablet       | 600         | Tablet      | 600        | 0               | 0            |

---

## Method 5: Forward-Fill Using last_value(ignorenulls)

```python
# Classic forward-fill: carry the last non-null value forward
sparse_data = [
    ("C001", "2025-01-01", "Gold"),
    ("C001", "2025-01-02", None),
    ("C001", "2025-01-03", None),
    ("C001", "2025-01-04", "Silver"),
    ("C001", "2025-01-05", None)
]
sparse_df = spark.createDataFrame(sparse_data, ["customer_id", "date", "tier"])
sparse_df = sparse_df.withColumn("date", to_date("date"))

# Forward-fill: use last non-null value up to current row
window_ffill = Window.partitionBy("customer_id").orderBy("date") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

filled = sparse_df.withColumn(
    "tier_filled",
    last_value("tier", ignorenulls=True).over(window_ffill)
)

filled.show(truncate=False)
```

| date       | tier   | tier_filled |
|-----------|--------|------------|
| 2025-01-01 | Gold   | Gold       |
| 2025-01-02 | null   | Gold       |
| 2025-01-03 | null   | Gold       |
| 2025-01-04 | Silver | Silver     |
| 2025-01-05 | null   | Silver     |

**Note:** For forward-fill, use the default frame (`CURRENT ROW`), NOT unboundedFollowing. You want to carry the last known value forward, not peek at future values.

---

## Method 6: Using SQL

```python
df.createOrReplaceTempView("orders")

spark.sql("""
    SELECT
        customer_id,
        order_date,
        product,
        amount,
        FIRST_VALUE(product) OVER (
            PARTITION BY customer_id ORDER BY order_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS first_product,
        LAST_VALUE(product) OVER (
            PARTITION BY customer_id ORDER BY order_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS last_product,
        NTH_VALUE(product, 2) OVER (
            PARTITION BY customer_id ORDER BY order_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS second_product
    FROM orders
    ORDER BY customer_id, order_date
""").show(truncate=False)
```

---

## first_value vs min/max — When You Need first_value

```python
# min/max only works for the column being aggregated
# first_value lets you get OTHER columns from the first/last row

# "What product did each customer buy FIRST?"
# min("product") → alphabetically first product name (WRONG)
# first_value("product") ordered by date → chronologically first (CORRECT)

# "What was the amount of the most recent order?"
# max("amount") → largest amount ever (WRONG)
# last_value("amount") ordered by date → most recent amount (CORRECT)
```

---

## Key Interview Talking Points

1. **The `last_value` frame trap:** Default frame with ORDER BY is `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`. `last_value` only sees up to the current row, giving a "running last." Always specify `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` for the true last value.

2. **first_value vs min/max:** `min("product")` gives the alphabetically smallest product. `first_value("product")` gives the product from the first row by sort order. These are fundamentally different.

3. **ignorenulls parameter:** `first_value(col, ignorenulls=True)` skips null values. Essential for forward-fill (carry last known value) and backward-fill patterns.

4. **nth_value for arbitrary position:** `nth_value("product", 3)` gets the 3rd row's product. Returns null if fewer than N rows exist. Used for "2nd purchase analysis" or "3rd interaction" type questions.

5. **Forward-fill pattern:** `last_value(col, ignorenulls=True)` with `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` carries the last non-null value forward. This is how you fill sparse/missing dimension values in time-series data.
