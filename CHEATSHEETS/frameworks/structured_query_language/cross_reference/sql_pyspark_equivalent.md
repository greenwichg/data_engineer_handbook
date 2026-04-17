# SQL & PySpark Equivalent - Complete Reference

> A side-by-side mapping of SQL and PySpark for every common interview pattern.
> Sourced from `sql_cheatsheet.md` and `pyspark_cheatsheet.md`.

---

## TABLE OF CONTENTS

```
01. Basic Operations
02. Filtering & Conditions
03. Aggregations
04. Ranking & Top-N
05. Running/Cumulative Calculations
06. Time-Series & Gap Analysis
07. Joins
08. Deduplication
09. Pivot & Unpivot
10. Comparison Problems (vs Average/Previous)
11. Hierarchical/Recursive Queries
12. Self-Referencing Problems
13. Pattern Matching & Sequences
14. Graph/Network Problems
15. Data Quality & Validation
16. Column Transformations
17. String Operations
18. Date Operations
19. Performance Optimization
20. Advanced PySpark Patterns (UDFs, Caching, Broadcast)
21. Quick Translation Guide
22. Syntax Quick Reference
23. Interview Pattern Recognition
24. Common Gotchas
25. Merge & Upsert
26. Type 2 Slowly Changing Dimensions (SCD2)
```

---

## 1. Basic Operations

### SELECT

```sql
-- SQL
SELECT col1, col2 FROM table_name;
SELECT * FROM table_name;
SELECT DISTINCT col1 FROM table_name;
```

```python
# PySpark
df.select("col1", "col2")
df.select("*")
df.select("col1").distinct()
```

### ORDER BY

```sql
-- SQL
SELECT * FROM table_name ORDER BY col1 DESC;
SELECT * FROM table_name ORDER BY col1 DESC, col2 ASC;
```

```python
# PySpark
df.orderBy(F.col("col1").desc())
df.orderBy(F.col("col1").desc(), F.col("col2").asc())
```

### LIMIT

```sql
-- SQL
SELECT * FROM table_name LIMIT 10;
```

```python
# PySpark
df.limit(10)
```

### UNION / UNION ALL

```sql
-- SQL
SELECT col1 FROM table_a UNION ALL SELECT col1 FROM table_b;
SELECT col1 FROM table_a UNION SELECT col1 FROM table_b;
```

```python
# PySpark
df_a.union(df_b)              # equivalent to UNION ALL
df_a.union(df_b).distinct()   # equivalent to UNION
```

### EXCEPT (Set Difference)

```sql
-- SQL
SELECT id FROM table_a
EXCEPT
SELECT id FROM table_b;
```

```python
# PySpark
df_a.select("id").exceptAll(df_b.select("id"))   # keeps duplicates
df_a.select("id").subtract(df_b.select("id"))     # removes duplicates
```

### Column Aliases & Derived Columns

```sql
-- SQL
SELECT col1 * 2 AS doubled FROM table_name;
```

```python
# PySpark
df.withColumn("doubled", F.col("col1") * 2)
df.select((F.col("col1") * 2).alias("doubled"))
```

---

## 2. Filtering & Conditions

### WHERE / filter

```sql
-- SQL
SELECT * FROM employees WHERE age > 18;
SELECT * FROM employees WHERE age > 18 AND country = 'US';
SELECT * FROM employees WHERE status IN ('active', 'pending');
SELECT * FROM employees WHERE status NOT IN ('cancelled', 'rejected');
SELECT * FROM employees WHERE email IS NOT NULL;
SELECT * FROM employees WHERE name LIKE '%smith%';
SELECT * FROM employees WHERE salary BETWEEN 50000 AND 100000;
```

```python
# PySpark
df.filter(F.col("age") > 18)
df.filter((F.col("age") > 18) & (F.col("country") == "US"))
df.filter(F.col("status").isin(["active", "pending"]))
df.filter(~F.col("status").isin(["cancelled", "rejected"]))
df.filter(F.col("email").isNotNull())
df.filter(F.col("name").like("%smith%"))
df.filter(F.col("salary").between(50000, 100000))
```

### CASE WHEN / when-otherwise

```sql
-- SQL
SELECT
    CASE
        WHEN value > 100 THEN 'High'
        WHEN value > 50  THEN 'Medium'
        ELSE 'Low'
    END AS category
FROM table_name;
```

```python
# PySpark
df.withColumn(
    "category",
    F.when(F.col("value") > 100, "High")
    .when(F.col("value") > 50, "Medium")
    .otherwise("Low")
)
```

### Complex Filtering (NOT EXISTS / Anti-Join)

```sql
-- SQL: Customers who never purchased
SELECT c.*
FROM customers c
WHERE NOT EXISTS (
    SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id
);

-- SQL Alternative: LEFT JOIN + NULL
SELECT c.*
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE o.customer_id IS NULL;
```

```python
# PySpark: left_anti join (equivalent to NOT EXISTS)
customers.join(orders, "customer_id", "left_anti")
```

### Date Range Filtering

```sql
-- SQL
SELECT * FROM orders
WHERE order_date >= '2024-01-01' AND order_date < '2024-02-01';

SELECT * FROM orders
WHERE order_date BETWEEN '2024-01-01' AND '2024-01-31';
```

```python
# PySpark
df.filter(
    (F.col("order_date") >= F.lit("2024-01-01")) &
    (F.col("order_date") < F.lit("2024-02-01"))
)

df.filter(F.col("order_date").between("2024-01-01", "2024-01-31"))
```

### Array / Collection Filtering (PySpark-Specific)

```python
# PySpark: Array contains
df.filter(F.array_contains(F.col("tags"), "urgent"))

# PySpark: Array overlap
from pyspark.sql.functions import array_intersect

df.filter(
    F.size(F.array_intersect(
        F.col("user_interests"),
        F.array(F.lit("tech"), F.lit("science"))
    )) > 0
)
```

### Case-Insensitive Filtering

```sql
-- SQL
SELECT * FROM users WHERE LOWER(status) = 'active';
SELECT * FROM users WHERE name ILIKE '%smith%';  -- PostgreSQL
```

```python
# PySpark
df.filter(F.lower(F.col("status")) == "active")
df.filter(F.lower(F.col("name")).contains("smith"))
```

### Products Not Ordered in Last 30 Days

```sql
-- SQL
SELECT p.*
FROM products p
LEFT JOIN orders o ON p.product_id = o.product_id
                   AND o.order_date >= CURRENT_DATE - INTERVAL '30 days'
WHERE o.product_id IS NULL;
```

```python
# PySpark
recent_orders = orders.filter(
    F.col("order_date") >= F.date_sub(F.current_date(), 30)
)
products.join(recent_orders, "product_id", "left_anti")
```

### Students Who Took Class A but Not Class B

```sql
-- SQL
SELECT student_id
FROM enrollments WHERE class_id = 'A'
AND student_id NOT IN (
    SELECT student_id FROM enrollments WHERE class_id = 'B'
);
```

```python
# PySpark
class_a = df.filter(F.col("class_id") == "A").select("student_id")
class_b = df.filter(F.col("class_id") == "B").select("student_id")
class_a.join(class_b, "student_id", "left_anti")
```

---

## 3. Aggregations

### Basic Aggregations

```sql
-- SQL
SELECT
    department,
    COUNT(*) AS count,
    SUM(salary) AS total,
    AVG(salary) AS avg_salary,
    MIN(salary) AS min_salary,
    MAX(salary) AS max_salary
FROM employees
GROUP BY department;
```

```python
# PySpark
df.groupBy("department").agg(
    F.count("*").alias("count"),
    F.sum("salary").alias("total"),
    F.avg("salary").alias("avg_salary"),
    F.min("salary").alias("min_salary"),
    F.max("salary").alias("max_salary")
)
```

### HAVING / filter after aggregation

```sql
-- SQL
SELECT product_id, SUM(quantity) AS total_quantity
FROM orders
GROUP BY product_id
HAVING SUM(quantity) > 1000;
```

```python
# PySpark
df.groupBy("product_id") \
  .agg(F.sum("quantity").alias("total_quantity")) \
  .filter(F.col("total_quantity") > 1000)
```

### Conditional Aggregation

```sql
-- SQL
SELECT
    department,
    COUNT(*) AS total_employees,
    SUM(CASE WHEN salary > 100000 THEN 1 ELSE 0 END) AS high_earners,
    SUM(CASE WHEN tenure > 5 THEN 1 ELSE 0 END) AS veterans,
    AVG(CASE WHEN performance = 'Excellent' THEN salary END) AS avg_salary_top
FROM employees
GROUP BY department;
```

```python
# PySpark
df.groupBy("department").agg(
    F.count("*").alias("total_employees"),
    F.sum(F.when(F.col("salary") > 100000, 1).otherwise(0)).alias("high_earners"),
    F.sum(F.when(F.col("tenure") > 5, 1).otherwise(0)).alias("veterans"),
    F.avg(F.when(F.col("performance") == "Excellent",
                 F.col("salary"))).alias("avg_salary_top")
)
```

### COUNT DISTINCT

```sql
-- SQL
SELECT department, COUNT(DISTINCT customer_id) AS unique_customers
FROM orders GROUP BY department;
```

```python
# PySpark
df.groupBy("department").agg(
    F.countDistinct("customer_id").alias("unique_customers")
)
```

### Collect List / String Aggregation

```sql
-- SQL (PostgreSQL)
SELECT customer_id, STRING_AGG(product, ', ') AS products
FROM purchases GROUP BY customer_id;
```

```python
# PySpark
df.groupBy("customer_id").agg(
    F.collect_list("product").alias("all_products"),
    F.collect_set("product").alias("unique_products")
)
```

### First / Last Value in Group

```sql
-- SQL
SELECT
    customer_id,
    FIRST_VALUE(product) OVER (PARTITION BY customer_id ORDER BY purchase_date) AS first_purchase,
    LAST_VALUE(product) OVER (PARTITION BY customer_id ORDER BY purchase_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_purchase
FROM purchases;
```

```python
# PySpark
window_spec = Window.partitionBy("customer_id").orderBy("purchase_date")

df.withColumn(
    "first_purchase", F.first("product").over(window_spec)
).withColumn(
    "last_purchase", F.last("product").over(window_spec)
)
```

### Statistical Aggregations

```sql
-- SQL
SELECT
    department,
    COUNT(*) AS count,
    AVG(salary) AS mean,
    STDDEV(salary) AS stddev,
    VARIANCE(salary) AS variance,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY salary) AS q1,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY salary) AS median,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY salary) AS q3,
    MODE() WITHIN GROUP (ORDER BY salary) AS mode
FROM employees
GROUP BY department;
```

```python
# PySpark
df.groupBy("department").agg(
    F.count("*").alias("count"),
    F.mean("salary").alias("mean"),
    F.stddev("salary").alias("stddev"),
    F.variance("salary").alias("variance"),
    F.expr("percentile_approx(salary, 0.25)").alias("q1"),
    F.expr("percentile_approx(salary, 0.5)").alias("median"),
    F.expr("percentile_approx(salary, 0.75)").alias("q3"),
    F.skewness("salary").alias("skewness"),
    F.kurtosis("salary").alias("kurtosis")
)

# Approximate aggregations (faster for large datasets)
df.groupBy("user_id").agg(
    F.approx_count_distinct("product_id", rsd=0.05).alias("approx_unique_products"),
    F.expr("percentile_approx(price, 0.5, 100)").alias("median_price")  # 100 = accuracy
)
```

---

## 4. Ranking & Top-N

### Function Choice Matrix

| Need                       | SQL               | PySpark              | Result Example  |
|----------------------------|-------------------|----------------------|-----------------|
| Unique ranks, skip on ties | `ROW_NUMBER()`    | `F.row_number()`     | 1,2,3,4,5       |
| Unique ranks, no gaps      | `DENSE_RANK()`    | `F.dense_rank()`     | 1,2,2,3,4       |
| Allow ties, skip numbers   | `RANK()`          | `F.rank()`           | 1,2,2,4,5       |
| Percentile ranking         | `PERCENT_RANK()`  | `F.percent_rank()`   | 0.0 to 1.0      |
| Divide into N buckets      | `NTILE(N)`        | `F.ntile(N)`         | Quartiles        |

### Top N Per Group

