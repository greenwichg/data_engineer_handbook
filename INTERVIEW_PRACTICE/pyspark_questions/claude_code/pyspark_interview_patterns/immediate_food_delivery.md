# PySpark Implementation: Immediate Food Delivery (First-Event Conditional Rate)

## Problem Statement

Given a `Delivery` table with `delivery_id`, `customer_id`, `order_date`, and `customer_pref_delivery_date`, find the **percentage of first orders that are "immediate"** (where `order_date == customer_pref_delivery_date`). Each customer's first order is the one with the earliest `order_date`. This is **LeetCode 1174 — Immediate Food Delivery II**.

### Sample Data

```
delivery_id  customer_id  order_date   customer_pref_delivery_date
1            1            2025-01-01   2025-01-02
2            2            2025-01-02   2025-01-02
3            1            2025-01-02   2025-01-02
4            3            2025-01-03   2025-01-05
5            3            2025-01-04   2025-01-04
6            4            2025-01-05   2025-01-05
```

### Expected Output

| immediate_percentage |
|---------------------|
| 50.00               |

**Explanation:** First orders: Customer 1 (delivery 1, scheduled — not immediate), Customer 2 (delivery 2, immediate), Customer 3 (delivery 4, scheduled), Customer 4 (delivery 6, immediate). 2 out of 4 = 50%.

---

## Method 1: Window Function to Find First Order (DataFrame API)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, when, row_number, round as spark_round, avg
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("ImmediateDelivery").getOrCreate()

data = [
    (1, 1, "2025-01-01", "2025-01-02"),
    (2, 2, "2025-01-02", "2025-01-02"),
    (3, 1, "2025-01-02", "2025-01-02"),
    (4, 3, "2025-01-03", "2025-01-05"),
    (5, 3, "2025-01-04", "2025-01-04"),
    (6, 4, "2025-01-05", "2025-01-05")
]

columns = ["delivery_id", "customer_id", "order_date", "customer_pref_delivery_date"]
df = spark.createDataFrame(data, columns)

# Find each customer's first order
w = Window.partitionBy("customer_id").orderBy("order_date")
first_orders = df.withColumn("rn", row_number().over(w)).filter(col("rn") == 1)

# Calculate immediate percentage
result = first_orders.select(
    spark_round(
        avg(when(col("order_date") == col("customer_pref_delivery_date"), 1).otherwise(0)) * 100,
        2
    ).alias("immediate_percentage")
)

result.show()
```

### Step-by-Step Explanation

#### Step 1: Assign row_number per customer ordered by order_date
- **What happens:** Each customer's orders are numbered chronologically. `rn = 1` is the first order.

  | delivery_id | customer_id | order_date | pref_date  | rn |
  |-------------|------------|------------|------------|-----|
  | 1           | 1          | 2025-01-01 | 2025-01-02 | 1   |
  | 3           | 1          | 2025-01-02 | 2025-01-02 | 2   |
  | 2           | 2          | 2025-01-02 | 2025-01-02 | 1   |
  | 4           | 3          | 2025-01-03 | 2025-01-05 | 1   |
  | 5           | 3          | 2025-01-04 | 2025-01-04 | 2   |
  | 6           | 4          | 2025-01-05 | 2025-01-05 | 1   |

#### Step 2: Filter to first orders only (rn == 1)

  | delivery_id | customer_id | order_date | pref_date  |
  |-------------|------------|------------|------------|
  | 1           | 1          | 2025-01-01 | 2025-01-02 |
  | 2           | 2          | 2025-01-02 | 2025-01-02 |
  | 4           | 3          | 2025-01-03 | 2025-01-05 |
  | 6           | 4          | 2025-01-05 | 2025-01-05 |

#### Step 3: Calculate percentage of immediate first orders
- Immediate = order_date matches pref_delivery_date.
- Customers 2 and 4 are immediate → 2/4 = 50%.

---

## Method 2: Using groupBy + min to Find First Order

```python
from pyspark.sql.functions import col, min as spark_min, when, avg, round as spark_round

# Get first order date per customer
first_order_dates = df.groupBy("customer_id") \
    .agg(spark_min("order_date").alias("first_order_date"))

# Join back to get the first order details
first_orders = df.join(
    first_order_dates,
    (df["customer_id"] == first_order_dates["customer_id"]) &
    (df["order_date"] == first_order_dates["first_order_date"])
).select(df["*"])

# Calculate percentage
result = first_orders.select(
    spark_round(
        avg(when(col("order_date") == col("customer_pref_delivery_date"), 1).otherwise(0)) * 100,
        2
    ).alias("immediate_percentage")
)

result.show()
```

---

## Method 3: Spark SQL

```python
df.createOrReplaceTempView("delivery")

result = spark.sql("""
    SELECT ROUND(
        AVG(CASE WHEN order_date = customer_pref_delivery_date THEN 1 ELSE 0 END) * 100,
        2
    ) AS immediate_percentage
    FROM (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS rn
        FROM delivery
    ) t
    WHERE rn = 1
""")

result.show()
```

---

## Edge Cases to Discuss

| Edge Case | What Happens | How to Handle |
|-----------|-------------|---------------|
| Customer with single order | That order is their first order | Works correctly |
| Tie in order_date for same customer | row_number picks one arbitrarily | Add delivery_id as tiebreaker |
| All first orders are immediate | Returns 100.00 | Correct |
| No first orders are immediate | Returns 0.00 | Correct |
| NULL delivery dates | Comparison with NULL is false | Filter NULLs first |

## Key Interview Talking Points

1. **AVG trick for percentage:**
   - `AVG(CASE WHEN condition THEN 1 ELSE 0 END) * 100` is the standard SQL idiom for computing percentage of rows matching a condition. Equivalent to `COUNT(IF) / COUNT(*)`.

2. **row_number vs. min(order_date):**
   - `row_number` approach gives the entire first-order row directly.
   - `min()` approach needs a join back, and may return duplicates if two orders share the same earliest date.

3. **Pattern generalization:**
   - This "analyze first event per entity" pattern applies to: first login behavior, first purchase analysis, onboarding metrics, etc.

4. **Follow-up: "What if you need first AND second order comparison?"**
   - Use `row_number()` and pivot on rn values, or use `lead()` to compare consecutive orders.
