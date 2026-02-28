# PySpark Implementation: Churn / Inactive User Detection

## Problem Statement 

Given a dataset of user activity events and a reference date (today), classify users as **active**, **at-risk**, or **churned** based on how long ago they were last active. Then compute churn rates by cohort, region, or any other dimension. This combines the `cumulative_distinct_count` first-seen trick with date arithmetic and conditional aggregation — a very common business intelligence question.

### Sample Data

```
user_id  activity_date  activity_type
U001     2025-01-20     purchase
U001     2025-01-10     login
U001     2024-12-25     purchase
U002     2025-01-25     login
U002     2025-01-22     purchase
U003     2024-11-15     login
U003     2024-11-10     purchase
U004     2025-01-28     login
U005     2024-12-01     purchase
U005     2024-10-15     login
U006     2024-09-01     login
```

**Reference date:** 2025-01-30

### Expected Output (User Classification)

| user_id | last_active | days_inactive | status   |
|---------|------------|---------------|----------|
| U004    | 2025-01-28 | 2             | Active   |
| U002    | 2025-01-25 | 5             | Active   |
| U001    | 2025-01-20 | 10            | Active   |
| U005    | 2024-12-01 | 60            | At-Risk  |
| U003    | 2024-11-15 | 76            | Churned  |
| U006    | 2024-09-01 | 151           | Churned  |

**Rules:**
- Active: last activity within 30 days
- At-Risk: last activity 31-60 days ago
- Churned: last activity more than 60 days ago

---

## PySpark Code Solution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_date, max as spark_max, datediff, \
    when, lit, count, sum as spark_sum, round as spark_round, min as spark_min, \
    countDistinct
from pyspark.sql.window import Window

# Initialize Spark session
spark = SparkSession.builder.appName("ChurnDetection").getOrCreate()

# Sample data
data = [
    ("U001", "2025-01-20", "purchase"), ("U001", "2025-01-10", "login"),
    ("U001", "2024-12-25", "purchase"), ("U002", "2025-01-25", "login"),
    ("U002", "2025-01-22", "purchase"), ("U003", "2024-11-15", "login"),
    ("U003", "2024-11-10", "purchase"), ("U004", "2025-01-28", "login"),
    ("U005", "2024-12-01", "purchase"), ("U005", "2024-10-15", "login"),
    ("U006", "2024-09-01", "login")
]
columns = ["user_id", "activity_date", "activity_type"]
df = spark.createDataFrame(data, columns)
df = df.withColumn("activity_date", to_date("activity_date"))

# Reference date (today)
REFERENCE_DATE = lit("2025-01-30").cast("date")

# Churn thresholds (days)
ACTIVE_THRESHOLD = 30
AT_RISK_THRESHOLD = 60

# Step 1: Find each user's last activity date
user_last_active = df.groupBy("user_id").agg(
    spark_max("activity_date").alias("last_active"),
    spark_min("activity_date").alias("first_active"),
    count("*").alias("total_activities"),
    countDistinct("activity_type").alias("activity_types")
)

# Step 2: Calculate days since last activity
user_status = user_last_active.withColumn(
    "days_inactive", datediff(REFERENCE_DATE, col("last_active"))
)

# Step 3: Classify users
user_status = user_status.withColumn(
    "status",
    when(col("days_inactive") <= ACTIVE_THRESHOLD, "Active")
    .when(col("days_inactive") <= AT_RISK_THRESHOLD, "At-Risk")
    .otherwise("Churned")
)

user_status.orderBy("days_inactive").show(truncate=False)
```

### Step-by-Step Explanation

#### Step 1: Last Activity Per User

| user_id | last_active | first_active | total_activities |
|---------|------------|-------------|-----------------|
| U001    | 2025-01-20 | 2024-12-25  | 3               |
| U002    | 2025-01-25 | 2025-01-22  | 2               |
| U003    | 2024-11-15 | 2024-11-10  | 2               |
| U004    | 2025-01-28 | 2025-01-28  | 1               |
| U005    | 2024-12-01 | 2024-10-15  | 2               |
| U006    | 2024-09-01 | 2024-09-01  | 1               |

#### Step 2-3: Days Inactive + Classification

| user_id | last_active | days_inactive | status  |
|---------|------------|---------------|---------|
| U004    | 2025-01-28 | 2             | Active  |
| U002    | 2025-01-25 | 5             | Active  |
| U001    | 2025-01-20 | 10            | Active  |
| U005    | 2024-12-01 | 60            | At-Risk |
| U003    | 2024-11-15 | 76            | Churned |
| U006    | 2024-09-01 | 151           | Churned |

---

## Churn Summary Report

```python
# Overall churn summary
churn_summary = user_status.groupBy("status").agg(
    count("*").alias("user_count")
)
total_users = user_status.count()