```sql
-- SQL
WITH ranked AS (
    SELECT *,
        DENSE_RANK() OVER (PARTITION BY dept ORDER BY salary DESC) AS rank
    FROM employees
)
SELECT * FROM ranked WHERE rank <= 3;
```

```python
# PySpark
window_spec = Window.partitionBy("dept").orderBy(F.col("salary").desc())

df_top = (df
    .withColumn("rank", F.dense_rank().over(window_spec))
    .filter(F.col("rank") <= 3)
)
```

### Nth Highest Value

```sql
-- SQL: 2nd highest salary
SELECT DISTINCT salary
FROM (
    SELECT salary, DENSE_RANK() OVER (ORDER BY salary DESC) AS rank
    FROM employees
) ranked
WHERE rank = 2;
```

```python
# PySpark
window_spec = Window.orderBy(F.col("salary").desc())

second_highest = (df
    .select("salary").distinct()
    .withColumn("rank", F.dense_rank().over(window_spec))
    .filter(F.col("rank") == 2)
)
```

### Top 10% of Earners (NTILE)

```sql
-- SQL
SELECT * FROM (
    SELECT *, NTILE(10) OVER (ORDER BY salary DESC) AS decile
    FROM employees
) bucketed
WHERE decile = 1;
```

```python
# PySpark
window_spec = Window.orderBy(F.col("salary").desc())

df_top_10pct = (df
    .withColumn("decile", F.ntile(10).over(window_spec))
    .filter(F.col("decile") == 1)
)
```

### Rank with Multiple Sorting Criteria

```sql
-- SQL
SELECT *,
    ROW_NUMBER() OVER (
        PARTITION BY department
        ORDER BY performance_score DESC, tenure DESC
    ) AS rank
FROM employees;
```

```python
# PySpark
window_spec = Window.partitionBy("department").orderBy(
    F.col("performance_score").desc(),
    F.col("tenure").desc()
)

df_ranked = df.withColumn("rank", F.row_number().over(window_spec))
```

### Comparing All Ranking Functions Side-by-Side

```python
# PySpark: See all ranking functions at once
window_spec = Window.partitionBy("category").orderBy(F.col("sales").desc())

df_with_ranks = (df
    .withColumn("row_num", F.row_number().over(window_spec))
    .withColumn("rank", F.rank().over(window_spec))
    .withColumn("dense_rank", F.dense_rank().over(window_spec))
)
```

### Common Pitfalls

```sql
-- SQL ❌ WRONG: LIMIT gives top N overall, NOT per group
SELECT * FROM employees ORDER BY salary DESC LIMIT 3;

-- SQL ✅ CORRECT: Window function for per-group
SELECT * FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY dept ORDER BY salary DESC) AS rn
    FROM employees
) WHERE rn <= 3;
```

```python
# PySpark ❌ WRONG
df.orderBy(F.col("salary").desc()).limit(3)

# PySpark ✅ CORRECT
window_spec = Window.partitionBy("dept").orderBy(F.col("salary").desc())
df.withColumn("rn", F.row_number().over(window_spec)).filter(F.col("rn") <= 3)

# ❌ WRONG: Not handling ties properly
df.orderBy(F.col("score").desc()).limit(10)
# If 10th and 11th have same score, one is randomly excluded

# ✅ CORRECT: Use dense_rank or rank for ties
window_spec = Window.orderBy(F.col("score").desc())
df.withColumn("rank", F.dense_rank().over(window_spec)).filter(F.col("rank") <= 10)
```

---

## 5. Running/Cumulative Calculations

### Frame Clause Options

| Need                    | SQL Frame                                    | PySpark Frame                                          |
|-------------------------|----------------------------------------------|--------------------------------------------------------|
| Running total (from start) | `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` | `Window.rowsBetween(Window.unboundedPreceding, Window.currentRow)` |
| Moving average (last 7) | `ROWS BETWEEN 6 PRECEDING AND CURRENT ROW`  | `Window.rowsBetween(-6, 0)`                            |
| Centered window         | `ROWS BETWEEN 3 PRECEDING AND 3 FOLLOWING`  | `Window.rowsBetween(-3, 3)`                            |
| All rows in partition   | No `ORDER BY` clause                         | `Window.partitionBy("col")` (no `orderBy`)             |

### rowsBetween vs rangeBetween (PySpark)

```python
# rowsBetween: Physical row positions
# Use when you want exactly N rows (e.g., "last 10 transactions")
Window.orderBy("date").rowsBetween(-6, 0)  # Last 7 rows

# rangeBetween: Logical value ranges (for dates/timestamps)
# Use when you want time-based windows (e.g., "last 7 days")
Window.orderBy(F.col("date").cast("long")).rangeBetween(
    -7*24*60*60, 0  # Last 7 days in seconds
)
```

### Running Total

```sql
-- SQL
SELECT
    date, amount,
    SUM(amount) OVER (ORDER BY date) AS running_total
FROM transactions;

-- Running total per category
SELECT
    category, date, amount,
    SUM(amount) OVER (PARTITION BY category ORDER BY date) AS category_running_total
FROM transactions;
```

```python
# PySpark
window_spec = Window.orderBy("date").rowsBetween(
    Window.unboundedPreceding, Window.currentRow
)
df.withColumn("running_total", F.sum("amount").over(window_spec))

# Running total per category
window_spec = Window.partitionBy("category").orderBy("date").rowsBetween(
    Window.unboundedPreceding, Window.currentRow
)
df.withColumn("category_running_total", F.sum("amount").over(window_spec))
```

### Running Total with Month Reset

```python
# PySpark: Reset running total each month
df_with_month = df.withColumn(
    "year_month",
    F.concat(F.year("date"), F.lit("-"), F.month("date"))
)

window_spec = Window.partitionBy("product_id", "year_month").orderBy("date").rowsBetween(
    Window.unboundedPreceding, Window.currentRow
)

df_monthly_running = df_with_month.withColumn(
    "monthly_running_total",
    F.sum("amount").over(window_spec)
)
```

### 7-Day Moving Average

```sql
-- SQL
SELECT
    date, daily_sales,
    AVG(daily_sales) OVER (
        ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS moving_avg_7day
FROM sales;
```

```python
# PySpark
window_spec = Window.orderBy("date").rowsBetween(-6, 0)
df.withColumn("moving_avg_7day", F.avg("daily_sales").over(window_spec))
```

### Rolling Sum with Time-Based Window (rangeBetween)

```python
# PySpark: Sum of sales in last 7 days (not last 7 rows)
window_spec = Window.partitionBy("store_id").orderBy(
    F.col("date").cast("long")
).rangeBetween(-7*24*60*60, 0)  # 7 days in seconds

df_rolling = df.withColumn(
    "sales_last_7_days",
    F.sum("sales").over(window_spec)
)
```

### LAG / LEAD (Previous/Next Value)

```sql
-- SQL
SELECT
    date, value,
    LAG(value, 1) OVER (ORDER BY date) AS prev_value,
    LEAD(value, 1) OVER (ORDER BY date) AS next_value,
    value - LAG(value, 1) OVER (ORDER BY date) AS change
FROM metrics;
```

```python
# PySpark
window_spec = Window.orderBy("date")

df_change = (df
    .withColumn("prev_value", F.lag("value", 1).over(window_spec))
    .withColumn("next_value", F.lead("value", 1).over(window_spec))
    .withColumn("change", F.col("value") - F.col("prev_value"))
)
```

### Cumulative Distinct Count

```python
# PySpark: Cumulative distinct products purchased
window_spec = Window.partitionBy("customer_id").orderBy("purchase_date").rowsBetween(
    Window.unboundedPreceding, Window.currentRow
)

df_cumulative = df.withColumn(
    "cumulative_distinct_products",
    F.size(F.collect_set("product_id").over(window_spec))
)
```

### Quick Reference

| Need              | SQL                  | PySpark                 |
|-------------------|----------------------|-------------------------|
| Running total     | `SUM() OVER`         | `F.sum().over()`        |
| Previous value    | `LAG(col, 1)`        | `F.lag("col", 1)`       |
| Next value        | `LEAD(col, 1)`       | `F.lead("col", 1)`      |
| First in group    | `FIRST_VALUE()`      | `F.first()`             |
| Last in group     | `LAST_VALUE()`       | `F.last()`              |

---

## 6. Time-Series & Gap Analysis

### Generate Date Series

```sql
-- SQL (Recursive CTE)
WITH RECURSIVE date_series AS (
    SELECT DATE '2024-01-01' AS date
    UNION ALL
    SELECT date + INTERVAL '1 day'
    FROM date_series WHERE date < DATE '2024-12-31'
)
SELECT * FROM date_series;
```

```python
# PySpark
date_series = spark.sql("""
    SELECT explode(sequence(
        to_date('2024-01-01'),
        to_date('2024-12-31'),
        interval 1 day
    )) as date
""")

# Alternative using DataFrame API
date_series = spark.range(0, 365).select(
    F.expr("date_add('2024-01-01', cast(id as int))").alias("date")
)
```

### Fill Missing Dates with 0 Values

```sql
-- SQL
WITH RECURSIVE date_series AS (
    SELECT DATE '2024-01-01' AS date
    UNION ALL
    SELECT date + INTERVAL '1 day' FROM date_series WHERE date < DATE '2024-12-31'
)
SELECT d.date, COALESCE(s.sales, 0) AS sales
FROM date_series d
LEFT JOIN daily_sales s ON d.date = s.date;
```

```python
# PySpark
date_series = spark.sql("""
    SELECT explode(sequence(to_date('2024-01-01'), to_date('2024-12-31'), interval 1 day)) as date
""")
complete_dates = date_series.join(df, "date", "left").fillna(0)
```

### Find Missing Transaction IDs

```sql
-- SQL
WITH RECURSIVE all_ids AS (
    SELECT 1 AS id
    UNION ALL
    SELECT id + 1 FROM all_ids WHERE id < 1000
)
SELECT id AS missing_id
FROM all_ids
WHERE NOT EXISTS (SELECT 1 FROM transactions WHERE transaction_id = id);
```

```python
# PySpark
max_id = df.agg(F.max("transaction_id")).first()[0]
all_ids = spark.range(1, max_id + 1).select(F.col("id").alias("transaction_id"))
missing_ids = all_ids.join(df, "transaction_id", "left_anti")
```

### Find Gaps

```sql
-- SQL
SELECT
    date,
    LEAD(date) OVER (ORDER BY date) AS next_date,
    LEAD(date) OVER (ORDER BY date) - date AS gap_days
FROM events
HAVING gap_days > 1;
```

```python
# PySpark: Find gaps using anti-join
date_range = spark.sql("""
    SELECT explode(sequence(to_date('2024-01-01'), to_date('2024-12-31'), interval 1 day)) as date
""")
gaps = date_range.join(df, "date", "left_anti")

# Or using lag/lead for time-based gaps
window_spec = Window.partitionBy("device_id").orderBy("event_time")
gaps = (df
    .withColumn("next_event", F.lead("event_time").over(window_spec))
    .withColumn("gap_seconds",
                F.unix_timestamp("next_event") - F.unix_timestamp("event_time"))
    .filter(F.col("gap_seconds") > 3600)  # Gaps > 1 hour
)
```

### Fill Gaps with Linear Interpolation (PySpark)

```python
# PySpark: Sensor data interpolation
window_spec = Window.partitionBy("sensor_id").orderBy("timestamp")

df_with_prev_next = (df
    .withColumn("prev_value", F.lag("temperature").over(window_spec))
    .withColumn("prev_time", F.lag("timestamp").over(window_spec))
    .withColumn("next_value", F.lead("temperature").over(window_spec))
    .withColumn("next_time", F.lead("timestamp").over(window_spec))
)

df_interpolated = df_with_prev_next.withColumn(
    "interpolated_temp",
    F.when(F.col("temperature").isNotNull(), F.col("temperature"))
    .otherwise(
        F.col("prev_value") +
        (F.col("next_value") - F.col("prev_value")) *
        (F.unix_timestamp("timestamp") - F.unix_timestamp("prev_time")) /
        (F.unix_timestamp("next_time") - F.unix_timestamp("prev_time"))
    )
)
```

### Consecutive Streak (Islands Problem)

