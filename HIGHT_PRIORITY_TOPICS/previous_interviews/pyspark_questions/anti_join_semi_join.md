# PySpark Implementation: Anti-Join & Semi-Join Patterns

## Problem Statement 

Given two datasets — a **customers** table and an **orders** table — answer these common interview questions:
1. **Anti-join:** Find all customers who have **never placed an order**
2. **Semi-join:** Find all customers who have placed **at least one order** (without duplicating customer rows)
3. Combine both to segment customers into "active" vs "dormant"

These are fundamental join patterns that appear in nearly every data engineering interview. They're distinct from inner/left/right joins because they filter one table based on the existence (or non-existence) of matches in another table — without bringing in any columns from the second table.

### Sample Data

**Customers:**
```
customer_id  name       signup_date   region
C001         Alice      2024-06-15    East
C002         Bob        2024-08-20    West
C003         Charlie    2024-09-01    East
C004         Diana      2024-10-10    West
C005         Eve        2024-11-05    East
C006         Frank      2024-12-01    West
```

**Orders:**
```
order_id  customer_id  order_date   amount
O001      C001         2025-01-05   250
O002      C001         2025-01-15   180
O003      C003         2025-01-08   320
O004      C003         2025-02-10   150
O005      C005         2025-01-20   400
```

### Expected Output: Anti-Join (Customers with NO Orders)

| customer_id | name  | signup_date | region |
|------------|-------|------------|--------|
| C002       | Bob   | 2024-08-20 | West   |
| C004       | Diana | 2024-10-10 | West   |
| C006       | Frank | 2024-12-01 | West   |

### Expected Output: Semi-Join (Customers WITH Orders — no duplicates)

| customer_id | name    | signup_date | region |
|------------|---------|------------|--------|
| C001       | Alice   | 2024-06-15 | East   |
| C003       | Charlie | 2024-09-01 | East   |
| C005       | Eve     | 2024-11-05 | East   |

---

## Setup

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_date, count, when, lit, countDistinct

# Initialize Spark session
spark = SparkSession.builder.appName("AntiSemiJoin").getOrCreate()

# Customers
cust_data = [
    ("C001", "Alice", "2024-06-15", "East"),
    ("C002", "Bob", "2024-08-20", "West"),
    ("C003", "Charlie", "2024-09-01", "East"),
    ("C004", "Diana", "2024-10-10", "West"),
    ("C005", "Eve", "2024-11-05", "East"),
    ("C006", "Frank", "2024-12-01", "West")
]
customers = spark.createDataFrame(cust_data, ["customer_id", "name", "signup_date", "region"])
customers = customers.withColumn("signup_date", to_date("signup_date"))

# Orders
order_data = [
    ("O001", "C001", "2025-01-05", 250),
    ("O002", "C001", "2025-01-15", 180),
    ("O003", "C003", "2025-01-08", 320),
    ("O004", "C003", "2025-02-10", 150),
    ("O005", "C005", "2025-01-20", 400)
]
orders = spark.createDataFrame(order_data, ["order_id", "customer_id", "order_date", "amount"])
orders = orders.withColumn("order_date", to_date("order_date"))
```

---

## Anti-Join: Find Customers with NO Orders

### Method 1: left_anti (Recommended)

```python
# left_anti: keep rows from left table that have NO match in right table
never_ordered = customers.join(
    orders,
    on="customer_id",
    how="left_anti"
)

never_ordered.show(truncate=False)
```

**How `left_anti` works:**
- Takes every row from the left table (customers)
- Checks if there's ANY match in the right table (orders)
- **Keeps only rows with NO match**
- Returns only columns from the left table

This is the cleanest and most performant way to do an anti-join in PySpark.

### Method 2: Left Join + Filter for Nulls

```python
# Classic approach: left join, then filter where right side is null
never_ordered_v2 = customers.join(
    orders,
    on="customer_id",
    how="left"
).filter(
    col("order_id").isNull()  # No matching order
).select(customers.columns)   # Keep only customer columns

