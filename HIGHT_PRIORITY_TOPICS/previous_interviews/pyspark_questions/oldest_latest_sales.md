# PySpark Implementation: Finding Oldest and Latest Sales per Product

## Problem Statement

Given a dataset of product sales with dates, find the **sales amount for both the oldest and latest sale** for each product. This tests your ability to use aggregations with joins or window functions to extract values associated with min/max dates.

### Sample Data

```
id  product  date        sales_amount
1   A        12-03-2025  45
2   A        25-03-2025  85
3   A        20-03-2025  75
4   B        20-07-2025  70
5   B        25-07-2025  15
6   B        01-07-2025  10
```

### Expected Output

| product | oldest_date | oldest_sales | latest_date | latest_sales |
|---------|-------------|--------------|-------------|--------------|
| A       | 2025-03-12  | 45           | 2025-03-25  | 85           |
| B       | 2025-07-01  | 10           | 2025-07-25  | 15           |

---

## PySpark Code Solution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import to_date, col, min as spark_min, max as spark_max
from pyspark.sql.window import Window
from pyspark.sql.functions import row_number

spark = SparkSession.builder.appName("OldestLatestSales").getOrCreate()

data = [
    (1, "A", "12-03-2025", 45),
    (2, "A", "25-03-2025", 85),
    (3, "A", "20-03-2025", 75),
    (4, "B", "20-07-2025", 70),
    (5, "B", "25-07-2025", 15),
    (6, "B", "01-07-2025", 10)
]

df = spark.createDataFrame(data, ["id", "product", "date", "sales_amount"])
df = df.withColumn("date", to_date(col("date"), "dd-MM-yyyy"))

# Step 1: Find min and max dates per product
date_extremes = df.groupBy("product").agg(
    spark_min("date").alias("oldest_date"),
    spark_max("date").alias("latest_date")
)

# Step 2: Join back to get oldest sales amount
oldest = date_extremes.join(
    df,
    (date_extremes.product == df.product) & (date_extremes.oldest_date == df.date),
    "inner"
).select(date_extremes.product, "oldest_date", col("sales_amount").alias("oldest_sales"))

# Step 3: Join back to get latest sales amount
latest = date_extremes.join(
    df,
    (date_extremes.product == df.product) & (date_extremes.latest_date == df.date),
    "inner"
).select(date_extremes.product, "latest_date", col("sales_amount").alias("latest_sales"))

# Step 4: Combine oldest and latest
result = oldest.join(latest, "product")
result.show()
```

---

## Step-by-Step Explanation with Intermediate DataFrames

### Step 1: Find Min/Max Dates per Product

- **What happens:** Groups by `product` and computes the earliest (`min`) and latest (`max`) dates.
- **Output (date_extremes):**

  | product | oldest_date | latest_date |
  |---------|-------------|-------------|
  | A       | 2025-03-12  | 2025-03-25  |
  | B       | 2025-07-01  | 2025-07-25  |

### Step 2: Join to Get Oldest Sales

- **What happens:** Joins `date_extremes` back to `df` where the product matches and `date == oldest_date`. This retrieves the `sales_amount` for the oldest transaction.
- **Output (oldest):**

  | product | oldest_date | oldest_sales |
  |---------|-------------|--------------|
  | A       | 2025-03-12  | 45           |
  | B       | 2025-07-01  | 10           |

### Step 3: Join to Get Latest Sales

- **What happens:** Same pattern but matching on `latest_date` to get the sales amount for the most recent transaction.
- **Output (latest):**

  | product | latest_date | latest_sales |
  |---------|-------------|--------------|
  | A       | 2025-03-25  | 85           |
  | B       | 2025-07-25  | 15           |

### Step 4: Combine Results

- **What happens:** Joins the `oldest` and `latest` DataFrames on `product` to produce the final side-by-side comparison.
- **Output (result):**

  | product | oldest_date | oldest_sales | latest_date | latest_sales |
  |---------|-------------|--------------|-------------|--------------|
  | A       | 2025-03-12  | 45           | 2025-03-25  | 85           |
  | B       | 2025-07-01  | 10           | 2025-07-25  | 15           |

---

## Alternative: Using Window Functions (Single Pass)

```python
from pyspark.sql.functions import first, last

# Window ordered by date per product
window_asc = Window.partitionBy("product").orderBy("date") \
    .rowsBetween(Window.unboundedPreceding, Window.unboundedFollowing)

# Use first() and last() over the full window frame
result_alt = df.select(
    "product",
    first("date").over(window_asc).alias("oldest_date"),
    first("sales_amount").over(window_asc).alias("oldest_sales"),
    last("date").over(window_asc).alias("latest_date"),
    last("sales_amount").over(window_asc).alias("latest_sales")
).dropDuplicates(["product"])

result_alt.show()
```

This approach uses `first()` and `last()` over a full-frame window to get the values associated with the min and max dates in a single pass — no joins required.

---

## Key Interview Talking Points

1. **Why not just use min/max on sales_amount?** The question asks for the sales amount *at* the oldest/latest date, not the min/max sales amount. These are different — the min date might not have the min sales. You need to retrieve the value associated with the extreme date.

2. **Join approach vs window approach:** The join approach (Method 1) is more intuitive and works when you need values from specific rows. The window approach (Method 2) with `first()`/`last()` is more efficient — single scan, no shuffle from joins.

3. **Handling ties:** If two sales share the same oldest or latest date, the join approach returns both rows (potential duplicates). The window approach with `first()`/`last()` picks one deterministically. Discuss which behavior is desired.

4. **Date parsing:** Always convert string dates to proper `DateType` before comparisons. String comparison of "12-03-2025" vs "01-07-2025" gives wrong results — `to_date(col, "dd-MM-yyyy")` ensures correct chronological ordering.