```sql
-- SQL
WITH daily_logins AS (
    SELECT DISTINCT user_id, DATE(login_time) AS login_date
    FROM user_logins
),
streaks AS (
    SELECT user_id, login_date,
        login_date - (ROW_NUMBER() OVER (
            PARTITION BY user_id ORDER BY login_date
        ) * INTERVAL '1 day') AS streak_group
    FROM daily_logins
)
SELECT user_id,
    MIN(login_date) AS streak_start,
    MAX(login_date) AS streak_end,
    COUNT(*) AS days_in_streak
FROM streaks
GROUP BY user_id, streak_group
HAVING COUNT(*) >= 7;
```

```python
# PySpark
window_spec = Window.partitionBy("user_id").orderBy("login_date")

df_islands = (df
    .select("user_id", F.to_date("login_timestamp").alias("login_date"))
    .distinct()
    .withColumn("prev_date", F.lag("login_date").over(window_spec))
    .withColumn("days_diff", F.datediff("login_date", "prev_date"))
    .withColumn("is_new_island",
                F.when((F.col("days_diff") > 1) | F.col("days_diff").isNull(), 1)
                .otherwise(0))
    .withColumn("island_id", F.sum("is_new_island").over(
        window_spec.rowsBetween(Window.unboundedPreceding, Window.currentRow)
    ))
)

streaks = (df_islands
    .groupBy("user_id", "island_id")
    .agg(
        F.min("login_date").alias("streak_start"),
        F.max("login_date").alias("streak_end"),
        F.count("*").alias("streak_days")
    )
    .filter(F.col("streak_days") >= 7)
)
```

---

## 7. Joins

### Join Types

| Join Type        | SQL                          | PySpark                                    |
|------------------|------------------------------|--------------------------------------------|
| Inner Join       | `A JOIN B ON ...`            | `df1.join(df2, "key", "inner")`            |
| Left Join        | `A LEFT JOIN B ON ...`       | `df1.join(df2, "key", "left")`             |
| Right Join       | `A RIGHT JOIN B ON ...`      | `df1.join(df2, "key", "right")`            |
| Full Outer Join  | `A FULL OUTER JOIN B ON ...` | `df1.join(df2, "key", "outer")`            |
| Cross Join       | `A CROSS JOIN B`             | `df1.crossJoin(df2)`                       |
| Semi Join (EXISTS)    | `WHERE EXISTS (...)`    | `df1.join(df2, "key", "left_semi")`        |
| Anti Join (NOT EXISTS) | `WHERE NOT EXISTS (...)` | `df1.join(df2, "key", "left_anti")`       |

### Multiple Join Conditions

```sql
-- SQL
SELECT *
FROM events e
JOIN campaigns c
    ON e.user_id = c.user_id
    AND e.event_date >= c.start_date
    AND e.event_date <= c.end_date;
```

```python
# PySpark
events.join(
    campaigns,
    (events.user_id == campaigns.user_id) &
    (events.event_date >= campaigns.start_date) &
    (events.event_date <= campaigns.end_date),
    "inner"
)
```

### Self-Join

```sql
-- SQL: Employees earning more than their manager
SELECT e.name AS employee, e.salary, m.name AS manager, m.salary
FROM employees e
JOIN employees m ON e.manager_id = m.emp_id
WHERE e.salary > m.salary;
```

```python
# PySpark
df.alias("e").join(
    df.alias("m"),
    F.col("e.manager_id") == F.col("m.emp_id"),
    "inner"
).filter(
    F.col("e.salary") > F.col("m.salary")
).select(
    F.col("e.name").alias("employee"),
    F.col("e.salary"),
    F.col("m.name").alias("manager"),
    F.col("m.salary")
)
```

### Broadcast Join (Small Table Optimization)

```sql
-- SQL: Use hints (database-specific)
SELECT /*+ BROADCAST(small_table) */ *
FROM large_table JOIN small_table ON ...;
```

```python
# PySpark: Broadcast small table (< 10MB)
from pyspark.sql.functions import broadcast

large_df.join(broadcast(small_df), "key", "left")
```

### Join with Column Renaming (Avoid Ambiguity)

```python
# PySpark: Rename before join to avoid duplicate column names
df1.join(
    df2.withColumnRenamed("id", "customer_id"),
    df1.id == df2.customer_id,
    "left"
).drop(df2.customer_id)
```

### Multiple Table Joins

```sql
-- SQL
SELECT o.order_id, c.customer_name, p.product_name, r.region_name, o.amount
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN products p ON o.product_id = p.product_id
LEFT JOIN regions r ON o.region_id = r.id;
```

```python
# PySpark
result = (orders
    .join(customers, "customer_id", "left")
    .join(products, "product_id", "left")
    .join(regions, orders.region_id == regions.id, "left")
    .select(
        orders["order_id"],
        customers["customer_name"],
        products["product_name"],
        regions["region_name"],
        orders["amount"]
    )
)
```

### Join Performance Checklist

| Do                                          | Don't                                             |
|---------------------------------------------|---------------------------------------------------|
| Use broadcast for small tables (< 10MB)     | Join without filtering large tables first          |
| Filter before joining                       | Use cross join accidentally (missing condition)    |
| Select only needed columns before join      | Keep all columns from both tables                  |
| Use appropriate join type                   | Use outer join when inner join suffices             |

---

## 8. Deduplication

### Simple Distinct

```sql
-- SQL
SELECT DISTINCT col1, col2 FROM table_name;

-- PostgreSQL: DISTINCT ON (keep first per group)
SELECT DISTINCT ON (key_column) *
FROM table_name
ORDER BY key_column, timestamp;
```

```python
# PySpark
df.select("col1", "col2").distinct()
df.dropDuplicates(["col1", "col2"])
```

### Keep Most Recent (Remove Duplicates)

```sql
-- SQL
SELECT * FROM (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY email ORDER BY created_date DESC) AS rn
    FROM users
) t
WHERE rn = 1;
```

```python
# PySpark
window_spec = Window.partitionBy("email").orderBy(F.col("created_date").desc())

df_latest = (df
    .withColumn("rn", F.row_number().over(window_spec))
    .filter(F.col("rn") == 1)
    .drop("rn")
)
```

### Find Duplicates

```sql
-- SQL
SELECT email, COUNT(*) AS duplicate_count,
    STRING_AGG(user_id::TEXT, ', ') AS user_ids
FROM users
GROUP BY email
HAVING COUNT(*) > 1;
```

```python
# PySpark
duplicates = (df
    .groupBy("email")
    .agg(
        F.count("*").alias("count"),
        F.collect_list("user_id").alias("duplicate_ids"),
        F.min("created_date").alias("first_created"),
        F.max("created_date").alias("last_created")
    )
    .filter(F.col("count") > 1)
)
```

### Keep Record with Most Complete Data

```sql
-- SQL
SELECT * FROM (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY
                CASE WHEN email IS NOT NULL THEN 0 ELSE 1 END,
                CASE WHEN phone IS NOT NULL THEN 0 ELSE 1 END,
                created_date DESC
        ) AS rn
    FROM customers
) t WHERE rn = 1;
```

```python
# PySpark
window_spec = Window.partitionBy("customer_id").orderBy(
    F.col("email").isNull().asc(),
    F.col("phone").isNull().asc(),
    F.col("created_date").desc()
)

df_best = (df
    .withColumn("rn", F.row_number().over(window_spec))
    .filter(F.col("rn") == 1)
    .drop("rn")
)
```

### Merge Duplicate Records (Consolidate)

```sql
-- SQL: Take non-null values from any duplicate
SELECT
    customer_id,
    MAX(name) AS name,
    MAX(email) AS email,
    MAX(phone) AS phone,
    MIN(created_date) AS created_date,
    MAX(updated_date) AS updated_date
FROM customer_records
GROUP BY customer_id;
```

```python
# PySpark
df_merged = df.groupBy("customer_id").agg(
    F.max("name").alias("name"),
    F.max("email").alias("email"),
    F.max("phone").alias("phone"),
    F.min("created_date").alias("created_date"),
    F.max("updated_date").alias("updated_date")
)
```

### Fuzzy Deduplication (Similar Records)

```python
# PySpark: Find records with similar names using levenshtein distance
from pyspark.sql.functions import levenshtein

df_similarity = df.alias("a").join(
    df.alias("b"),
    (F.col("a.id") < F.col("b.id")) &  # Avoid comparing same record twice
    (F.levenshtein(F.col("a.name"), F.col("b.name")) <= 3),  # Edit distance <= 3
    "inner"
).select(
    F.col("a.id").alias("id_1"),
    F.col("b.id").alias("id_2"),
    F.col("a.name").alias("name_1"),
    F.col("b.name").alias("name_2"),
    F.levenshtein(F.col("a.name"), F.col("b.name")).alias("edit_distance")
)
```

---

## 9. Pivot & Unpivot

### Pivot (Rows to Columns)

```sql
-- SQL
SELECT
    product_name,
    SUM(CASE WHEN month = 1 THEN sales ELSE 0 END) AS Jan,
    SUM(CASE WHEN month = 2 THEN sales ELSE 0 END) AS Feb,
    SUM(CASE WHEN month = 3 THEN sales ELSE 0 END) AS Mar
FROM monthly_sales
GROUP BY product_name;

-- PostgreSQL: Dynamic pivot using crosstab
SELECT * FROM crosstab(
    'SELECT region, quarter, revenue FROM sales ORDER BY 1,2',
    'SELECT DISTINCT quarter FROM sales ORDER BY 1'
) AS ct(region text, Q1 numeric, Q2 numeric, Q3 numeric, Q4 numeric);
```

```python
# PySpark
df.groupBy("product_name").pivot("month").agg(F.sum("sales"))

# With specific values (faster - avoids extra scan)
df.groupBy("product_name").pivot("month", [1, 2, 3]).agg(F.sum("sales"))
```

### Pivot with Multiple Aggregations

```python
# PySpark
df_pivoted = (df
    .groupBy("region")
    .pivot("quarter")
    .agg(
        F.sum("revenue").alias("total_revenue"),
        F.avg("price").alias("avg_price")
    )
)
```

### Conditional Pivot

```python
# PySpark: Pivot with conditions
df_pivoted = (df
    .groupBy("product")
    .pivot("region")
    .agg(
        F.sum(F.when(F.col("status") == "completed",
                     F.col("amount")).otherwise(0)).alias("completed_sales"),
        F.sum(F.when(F.col("status") == "pending",
                     F.col("amount")).otherwise(0)).alias("pending_sales")
    )
)
```

### Unpivot (Columns to Rows)

```sql
-- SQL
SELECT employee_id, 'Q1' AS quarter, Q1_sales AS sales FROM quarterly_data
UNION ALL
SELECT employee_id, 'Q2' AS quarter, Q2_sales AS sales FROM quarterly_data
UNION ALL
SELECT employee_id, 'Q3' AS quarter, Q3_sales AS sales FROM quarterly_data
UNION ALL
SELECT employee_id, 'Q4' AS quarter, Q4_sales AS sales FROM quarterly_data;
```

```python
# PySpark: Using stack()
df.selectExpr(
    "employee_id",
    "stack(4, "
    "'Q1', Q1_sales, "
    "'Q2', Q2_sales, "
    "'Q3', Q3_sales, "
    "'Q4', Q4_sales"
    ") as (quarter, sales)"
)
```

### Dynamic Unpivot (All Columns Except ID)

```python
# PySpark: Dynamically unpivot all value columns
value_cols = [c for c in df.columns if c not in ['id', 'name']]
stack_expr = f"stack({len(value_cols)}, " + \
             ", ".join([f"'{c}', {c}" for c in value_cols]) + \
             ") as (metric, value)"

df_unpivoted = df.selectExpr("id", "name", stack_expr)
```

---

## 10. Comparison Problems (vs Average / Previous)

### Compare to Group Average

```sql
-- SQL (Window Function - single pass)
SELECT * FROM (
    SELECT *,
        AVG(salary) OVER (PARTITION BY department) AS dept_avg
    FROM employees
) t
WHERE salary > dept_avg;

-- SQL Alternative: Subquery approach
SELECT *
FROM employees t
JOIN (
    SELECT department, AVG(salary) AS avg_salary
    FROM employees GROUP BY department
) agg ON t.department = agg.department
WHERE t.salary > agg.avg_salary;
```

