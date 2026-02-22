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
12. Pattern Matching & Sequences
13. Data Quality & Validation
14. String Operations
15. Date Operations
16. Performance Optimization
17. Quick Translation Guide
18. Interview Pattern Recognition
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
    SUM(CASE WHEN salary > 100000 THEN 1 ELSE 0 END) AS high_earners
FROM employees
GROUP BY department;
```

```python
# PySpark
df.groupBy("department").agg(
    F.count("*").alias("total_employees"),
    F.sum(F.when(F.col("salary") > 100000, 1).otherwise(0)).alias("high_earners")
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

### Statistical Aggregations

```sql
-- SQL
SELECT
    department,
    AVG(salary) AS mean,
    STDDEV(salary) AS stddev,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary) AS median
FROM employees
GROUP BY department;
```

```python
# PySpark
df.groupBy("department").agg(
    F.mean("salary").alias("mean"),
    F.stddev("salary").alias("stddev"),
    F.expr("percentile_approx(salary, 0.5)").alias("median")
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

### Common Pitfall

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

### Running Total

```sql
-- SQL
SELECT
    date, amount,
    SUM(amount) OVER (ORDER BY date) AS running_total
FROM transactions;
```

```python
# PySpark
window_spec = Window.orderBy("date").rowsBetween(
    Window.unboundedPreceding, Window.currentRow
)
df.withColumn("running_total", F.sum("amount").over(window_spec))
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

# Or using lag/lead
window_spec = Window.partitionBy("device_id").orderBy("event_time")
gaps = (df
    .withColumn("next_event", F.lead("event_time").over(window_spec))
    .withColumn("gap_seconds",
                F.unix_timestamp("next_event") - F.unix_timestamp("event_time"))
    .filter(F.col("gap_seconds") > 3600)
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

---

## 8. Deduplication

### Simple Distinct

```sql
-- SQL
SELECT DISTINCT col1, col2 FROM table_name;
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
        F.collect_list("user_id").alias("duplicate_ids")
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
```

```python
# PySpark
df.groupBy("product_name").pivot("month").agg(F.sum("sales"))

# With specific values (faster)
df.groupBy("product_name").pivot("month", [1, 2, 3]).agg(F.sum("sales"))
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
```

```python
# PySpark
window_spec = Window.partitionBy("department")

above_avg = (df
    .withColumn("dept_avg", F.avg("salary").over(window_spec))
    .filter(F.col("salary") > F.col("dept_avg"))
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

### Employee Reporting Chain

```sql
-- SQL: Recursive CTE
WITH RECURSIVE chain AS (
    SELECT emp_id, name, manager_id, 0 AS level
    FROM employees WHERE emp_id = 123

    UNION ALL

    SELECT e.emp_id, e.name, e.manager_id, c.level + 1
    FROM employees e
    JOIN chain c ON c.manager_id = e.emp_id
)
SELECT * FROM chain ORDER BY level;
```

```python
# PySpark: No native recursive CTE support
# Approach: Use iterative joins or GraphFrames

# Iterative approach
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

# Alternative: Use Spark SQL which supports recursive CTEs in newer versions
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

---

## 12. Pattern Matching & Sequences

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

## 13. Data Quality & Validation

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
```

---

## 14. String Operations

| Operation        | SQL                                        | PySpark                                               |
|------------------|--------------------------------------------|-------------------------------------------------------|
| Upper case       | `UPPER(col)`                               | `F.upper("col")`                                      |
| Lower case       | `LOWER(col)`                               | `F.lower("col")`                                      |
| Title case       | `INITCAP(col)`                             | `F.initcap("col")`                                    |
| Trim             | `TRIM(col)`                                | `F.trim("col")`                                       |
| Concat           | `CONCAT(a, ' ', b)`                        | `F.concat(F.col("a"), F.lit(" "), F.col("b"))`        |
| Concat with sep  | `CONCAT_WS('\|', a, b, c)`                | `F.concat_ws("\|", F.col("a"), F.col("b"), F.col("c"))` |
| Substring        | `SUBSTRING(col, 1, 5)`                     | `F.substring("col", 1, 5)`                            |
| Replace          | `REPLACE(col, 'old', 'new')`               | `F.regexp_replace("col", "old", "new")`               |
| Regex extract    | `REGEXP_MATCHES(col, pattern)`             | `F.regexp_extract("col", pattern, 1)`                 |
| Length           | `LENGTH(col)`                              | `F.length("col")`                                     |
| Left pad         | `LPAD(col, 10, '0')`                       | `F.lpad("col", 10, "0")`                              |
| Split            | `SPLIT_PART(col, ',', 1)`                  | `F.split("col", ",").getItem(0)`                      |
| Contains         | `col LIKE '%text%'`                        | `F.col("col").contains("text")`                       |
| Starts with      | `col LIKE 'prefix%'`                       | `F.col("col").startswith("prefix")`                   |

---

## 15. Date Operations

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

---

## 16. Performance Optimization

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

---

## 17. Quick Translation Guide

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

---

## 18. Interview Pattern Recognition

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

---

## Common Gotchas

| Gotcha                         | SQL Solution                       | PySpark Solution                          |
|--------------------------------|------------------------------------|-------------------------------------------|
| NULLs in NOT IN                | `WHERE col IS NOT NULL`            | Filter nulls before `.isin()`             |
| Division by zero               | `NULLIF(denominator, 0)`           | `F.when(F.col("d") != 0, ...)`           |
| String concat with NULL        | `COALESCE(col, '')`               | `F.coalesce(F.col("col"), F.lit(""))`     |
| Aggregate in WHERE             | Use `HAVING`                       | `.filter()` after `.agg()`                |
| Window function in WHERE       | Wrap in subquery/CTE               | `.withColumn()` then `.filter()`          |
| Column ambiguity in joins      | Table aliases `t1.col`             | `df.alias("a")` + `F.col("a.col")`       |
| Top N per group (not overall)  | Window function, not `LIMIT`       | Window function, not `.limit()`           |

---

**This reference covers 95% of SQL-PySpark interview problems. Keep it handy during practice!**
