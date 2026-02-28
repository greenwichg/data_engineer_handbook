# PySpark Implementation: Cohort Retention Analysis

## Problem Statement

Given a dataset of user activity events, build a **cohort retention matrix** — group users by the month they first appeared (their "cohort"), then for each subsequent month, calculate what percentage of that cohort was still active. This is the analytics version of the `conditional_aggregations` pattern — it uses `sum(when())` and `count(when())` combined with the `cumulative_distinct_count` first-seen trick.

### Sample Data

```
user_id  activity_date
U001     2025-01-05
U001     2025-01-15
U001     2025-02-10
U001     2025-03-20
U002     2025-01-08
U002     2025-02-14
U003     2025-01-20
U004     2025-02-01
U004     2025-02-15
U004     2025-03-10
U004     2025-04-05
U005     2025-02-08
U005     2025-04-12
U006     2025-03-01
U006     2025-03-15
```

### Expected Output (Retention Matrix)

| cohort_month | cohort_size | month_0 | month_1 | month_2 | month_3 |
|-------------|-------------|---------|---------|---------|---------|
| 2025-01     | 3           | 100.0%  | 66.7%   | 33.3%   | 0.0%    |
| 2025-02     | 2           | 100.0%  | 50.0%   | 50.0%   | N/A     |
| 2025-03     | 1           | 100.0%  | 0.0%    | N/A     | N/A     |

**Explanation:**
- Jan cohort: U001, U002, U003 (3 users). In Feb (month_1): U001, U002 active → 66.7%. In Mar (month_2): U001 only → 33.3%.
- Feb cohort: U004, U005 (2 users). In Mar: U004 active → 50%. In Apr: U004, U005 active → 50% (U005 returned).

---

## PySpark Code Solution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_date, date_format, min as spark_min, \
    countDistinct, count, when, round as spark_round, months_between, floor
from pyspark.sql.window import Window

# Initialize Spark session
spark = SparkSession.builder.appName("CohortRetention").getOrCreate()

# Sample data
data = [
    ("U001", "2025-01-05"), ("U001", "2025-01-15"), ("U001", "2025-02-10"),
    ("U001", "2025-03-20"), ("U002", "2025-01-08"), ("U002", "2025-02-14"),
    ("U003", "2025-01-20"), ("U004", "2025-02-01"), ("U004", "2025-02-15"),
    ("U004", "2025-03-10"), ("U004", "2025-04-05"), ("U005", "2025-02-08"),
    ("U005", "2025-04-12"), ("U006", "2025-03-01"), ("U006", "2025-03-15")
]
columns = ["user_id", "activity_date"]
df = spark.createDataFrame(data, columns)
df = df.withColumn("activity_date", to_date("activity_date"))

# Step 1: Add activity_month to each event
df = df.withColumn("activity_month", date_format("activity_date", "yyyy-MM"))

# Step 2: Find each user's cohort (first activity month)
user_cohort = df.groupBy("user_id").agg(
    spark_min("activity_month").alias("cohort_month")
)

# Step 3: Join cohort back to activity data
df_with_cohort = df.join(user_cohort, on="user_id")

# Step 4: Calculate months since cohort (period_number)
df_with_period = df_with_cohort.withColumn(
    "period_number",
    floor(months_between(
        to_date(col("activity_month"), "yyyy-MM"),
        to_date(col("cohort_month"), "yyyy-MM")
    )).cast("int")
)

# Step 5: Get distinct active users per cohort per period
cohort_activity = df_with_period.groupBy("cohort_month", "period_number").agg(
    countDistinct("user_id").alias("active_users")
)

# Step 6: Get cohort sizes (month_0 users)
cohort_sizes = cohort_activity.filter(col("period_number") == 0) \
    .select(col("cohort_month"), col("active_users").alias("cohort_size"))

# Step 7: Join and calculate retention rate
retention = cohort_activity.join(cohort_sizes, on="cohort_month") \
    .withColumn(
        "retention_rate",
        spark_round(col("active_users") / col("cohort_size") * 100, 1)
    ).orderBy("cohort_month", "period_number")