```python
# PySpark
window_spec = Window.partitionBy("department")

above_avg = (df
    .withColumn("dept_avg", F.avg("salary").over(window_spec))
    .filter(F.col("salary") > F.col("dept_avg"))
)
```

### Sales Above Monthly Median

```sql
-- SQL
SELECT date, sales_amount, monthly_median
FROM (
    SELECT date, sales_amount,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sales_amount)
            OVER (PARTITION BY DATE_TRUNC('month', date)) AS monthly_median
    FROM daily_sales
) t
WHERE sales_amount > monthly_median;
```

```python
# PySpark
monthly_window = Window.partitionBy(F.date_trunc("month", F.col("date")))

df_above_median = (df
    .withColumn("monthly_median",
        F.expr("percentile_approx(sales_amount, 0.5)").over(monthly_window))
    .filter(F.col("sales_amount") > F.col("monthly_median"))
)
```

### Outlier Detection (Z-Score)

```sql
-- SQL
SELECT name, salary,
    (salary - avg_salary) / stddev_salary AS z_score
FROM employees,
LATERAL (
    SELECT AVG(salary) AS avg_salary, STDDEV(salary) AS stddev_salary
    FROM employees
) stats
WHERE ABS((salary - avg_salary) / stddev_salary) > 2;
```

```python
# PySpark
window_spec = Window.partitionBy()

df_outliers = (df
    .withColumn("avg_salary", F.avg("salary").over(window_spec))
    .withColumn("stddev_salary", F.stddev("salary").over(window_spec))
    .withColumn("z_score",
        (F.col("salary") - F.col("avg_salary")) / F.col("stddev_salary"))
    .filter(F.abs(F.col("z_score")) > 2)
)
```

### Outlier Detection (IQR Method)

```sql
-- SQL
WITH stats AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY salary) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY salary) AS q3
    FROM employees
),
bounds AS (
    SELECT
        q1 - 1.5 * (q3 - q1) AS lower_bound,
        q3 + 1.5 * (q3 - q1) AS upper_bound
    FROM stats
)
SELECT *
FROM employees, bounds
WHERE salary < lower_bound OR salary > upper_bound;
```

```python
# PySpark
window_spec = Window.partitionBy()

df_outliers = (df
    .withColumn("q1", F.expr("percentile_approx(salary, 0.25)").over(window_spec))
    .withColumn("q3", F.expr("percentile_approx(salary, 0.75)").over(window_spec))
    .withColumn("iqr", F.col("q3") - F.col("q1"))
    .withColumn("lower_bound", F.col("q1") - 1.5 * F.col("iqr"))
    .withColumn("upper_bound", F.col("q3") + 1.5 * F.col("iqr"))
    .filter(
        (F.col("salary") < F.col("lower_bound")) |
        (F.col("salary") > F.col("upper_bound"))
    )
)
```

### Month-over-Month Change

```sql
-- SQL
SELECT
    month, revenue,
    LAG(revenue) OVER (ORDER BY month) AS prev_revenue,
    ROUND((revenue - LAG(revenue) OVER (ORDER BY month))
        / LAG(revenue) OVER (ORDER BY month) * 100, 2) AS mom_change_pct
FROM monthly_revenue;
```

```python
# PySpark
window_spec = Window.orderBy("month")

df_mom = (df
    .withColumn("prev_revenue", F.lag("revenue", 1).over(window_spec))
    .withColumn("mom_change_pct",
        F.round(
            (F.col("revenue") - F.col("prev_revenue")) / F.col("prev_revenue") * 100,
            2
        )
    )
)
```

---

## 11. Hierarchical / Recursive Queries

### Employee Reporting Chain (Bottom-Up)

```sql
-- SQL: Recursive CTE
-- Find the full management chain for a specific employee.
-- Traverses the org chart BOTTOM-UP: starts at the employee and walks
-- up to the CEO, one level per iteration.
WITH RECURSIVE chain AS (

    -- ANCHOR: Start recursion at the specified employee.
    -- 123 is the emp_id of the employee whose management chain we want.
    -- `level = 0` marks this as the starting point; each step up the tree
    -- will increment level by 1.
    SELECT emp_id, name, manager_id, 0 AS level
    FROM employees
    WHERE emp_id = 123

    UNION ALL

    -- RECURSIVE STEP: For each person currently in `chain`,
    -- find the employee who is their manager. Each iteration
    -- climbs one level up the hierarchy:
    --   Iteration 1: finds the employee's direct manager
    --   Iteration 2: finds that manager's manager
    --   ...continues until we reach the CEO (manager_id IS NULL),
    --      at which point the INNER JOIN produces no match and stops.
    --
    -- Join direction note: `c.manager_id = e.emp_id` means
    -- "find the employee (e) whose emp_id matches the manager_id
    -- in the CTE (c)" — this walks UP the hierarchy by following
    -- the current row's pointer to its parent.
    --
    -- `c.level + 1` tracks depth: level 0 = employee, level 1 = their
    -- manager, level 2 = their manager's manager, and so on.
    SELECT e.emp_id, e.name, e.manager_id, c.level + 1
    FROM employees e
    JOIN chain c ON c.manager_id = e.emp_id
)

-- Order by level so the chain reads bottom-up: the starting employee
-- appears first (level 0), followed by each successive manager up to the CEO.
SELECT *
FROM chain
ORDER BY level;
```

```python
# PySpark: No native recursive CTE support - use iterative joins
current_level = df.filter(F.col("emp_id") == 123).withColumn("level", F.lit(0))
result = current_level

for i in range(1, max_depth):
    next_level = (current_level
        .join(df, current_level.manager_id == df.emp_id)
        .select(df["*"])
        .withColumn("level", F.lit(i))
    )
    if next_level.count() == 0:
        break
    result = result.union(next_level)
    current_level = next_level

# Alternative: Spark SQL supports recursive CTEs in newer versions
spark.sql("""
    WITH RECURSIVE chain AS (
        SELECT emp_id, name, manager_id, 0 AS level
        FROM employees WHERE emp_id = 123
        UNION ALL
        SELECT e.emp_id, e.name, e.manager_id, c.level + 1
        FROM employees e JOIN chain c ON c.manager_id = e.emp_id
    )
    SELECT * FROM chain
""")
```

### All Subordinates - Direct & Indirect (Top-Down)

```sql
-- SQL
-- Find all subordinates (direct and indirect) of a specific manager.
-- Traverses the org chart TOP-DOWN: starts at the manager and walks
-- down to leaves, one level per iteration.
WITH RECURSIVE subordinates AS (

    -- ANCHOR: Start recursion at the specified manager.
    -- 456 is the emp_id of the manager whose org we want to explore.
    SELECT emp_id, name, manager_id
    FROM employees
    WHERE emp_id = 456

    UNION ALL

    -- RECURSIVE STEP: For each person currently in `subordinates`,
    -- find employees who report directly to them. Each iteration
    -- extends the tree one level deeper:
    --   Iteration 1: finds the manager's direct reports
    --   Iteration 2: finds reports of those reports
    --   ...continues until no new reports are found.
    --
    -- Join direction note: `e.manager_id = s.emp_id` means
    -- "find employees (e) whose manager is someone already in
    -- the CTE (s)" — this walks DOWN the hierarchy.
    SELECT e.emp_id, e.name, e.manager_id
    FROM employees e
    JOIN subordinates s ON e.manager_id = s.emp_id
)

-- Exclude the starting manager from the output.
-- The anchor added them to the CTE, but they are not their own subordinate.
SELECT *
FROM subordinates
WHERE emp_id != 456;
```

### Category Path Building

```sql
-- SQL
WITH RECURSIVE category_path AS (
    SELECT
        category_id, category_name, parent_id,
        category_name AS path
    FROM categories
    WHERE parent_id IS NULL

    UNION ALL

    SELECT
        c.category_id, c.category_name, c.parent_id,
        cp.path || ' > ' || c.category_name
    FROM categories c
    JOIN category_path cp ON c.parent_id = cp.category_id
)
SELECT * FROM category_path;
```

### Direction Templates

```sql
-- TOP-DOWN: Root to leaves (find children)
WHERE parent_id IS NULL          -- Start at root
JOIN ON t.parent_id = h.id       -- Find children

-- BOTTOM-UP: Leaf to root (find parents)
WHERE id = specific_leaf         -- Start at leaf
JOIN ON h.parent_id = t.id       -- Find parents

-- SIBLINGS: Same parent
SELECT t2.*
FROM table_name t1
JOIN table_name t2 ON t1.parent_id = t2.parent_id
WHERE t1.id = specific_id AND t2.id != specific_id;
```

### Cycle Detection

```sql
-- SQL: Always add cycle protection in recursive CTEs!
WITH RECURSIVE hierarchy AS (
    SELECT id, parent_id, ARRAY[id] AS path
    FROM table_name
    WHERE parent_id IS NULL

    UNION ALL

    SELECT t.id, t.parent_id, h.path || t.id
    FROM table_name t
    JOIN hierarchy h ON t.parent_id = h.id
    WHERE NOT (t.id = ANY(h.path))      -- Prevent cycles
      AND ARRAY_LENGTH(h.path, 1) < 100 -- Depth limit
)
SELECT * FROM hierarchy;
```

---

## 12. Self-Referencing Problems

### When to Use Each Approach

| Scenario                   | Approach                 | Why                  |
|----------------------------|--------------------------|----------------------|
| Compare to previous/next   | Window function (LAG/LEAD) | More efficient     |
| Find duplicates            | Self-join with id < id   | Classic pattern      |
| All pairs comparison       | Self-join with id != id  | Need all combos      |
| Running comparisons        | Window function          | Single pass          |

### Find Duplicate Records via Self-Join

```sql
-- SQL: a.id < b.id prevents double counting
SELECT a.*
FROM records a
JOIN records b ON a.email = b.email AND a.id < b.id;
```

```python
# PySpark
df.alias("a").join(
    df.alias("b"),
    (F.col("a.email") == F.col("b.email")) & (F.col("a.id") < F.col("b.id")),
    "inner"
)
```

### Customers Who Bought Same Product Multiple Times

```sql
-- SQL
SELECT customer_id, product_id, COUNT(*) AS times_purchased
FROM purchases
GROUP BY customer_id, product_id
HAVING COUNT(*) > 1;
```

```python
# PySpark
df.groupBy("customer_id", "product_id") \
  .agg(F.count("*").alias("times_purchased")) \
  .filter(F.col("times_purchased") > 1)
```

---

## 13. Pattern Matching & Sequences

### Find Sequence: View -> Add to Cart -> Purchase

```sql
-- SQL
WITH user_journey AS (
    SELECT user_id, event_type, timestamp,
        LEAD(event_type, 1) OVER (PARTITION BY user_id ORDER BY timestamp) AS next_event,
        LEAD(event_type, 2) OVER (PARTITION BY user_id ORDER BY timestamp) AS event_after
    FROM user_events
)
SELECT DISTINCT user_id
FROM user_journey
WHERE event_type = 'view'
  AND next_event = 'add_to_cart'
  AND event_after = 'purchase';
```

```python
# PySpark
window_spec = Window.partitionBy("user_id").orderBy("timestamp")

users_converted = (df
    .withColumn("next_event", F.lead("event_type", 1).over(window_spec))
    .withColumn("event_after", F.lead("event_type", 2).over(window_spec))
    .filter(
        (F.col("event_type") == "view") &
        (F.col("next_event") == "add_to_cart") &
        (F.col("event_after") == "purchase")
    )
    .select("user_id").distinct()
)
```

### Stock Went Up 3 Days in a Row

```sql
-- SQL
WITH price_changes AS (
    SELECT
        date, close_price,
        LAG(close_price, 1) OVER (ORDER BY date) AS prev_1,
        LAG(close_price, 2) OVER (ORDER BY date) AS prev_2
    FROM stock_prices
)
SELECT date
FROM price_changes
WHERE close_price > prev_1 AND prev_1 > prev_2;
```

```python
# PySpark
window_spec = Window.orderBy("date")

three_day_up = (df
    .withColumn("prev_1", F.lag("close_price", 1).over(window_spec))
    .withColumn("prev_2", F.lag("close_price", 2).over(window_spec))
    .filter(
        (F.col("close_price") > F.col("prev_1")) &
        (F.col("prev_1") > F.col("prev_2"))
    )
)
```

