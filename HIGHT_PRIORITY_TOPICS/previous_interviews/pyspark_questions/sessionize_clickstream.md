# PySpark Implementation: Sessionizing Clickstream Data

## Problem Statement 

Given a dataset of user clickstream events with timestamps, **assign session IDs** to each event. A new session begins when the gap between two consecutive events for the same user exceeds **30 minutes**. Then compute session-level metrics (duration, event count, etc.). This is a very common data engineering interview question, especially for companies dealing with web analytics, ad-tech, or user behavior analysis.

### Sample Data

```
user_id  event_time            page
U001     2025-01-15 10:00:00   /home
U001     2025-01-15 10:05:00   /products
U001     2025-01-15 10:12:00   /products/laptop
U001     2025-01-15 10:45:00   /cart
U001     2025-01-15 11:30:00   /home
U001     2025-01-15 11:35:00   /about
U002     2025-01-15 09:00:00   /home
U002     2025-01-15 09:10:00   /search
U002     2025-01-15 10:00:00   /home
```

### Expected Output (with session IDs)

| user_id | event_time          | page             | session_id |
|---------|---------------------|------------------|------------|
| U001    | 2025-01-15 10:00:00 | /home            | 1          |
| U001    | 2025-01-15 10:05:00 | /products        | 1          |
| U001    | 2025-01-15 10:12:00 | /products/laptop | 1          |
| U001    | 2025-01-15 10:45:00 | /cart            | 2          |
| U001    | 2025-01-15 11:30:00 | /home            | 3          |
| U001    | 2025-01-15 11:35:00 | /about           | 3          |
| U002    | 2025-01-15 09:00:00 | /home            | 1          |
| U002    | 2025-01-15 09:10:00 | /search          | 1          |
| U002    | 2025-01-15 10:00:00 | /home            | 2          |

### Expected Session Summary

| user_id | session_id | session_start       | session_end         | duration_min | event_count |
|---------|------------|---------------------|---------------------|-------------|-------------|
| U001    | 1          | 2025-01-15 10:00:00 | 2025-01-15 10:12:00 | 12          | 3           |
| U001    | 2          | 2025-01-15 10:45:00 | 2025-01-15 10:45:00 | 0           | 1           |
| U001    | 3          | 2025-01-15 11:30:00 | 2025-01-15 11:35:00 | 5           | 2           |
| U002    | 1          | 2025-01-15 09:00:00 | 2025-01-15 09:10:00 | 10          | 2           |
| U002    | 2          | 2025-01-15 10:00:00 | 2025-01-15 10:00:00 | 0           | 1           |

---

## PySpark Code Solution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lag, when, sum as spark_sum, to_timestamp, \
    unix_timestamp, min as spark_min, max as spark_max, count, round as spark_round
from pyspark.sql.window import Window

# Initialize Spark session
spark = SparkSession.builder.appName("Sessionization").getOrCreate()

# Sample data
data = [
    ("U001", "2025-01-15 10:00:00", "/home"),
    ("U001", "2025-01-15 10:05:00", "/products"),
    ("U001", "2025-01-15 10:12:00", "/products/laptop"),
    ("U001", "2025-01-15 10:45:00", "/cart"),
    ("U001", "2025-01-15 11:30:00", "/home"),
    ("U001", "2025-01-15 11:35:00", "/about"),
    ("U002", "2025-01-15 09:00:00", "/home"),
    ("U002", "2025-01-15 09:10:00", "/search"),
    ("U002", "2025-01-15 10:00:00", "/home")
]

columns = ["user_id", "event_time", "page"]
df = spark.createDataFrame(data, columns)

# Convert event_time to timestamp
df = df.withColumn("event_time", to_timestamp(col("event_time")))

# Session timeout threshold (30 minutes = 1800 seconds)
SESSION_TIMEOUT = 30 * 60

# Step 1: Define window partitioned by user, ordered by event time
window_user = Window.partitionBy("user_id").orderBy("event_time")

# Step 2: Get previous event time using lag
df_with_lag = df.withColumn("prev_event_time", lag("event_time").over(window_user))