retention.show(truncate=False)
```

### Step-by-Step Explanation

#### Step 2: User Cohort Assignment (First-Seen Trick from cumulative_distinct_count)

| user_id | cohort_month |
|---------|-------------|
| U001    | 2025-01     |
| U002    | 2025-01     |
| U003    | 2025-01     |
| U004    | 2025-02     |
| U005    | 2025-02     |
| U006    | 2025-03     |

#### Step 4: Period Number Calculation

| user_id | activity_month | cohort_month | period_number |
|---------|---------------|-------------|---------------|
| U001    | 2025-01       | 2025-01     | 0             |
| U001    | 2025-02       | 2025-01     | 1             |
| U001    | 2025-03       | 2025-01     | 2             |
| U004    | 2025-02       | 2025-02     | 0             |
| U004    | 2025-03       | 2025-02     | 1             |
| U004    | 2025-04       | 2025-02     | 2             |

#### Steps 5-7: Retention Rates

| cohort_month | period_number | active_users | cohort_size | retention_rate |
|-------------|---------------|-------------|-------------|---------------|
| 2025-01     | 0             | 3           | 3           | 100.0         |
| 2025-01     | 1             | 2           | 3           | 66.7          |
| 2025-01     | 2             | 1           | 3           | 33.3          |
| 2025-02     | 0             | 2           | 2           | 100.0         |
| 2025-02     | 1             | 1           | 2           | 50.0          |
| 2025-02     | 2             | 2           | 2           | 100.0         |
| 2025-03     | 0             | 1           | 1           | 100.0         |

---

## Method 2: Pivot for Matrix Format (Using Conditional Aggregation)

```python
# Create the classic retention matrix using pivot
retention_matrix = cohort_activity.join(cohort_sizes, on="cohort_month") \
    .withColumn(
        "retention_rate",
        spark_round(col("active_users") / col("cohort_size") * 100, 1)
    )

# Pivot period_number into columns
matrix = retention_matrix.groupBy("cohort_month", "cohort_size") \
    .pivot("period_number") \
    .agg(spark_round(spark_min("retention_rate"), 1)) \
    .orderBy("cohort_month")

# Rename columns for clarity
for c in matrix.columns:
    if c not in ["cohort_month", "cohort_size"]:
        matrix = matrix.withColumnRenamed(c, f"month_{c}")

matrix.show(truncate=False)
```

- **Output:**

  | cohort_month | cohort_size | month_0 | month_1 | month_2 |
  |-------------|-------------|---------|---------|---------|
  | 2025-01     | 3           | 100.0   | 66.7    | 33.3    |
  | 2025-02     | 2           | 100.0   | 50.0    | 100.0   |
  | 2025-03     | 1           | 100.0   | null    | null    |

---

## Method 3: Using sum(when()) — Direct Conditional Aggregation

```python
# Alternative: compute all retention periods in a single aggregation
# using the sum(when()) pattern from conditional_aggregations

all_periods = df_with_period.groupBy("cohort_month").agg(
    countDistinct("user_id").alias("cohort_size"),

    countDistinct(when(col("period_number") == 0, col("user_id"))).alias("m0_users"),
    countDistinct(when(col("period_number") == 1, col("user_id"))).alias("m1_users"),
    countDistinct(when(col("period_number") == 2, col("user_id"))).alias("m2_users"),
    countDistinct(when(col("period_number") == 3, col("user_id"))).alias("m3_users")
)

# Calculate retention percentages
all_periods = all_periods.withColumn("m0_pct", spark_round(col("m0_users") / col("cohort_size") * 100, 1)) \
    .withColumn("m1_pct", spark_round(col("m1_users") / col("cohort_size") * 100, 1)) \
    .withColumn("m2_pct", spark_round(col("m2_users") / col("cohort_size") * 100, 1)) \
    .withColumn("m3_pct", spark_round(col("m3_users") / col("cohort_size") * 100, 1))

all_periods.select("cohort_month", "cohort_size",
                   "m0_pct", "m1_pct", "m2_pct", "m3_pct") \
    .orderBy("cohort_month").show(truncate=False)