### 3+ Consecutive Failed Logins

```sql
-- SQL
WITH login_attempts AS (
    SELECT user_id, timestamp, success,
        SUM(CASE WHEN success = false THEN 1 ELSE 0 END) OVER (
            PARTITION BY user_id ORDER BY timestamp
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS failures_in_window
    FROM login_log
)
SELECT DISTINCT user_id FROM login_attempts WHERE failures_in_window >= 3;
```

```python
# PySpark
window_spec = (Window.partitionBy("user_id")
    .orderBy("timestamp")
    .rowsBetween(-2, 0))

flagged_users = (df
    .withColumn("failures_in_window",
        F.sum(F.when(F.col("success") == False, 1).otherwise(0)).over(window_spec))
    .filter(F.col("failures_in_window") >= 3)
    .select("user_id").distinct()
)
```

---

## 14. Graph/Network Problems

### Key Pattern: BFS/DFS Traversal

```sql
-- SQL: Find connections (BFS/DFS)
WITH RECURSIVE connections AS (
    SELECT node_id, 0 AS distance, ARRAY[node_id] AS path
    FROM nodes
    WHERE node_id = start_node

    UNION

    SELECT
        e.to_node,
        c.distance + 1,
        c.path || e.to_node
    FROM connections c
    JOIN edges e ON c.node_id = e.from_node
    WHERE NOT (e.to_node = ANY(c.path))  -- Avoid cycles
      AND c.distance < max_distance
)
SELECT * FROM connections;
```

### Shortest Path in Social Network

```sql
-- SQL
WITH RECURSIVE friend_path AS (
    SELECT
        user_id, friend_id,
        1 AS degree,
        ARRAY[user_id, friend_id] AS path
    FROM friendships
    WHERE user_id = 123

    UNION

    SELECT
        fp.user_id, f.friend_id,
        fp.degree + 1,
        fp.path || f.friend_id
    FROM friend_path fp
    JOIN friendships f ON fp.friend_id = f.user_id
    WHERE NOT (f.friend_id = ANY(fp.path))
      AND fp.degree < 6  -- 6 degrees of separation
)
SELECT *
FROM friend_path
WHERE friend_id = 456
ORDER BY degree
LIMIT 1;
```

```python
# PySpark: Use GraphFrames library for graph problems
# pip install graphframes

from graphframes import GraphFrame

vertices = spark.createDataFrame([
    ("1", "Alice"), ("2", "Bob"), ("3", "Carol")
], ["id", "name"])

edges = spark.createDataFrame([
    ("1", "2", "friend"), ("2", "3", "friend")
], ["src", "dst", "relationship"])

g = GraphFrame(vertices, edges)

# Shortest paths
results = g.shortestPaths(landmarks=["3"])

# BFS
paths = g.bfs(fromExpr="id = '1'", toExpr="id = '3'", maxPathLength=6)

# Or use iterative joins (same pattern as hierarchical queries)
```

### Find All Reachable Nodes

```sql
-- SQL
WITH RECURSIVE reachable AS (
    SELECT node_id FROM nodes WHERE node_id = 1
    UNION
    SELECT e.to_node
    FROM edges e
    JOIN reachable r ON e.from_node = r.node_id
)
SELECT node_id FROM reachable;
```

---

## 15. Data Quality & Validation

### Null Checks

```sql
-- SQL
SELECT
    SUM(CASE WHEN col1 IS NULL THEN 1 ELSE 0 END) AS col1_nulls,
    SUM(CASE WHEN col2 IS NULL THEN 1 ELSE 0 END) AS col2_nulls
FROM table_name;
```

```python
# PySpark
null_counts = df.select([
    F.count(F.when(F.col(c).isNull(), c)).alias(c)
    for c in df.columns
])

# With percentages
total_rows = df.count()
null_pcts = df.select([
    (F.count(F.when(F.col(c).isNull(), c)) / total_rows * 100).alias(f"{c}_null_pct")
    for c in df.columns
])
```

### Referential Integrity

```sql
-- SQL: Orphaned orders (no matching customer)
SELECT o.*
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;
```

```python
# PySpark
orphaned = orders.join(customers, "customer_id", "left_anti")
```

### Pattern Validation

```sql
-- SQL
SELECT * FROM users
WHERE email !~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
```

```python
# PySpark
invalid_emails = df.filter(
    ~F.col("email").rlike(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
)

invalid_phone = df.filter(
    ~F.col("phone").rlike(r'^\d{3}-\d{3}-\d{4}$')
)
```

### Cross-Field Validation

```python
# PySpark: Validate relationships between columns
invalid_combinations = df.filter(
    (F.col("end_date") < F.col("start_date")) |
    (F.col("discounted_price") > F.col("original_price")) |
    ((F.col("status") == "shipped") & (F.col("shipped_date").isNull()))
)
```

### Schema Validation (PySpark)

```python
from pyspark.sql.types import StructType, StructField, IntegerType, StringType

expected_schema = StructType([
    StructField("id", IntegerType(), False),
    StructField("name", StringType(), False),
    StructField("email", StringType(), True),
    StructField("age", IntegerType(), True)
])

def validate_schema(df, expected_schema):
    """Validate DataFrame schema against expected"""
    issues = []
    expected_cols = set([f.name for f in expected_schema.fields])
    actual_cols = set(df.columns)

    missing = expected_cols - actual_cols
    extra = actual_cols - expected_cols

    if missing: issues.append(f"Missing columns: {missing}")
    if extra: issues.append(f"Extra columns: {extra}")

    for field in expected_schema.fields:
        if field.name in df.columns:
            actual_type = dict(df.dtypes)[field.name]
            expected_type = str(field.dataType).lower()
            if actual_type != expected_type:
                issues.append(f"Column {field.name}: expected {expected_type}, got {actual_type}")
    return issues
```

### DataValidator Framework (PySpark)

```python
class DataValidator:
    def __init__(self, df):
        self.df = df
        self.errors = []

    def check_nulls(self, columns, threshold=0.1):
        total = self.df.count()
        for col in columns:
            null_count = self.df.filter(F.col(col).isNull()).count()
            null_pct = null_count / total
            if null_pct > threshold:
                self.errors.append(
                    f"{col}: {null_pct*100:.2f}% nulls (threshold: {threshold*100}%)")

    def check_duplicates(self, key_columns):
        dup_count = (self.df.groupBy(key_columns).count()
            .filter(F.col("count") > 1).count())
        if dup_count > 0:
            self.errors.append(f"Found {dup_count} duplicate keys on {key_columns}")

    def check_range(self, column, min_val=None, max_val=None):
        if min_val is not None:
            invalid = self.df.filter(F.col(column) < min_val).count()
            if invalid > 0:
                self.errors.append(f"{column}: {invalid} values below {min_val}")
        if max_val is not None:
            invalid = self.df.filter(F.col(column) > max_val).count()
            if invalid > 0:
                self.errors.append(f"{column}: {invalid} values above {max_val}")

    def check_referential_integrity(self, ref_df, key_column):
        orphaned = self.df.join(ref_df, key_column, "left_anti").count()
        if orphaned > 0:
            self.errors.append(f"Found {orphaned} orphaned records (no matching {key_column})")

    def get_report(self):
        if self.errors:
            return {"status": "FAILED", "errors": self.errors}
        return {"status": "PASSED", "errors": []}

# Usage
validator = DataValidator(df)
validator.check_nulls(["customer_id", "order_date"], threshold=0.05)
validator.check_duplicates(["order_id"])
validator.check_range("age", min_val=0, max_val=120)
validator.check_referential_integrity(customers_df, "customer_id")
report = validator.get_report()
```

---

## 16. Column Transformations

### Type Casting

```sql
-- SQL
SELECT CAST(price AS DECIMAL(10,2)), CAST(quantity AS INTEGER)
FROM orders;
```

```python
# PySpark
df.withColumn("price_decimal", F.col("price").cast("decimal(10,2)")) \
  .withColumn("quantity_int", F.col("quantity").cast("integer")) \
  .withColumn("timestamp_ts", F.col("timestamp_string").cast("timestamp"))
```

### Array & Struct Operations (PySpark-Specific)

```python
# Split string to array
df.withColumn("tags_array", F.split(F.col("tags"), ","))

# Array operations
df.withColumn("num_tags", F.size(F.col("tags_array")))
df.withColumn("has_premium", F.array_contains(F.col("tags_array"), "premium"))

# Explode array to rows
df.withColumn("tag", F.explode(F.col("tags_array")))
```

### JSON Parsing (PySpark-Specific)

```python
from pyspark.sql.types import StructType, StructField, StringType, IntegerType

json_schema = StructType([
    StructField("name", StringType()),
    StructField("age", IntegerType())
])

df_json = df.withColumn(
    "parsed_json", F.from_json(F.col("json_string"), json_schema)
).withColumn("name", F.col("parsed_json.name")) \
 .withColumn("age", F.col("parsed_json.age"))
```

### Complex Conditional Logic

```sql
-- SQL
SELECT *,
    CASE
        WHEN age < 25 AND income < 30000 THEN 'High Risk'
        WHEN age >= 25 AND age < 40 AND credit_score > 700 THEN 'Low Risk'
        WHEN credit_score < 600 THEN 'High Risk'
        ELSE 'Medium Risk'
    END AS risk_category
FROM customers;
```

```python
# PySpark
df.withColumn(
    "risk_category",
    F.when((F.col("age") < 25) & (F.col("income") < 30000), "High Risk")
    .when((F.col("age") >= 25) & (F.col("age") < 40) &
          (F.col("credit_score") > 700), "Low Risk")
    .when(F.col("credit_score") < 600, "High Risk")
    .otherwise("Medium Risk")
)
```

---

## 17. String Operations

| Operation        | SQL                                        | PySpark                                               |
|------------------|--------------------------------------------|-------------------------------------------------------|
| Upper case       | `UPPER(col)`                               | `F.upper("col")`                                      |
| Lower case       | `LOWER(col)`                               | `F.lower("col")`                                      |
| Title case       | `INITCAP(col)`                             | `F.initcap("col")`                                    |
| Trim             | `TRIM(col)`                                | `F.trim("col")`                                       |
| Left trim        | `LTRIM(col)`                               | `F.ltrim("col")`                                      |
| Right trim       | `RTRIM(col)`                               | `F.rtrim("col")`                                      |
| Concat           | `CONCAT(a, ' ', b)`                        | `F.concat(F.col("a"), F.lit(" "), F.col("b"))`        |
| Concat with sep  | `CONCAT_WS('\|', a, b, c)`                | `F.concat_ws("\|", F.col("a"), F.col("b"), F.col("c"))` |
| Substring        | `SUBSTRING(col, 1, 5)`                     | `F.substring("col", 1, 5)`                            |
| Replace          | `REPLACE(col, 'old', 'new')`               | `F.regexp_replace("col", "old", "new")`               |
| Char replace     | `TRANSLATE(col, 'abc', '123')`             | `F.translate("col", "abc", "123")`                     |
| Regex extract    | `REGEXP_MATCHES(col, pattern)`             | `F.regexp_extract("col", pattern, 1)`                 |
| Length           | `LENGTH(col)`                              | `F.length("col")`                                     |
| Left pad         | `LPAD(col, 10, '0')`                       | `F.lpad("col", 10, "0")`                              |
| Right pad        | `RPAD(col, 10, ' ')`                       | `F.rpad("col", 10, " ")`                              |
| Split            | `SPLIT_PART(col, ',', 1)`                  | `F.split("col", ",").getItem(0)`                      |
| Contains         | `col LIKE '%text%'`                        | `F.col("col").contains("text")`                       |
| Starts with      | `col LIKE 'prefix%'`                       | `F.col("col").startswith("prefix")`                   |

### String Parsing Example

```sql
-- SQL
SELECT
    SPLIT_PART(full_name, ' ', 1) AS first_name,
    SPLIT_PART(full_name, ' ', 2) AS last_name,
    SUBSTRING(email FROM '@(.+)$') AS email_domain
FROM users;
```

```python
# PySpark
df.withColumn("first_name", F.split(F.col("full_name"), " ").getItem(0)) \
  .withColumn("last_name", F.split(F.col("full_name"), " ").getItem(1)) \
  .withColumn("email_domain", F.regexp_extract(F.col("email"), r'@(.+)$', 1)) \
  .withColumn("phone_cleaned", F.regexp_replace(F.col("phone"), r'[^\d]', ''))
```

