# PySpark Implementation: Conditional Aggregations 

## Problem Statement

Given a dataset of e-commerce orders, compute **conditional aggregations** — aggregations that apply only to rows meeting certain conditions. For example: total revenue only from completed orders, count of cancelled orders per customer, average order value by category only for premium customers. This is a very common interview pattern that tests your ability to combine `when()` with aggregation functions.

### Sample Data

```
order_id  customer_id  category     amount  status      order_date
O001      C001         Electronics  1200    Completed   2025-01-05
O002      C001         Clothing     300     Completed   2025-01-10
O003      C002         Electronics  800     Cancelled   2025-01-08
O004      C002         Electronics  950     Completed   2025-01-15
O005      C003         Clothing     200     Returned    2025-01-12
O006      C001         Electronics  1500    Completed   2025-01-20
O007      C003         Electronics  1100    Completed   2025-01-22
O008      C002         Clothing     400     Cancelled   2025-01-25
O009      C003         Clothing     350     Completed   2025-01-28
O010      C001         Clothing     250     Returned    2025-01-30
```

### Expected Output: Revenue Summary

| category    | total_revenue | completed_revenue | cancelled_revenue | returned_revenue | completion_rate |
|-------------|---------------|-------------------|-------------------|------------------|-----------------|
| Electronics | 5550          | 4750              | 800               | 0                | 75.0            |
| Clothing    | 1500          | 900               | 400               | 200              | 50.0            |

---

## Method 1: sum(when(...)) Pattern

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum as spark_sum, count, avg, when, round as spark_round, lit

# Initialize Spark session
spark = SparkSession.builder.appName("ConditionalAggregations").getOrCreate()

# Sample data
data = [
    ("O001", "C001", "Electronics", 1200, "Completed", "2025-01-05"),
    ("O002", "C001", "Clothing", 300, "Completed", "2025-01-10"),
    ("O003", "C002", "Electronics", 800, "Cancelled", "2025-01-08"),
    ("O004", "C002", "Electronics", 950, "Completed", "2025-01-15"),
    ("O005", "C003", "Clothing", 200, "Returned", "2025-01-12"),
    ("O006", "C001", "Electronics", 1500, "Completed", "2025-01-20"),
    ("O007", "C003", "Electronics", 1100, "Completed", "2025-01-22"),
    ("O008", "C002", "Clothing", 400, "Cancelled", "2025-01-25"),
    ("O009", "C003", "Clothing", 350, "Completed", "2025-01-28"),
    ("O010", "C001", "Clothing", 250, "Returned", "2025-01-30")
]
columns = ["order_id", "customer_id", "category", "amount", "status", "order_date"]
df = spark.createDataFrame(data, columns)

# Conditional aggregation by category
category_summary = df.groupBy("category").agg(
    # Total revenue (all statuses)
    spark_sum("amount").alias("total_revenue"),

    # Revenue only from completed orders
    spark_sum(when(col("status") == "Completed", col("amount")).otherwise(0)).alias("completed_revenue"),

    # Revenue from cancelled orders
    spark_sum(when(col("status") == "Cancelled", col("amount")).otherwise(0)).alias("cancelled_revenue"),

    # Revenue from returned orders
    spark_sum(when(col("status") == "Returned", col("amount")).otherwise(0)).alias("returned_revenue"),

    # Count of orders by status
    count(when(col("status") == "Completed", True)).alias("completed_count"),
    count(when(col("status") == "Cancelled", True)).alias("cancelled_count"),
    count(when(col("status") == "Returned", True)).alias("returned_count"),

    # Total orders
    count("*").alias("total_orders")
)

# Add completion rate
category_summary = category_summary.withColumn(
    "completion_rate",
    spark_round(col("completed_count") / col("total_orders") * 100, 1)
)

category_summary.show(truncate=False)
```

### Step-by-Step Explanation

#### The Core Pattern: sum(when(condition, value).otherwise(0))

```python
# This pattern applies the aggregation only to rows matching the condition

spark_sum(when(col("status") == "Completed", col("amount")).otherwise(0))

# Equivalent SQL:
# SUM(CASE WHEN status = 'Completed' THEN amount ELSE 0 END)
```

#### How It Works Row by Row

| order_id | status    | amount | completed? | value used |
|----------|-----------|--------|------------|------------|
| O001     | Completed | 1200   | Yes        | 1200       |
| O003     | Cancelled | 800    | No         | 0          |
| O005     | Returned  | 200    | No         | 0          |

- **Output:**

  | category    | total_revenue | completed_revenue | cancelled_revenue | returned_revenue | completed_count | cancelled_count | returned_count | total_orders | completion_rate |
  |-------------|---------------|-------------------|-------------------|------------------|-----------------|-----------------|----------------|-------------|-----------------|
  | Electronics | 5550          | 4750              | 800               | 0                | 4               | 1               | 0              | 5           | 80.0            |
  | Clothing    | 1500          | 900               | 400               | 200              | 2               | 1               | 1              | 4           | 50.0            |

---

## Method 2: count(when(...)) vs sum(when(..., 1))

```python
# Both count rows matching a condition — functionally equivalent

# Approach A: count(when(condition, True))
# count ignores nulls, so when condition is false, when returns null → not counted
count_a = df.agg(count(when(col("status") == "Completed", True)).alias("method_a"))