churn_summary = churn_summary.withColumn(
    "percentage",
    spark_round(col("user_count") / lit(total_users) * 100, 1)
).orderBy(
    when(col("status") == "Active", 1)
    .when(col("status") == "At-Risk", 2)
    .otherwise(3)
)

churn_summary.show(truncate=False)
```

- **Output:**

  | status  | user_count | percentage |
  |---------|-----------|-----------|
  | Active  | 3         | 50.0      |
  | At-Risk | 1         | 16.7      |
  | Churned | 2         | 33.3      |

---

## Extension 1: Churn by Signup Cohort

```python
from pyspark.sql.functions import date_format

# Add signup month (first activity) as cohort
user_cohort = user_status.withColumn(
    "cohort_month", date_format("first_active", "yyyy-MM")
)

# Churn rate by cohort
cohort_churn = user_cohort.groupBy("cohort_month").agg(
    count("*").alias("cohort_size"),
    count(when(col("status") == "Churned", True)).alias("churned_count"),
    count(when(col("status") == "At-Risk", True)).alias("at_risk_count"),
    count(when(col("status") == "Active", True)).alias("active_count")
).withColumn(
    "churn_rate",
    spark_round(col("churned_count") / col("cohort_size") * 100, 1)
).orderBy("cohort_month")

cohort_churn.show(truncate=False)
```

---

## Extension 2: Churn Trend Over Time

```python
from pyspark.sql.functions import explode, sequence, expr

# Calculate churn rate at multiple points in time (weekly snapshots)
# Generate snapshot dates
snapshot_dates = spark.createDataFrame(
    [("2025-01-01",), ("2025-01-08",), ("2025-01-15",),
     ("2025-01-22",), ("2025-01-30",)],
    ["snapshot_date"]
).withColumn("snapshot_date", to_date("snapshot_date"))

# For each snapshot date, classify all users
# Cross join users with snapshot dates
from pyspark.sql.functions import broadcast

user_snapshots = user_last_active.crossJoin(broadcast(snapshot_dates))

churn_trend = user_snapshots.withColumn(
    "days_inactive", datediff(col("snapshot_date"), col("last_active"))
).filter(
    col("days_inactive") >= 0  # Only users who existed by snapshot date
).withColumn(
    "status",
    when(col("days_inactive") <= ACTIVE_THRESHOLD, "Active")
    .when(col("days_inactive") <= AT_RISK_THRESHOLD, "At-Risk")
    .otherwise("Churned")
)

# Aggregate per snapshot
trend_summary = churn_trend.groupBy("snapshot_date").agg(
    count("*").alias("total_users"),
    count(when(col("status") == "Active", True)).alias("active"),
    count(when(col("status") == "At-Risk", True)).alias("at_risk"),
    count(when(col("status") == "Churned", True)).alias("churned")
).withColumn(
    "churn_rate", spark_round(col("churned") / col("total_users") * 100, 1)
).orderBy("snapshot_date")

trend_summary.show(truncate=False)
```

---

## Extension 3: Days-Since-Last-Activity Distribution

```python
from pyspark.sql.functions import ntile

# Bucket users by inactivity using ntile
window_inactive = Window.orderBy("days_inactive")

user_buckets = user_status.withColumn(
    "inactivity_bucket",
    when(col("days_inactive") <= 7, "0-7 days")
    .when(col("days_inactive") <= 14, "8-14 days")
    .when(col("days_inactive") <= 30, "15-30 days")
    .when(col("days_inactive") <= 60, "31-60 days")
    .when(col("days_inactive") <= 90, "61-90 days")
    .otherwise("90+ days")
)