never_ordered_v2.show(truncate=False)
```

**Why `left_anti` is better:**
- `left_anti` doesn't need to carry the right-side columns through the join
- No need for a post-join filter
- Spark optimizer can short-circuit once it finds any match (doesn't need all matches)

### Method 3: Using NOT EXISTS in SQL

```python
customers.createOrReplaceTempView("customers")
orders.createOrReplaceTempView("orders")

spark.sql("""
    SELECT c.*
    FROM customers c
    WHERE NOT EXISTS (
        SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id
    )
""").show(truncate=False)
```

### Method 4: Using EXCEPT (for single-column check)

```python
from pyspark.sql.functions import col

# Get customer_ids that have orders
ordered_ids = orders.select("customer_id").distinct()

# Get customer_ids that DON'T have orders
never_ordered_ids = customers.select("customer_id").exceptAll(ordered_ids)

# Join back to get full customer details
never_ordered_v4 = customers.join(never_ordered_ids, on="customer_id")
never_ordered_v4.show(truncate=False)
```

---

## Semi-Join: Find Customers WITH Orders (No Duplicates)

### Method 1: left_semi (Recommended)

```python
# left_semi: keep rows from left table that HAVE a match in right table
# Returns only left-side columns, no duplicates even if multiple matches
has_ordered = customers.join(
    orders,
    on="customer_id",
    how="left_semi"
)

has_ordered.show(truncate=False)
```

**How `left_semi` works:**
- Takes every row from the left table (customers)
- Checks if there's ANY match in the right table (orders)
- **Keeps only rows WITH at least one match**
- Returns only columns from the left table
- **No duplicates** — even though C001 has 2 orders, they appear once

### Method 2: Inner Join + Distinct (Avoid This)

```python
# Common mistake: inner join creates duplicates
# C001 appears TWICE because they have 2 orders
duplicated = customers.join(orders, on="customer_id", how="inner")
print(f"Inner join rows: {duplicated.count()}")  # 5 (not 3!)

# Must deduplicate — wasteful
has_ordered_v2 = duplicated.select(customers.columns).distinct()
has_ordered_v2.show(truncate=False)
```

**Why `left_semi` is better:**
- No duplicates to deal with
- Doesn't carry right-side columns (less data shuffled)
- Spark can stop checking after first match per left row

### Method 3: Using EXISTS in SQL

```python
spark.sql("""
    SELECT c.*
    FROM customers c
    WHERE EXISTS (
        SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id
    )
""").show(truncate=False)
```

---

## Combining Anti + Semi: Customer Segmentation

```python
# Tag every customer as "Active" (has orders) or "Dormant" (no orders)
# Using a left join approach
segmented = customers.join(
    orders.select("customer_id").distinct().withColumn("has_orders", lit(True)),
    on="customer_id",
    how="left"
).withColumn(
    "segment",
    when(col("has_orders") == True, "Active").otherwise("Dormant")
).drop("has_orders")

segmented.show(truncate=False)

# Summary by region
segmented.groupBy("region", "segment").agg(
    count("*").alias("customer_count")
).orderBy("region", "segment").show(truncate=False)
```

- **Output:**

  | region | segment | customer_count |
  |--------|---------|---------------|
  | East   | Active  | 3             |
  | West   | Dormant | 3             |

---

## Practical Application: Find Products Never Sold

```python
# Products table
products_data = [
    ("P001", "Laptop", "Electronics"),
    ("P002", "Phone", "Electronics"),
    ("P003", "Keyboard", "Accessories"),
    ("P004", "Mouse", "Accessories"),
    ("P005", "Monitor", "Electronics")
]
products = spark.createDataFrame(products_data, ["product_id", "name", "category"])

# Sales table
sales_data = [
    ("S001", "P001", "2025-01-05"), ("S002", "P001", "2025-01-10"),
    ("S003", "P002", "2025-01-08"), ("S004", "P003", "2025-01-15")
]
sales = spark.createDataFrame(sales_data, ["sale_id", "product_id", "sale_date"])