# Approach B: sum(when(condition, 1).otherwise(0))
# Explicitly sums 1 for matches, 0 for non-matches
count_b = df.agg(spark_sum(when(col("status") == "Completed", 1).otherwise(0)).alias("method_b"))

count_a.show()  # 6
count_b.show()  # 6 (same result)
```

**Note:** `count(when(..., True))` is slightly cleaner for counting. Use `sum(when(..., value))` when aggregating non-count values.

---

## Method 3: Multiple Conditions

```python
# Per-customer summary with complex conditions
customer_summary = df.groupBy("customer_id").agg(
    # Total spend on completed Electronics orders
    spark_sum(
        when((col("status") == "Completed") & (col("category") == "Electronics"), col("amount"))
        .otherwise(0)
    ).alias("completed_electronics_spend"),

    # Average order value for non-cancelled orders
    avg(
        when(col("status") != "Cancelled", col("amount"))
    ).alias("avg_non_cancelled_amount"),

    # Flag: has any cancelled order?
    count(when(col("status") == "Cancelled", True)).alias("cancellation_count"),

    # Max single order amount for completed
    spark_sum(when(col("status") == "Completed", col("amount"))).alias("total_completed")
)

customer_summary.show(truncate=False)
```

- **Output:**

  | customer_id | completed_electronics_spend | avg_non_cancelled_amount | cancellation_count | total_completed |
  |-------------|----------------------------|--------------------------|--------------------|-----------------|
  | C001        | 2700                       | 812.5                    | 0                  | 3000            |
  | C002        | 950                        | 950.0                    | 2                  | 950             |
  | C003        | 1100                       | 550.0                    | 0                  | 1450            |

---

## Method 4: Conditional Aggregation with Window Functions

```python
from pyspark.sql.window import Window

# Running total of completed orders per customer
window_cust = Window.partitionBy("customer_id").orderBy("order_date") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

df_running = df.withColumn(
    "running_completed_revenue",
    spark_sum(
        when(col("status") == "Completed", col("amount")).otherwise(0)
    ).over(window_cust)
).withColumn(
    "running_order_count",
    count(when(col("status") == "Completed", True)).over(window_cust)
)

df_running.select("order_id", "customer_id", "amount", "status",
                  "running_completed_revenue", "running_order_count") \
    .orderBy("customer_id", "order_date").show(truncate=False)
```

---

## Method 5: Using SQL — CASE WHEN

```python
df.createOrReplaceTempView("orders")

sql_result = spark.sql("""
    SELECT
        category,
        SUM(amount) AS total_revenue,
        SUM(CASE WHEN status = 'Completed' THEN amount ELSE 0 END) AS completed_revenue,
        SUM(CASE WHEN status = 'Cancelled' THEN amount ELSE 0 END) AS cancelled_revenue,
        COUNT(CASE WHEN status = 'Completed' THEN 1 END) AS completed_count,
        COUNT(*) AS total_orders,
        ROUND(COUNT(CASE WHEN status = 'Completed' THEN 1 END) * 100.0 / COUNT(*), 1) AS completion_rate
    FROM orders
    GROUP BY category
    ORDER BY category
""")

sql_result.show(truncate=False)
```

---

## Method 6: Pivot as Alternative to Conditional Aggregation

```python
# Instead of multiple CASE WHEN, use pivot for cleaner code
pivoted = df.groupBy("category") \
    .pivot("status", ["Completed", "Cancelled", "Returned"]) \
    .agg(spark_sum("amount"))

pivoted.show(truncate=False)
```

- **Output:**

  | category    | Completed | Cancelled | Returned |
  |-------------|-----------|-----------|----------|
  | Electronics | 4750      | 800       | null     |
  | Clothing    | 900       | 400       | 200      |

- **Note:** Pivot is cleaner when you want to split one metric by categories. Use `sum(when(...))` when you need different aggregation types or complex conditions.

---

## Common Patterns Summary

| Pattern | PySpark | SQL Equivalent |
|---------|---------|----------------|
| Conditional sum | `sum(when(cond, col))` | `SUM(CASE WHEN ... THEN col END)` |
| Conditional count | `count(when(cond, True))` | `COUNT(CASE WHEN ... THEN 1 END)` |
| Conditional avg | `avg(when(cond, col))` | `AVG(CASE WHEN ... THEN col END)` |
| Conditional max | `max(when(cond, col))` | `MAX(CASE WHEN ... THEN col END)` |
| Ratio/percentage | `count(when(A)) / count(*)` | `COUNT(CASE A) / COUNT(*)` |

## Key Interview Talking Points

1. **when() returns null by default:** If you don't specify `.otherwise()`, unmatched rows return null. `sum()` and `avg()` ignore nulls, but `count()` also ignores them — which is why `count(when(cond, True))` works for conditional counting.

2. **otherwise(0) vs no otherwise:** For `sum()`, both work: null is ignored, 0 adds nothing. But for `avg()`, null is ignored (correct) while 0 would be included (incorrect). Omit `.otherwise()` for `avg()`.

3. **Pivot vs conditional agg:** Use pivot when splitting one metric across a categorical column. Use conditional agg when you need different metrics or complex multi-condition logic.

4. **Performance:** Conditional aggregations are computed in a single pass — no need for multiple filter-then-aggregate steps. This is significantly more efficient than running separate queries for each condition.

5. **Real-world applications:**
   - Revenue dashboards with status breakdowns
   - Customer segmentation metrics
   - A/B test result analysis
   - SLA compliance reporting