# Step 3: Calculate gap in seconds between consecutive events
df_with_gap = df_with_lag.withColumn(
    "gap_seconds",
    unix_timestamp(col("event_time")) - unix_timestamp(col("prev_event_time"))
)

# Step 4: Flag new sessions (gap > threshold OR first event)
df_flagged = df_with_gap.withColumn(
    "new_session",
    when(
        (col("gap_seconds") > SESSION_TIMEOUT) | col("prev_event_time").isNull(), 1
    ).otherwise(0)
)

# Step 5: Cumulative sum of new_session flags = session_id
df_sessioned = df_flagged.withColumn(
    "session_id",
    spark_sum("new_session").over(window_user)
)

# Display event-level result
df_sessioned.select("user_id", "event_time", "page", "session_id") \
    .orderBy("user_id", "event_time").show(truncate=False)

# Step 6: Session-level aggregation
session_summary = df_sessioned.groupBy("user_id", "session_id").agg(
    spark_min("event_time").alias("session_start"),
    spark_max("event_time").alias("session_end"),
    spark_round(
        (unix_timestamp(spark_max("event_time")) - unix_timestamp(spark_min("event_time"))) / 60, 0
    ).alias("duration_min"),
    count("*").alias("event_count")
)

session_summary.orderBy("user_id", "session_id").show(truncate=False)
```

---

## Step-by-Step Explanation with Intermediate DataFrames

### Step 1: Initial DataFrame (after timestamp conversion)

| user_id | event_time          | page             |
|---------|---------------------|------------------|
| U001    | 2025-01-15 10:00:00 | /home            |
| U001    | 2025-01-15 10:05:00 | /products        |
| U001    | 2025-01-15 10:12:00 | /products/laptop |
| U001    | 2025-01-15 10:45:00 | /cart            |
| U001    | 2025-01-15 11:30:00 | /home            |
| U001    | 2025-01-15 11:35:00 | /about           |
| U002    | 2025-01-15 09:00:00 | /home            |
| U002    | 2025-01-15 09:10:00 | /search          |
| U002    | 2025-01-15 10:00:00 | /home            |

### Step 2: Add Previous Event Time (lag)

| user_id | event_time          | page             | prev_event_time     |
|---------|---------------------|------------------|---------------------|
| U001    | 2025-01-15 10:00:00 | /home            | null                |
| U001    | 2025-01-15 10:05:00 | /products        | 2025-01-15 10:00:00 |
| U001    | 2025-01-15 10:12:00 | /products/laptop | 2025-01-15 10:05:00 |
| U001    | 2025-01-15 10:45:00 | /cart            | 2025-01-15 10:12:00 |
| U001    | 2025-01-15 11:30:00 | /home            | 2025-01-15 10:45:00 |
| U001    | 2025-01-15 11:35:00 | /about           | 2025-01-15 11:30:00 |
| U002    | 2025-01-15 09:00:00 | /home            | null                |
| U002    | 2025-01-15 09:10:00 | /search          | 2025-01-15 09:00:00 |
| U002    | 2025-01-15 10:00:00 | /home            | 2025-01-15 09:10:00 |

### Step 3: Calculate Gap in Seconds

| user_id | event_time          | page             | gap_seconds |
|---------|---------------------|------------------|-------------|
| U001    | 2025-01-15 10:00:00 | /home            | null        |
| U001    | 2025-01-15 10:05:00 | /products        | 300         |
| U001    | 2025-01-15 10:12:00 | /products/laptop | 420         |
| U001    | 2025-01-15 10:45:00 | /cart            | 1980        |
| U001    | 2025-01-15 11:30:00 | /home            | 2700        |
| U001    | 2025-01-15 11:35:00 | /about           | 300         |
| U002    | 2025-01-15 09:00:00 | /home            | null        |
| U002    | 2025-01-15 09:10:00 | /search          | 600         |
| U002    | 2025-01-15 10:00:00 | /home            | 3000        |

Key observations:
- U001 10:45 → gap = 1980s (33 min) > 1800s threshold → **new session**
- U001 11:30 → gap = 2700s (45 min) > 1800s threshold → **new session**
- U002 10:00 → gap = 3000s (50 min) > 1800s threshold → **new session**

### Step 4: Flag New Sessions

| user_id | event_time          | gap_seconds | new_session |
|---------|---------------------|-------------|-------------|
| U001    | 2025-01-15 10:00:00 | null        | 1           |
| U001    | 2025-01-15 10:05:00 | 300         | 0           |
| U001    | 2025-01-15 10:12:00 | 420         | 0           |
| U001    | 2025-01-15 10:45:00 | 1980        | 1           |
| U001    | 2025-01-15 11:30:00 | 2700        | 1           |
| U001    | 2025-01-15 11:35:00 | 300         | 0           |
| U002    | 2025-01-15 09:00:00 | null        | 1           |
| U002    | 2025-01-15 09:10:00 | 600         | 0           |
| U002    | 2025-01-15 10:00:00 | 3000        | 1           |

### Step 5: Cumulative Sum → Session ID

- **What happens:** Running sum of `new_session` flags creates incrementing session IDs.
- **Output:**

  | user_id | event_time          | page             | session_id |
  |---------|---------------------|------------------|------------|
  | U001    | 2025-01-15 10:00:00 | /home            | 1          |
  | U001    | 2025-01-15 10:05:00 | /products        | 1          |
  | U001    | 2025-01-15 10:12:00 | /products/laptop | 1          |
  | U001    | 2025-01-15 10:45:00 | /cart            | 2          |
  | U001    | 2025-01-15 11:30:00 | /home            | 3          |
  | U001    | 2025-01-15 11:35:00 | /about           | 3          |
  | U002    | 2025-01-15 09:00:00 | /home            | 1          |
  | U002    | 2025-01-15 09:10:00 | /search          | 1          |
  | U002    | 2025-01-15 10:00:00 | /home            | 2          |

### Step 6: Session Summary

| user_id | session_id | session_start       | session_end         | duration_min | event_count |
|---------|------------|---------------------|---------------------|-------------|-------------|
| U001    | 1          | 2025-01-15 10:00:00 | 2025-01-15 10:12:00 | 12          | 3           |
| U001    | 2          | 2025-01-15 10:45:00 | 2025-01-15 10:45:00 | 0           | 1           |
| U001    | 3          | 2025-01-15 11:30:00 | 2025-01-15 11:35:00 | 5           | 2           |
| U002    | 1          | 2025-01-15 09:00:00 | 2025-01-15 09:10:00 | 10          | 2           |
| U002    | 2          | 2025-01-15 10:00:00 | 2025-01-15 10:00:00 | 0           | 1           |

---

## The Core Pattern: lag → flag → cumulative sum

This three-step pattern is used in many sessionization and grouping problems:

```
1. lag()          → Get previous value
2. when(condition) → Flag boundaries (0 or 1)
3. sum().over()   → Cumulative sum creates group IDs
```

This is the same technique used in:
- Network session detection
- Manufacturing batch identification
- Financial trade grouping
- Any "gap-based grouping" problem

---

## Key Interview Talking Points

1. **Why cumulative sum works:** Each `1` in the new_session flag increments the running sum, creating a new group. `0` values keep the same group. This is a standard technique for converting boundary flags into group IDs.

2. **Session timeout is configurable:** In production, the timeout (30 min) is usually a parameter. Google Analytics uses 30 minutes as the default.

3. **Global session IDs:** If you need globally unique session IDs (not just per-user), concatenate: `concat(user_id, "_", session_id)` or use `monotonically_increasing_id()`.

4. **Performance consideration:** The window `partitionBy("user_id").orderBy("event_time")` requires shuffling data by user_id and sorting. For billions of events, ensure the user_id has good cardinality to balance partitions.

5. **Follow-up questions:**
   - "How would you handle overlapping sessions across devices?" → Add device_id to partition key.
   - "What about bot detection?" → Filter users with unusually high event counts per session.
   - "How to compute bounce rate?" → Sessions with `event_count == 1`.