---

## 18. Date Operations

| Operation        | SQL                                        | PySpark                                         |
|------------------|--------------------------------------------|-------------------------------------------------|
| Current date     | `CURRENT_DATE`                             | `F.current_date()`                              |
| Extract year     | `EXTRACT(YEAR FROM date)`                  | `F.year("date")`                                |
| Extract month    | `EXTRACT(MONTH FROM date)`                 | `F.month("date")`                               |
| Extract day      | `EXTRACT(DAY FROM date)`                   | `F.dayofmonth("date")`                          |
| Day of week      | `EXTRACT(DOW FROM date)`                   | `F.dayofweek("date")`                           |
| Quarter          | `EXTRACT(QUARTER FROM date)`               | `F.quarter("date")`                             |
| Date difference  | `date1 - date2` or `DATEDIFF(d1, d2)`     | `F.datediff("date1", "date2")`                  |
| Add days         | `date + INTERVAL '7 days'`                 | `F.date_add("date", 7)`                         |
| Truncate         | `DATE_TRUNC('month', date)`                | `F.date_trunc("month", "date")`                 |
| To date          | `TO_DATE(str, 'YYYY-MM-DD')`              | `F.to_date("col", "yyyy-MM-dd")`                |
| To timestamp     | `TO_TIMESTAMP(str, format)`                | `F.to_timestamp("col", "yyyy-MM-dd HH:mm:ss")` |
| Format           | `TO_CHAR(date, 'YYYY-MM')`                | `F.date_format("date", "yyyy-MM")`              |

### Date Transformation Example

```sql
-- SQL
SELECT
    order_date,
    EXTRACT(YEAR FROM order_date) AS order_year,
    EXTRACT(MONTH FROM order_date) AS order_month,
    EXTRACT(QUARTER FROM order_date) AS order_quarter,
    CURRENT_DATE - order_date AS days_since_order,
    CASE WHEN EXTRACT(DOW FROM order_date) IN (0, 6) THEN true ELSE false END AS is_weekend
FROM orders;
```

```python
# PySpark
df.withColumn("order_year", F.year("order_date")) \
  .withColumn("order_month", F.month("order_date")) \
  .withColumn("order_quarter", F.quarter("order_date")) \
  .withColumn("days_since_order", F.datediff(F.current_date(), F.col("order_date"))) \
  .withColumn("is_weekend", F.dayofweek("order_date").isin([1, 7]))  # Sun=1, Sat=7
```

---

## 19. Performance Optimization

| Tip                          | SQL                                        | PySpark                                    |
|------------------------------|--------------------------------------------|--------------------------------------------|
| Filter early                 | `WHERE` before `JOIN`                      | `.filter()` before `.join()`               |
| Select needed columns        | Avoid `SELECT *`                           | `.select("col1", "col2")`                  |
| Use EXISTS over COUNT        | `EXISTS (...)` not `COUNT(*) > 0`          | `.join(..., "left_semi")`                  |
| Broadcast small tables       | DB-specific hints                          | `broadcast(small_df)`                      |
| Avoid repeated scans         | CTEs / Temp tables                         | `.cache()` / `.persist()`                  |
| Use UNION ALL over UNION     | `UNION ALL` when dups OK                   | `.union()` (already UNION ALL)             |
| Approximate functions        | N/A                                        | `F.approx_count_distinct()` for large data |
| Index / Partition columns    | `CREATE INDEX` on JOIN/WHERE cols          | `.repartition(200, "key_col")`             |
| Avoid row-by-row processing  | Set-based operations                       | Built-in functions over Python UDFs        |
| Avoid collect on large data  | N/A                                        | Aggregate first, then `.collect()`         |
| CTE materialization          | Consider temp tables for complex CTEs      | `.cache()` intermediate DataFrames         |
| Partition pruning            | Filter on partitioned columns              | Filter on partition columns first          |

### PySpark Performance: Cache Strategically

```python
# ❌ BAD: Cache too early (caching huge unfiltered data)
df_cached = df.cache()
df_filtered = df_cached.filter(F.col("active") == True)  # Only 1% of data

# ✅ GOOD: Cache after filtering
df_filtered = df.filter(F.col("active") == True).cache()
# Now df_filtered is smaller and cached

# Always unpersist when done
df_filtered.unpersist()
```

### PySpark Performance: Avoid UDFs When Possible

```python
# ❌ SLOW: Python UDF (serializes data to Python, processes row-by-row)
from pyspark.sql.types import StringType

def categorize_udf(value):
    if value > 100: return "High"
    elif value > 50: return "Medium"
    else: return "Low"

categorize = F.udf(categorize_udf, StringType())
df.withColumn("category", categorize(F.col("value")))

# ✅ FAST: Built-in functions (runs in JVM, vectorized)
df.withColumn(
    "category",
    F.when(F.col("value") > 100, "High")
    .when(F.col("value") > 50, "Medium")
    .otherwise("Low")
)
```

### PySpark Performance: Partition Pruning

```python
# ❌ BAD: Scans all partitions
df_partitioned.filter(F.col("amount") > 100)

# ✅ GOOD: Filter on partition column first
df_partitioned.filter(
    (F.col("date") == "2024-01-01") &  # Partition column - enables pruning
    (F.col("amount") > 100)
)
```

### PySpark Performance: Optimize Multiple Aggregations

```python
# ❌ BAD: Multiple passes over data
count1 = df.filter(F.col("type") == "A").count()
count2 = df.filter(F.col("type") == "B").count()
count3 = df.filter(F.col("type") == "C").count()

# ✅ GOOD: Single pass
result = df.groupBy("type").count().collect()
counts = {row['type']: row['count'] for row in result}
```

### PySpark Performance: Avoid collect() on Large Data

```python
# ❌ BAD: Brings all data to driver - OOM risk
all_data = df.collect()

# ✅ GOOD: Aggregate first, then collect small result
summary = df.agg(F.sum("amount")).collect()

# Or process iteratively
for row in df.toLocalIterator():
    process(row)
```

### Performance Checklist

**DO:**
1. Cache only filtered/processed data
2. Broadcast small tables in joins (< 10MB)
3. Filter before joins and aggregations
4. Select only needed columns
5. Use built-in functions over UDFs
6. Partition data appropriately (100-1000 partitions)
7. Use approximate functions for large datasets
8. Persist intermediate results used multiple times

**DON'T:**
1. Cache entire large datasets unnecessarily
2. Use collect() on large DataFrames
3. Create too many or too few partitions
4. Use Python UDFs when SQL functions work
5. Join without considering table sizes
6. Process data row-by-row (use batch operations)
7. Ignore data skew
8. Chain many operations without caching intermediate results

---

## 20. Advanced PySpark Patterns (UDFs, Caching, Broadcast)

### Simple UDF

```python
from pyspark.sql.types import StringType

def categorize(value):
    if value > 100: return "High"
    elif value > 50: return "Medium"
    return "Low"

categorize_udf = F.udf(categorize, StringType())
df.withColumn("category", categorize_udf(F.col("amount")))
```

### Pandas UDF (Vectorized - Much Faster)

```python
from pyspark.sql.functions import pandas_udf
from pyspark.sql.types import DoubleType
import pandas as pd
import numpy as np

@pandas_udf(DoubleType())
def vectorized_calc(a: pd.Series, b: pd.Series, c: pd.Series) -> pd.Series:
    return np.sqrt(a**2 + b**2) / c.replace(0, np.nan)

df.withColumn("result", vectorized_calc(F.col("a"), F.col("b"), F.col("c")))
```

### Struct Return Type UDF

```python
from pyspark.sql.types import StructType, StructField, StringType, IntegerType

schema = StructType([
    StructField("parsed_name", StringType()),
    StructField("name_length", IntegerType())
])

@F.udf(schema)
def parse_name(name):
    return {
        "parsed_name": name.upper() if name else None,
        "name_length": len(name) if name else 0
    }

df.withColumn("name_info", parse_name(F.col("name"))) \
  .withColumn("parsed_name", F.col("name_info.parsed_name")) \
  .withColumn("name_length", F.col("name_info.name_length"))
```

### Broadcast Variable with UDF

```python
# For large lookup dictionaries used inside UDFs
lookup_dict = {"A": 1, "B": 2, "C": 3}
broadcast_dict = spark.sparkContext.broadcast(lookup_dict)

@F.udf(IntegerType())
def lookup_value(key):
    return broadcast_dict.value.get(key, 0)

df.withColumn("value", lookup_value(F.col("category")))
```

### Caching Pattern

```python
# Cache when DataFrame will be reused multiple times
df_processed = (df
    .filter(F.col("active") == True)
    .withColumn("score", F.col("metric_a") * 0.7 + F.col("metric_b") * 0.3)
    .cache()
)

# Use multiple times
result1 = df_processed.filter(F.col("score") > 0.5)
result2 = df_processed.groupBy("category").agg(F.avg("score"))

# Always unpersist when done
df_processed.unpersist()
```

### Accumulators for Monitoring

```python
null_counter = spark.sparkContext.accumulator(0)

def count_nulls(value):
    global null_counter
    if value is None:
        null_counter.add(1)
    return value

count_nulls_udf = F.udf(count_nulls, StringType())
df.withColumn("checked", count_nulls_udf(F.col("name"))).count()
print(f"Null values found: {null_counter.value}")
```

### Repartition vs Coalesce

```python
# repartition: Full shuffle - use when increasing partitions or for even distribution
df.repartition(200, "customer_id")  # 200 partitions by customer_id

# coalesce: No shuffle - use ONLY when reducing partitions
df.coalesce(10)  # Reduce to 10 partitions (no shuffle)

# ❌ BAD: coalesce to increase partitions (doesn't shuffle!)
df.coalesce(200)  # Won't actually increase partitions

# ✅ GOOD: repartition to increase partitions
df.repartition(200)
```

---

## 21. Quick Translation Guide

| SQL                            | PySpark                                           |
|--------------------------------|---------------------------------------------------|
| `SELECT * FROM table`          | `df.select("*")`                                  |
| `SELECT col1, col2`           | `df.select("col1", "col2")`                       |
| `WHERE condition`             | `df.filter(condition)`                             |
| `GROUP BY col`                | `df.groupBy("col")`                               |
| `ORDER BY col DESC`           | `df.orderBy(F.col("col").desc())`                 |
| `LIMIT 10`                    | `df.limit(10)`                                    |
| `DISTINCT`                    | `df.distinct()`                                   |
| `CASE WHEN... THEN... END`    | `F.when(...).otherwise(...)`                       |
| `ROW_NUMBER() OVER (...)`     | `F.row_number().over(Window...)`                   |
| `LAG(col, 1)`                 | `F.lag("col", 1).over(Window...)`                  |
| `LEAD(col, 1)`                | `F.lead("col", 1).over(Window...)`                 |
| `COUNT(DISTINCT col)`         | `F.countDistinct("col")`                           |
| `SUM(col)`                    | `F.sum("col")`                                    |
| `AVG(col)`                    | `F.avg("col")` or `F.mean("col")`                 |
| `COALESCE(a, b, c)`           | `F.coalesce(F.col("a"), F.col("b"), F.col("c"))`  |
| `CONCAT(a, b)`                | `F.concat(F.col("a"), F.col("b"))`                |
| `UPPER(col)`                  | `F.upper("col")`                                  |
| `SUBSTRING(col, 1, 5)`        | `F.substring("col", 1, 5)`                        |
| `IN (val1, val2)`             | `F.col("col").isin([val1, val2])`                  |
| `NOT IN (...)`                | `~F.col("col").isin([...])`                        |
| `IS NULL`                     | `F.col("col").isNull()`                            |
| `IS NOT NULL`                 | `F.col("col").isNotNull()`                         |
| `BETWEEN a AND b`             | `F.col("col").between(a, b)`                       |
| `LIKE '%pattern%'`            | `F.col("col").like("%pattern%")`                   |
| `LEFT JOIN`                   | `df1.join(df2, "key", "left")`                     |
| `NOT EXISTS`                  | `df1.join(df2, "key", "left_anti")`                |
| `EXISTS`                      | `df1.join(df2, "key", "left_semi")`                |
| `UNION ALL`                   | `df1.union(df2)`                                   |
| `EXCEPT`                      | `df1.subtract(df2)`                                |

