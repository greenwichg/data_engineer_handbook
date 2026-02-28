# PySpark Implementation: New vs Returning Customer Classification

## Problem Statement

Given a dataset of e-commerce transactions, classify each transaction as coming from a **new customer** (first-ever purchase) or a **returning customer** (has purchased before). Then compute daily and monthly metrics: new customer count, returning customer count, and new customer revenue percentage. This is a direct application of the `cumulative_distinct_count` first-seen trick — the same technique of finding each user's first appearance date, then using that to classify all subsequent events.

### Sample Data

```
order_id  customer_id  order_date   amount
O001      C001         2025-01-05   250
O002      C002         2025-01-05   180
O003      C003         2025-01-08   320
O004      C001         2025-01-10   150
O005      C004         2025-01-10   400
O006      C002         2025-01-15   200
O007      C005         2025-01-15   90
O008      C001         2025-01-20   500
O009      C006         2025-01-20   175
O010      C003         2025-01-25   280
```

### Expected Output (Transaction-Level)

| order_id | customer_id | order_date | amount | customer_type |
|----------|------------|-----------|--------|---------------|
| O001     | C001       | 2025-01-05 | 250    | New           |
| O002     | C002       | 2025-01-05 | 180    | New           |
| O003     | C003       | 2025-01-08 | 320    | New           |
| O004     | C001       | 2025-01-10 | 150    | Returning     |
| O005     | C004       | 2025-01-10 | 400    | New           |
| O006     | C002       | 2025-01-15 | 200    | Returning     |
| O007     | C005       | 2025-01-15 | 90     | New           |
| O008     | C001       | 2025-01-20 | 500    | Returning     |
| O009     | C006       | 2025-01-20 | 175    | New           |
| O010     | C003       | 2025-01-25 | 280    | Returning     |

### Expected Daily Summary

| order_date | new_customers | returning_customers | new_revenue | returning_revenue | new_pct |
|-----------|--------------|--------------------|-----------|--------------------|---------|
| 2025-01-05 | 2            | 0                  | 430       | 0                  | 100.0   |
| 2025-01-08 | 1            | 0                  | 320       | 0                  | 100.0   |
| 2025-01-10 | 1            | 1                  | 400       | 150                | 72.7    |
| 2025-01-15 | 1            | 1                  | 90        | 200                | 31.0    |
| 2025-01-20 | 1            | 1                  | 175       | 500                | 25.9    |
| 2025-01-25 | 0            | 1                  | 0         | 280                | 0.0     |

---

## PySpark Code Solution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_date, min as spark_min, when, \
    count, sum as spark_sum, round as spark_round, countDistinct
from pyspark.sql.window import Window

# Initialize Spark session
spark = SparkSession.builder.appName("NewVsReturning").getOrCreate()

# Sample data
data = [
    ("O001", "C001", "2025-01-05", 250),
    ("O002", "C002", "2025-01-05", 180),
    ("O003", "C003", "2025-01-08", 320),
    ("O004", "C001", "2025-01-10", 150),
    ("O005", "C004", "2025-01-10", 400),
    ("O006", "C002", "2025-01-15", 200),
    ("O007", "C005", "2025-01-15", 90),
    ("O008", "C001", "2025-01-20", 500),
    ("O009", "C006", "2025-01-20", 175),
    ("O010", "C003", "2025-01-25", 280)
]
columns = ["order_id", "customer_id", "order_date", "amount"]
df = spark.createDataFrame(data, columns)
df = df.withColumn("order_date", to_date("order_date"))

# Step 1: Find each customer's first purchase date (from cumulative_distinct_count)
first_purchase = df.groupBy("customer_id").agg(
    spark_min("order_date").alias("first_purchase_date")
)

# Step 2: Join back and classify
df_classified = df.join(first_purchase, on="customer_id").withColumn(
    "customer_type",
    when(col("order_date") == col("first_purchase_date"), "New")
    .otherwise("Returning")
)

# Display transaction-level classification
df_classified.select("order_id", "customer_id", "order_date", "amount", "customer_type") \
    .orderBy("order_date", "order_id").show(truncate=False)
```

### Step-by-Step Explanation

#### Step 1: First Purchase Date (Same as cumulative_distinct_count Step 1)

| customer_id | first_purchase_date |
|------------|-------------------|
| C001       | 2025-01-05        |
| C002       | 2025-01-05        |
| C003       | 2025-01-08        |
| C004       | 2025-01-10        |
| C005       | 2025-01-15        |
| C006       | 2025-01-20        |

#### Step 2: Classification Logic

```python
when(order_date == first_purchase_date, "New").otherwise("Returning")
```

- C001 on Jan 05: first_purchase = Jan 05 → **New**
- C001 on Jan 10: first_purchase = Jan 05, Jan 10 ≠ Jan 05 → **Returning**
- C004 on Jan 10: first_purchase = Jan 10 → **New**

---

## Daily Summary with Conditional Aggregation

```python
# Daily new vs returning summary (uses conditional_aggregations pattern)
daily_summary = df_classified.groupBy("order_date").agg(
    # Counts (conditional aggregation pattern)
    countDistinct(when(col("customer_type") == "New", col("customer_id"))).alias("new_customers"),
    countDistinct(when(col("customer_type") == "Returning", col("customer_id"))).alias("returning_customers"),

    # Revenue (conditional aggregation pattern)
    spark_sum(when(col("customer_type") == "New", col("amount")).otherwise(0)).alias("new_revenue"),
    spark_sum(when(col("customer_type") == "Returning", col("amount")).otherwise(0)).alias("returning_revenue"),

    # Total
    spark_sum("amount").alias("total_revenue")
).withColumn(
    "new_pct",
    spark_round(col("new_revenue") / col("total_revenue") * 100, 1)
).orderBy("order_date")