```

This is the direct application of the `sum(when())` pattern from `conditional_aggregations.md`, with `countDistinct(when())` instead of `sum(when())`.

---

## Method 4: Using SQL

```python
df.createOrReplaceTempView("user_activity")

spark.sql("""
    WITH user_cohort AS (
        SELECT user_id, MIN(DATE_FORMAT(activity_date, 'yyyy-MM')) AS cohort_month
        FROM user_activity
        GROUP BY user_id
    ),
    with_period AS (
        SELECT
            a.user_id,
            uc.cohort_month,
            FLOOR(MONTHS_BETWEEN(
                TO_DATE(DATE_FORMAT(a.activity_date, 'yyyy-MM'), 'yyyy-MM'),
                TO_DATE(uc.cohort_month, 'yyyy-MM')
            )) AS period_number
        FROM user_activity a
        JOIN user_cohort uc ON a.user_id = uc.user_id
    ),
    cohort_counts AS (
        SELECT cohort_month, period_number,
               COUNT(DISTINCT user_id) AS active_users
        FROM with_period
        GROUP BY cohort_month, period_number
    ),
    sizes AS (
        SELECT cohort_month, active_users AS cohort_size
        FROM cohort_counts WHERE period_number = 0
    )
    SELECT
        c.cohort_month,
        s.cohort_size,
        c.period_number,
        c.active_users,
        ROUND(c.active_users / s.cohort_size * 100, 1) AS retention_pct
    FROM cohort_counts c
    JOIN sizes s ON c.cohort_month = s.cohort_month
    ORDER BY c.cohort_month, c.period_number
""").show(truncate=False)
```

---

## Practical Extension: Weekly Cohorts

```python
from pyspark.sql.functions import weekofyear, year, concat_ws, datediff, \
    date_trunc

# Weekly cohorts instead of monthly
df_weekly = df.withColumn(
    "activity_week", date_trunc("week", col("activity_date"))
)

user_weekly_cohort = df_weekly.groupBy("user_id").agg(
    spark_min("activity_week").alias("cohort_week")
)

df_weekly_with_cohort = df_weekly.join(user_weekly_cohort, on="user_id")

df_weekly_periods = df_weekly_with_cohort.withColumn(
    "week_number",
    (datediff(col("activity_week"), col("cohort_week")) / 7).cast("int")
)

weekly_retention = df_weekly_periods.groupBy("cohort_week", "week_number").agg(
    countDistinct("user_id").alias("active_users")
)

weekly_sizes = weekly_retention.filter(col("week_number") == 0) \
    .select(col("cohort_week"), col("active_users").alias("cohort_size"))

weekly_result = weekly_retention.join(weekly_sizes, on="cohort_week") \
    .withColumn("retention_pct",
                spark_round(col("active_users") / col("cohort_size") * 100, 1)) \
    .orderBy("cohort_week", "week_number")

weekly_result.show(truncate=False)
```

---

## Connection to Parent Patterns

| Technique Used | From Pattern | How It's Used Here |
|---------------|-------------|-------------------|
| First-seen identification | `cumulative_distinct_count` | Find user's cohort month |
| `countDistinct(when())` | `conditional_aggregations` | Count active users per period |
| `pivot()` | `pivot_unpivot` | Create the retention matrix |
| Running distinct concept | `cumulative_distinct_count` | Track users over time |

---

## Key Interview Talking Points

1. **Combines three patterns:** Cohort retention uses first-seen (from cumulative_distinct_count), conditional counting (from conditional_aggregations), and optionally pivot for the matrix format. It's a synthesis problem.

2. **month_0 is always 100%:** By definition, every user in a cohort was active in their cohort month. This is a good sanity check.

3. **Retention vs churn:** Retention rate + churn rate = 100% for each period. You can derive one from the other. Interviewers often ask for both.

4. **Period calculation:** Use `months_between()` for monthly cohorts, `datediff() / 7` for weekly. Handle edge cases where `months_between` returns fractional values by using `floor()`.

5. **Real-world use cases:**
   - SaaS product retention (monthly active users by signup cohort)
   - Mobile app retention (day-1, day-7, day-30 retention)
   - Subscription renewal analysis
   - Customer lifetime value (LTV) estimation base
   - A/B test impact on retention by cohort