---

## 22. Syntax Quick Reference

### Window Function Syntax

```sql
-- SQL
function_name([arguments]) OVER (
    [PARTITION BY partition_columns]
    [ORDER BY sort_columns]
    [ROWS|RANGE BETWEEN frame_start AND frame_end]
)
```

```python
# PySpark
from pyspark.sql.window import Window

window_spec = (Window
    .partitionBy("partition_col")
    .orderBy("sort_col")
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)
)
F.sum("col").over(window_spec)
```

### CTE Syntax

```sql
-- SQL
WITH cte_name AS (
    SELECT ...
),
cte_name2 AS (
    SELECT ... FROM cte_name ...
)
SELECT ... FROM cte_name2;
```

```python
# PySpark equivalent: chain transformations or use temp views
df_cte1 = df.filter(...)
df_cte2 = df_cte1.join(...)
result = df_cte2.select(...)

# Or register as temp views for Spark SQL
df.createOrReplaceTempView("table_name")
spark.sql("WITH cte AS (...) SELECT ...")
```

### Recursive CTE Syntax

```sql
-- SQL
WITH RECURSIVE cte_name AS (
    -- Anchor (base case)
    SELECT ...

    UNION [ALL]

    -- Recursive (iterative case)
    SELECT ...
    FROM cte_name
    WHERE termination_condition
)
SELECT ... FROM cte_name;
```

```python
# PySpark: Iterative loop pattern (no native recursive support in DataFrame API)
current = df.filter(base_condition).withColumn("level", F.lit(0))
result = current

for i in range(1, max_depth):
    next_level = current.join(df, join_condition).withColumn("level", F.lit(i))
    if next_level.count() == 0:
        break
    result = result.union(next_level)
    current = next_level
```

---

## 23. Interview Pattern Recognition

| Interview Phrase                 | SQL Pattern                              | PySpark Pattern                                           |
|----------------------------------|------------------------------------------|-----------------------------------------------------------|
| "for each group"                 | `PARTITION BY`                           | `Window.partitionBy()`                                    |
| "top 3"                          | `ROW_NUMBER() WHERE rn <= 3`             | `F.row_number().over(...).filter(rn <= 3)`                |
| "compared to average"            | `AVG() OVER (PARTITION BY)`              | `F.avg().over(Window.partitionBy())`                      |
| "consecutive" / "streak"         | Recursive CTE or ROW_NUMBER trick        | `lag()` + difference check or row_number                  |
| "running total"                  | `SUM() OVER (ORDER BY)`                  | `F.sum().over(rowsBetween(unboundedPreceding, currentRow))` |
| "fill missing dates"             | Recursive CTE + LEFT JOIN                | Generate date series + left join                          |
| "remove duplicates"              | `ROW_NUMBER() WHERE rn = 1`              | `dropDuplicates()` or `row_number() == 1`                 |
| "previous value"                 | `LAG()`                                  | `F.lag().over(Window...)`                                 |
| "pivot table"                    | `CASE WHEN + GROUP BY`                   | `groupBy().pivot().agg()`                                 |
| "never did X"                    | `NOT EXISTS` / `LEFT JOIN NULL`          | `.join(..., "left_anti")`                                 |
| "hierarchy" / "reporting chain"  | Recursive CTE                            | Iterative joins or Spark SQL recursive CTE                |
| "in every category"              | `HAVING COUNT(DISTINCT) = total`         | `groupBy + countDistinct + filter`                        |
| "friends of friends" / "network" | Recursive CTE (graph traversal)          | GraphFrames or iterative joins                            |
| "shortest path"                  | Recursive CTE with depth limit           | GraphFrames `shortestPaths()`                             |
| "unique values"                  | `DISTINCT`                               | `distinct()` or `dropDuplicates()`                        |
| "similar records"                | `LEVENSHTEIN()` or fuzzy match           | `F.levenshtein()` self-join                               |

### Quick Decision Tree

```
WHICH SQL/PYSPARK PATTERN DO I NEED?

Need top/bottom N?
  -> ROW_NUMBER() / RANK() / DENSE_RANK()
  -> F.row_number().over(Window...)

Compare to previous/next row?
  -> LAG() / LEAD()
  -> F.lag() / F.lead()

Running total or moving average?
  -> SUM/AVG() OVER (ORDER BY ... ROWS BETWEEN)
  -> F.sum().over(Window.rowsBetween(...))

Compare to group aggregate?
  -> Window function with PARTITION BY
  -> F.avg().over(Window.partitionBy())

Find missing values in sequence?
  -> Recursive CTE to generate series + LEFT JOIN
  -> Generate series + left_anti join

Traverse hierarchy or graph?
  -> Recursive CTE
  -> Iterative joins or GraphFrames

Need to pivot (rows to columns)?
  -> CASE WHEN with GROUP BY
  -> groupBy().pivot().agg()

Find duplicates?
  -> GROUP BY ... HAVING COUNT(*) > 1
  -> groupBy().agg(count).filter(> 1)

Remove duplicates?
  -> ROW_NUMBER() ... WHERE rn = 1
  -> dropDuplicates() or row_number() == 1

Find records NOT in another table?
  -> NOT EXISTS or LEFT JOIN ... WHERE NULL
  -> .join(..., "left_anti")

Statistical analysis?
  -> PERCENTILE_CONT, STDDEV, VARIANCE
  -> percentile_approx, stddev, variance
```

---

## 24. Common Gotchas

| Gotcha                           | SQL Solution                       | PySpark Solution                          |
|----------------------------------|------------------------------------|-------------------------------------------|
| NULLs in NOT IN                  | `WHERE col IS NOT NULL`            | Filter nulls before `.isin()`             |
| Division by zero                 | `NULLIF(denominator, 0)`           | `F.when(F.col("d") != 0, ...)`           |
| String concat with NULL          | `COALESCE(col, '')`               | `F.coalesce(F.col("col"), F.lit(""))`     |
| Aggregate in WHERE               | Use `HAVING`                       | `.filter()` after `.agg()`                |
| Window function in WHERE         | Wrap in subquery/CTE               | `.withColumn()` then `.filter()`          |
| Column ambiguity in joins        | Table aliases `t1.col`             | `df.alias("a")` + `F.col("a.col")`       |
| Top N per group (not overall)    | Window function, not `LIMIT`       | Window function, not `.limit()`           |
| Date arithmetic across timezones | Normalize to UTC first             | Convert to UTC before operations          |
| GROUP BY with NULL keys          | NULLs form their own group         | Same behavior in PySpark                  |
| Self-join Cartesian explosion    | Add proper join condition          | Add `id < id` or `id != id` condition     |
| Recursive CTE infinite loop      | Add depth limit                    | Loop with `max_depth` or count check      |
| VARCHAR comparison case-sensitive | Use `LOWER()` or `ILIKE`           | Use `F.lower()` before comparison         |
| Using Python UDF unnecessarily   | N/A                                | Use built-in functions instead            |
| Caching before filtering         | N/A                                | Filter first, then `.cache()`             |
| Not unpersisting cached data     | N/A                                | Always call `.unpersist()` when done      |
| Too many/few partitions          | N/A                                | Aim for 100-1000 partitions               |
| collect() on large DataFrame     | N/A                                | Aggregate first, then `.collect()`        |
| Not broadcasting small tables    | N/A                                | Use `broadcast()` for tables < 10MB       |
| Ignoring data skew               | N/A                                | Salt keys or repartition                  |
| Type mismatch in operations      | Explicit `CAST()`                  | Explicit `.cast()` before operations      |

---

## 25. Merge & Upsert

### SQL MERGE (Standard / Delta Lake SQL)

```sql
-- MERGE: Insert new rows, update existing rows, optionally delete
-- Works in databases that support MERGE (SQL Server, Oracle, PostgreSQL 15+, Delta Lake SQL)

MERGE INTO target_table AS t
USING source_table AS s
ON t.id = s.id

-- When a match is found → UPDATE
WHEN MATCHED AND s.is_deleted = 1 THEN
    DELETE

WHEN MATCHED THEN
    UPDATE SET
        t.name = s.name,
        t.email = s.email,
        t.updated_at = CURRENT_TIMESTAMP

-- When no match in target → INSERT
WHEN NOT MATCHED THEN
    INSERT (id, name, email, created_at, updated_at)
    VALUES (s.id, s.name, s.email, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);
```

```sql
-- Simple UPSERT using INSERT ... ON CONFLICT (PostgreSQL)
INSERT INTO target_table (id, name, email, updated_at)
VALUES (1, 'Alice', 'alice@example.com', CURRENT_TIMESTAMP)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    email = EXCLUDED.email,
    updated_at = CURRENT_TIMESTAMP;
```

```sql
-- Batch UPSERT from source table (PostgreSQL)
INSERT INTO target_table (id, name, email, updated_at)
SELECT id, name, email, CURRENT_TIMESTAMP
FROM source_table
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    email = EXCLUDED.email,
    updated_at = CURRENT_TIMESTAMP;
```

```sql
-- MySQL equivalent: INSERT ... ON DUPLICATE KEY UPDATE
INSERT INTO target_table (id, name, email, updated_at)
VALUES (1, 'Alice', 'alice@example.com', NOW())
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    email = VALUES(email),
    updated_at = NOW();
```

### PySpark MERGE — Delta Lake

```python
# PySpark: Delta Lake MERGE (preferred approach)
from delta.tables import DeltaTable

target = DeltaTable.forPath(spark, "/path/to/target")
source = spark.read.table("source_table")

target.alias("t").merge(
    source.alias("s"),
    "t.id = s.id"
).whenMatchedUpdate(
    set={
        "name": "s.name",
        "email": "s.email",
        "updated_at": "current_timestamp()"
    }
).whenNotMatchedInsert(
    values={
        "id": "s.id",
        "name": "s.name",
        "email": "s.email",
        "created_at": "current_timestamp()",
        "updated_at": "current_timestamp()"
    }
).execute()
```

```python
# Delta Lake MERGE with DELETE condition
target.alias("t").merge(
    source.alias("s"),
    "t.id = s.id"
).whenMatchedDelete(
    condition="s.is_deleted = true"
).whenMatchedUpdate(
    condition="s.is_deleted = false",
    set={
        "name": "s.name",
        "email": "s.email",
        "updated_at": "current_timestamp()"
    }
).whenNotMatchedInsert(
    condition="s.is_deleted = false",
    values={
        "id": "s.id",
        "name": "s.name",
        "email": "s.email",
        "created_at": "current_timestamp()",
        "updated_at": "current_timestamp()"
    }
).execute()
```

```python
# Delta Lake MERGE with updateAll / insertAll (schema must match)
target.alias("t").merge(
    source.alias("s"),
    "t.id = s.id"
).whenMatchedUpdateAll(
).whenNotMatchedInsertAll(
).execute()
```

### PySpark UPSERT — Without Delta Lake (Manual Approach)

```python
# Manual upsert using left anti join + union
# Step 1: Identify new rows (in source but not in target)
new_rows = source.join(target, on="id", how="left_anti")

# Step 2: Identify existing rows to update (take source version)
updated_rows = source.join(target.select("id"), on="id", how="inner")

# Step 3: Identify unchanged rows (in target but not in source)
unchanged_rows = target.join(source.select("id"), on="id", how="left_anti")

# Step 4: Combine
result = unchanged_rows.unionByName(updated_rows).unionByName(new_rows)

# Step 5: Overwrite target
result.write.mode("overwrite").saveAsTable("target_table")
```

```python
# Alternative manual upsert: coalesce approach with full outer join
from pyspark.sql import functions as F

result = source.alias("s").join(
    target.alias("t"),
    on="id",
    how="full_outer"
).select(
    F.coalesce(F.col("s.id"), F.col("t.id")).alias("id"),
    # Source values take priority (upsert), fall back to target
    F.coalesce(F.col("s.name"), F.col("t.name")).alias("name"),
    F.coalesce(F.col("s.email"), F.col("t.email")).alias("email"),
    F.when(F.col("s.id").isNotNull(), F.current_timestamp())
     .otherwise(F.col("t.updated_at")).alias("updated_at"),
    F.coalesce(F.col("t.created_at"), F.current_timestamp()).alias("created_at")
)
```

### Merge/Upsert Quick Reference