# Find products that have never been sold
never_sold = products.join(sales, on="product_id", how="left_anti")
never_sold.show(truncate=False)
```

- **Output:** P004 (Mouse), P005 (Monitor) — never appeared in sales.

---

## Practical Application: Find Missing Records Between Two Extracts

```python
# Yesterday's extract
yesterday = spark.createDataFrame([
    (1, "A"), (2, "B"), (3, "C"), (4, "D")
], ["id", "value"])

# Today's extract
today = spark.createDataFrame([
    (1, "A"), (2, "B_updated"), (4, "D"), (5, "E")
], ["id", "value"])

# Records in yesterday but NOT in today (deletions)
deleted = yesterday.join(today, on="id", how="left_anti")
print("Deleted records:")
deleted.show()

# Records in today but NOT in yesterday (additions)
added = today.join(yesterday, on="id", how="left_anti")
print("New records:")
added.show()

# Records in both (potential updates) — use semi join
common = today.join(yesterday, on="id", how="left_semi")
print("Common records (may have updates):")
common.show()
```

---

## Method Comparison

| Goal | Best Method | Alternative | Avoid |
|------|------------|-------------|-------|
| Rows in A with NO match in B | `left_anti` | Left join + filter null | Subquery with NOT IN |
| Rows in A WITH match in B | `left_semi` | EXISTS subquery | Inner join + distinct |
| Rows in A but not in B (by value) | `exceptAll` | `left_anti` on all columns | Manual comparison |

### Performance Ranking

1. **`left_anti` / `left_semi`** — Best. Spark optimizes internally, stops checking after first match/non-match.
2. **SQL `EXISTS` / `NOT EXISTS`** — Same execution plan as anti/semi joins.
3. **Left join + null filter** — Worse. Carries all right-side columns, then discards.
4. **`NOT IN` subquery** — Worst. Doesn't handle nulls correctly and can be very slow.

---

## The NOT IN Null Trap

```python
# DANGER: NOT IN with nulls gives unexpected results
spark.sql("""
    SELECT * FROM customers
    WHERE customer_id NOT IN (SELECT customer_id FROM orders)
""").show()
# Works fine here because orders.customer_id has no nulls

# But if orders had a NULL customer_id:
orders_with_null = orders.union(
    spark.createDataFrame([("O999", None, "2025-01-01", 0)],
                          ["order_id", "customer_id", "order_date", "amount"])
)
orders_with_null.createOrReplaceTempView("orders_with_null")

spark.sql("""
    SELECT * FROM customers
    WHERE customer_id NOT IN (SELECT customer_id FROM orders_with_null)
""").show()
# Returns ZERO rows! NOT IN with NULL = all false

# left_anti handles this correctly:
customers.join(orders_with_null, on="customer_id", how="left_anti").show()
# Returns the correct 3 customers
```

**Key lesson:** Always use `left_anti` instead of `NOT IN` — it's both faster and null-safe.

---

## Key Interview Talking Points

1. **`left_anti` = NOT EXISTS, `left_semi` = EXISTS:** These are the PySpark equivalents of SQL's `WHERE [NOT] EXISTS`. They're purpose-built for filtering based on existence without bringing in extra columns.

2. **No duplicates with semi-join:** Unlike inner join, `left_semi` never produces more rows than the left table. C001 with 5 orders still appears once. This is the #1 reason to use it.

3. **The NOT IN null trap:** `WHERE x NOT IN (subquery)` returns zero rows if the subquery contains ANY null. This is a classic SQL gotcha. `left_anti` handles nulls correctly.

4. **Performance:** Anti/semi joins are optimized in Spark's Catalyst optimizer. They can use broadcast hash, sort merge, or even skip the full join if statistics allow early termination.

5. **Common interview questions using anti-join:**
   - "Find customers who never purchased"
   - "Find products with no reviews"
   - "Find employees not assigned to any project"
   - "Find records in source A missing from source B"
   - "Identify orphan records (child with no parent)"
