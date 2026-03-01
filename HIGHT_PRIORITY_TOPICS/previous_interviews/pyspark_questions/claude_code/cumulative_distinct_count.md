# PySpark Implementation: Cumulative Distinct Count

## Problem Statement

Given a dataset of daily user logins, compute the **running (cumulative) count of distinct users** up to each date. This is different from a simple daily unique count — on each date, the answer should reflect the total number of **unique users ever seen** from the beginning up to and including that date.

### Sample Data

```
login_date   user_id
2025-01-01   U001
2025-01-01   U002
2025-01-01   U003
2025-01-02   U002
2025-01-02   U004
2025-01-03   U001
2025-01-03   U004
2025-01-03   U005
2025-01-04   U005
2025-01-04   U006
```

### Expected Output

| login_date | daily_unique | cumulative_unique |
|------------|-------------|-------------------|
| 2025-01-01 | 3           | 3                 |
| 2025-01-02 | 2           | 4                 |
| 2025-01-03 | 3           | 5                 |
| 2025-01-04 | 2           | 6                 |

**Explanation:**
- Jan 01: U001, U002, U003 → 3 new users, cumulative = 3
- Jan 02: U002 (seen), U004 (new) → daily = 2, cumulative = 4
- Jan 03: U001 (seen), U004 (seen), U005 (new) → daily = 3, cumulative = 5
- Jan 04: U005 (seen), U006 (new) → daily = 2, cumulative = 6

---

## Why This Is Tricky

`countDistinct` doesn't work with window functions:
```python
# THIS DOES NOT WORK:
countDistinct("user_id").over(Window.orderBy("login_date").rowsBetween(...))
# Error: countDistinct is not supported in window functions
```

You need an alternative approach.

---

## Method 1: Find First Appearance, Then Cumulative Sum

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, min as spark_min, count, countDistinct, \
    sum as spark_sum
from pyspark.sql.window import Window

# Initialize Spark session
spark = SparkSession.builder.appName("CumulativeDistinct").getOrCreate()

# Sample data
data = [
    ("2025-01-01", "U001"), ("2025-01-01", "U002"), ("2025-01-01", "U003"),
    ("2025-01-02", "U002"), ("2025-01-02", "U004"),
    ("2025-01-03", "U001"), ("2025-01-03", "U004"), ("2025-01-03", "U005"),
    ("2025-01-04", "U005"), ("2025-01-04", "U006")
]
columns = ["login_date", "user_id"]
df = spark.createDataFrame(data, columns)

# Step 1: Find each user's first login date
first_seen = df.groupBy("user_id").agg(
    spark_min("login_date").alias("first_login")
)

first_seen.orderBy("first_login", "user_id").show()

# Step 2: Count new users per date
new_users_per_day = first_seen.groupBy("first_login").agg(
    count("*").alias("new_users")
).withColumnRenamed("first_login", "login_date")

# Step 3: Get daily unique counts
daily_unique = df.groupBy("login_date").agg(
    countDistinct("user_id").alias("daily_unique")
)

# Step 4: Join and compute cumulative sum
window_date = Window.orderBy("login_date") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

result = daily_unique.join(new_users_per_day, on="login_date", how="left") \
    .fillna({"new_users": 0}) \
    .withColumn("cumulative_unique", spark_sum("new_users").over(window_date)) \
    .select("login_date", "daily_unique", "cumulative_unique") \
    .orderBy("login_date")

result.show()
```

### Step-by-Step Explanation

#### Step 1: First Login Per User

| user_id | first_login |
|---------|-------------|
| U001    | 2025-01-01  |
| U002    | 2025-01-01  |
| U003    | 2025-01-01  |
| U004    | 2025-01-02  |
| U005    | 2025-01-03  |
| U006    | 2025-01-04  |

#### Step 2: New Users Per Day

| login_date | new_users |
|------------|-----------|
| 2025-01-01 | 3         |
| 2025-01-02 | 1         |
| 2025-01-03 | 1         |
| 2025-01-04 | 1         |

#### Step 3: Cumulative Sum of New Users

| login_date | daily_unique | new_users | cumulative_unique |
|------------|-------------|-----------|-------------------|
| 2025-01-01 | 3           | 3         | 3                 |
| 2025-01-02 | 2           | 1         | 4                 |
| 2025-01-03 | 3           | 1         | 5                 |
| 2025-01-04 | 2           | 1         | 6                 |

**Key insight:** cumulative distinct count = cumulative sum of new users. A user is "new" only on their first appearance date. Summing new users over time gives the running distinct count.

---

## Method 2: Cross Join with Distinct (Small Data Only)

```python
# Get all unique dates
dates = df.select("login_date").distinct().orderBy("login_date")