| Operation                    | SQL                                        | PySpark (Delta Lake)                       | PySpark (No Delta)                    |
|------------------------------|--------------------------------------------|--------------------------------------------|---------------------------------------|
| Upsert (insert or update)   | `MERGE INTO ... WHEN MATCHED / NOT MATCHED`| `DeltaTable.merge().whenMatched...`        | `left_anti` join + `union`            |
| Insert if not exists         | `INSERT ... ON CONFLICT DO NOTHING`        | `.whenNotMatchedInsert()`                  | `left_anti` join + `union`            |
| Conditional update           | `WHEN MATCHED AND condition THEN UPDATE`   | `.whenMatchedUpdate(condition=...)`        | Filter + join + union                 |
| Delete on match              | `WHEN MATCHED THEN DELETE`                 | `.whenMatchedDelete()`                     | `left_anti` join (exclude matched)    |
| Full sync (mirror source)    | MERGE with INSERT + UPDATE + DELETE        | `whenMatched` + `whenNotMatched` + delete  | Overwrite entire table                |

---

## 26. Type 2 Slowly Changing Dimensions (SCD2)

> **SCD2 Pattern**: Track historical changes by creating new rows for each change.
> Each row has `effective_date`, `end_date`, and `is_current` flag.

### Understanding SCD2

```
Dimension table tracks FULL HISTORY of changes:

| customer_id | name    | city      | effective_date | end_date   | is_current |
|-------------|---------|-----------|----------------|------------|------------|
| 101         | Alice   | New York  | 2023-01-01     | 2024-03-14 | false      |
| 101         | Alice   | Chicago   | 2024-03-15     | 9999-12-31 | true       |
| 102         | Bob     | Boston    | 2023-06-01     | 9999-12-31 | true       |

When Alice moves from New York to Chicago:
  - Old row: end_date updated to day before change, is_current → false
  - New row: inserted with new city, effective_date = change date, end_date = 9999-12-31, is_current = true
```

### SQL: SCD2 Implementation with MERGE

```sql
-- SQL MERGE for SCD Type 2
-- source_updates contains incoming changes
-- dim_customer is the SCD2 dimension table

-- Step 1: Identify changed records
WITH changes AS (
    SELECT
        s.customer_id,
        s.name,
        s.city,
        s.email
    FROM source_updates s
    INNER JOIN dim_customer t
        ON s.customer_id = t.customer_id
        AND t.is_current = true
    WHERE s.name != t.name
       OR s.city != t.city
       OR s.email != t.email
)

-- Step 2: MERGE to expire old rows and insert new ones
MERGE INTO dim_customer AS t
USING (
    -- Union: rows to expire + new version rows + brand new customers
    SELECT customer_id, name, city, email,
           CAST(CURRENT_DATE AS DATE) AS effective_date,
           CAST('9999-12-31' AS DATE) AS end_date,
           true AS is_current,
           'insert' AS merge_action
    FROM changes

    UNION ALL

    SELECT customer_id, name, city, email,
           CAST(CURRENT_DATE AS DATE) AS effective_date,
           CAST('9999-12-31' AS DATE) AS end_date,
           true AS is_current,
           'insert' AS merge_action
    FROM source_updates s
    WHERE NOT EXISTS (
        SELECT 1 FROM dim_customer d
        WHERE d.customer_id = s.customer_id
    )
) AS s
ON t.customer_id = s.customer_id
   AND t.is_current = true
   AND s.merge_action = 'insert'

-- Expire old current record
WHEN MATCHED THEN
    UPDATE SET
        t.is_current = false,
        t.end_date = CURRENT_DATE - INTERVAL '1 day'

-- Insert new version / new customer
WHEN NOT MATCHED THEN
    INSERT (customer_id, name, city, email, effective_date, end_date, is_current)
    VALUES (s.customer_id, s.name, s.city, s.email,
            s.effective_date, s.end_date, s.is_current);
```

```sql
-- Simpler SQL SCD2 approach (two-step, no MERGE)
-- Step 1: Expire changed rows
UPDATE dim_customer t
SET
    is_current = false,
    end_date = CURRENT_DATE - INTERVAL '1 day'
WHERE t.is_current = true
  AND EXISTS (
      SELECT 1 FROM source_updates s
      WHERE s.customer_id = t.customer_id
        AND (s.name != t.name OR s.city != t.city OR s.email != t.email)
  );

-- Step 2: Insert new versions of changed rows
INSERT INTO dim_customer (customer_id, name, city, email, effective_date, end_date, is_current)
SELECT
    s.customer_id, s.name, s.city, s.email,
    CURRENT_DATE,
    CAST('9999-12-31' AS DATE),
    true
FROM source_updates s
WHERE EXISTS (
    -- Row was just expired (changed record)
    SELECT 1 FROM dim_customer t
    WHERE t.customer_id = s.customer_id
      AND t.is_current = false
      AND t.end_date = CURRENT_DATE - INTERVAL '1 day'
)
OR NOT EXISTS (
    -- Brand new customer
    SELECT 1 FROM dim_customer t
    WHERE t.customer_id = s.customer_id
);
```

### PySpark: SCD2 with Delta Lake

```python
from delta.tables import DeltaTable
from pyspark.sql import functions as F

# Load target dimension and source updates
dim_table = DeltaTable.forPath(spark, "/path/to/dim_customer")
dim_df = dim_table.toDF()
source_df = spark.read.table("source_updates")

# Step 1: Identify changed records (compare source vs current dimension)
current_dim = dim_df.filter(F.col("is_current") == True)

changed = source_df.alias("s").join(
    current_dim.alias("t"),
    on="customer_id",
    how="inner"
).filter(
    (F.col("s.name") != F.col("t.name")) |
    (F.col("s.city") != F.col("t.city")) |
    (F.col("s.email") != F.col("t.email"))
).select("s.*")

# Step 2: Identify new customers (not in dimension at all)
new_customers = source_df.join(
    dim_df.select("customer_id").distinct(),
    on="customer_id",
    how="left_anti"
)

# Step 3: Build staged updates for MERGE
# Rows to insert (new versions of changed + brand new)
new_rows = changed.unionByName(new_customers).withColumn(
    "effective_date", F.current_date()
).withColumn(
    "end_date", F.lit("9999-12-31").cast("date")
).withColumn(
    "is_current", F.lit(True)
).withColumn(
    "merge_key", F.lit(None).cast("long")  # dummy key to force NOT MATCHED
)

# Rows to expire (use real key so they MATCH)
expire_rows = changed.select(
    F.col("customer_id").alias("merge_key"),
    "customer_id", "name", "city", "email"
).withColumn("effective_date", F.current_date()
).withColumn("end_date", F.lit("9999-12-31").cast("date")
).withColumn("is_current", F.lit(True))

# Combine: expire rows (will match) + new rows (will not match)
staged = expire_rows.unionByName(new_rows)

# Step 4: Execute MERGE
dim_table.alias("t").merge(
    staged.alias("s"),
    "t.customer_id = s.merge_key AND t.is_current = true"
).whenMatchedUpdate(
    set={
        "is_current": "false",
        "end_date": "current_date() - interval 1 day"
    }
).whenNotMatchedInsert(
    values={
        "customer_id": "s.customer_id",
        "name": "s.name",
        "city": "s.city",
        "email": "s.email",
        "effective_date": "s.effective_date",
        "end_date": "s.end_date",
        "is_current": "s.is_current"
    }
).execute()
```

### PySpark: SCD2 Without Delta Lake (Manual Approach)

```python
from pyspark.sql import functions as F

# Load existing dimension and source
dim_df = spark.read.parquet("/path/to/dim_customer")
source_df = spark.read.table("source_updates")

# Current records from dimension
current_dim = dim_df.filter(F.col("is_current") == True)
historical_dim = dim_df.filter(F.col("is_current") == False)

# Step 1: Identify what changed
joined = current_dim.alias("t").join(
    source_df.alias("s"),
    on="customer_id",
    how="inner"
).filter(
    (F.col("s.name") != F.col("t.name")) |
    (F.col("s.city") != F.col("t.city")) |
    (F.col("s.email") != F.col("t.email"))
)

changed_ids = joined.select(F.col("t.customer_id"))

# Step 2: Expire old rows (set is_current=false, end_date=yesterday)
expired_rows = current_dim.join(
    changed_ids, on="customer_id", how="inner"
).withColumn(
    "is_current", F.lit(False)
).withColumn(
    "end_date", F.date_sub(F.current_date(), 1)
)

# Step 3: Create new version rows for changed records
new_versions = source_df.join(
    changed_ids, on="customer_id", how="inner"
).withColumn(
    "effective_date", F.current_date()
).withColumn(
    "end_date", F.lit("9999-12-31").cast("date")
).withColumn(
    "is_current", F.lit(True)
)

# Step 4: Identify brand new customers
new_customers = source_df.join(
    dim_df.select("customer_id").distinct(),
    on="customer_id",
    how="left_anti"
).withColumn(
    "effective_date", F.current_date()
).withColumn(
    "end_date", F.lit("9999-12-31").cast("date")
).withColumn(
    "is_current", F.lit(True)
)

# Step 5: Unchanged current rows
unchanged = current_dim.join(
    changed_ids, on="customer_id", how="left_anti"
)

# Step 6: Combine everything
final_dim = (
    historical_dim        # all historical rows (untouched)
    .unionByName(expired_rows)   # newly expired rows
    .unionByName(unchanged)      # current rows that didn't change
    .unionByName(new_versions)   # new versions of changed records
    .unionByName(new_customers)  # brand new customers
)

# Step 7: Write out
final_dim.write.mode("overwrite").parquet("/path/to/dim_customer")
```

### SCD2 Query Patterns

```sql
-- SQL: Get current state of a customer
SELECT * FROM dim_customer
WHERE customer_id = 101
  AND is_current = true;

-- SQL: Get customer state at a specific point in time
SELECT * FROM dim_customer
WHERE customer_id = 101
  AND effective_date <= '2023-06-15'
  AND end_date >= '2023-06-15';

-- SQL: Get full history of a customer
SELECT * FROM dim_customer
WHERE customer_id = 101
ORDER BY effective_date;

-- SQL: Count how many times a customer changed
SELECT customer_id, COUNT(*) - 1 AS num_changes
FROM dim_customer
GROUP BY customer_id
HAVING COUNT(*) > 1;
```

```python
# PySpark: Get current state of a customer
dim_df.filter(
    (F.col("customer_id") == 101) &
    (F.col("is_current") == True)
)

# PySpark: Get customer state at a specific point in time
dim_df.filter(
    (F.col("customer_id") == 101) &
    (F.col("effective_date") <= "2023-06-15") &
    (F.col("end_date") >= "2023-06-15")
)

# PySpark: Get full history of a customer
dim_df.filter(
    F.col("customer_id") == 101
).orderBy("effective_date")

# PySpark: Count how many times a customer changed
dim_df.groupBy("customer_id").count().filter(
    F.col("count") > 1
).withColumn("num_changes", F.col("count") - 1)
```

### SCD2 Quick Reference

| Operation                   | SQL                                               | PySpark (Delta Lake)                        | PySpark (No Delta)                        |
|-----------------------------|----------------------------------------------------|---------------------------------------------|-------------------------------------------|
| Expire old record           | `UPDATE SET is_current=false, end_date=yesterday`  | `.whenMatchedUpdate(set={...})`             | `.withColumn("is_current", lit(False))`   |
| Insert new version          | `INSERT ... effective_date=today, end_date=9999`   | `.whenNotMatchedInsert(values={...})`       | `.unionByName(new_versions)`              |
| Detect changes              | `JOIN + WHERE col != col`                          | `.join().filter(col != col)`                | `.join().filter(col != col)`              |
| Point-in-time query         | `WHERE eff_date <= X AND end_date >= X`            | `.filter((eff <= X) & (end >= X))`          | Same                                      |
| Get current records         | `WHERE is_current = true`                          | `.filter(is_current == True)`               | Same                                      |
| Full history                | `ORDER BY effective_date`                          | `.orderBy("effective_date")`                | Same                                      |
| Merge key trick (Delta)     | N/A                                                | `merge_key=None` for inserts                | N/A                                       |

---

**This reference covers 95%+ of SQL-PySpark interview problems. Keep it handy during practice!**