daily_summary.show(truncate=False)
```

This is the direct application of `sum(when())` and `countDistinct(when())` from the `conditional_aggregations` pattern.

---

## Method 2: Using Window Functions (Alternative to Join)

```python
# Instead of groupBy + join, use a window function
window_customer = Window.partitionBy("customer_id").orderBy("order_date")

from pyspark.sql.functions import row_number

df_with_rn = df.withColumn(
    "purchase_number", row_number().over(window_customer)
).withColumn(
    "customer_type",
    when(col("purchase_number") == 1, "New").otherwise("Returning")
)

df_with_rn.select("order_id", "customer_id", "order_date", "amount",
                  "purchase_number", "customer_type") \
    .orderBy("order_date", "order_id").show(truncate=False)
```

**Alternative:** `row_number() == 1` marks the first purchase. This avoids the separate `groupBy` + `join` and is often more efficient.

---

## Method 3: Cumulative New Customer Metrics

```python
# Combine with cumulative_distinct_count to track new customer growth
new_per_day = first_purchase.groupBy("first_purchase_date").agg(
    count("*").alias("new_customers_today")
).withColumnRenamed("first_purchase_date", "order_date")

window_cumulative = Window.orderBy("order_date") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

cumulative_customers = new_per_day.withColumn(
    "total_customers_ever",
    spark_sum("new_customers_today").over(window_cumulative)
)

# Join with daily summary for a complete picture
complete_daily = daily_summary.join(cumulative_customers, on="order_date", how="left") \
    .fillna({"new_customers_today": 0})

complete_daily.select(
    "order_date", "new_customers", "returning_customers",
    "new_revenue", "returning_revenue", "total_customers_ever"
).show(truncate=False)
```

---

## Method 4: Monthly Cohort Classification

```python
from pyspark.sql.functions import date_format

# Monthly view — classify customers as new or returning per month
df_monthly = df_classified.withColumn(
    "order_month", date_format("order_date", "yyyy-MM")
)

monthly_summary = df_monthly.groupBy("order_month").agg(
    countDistinct(when(col("customer_type") == "New", col("customer_id"))).alias("new_customers"),
    countDistinct(when(col("customer_type") == "Returning", col("customer_id"))).alias("returning_customers"),
    spark_sum(when(col("customer_type") == "New", col("amount")).otherwise(0)).alias("new_revenue"),
    spark_sum(when(col("customer_type") == "Returning", col("amount")).otherwise(0)).alias("returning_revenue"),
    countDistinct("customer_id").alias("total_active_customers")
).withColumn(
    "new_customer_pct",
    spark_round(col("new_customers") / col("total_active_customers") * 100, 1)
).orderBy("order_month")

monthly_summary.show(truncate=False)
```

---

## Method 5: Using SQL

```python
df.createOrReplaceTempView("orders")

spark.sql("""
    WITH first_purchase AS (
        SELECT customer_id, MIN(order_date) AS first_purchase_date
        FROM orders
        GROUP BY customer_id
    ),
    classified AS (
        SELECT
            o.*,
            fp.first_purchase_date,
            CASE WHEN o.order_date = fp.first_purchase_date
                 THEN 'New' ELSE 'Returning' END AS customer_type
        FROM orders o
        JOIN first_purchase fp ON o.customer_id = fp.customer_id
    )
    SELECT
        order_date,
        COUNT(DISTINCT CASE WHEN customer_type = 'New' THEN customer_id END) AS new_customers,
        COUNT(DISTINCT CASE WHEN customer_type = 'Returning' THEN customer_id END) AS returning_customers,
        SUM(CASE WHEN customer_type = 'New' THEN amount ELSE 0 END) AS new_revenue,
        SUM(CASE WHEN customer_type = 'Returning' THEN amount ELSE 0 END) AS returning_revenue,
        ROUND(
            SUM(CASE WHEN customer_type = 'New' THEN amount ELSE 0 END) * 100.0 /
            SUM(amount), 1
        ) AS new_revenue_pct
    FROM classified
    GROUP BY order_date
    ORDER BY order_date
""").show(truncate=False)
```

---

## Connection to Parent Patterns

| Technique Used | From Pattern | How It's Used Here |
|---------------|-------------|-------------------|
| First-seen date (`min(date)`) | `cumulative_distinct_count` | Find each customer's first purchase |
| `sum(when())` / `count(when())` | `conditional_aggregations` | Split metrics by new vs returning |
| `row_number()` alternative | `top_n_per_group` | Identify first purchase without groupBy |
| Cumulative sum of new users | `cumulative_distinct_count` | Track total customer growth |

---

## Key Interview Talking Points

1. **Same first-seen trick as cumulative_distinct_count:** Find `min(date)` per customer, join back, compare. If `order_date == first_purchase_date`, the customer is "new" on that transaction.

2. **row_number() vs groupBy+join:** Both work. `row_number() == 1` avoids a separate aggregation and join, making it slightly more efficient. But the `groupBy` approach is more readable and interviewers often expect it.

3. **Why this matters in business:** New vs returning customer ratio is a key health metric. A business that depends entirely on new customers has poor retention. A business with mostly returning customers has strong loyalty but may not be growing.

4. **Edge case — multiple purchases on first day:** If C001 has two orders on Jan 05 (their first day), both are classified as "New". This is correct — the customer is new to the business that day. Use `row_number()` if you want only the literal first transaction marked as "New".

5. **Real-world use cases:**
   - E-commerce: new vs repeat buyer dashboards
   - SaaS: new trial users vs returning subscribers
   - Mobile app: new installs vs returning active users
   - Customer acquisition cost (CAC) calculation (only new customers)
   - Marketing attribution: which campaigns bring new customers vs reactivate old ones