# For each date, count distinct users up to that date
from pyspark.sql.functions import countDistinct

cumulative = dates.alias("d").crossJoin(df.alias("l")) \
    .filter(col("l.login_date") <= col("d.login_date")) \
    .groupBy(col("d.login_date").alias("login_date")) \
    .agg(countDistinct("l.user_id").alias("cumulative_unique")) \
    .orderBy("login_date")

cumulative.show()
```

- **Warning:** This is O(dates * events) — very expensive for large data. Use Method 1 in production.

---

## Method 3: Using SQL

```python
df.createOrReplaceTempView("logins")

spark.sql("""
    WITH first_seen AS (
        SELECT user_id, MIN(login_date) AS first_login
        FROM logins
        GROUP BY user_id
    ),
    new_per_day AS (
        SELECT first_login AS login_date, COUNT(*) AS new_users
        FROM first_seen
        GROUP BY first_login
    ),
    daily AS (
        SELECT login_date, COUNT(DISTINCT user_id) AS daily_unique
        FROM logins
        GROUP BY login_date
    )
    SELECT
        d.login_date,
        d.daily_unique,
        SUM(n.new_users) OVER (ORDER BY d.login_date) AS cumulative_unique
    FROM daily d
    LEFT JOIN new_per_day n ON d.login_date = n.login_date
    ORDER BY d.login_date
""").show()
```

---

## Method 4: collect_set with Window (Medium Data)

```python
from pyspark.sql.functions import collect_set, size, flatten, array_distinct

# Collect all user_ids up to each date, then count distinct
window_cumulative = Window.orderBy("login_date") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

# First, get daily user sets
daily_sets = df.groupBy("login_date").agg(
    collect_set("user_id").alias("daily_users")
)

# Collect sets of sets, then flatten and distinct
cumulative_sets = daily_sets.withColumn(
    "all_users_so_far",
    flatten(collect_list("daily_users").over(window_cumulative))
).withColumn(
    "unique_users_so_far",
    array_distinct(col("all_users_so_far"))
).withColumn(
    "cumulative_unique",
    size(col("unique_users_so_far"))
)

cumulative_sets.select("login_date", "cumulative_unique").orderBy("login_date").show()
```

- **Note:** This approach stores all user IDs in memory per row. Works for medium data (thousands of users) but not millions.

---

## Method Comparison

| Method | Performance | Scalability | Complexity |
|--------|-------------|-------------|------------|
| First-seen + cumsum (Method 1) | Best | Handles billions | Simple |
| Cross join (Method 2) | Worst | Small data only | Simple |
| SQL CTE (Method 3) | Best | Handles billions | Moderate |
| collect_set (Method 4) | Medium | Medium data | Simple |

**Always use Method 1 or 3 in production.**

---

## Variation: Cumulative Distinct with HyperLogLog (Approximate)

```python
from pyspark.sql.functions import approx_count_distinct

# For very large datasets where exact count is too expensive
# Use approx_count_distinct which uses HyperLogLog

# Note: This gives per-day approximate distinct, not cumulative
# For approximate cumulative, use Method 1 logic with approx_count_distinct
daily_approx = df.groupBy("login_date").agg(
    approx_count_distinct("user_id", rsd=0.05).alias("approx_daily_unique")
)
daily_approx.show()
```

## Key Interview Talking Points

1. **Why countDistinct doesn't work in windows:** Window functions process rows one at a time and maintain state. `countDistinct` requires seeing all values at once — it's an aggregate, not a window function. Spark doesn't support it in window context.

2. **The first-seen trick:** By identifying each user's first appearance date and summing new users cumulatively, you convert a "running distinct" problem into a simple "running sum" — which window functions handle naturally.

3. **Performance at scale:** Method 1 requires only two `groupBy` operations and one window function — all standard distributed operations. It works efficiently on billions of rows.

4. **Approximate alternatives:** For extremely large datasets (billions of unique users), use HyperLogLog (`approx_count_distinct`) for daily counts. For cumulative approximation, maintain an HLL sketch per day.

5. **Common interview variations:**
   - "Cumulative distinct products sold per month"
   - "Running unique visitors to a website per week"
   - "Total distinct customers ever seen, computed daily"
   - "Cumulative distinct count with a rolling 30-day window" (harder — requires different approach)