distribution = user_buckets.groupBy("inactivity_bucket").agg(
    count("*").alias("user_count")
).orderBy(
    when(col("inactivity_bucket") == "0-7 days", 1)
    .when(col("inactivity_bucket") == "8-14 days", 2)
    .when(col("inactivity_bucket") == "15-30 days", 3)
    .when(col("inactivity_bucket") == "31-60 days", 4)
    .when(col("inactivity_bucket") == "61-90 days", 5)
    .otherwise(6)
)

distribution.show(truncate=False)
```

---

## Extension 4: Reactivation Detection

```python
# Find users who were churned but came back (reactivated)
# Define: churned = inactive > 60 days, then had new activity

window_user = Window.partitionBy("user_id").orderBy("activity_date")

from pyspark.sql.functions import lag

reactivation = df.withColumn(
    "prev_activity", lag("activity_date").over(window_user)
).withColumn(
    "days_gap", datediff(col("activity_date"), col("prev_activity"))
).filter(
    col("days_gap") > AT_RISK_THRESHOLD  # Gap longer than churn threshold
).select(
    "user_id",
    col("prev_activity").alias("last_before_churn"),
    col("activity_date").alias("reactivation_date"),
    col("days_gap").alias("days_churned")
)

print("=== REACTIVATED USERS ===")
reactivation.show(truncate=False)
```

---

## Method 2: Using SQL

```python
df.createOrReplaceTempView("activity")

spark.sql("""
    WITH user_last AS (
        SELECT
            user_id,
            MAX(activity_date) AS last_active,
            MIN(activity_date) AS first_active,
            COUNT(*) AS total_activities
        FROM activity
        GROUP BY user_id
    ),
    classified AS (
        SELECT *,
            DATEDIFF(DATE '2025-01-30', last_active) AS days_inactive,
            CASE
                WHEN DATEDIFF(DATE '2025-01-30', last_active) <= 30 THEN 'Active'
                WHEN DATEDIFF(DATE '2025-01-30', last_active) <= 60 THEN 'At-Risk'
                ELSE 'Churned'
            END AS status
        FROM user_last
    )
    SELECT
        status,
        COUNT(*) AS user_count,
        ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM classified), 1) AS percentage
    FROM classified
    GROUP BY status
    ORDER BY
        CASE status WHEN 'Active' THEN 1 WHEN 'At-Risk' THEN 2 ELSE 3 END
""").show(truncate=False)
```

---

## Connection to Existing Patterns

| Technique Used | From Pattern | How It's Used Here |
|---------------|-------------|-------------------|
| `max(activity_date)` per user | `cumulative_distinct_count` | Find last activity (like first-seen, but max) |
| `datediff()` + `when()` | `conditional_aggregations` | Classify users by threshold |
| `count(when())` for summary | `conditional_aggregations` | Churn rate by segment |
| `lag()` for gap detection | `gaps_and_islands` | Reactivation detection |
| `ntile()` for bucketing | `ntile_percentile_bucketing` | Inactivity distribution |

---

## Key Interview Talking Points

1. **Simple pattern, high business value:** This is just `max(date)` per user + `datediff` + `when`. The technique is straightforward, but interviewers test whether you can translate business requirements ("30-day churn") into PySpark code.

2. **Configurable thresholds:** Different businesses define churn differently — 7 days (mobile games), 30 days (SaaS), 90 days (enterprise software). Make thresholds parameters, not hardcoded.

3. **Churn rate vs retention rate:** Churn rate = churned / total. Retention rate = active / total. They're complements (churn + retention ≈ 100%, with at-risk in between).

4. **Point-in-time analysis:** Churn changes daily. To track trends, compute churn at multiple snapshot dates. The cross-join approach (users × dates) is efficient for a small number of snapshots.

5. **Real-world use cases:**
   - SaaS subscription health dashboards
   - Mobile app DAU/MAU ratio
   - E-commerce customer lifecycle management
   - "Win-back" campaign targeting (at-risk users)
   - Customer lifetime value (LTV) adjustment based on churn risk
   - Freemium conversion analysis (free users who churned vs converted)
