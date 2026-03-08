# PySpark Implementation: Windowed Deduplication (Time-Based)

## Problem Statement
Given a stream of user click/event data, keep only one event per user within each 30-minute time window. This is a common pattern in clickstream analytics, IoT data processing, and event deduplication — frequently asked in interviews for streaming and batch processing roles.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("WindowedDedup").getOrCreate()

data = [
    ("user_1", "2025-01-15 09:05:00", "page_view", "/home"),
    ("user_1", "2025-01-15 09:08:00", "page_view", "/products"),
    ("user_1", "2025-01-15 09:22:00", "click", "/products/123"),
    ("user_1", "2025-01-15 09:45:00", "page_view", "/cart"),
    ("user_1", "2025-01-15 09:50:00", "click", "/checkout"),
    ("user_2", "2025-01-15 10:01:00", "page_view", "/home"),
    ("user_2", "2025-01-15 10:15:00", "click", "/products/456"),
    ("user_2", "2025-01-15 10:40:00", "page_view", "/products"),
    ("user_2", "2025-01-15 11:05:00", "click", "/cart"),
]

columns = ["user_id", "event_time", "event_type", "page"]
df = spark.createDataFrame(data, columns)
df = df.withColumn("event_time", F.to_timestamp("event_time"))
df.show(truncate=False)
```

```
+-------+-------------------+----------+-------------+
|user_id|event_time         |event_type|page         |
+-------+-------------------+----------+-------------+
|user_1 |2025-01-15 09:05:00|page_view |/home        |
|user_1 |2025-01-15 09:08:00|page_view |/products    |
|user_1 |2025-01-15 09:22:00|click     |/products/123|
|user_1 |2025-01-15 09:45:00|page_view |/cart        |
|user_1 |2025-01-15 09:50:00|click     |/checkout    |
|user_2 |2025-01-15 10:01:00|page_view |/home        |
|user_2 |2025-01-15 10:15:00|click     |/products/456|
|user_2 |2025-01-15 10:40:00|page_view |/products    |
|user_2 |2025-01-15 11:05:00|click     |/cart        |
+-------+-------------------+----------+-------------+
```

### Expected Output (keep first event per user per 30-min window)
```
+-------+-------------------+----------+-------------+-----------+
|user_id|event_time         |event_type|page         |window_key |
+-------+-------------------+----------+-------------+-----------+
|user_1 |2025-01-15 09:05:00|page_view |/home        |09:00-09:30|
|user_1 |2025-01-15 09:45:00|page_view |/cart        |09:30-10:00|
|user_2 |2025-01-15 10:01:00|page_view |/home        |10:00-10:30|
|user_2 |2025-01-15 10:40:00|page_view |/products    |10:30-11:00|
|user_2 |2025-01-15 11:05:00|click     |/cart        |11:00-11:30|
+-------+-------------------+----------+-------------+-----------+
```

---

## Method 1: Tumbling Window with row_number() (Recommended)

```python
# Step 1: Assign each event to a 30-minute tumbling window
df_windowed = df.withColumn(
    "window_start",
    F.window("event_time", "30 minutes").start
)

# Step 2: Rank events within each user + window (earliest first)
window_spec = Window.partitionBy("user_id", "window_start").orderBy("event_time")

df_ranked = df_windowed.withColumn("rn", F.row_number().over(window_spec))

# Step 3: Keep only the first event per user per window
result = df_ranked.filter(F.col("rn") == 1).drop("rn")
result.orderBy("user_id", "event_time").show(truncate=False)
```

### Step-by-Step Explanation

#### Step 1: Assign tumbling windows
- **What happens:** `F.window("event_time", "30 minutes")` creates fixed 30-minute buckets: [09:00-09:30), [09:30-10:00), etc.
- **Output:**

  | user_id | event_time | window_start        |
  |---------|------------|---------------------|
  | user_1  | 09:05      | 2025-01-15 09:00:00 |
  | user_1  | 09:08      | 2025-01-15 09:00:00 |
  | user_1  | 09:22      | 2025-01-15 09:00:00 |
  | user_1  | 09:45      | 2025-01-15 09:30:00 |
  | user_1  | 09:50      | 2025-01-15 09:30:00 |

#### Step 2: Rank within each user + window
- **Output:**

  | user_id | event_time | window_start | rn |
  |---------|------------|--------------|-----|
  | user_1  | 09:05      | 09:00        | 1   |
  | user_1  | 09:08      | 09:00        | 2   |
  | user_1  | 09:22      | 09:00        | 3   |
  | user_1  | 09:45      | 09:30        | 1   |
  | user_1  | 09:50      | 09:30        | 2   |

#### Step 3: Keep rn == 1
- One event per user per 30-minute window is retained.

---

## Method 2: Floor-Based Bucketing (No window() function)

```python
# Manually compute the 30-minute bucket using floor division
window_minutes = 30

df_bucketed = df.withColumn(
    "bucket",
    F.from_unixtime(
        (F.unix_timestamp("event_time") / (window_minutes * 60)).cast("long")
        * (window_minutes * 60)
    )
)

# Rank and keep first per user per bucket
window_spec = Window.partitionBy("user_id", "bucket").orderBy("event_time")
result_bucket = (
    df_bucketed
    .withColumn("rn", F.row_number().over(window_spec))
    .filter(F.col("rn") == 1)
    .drop("rn", "bucket")
)
result_bucket.orderBy("user_id", "event_time").show(truncate=False)
```

- **When to use:** When you need compatibility with older Spark versions that don't support `F.window()`, or when you need custom bucket sizes.

---

## Method 3: Session-Based Dedup (Gap-Based Windows)

Instead of fixed 30-minute tumbling windows, create a new "session" whenever there is a 30+ minute gap between events for the same user:

```python
# Step 1: Compute gap to previous event per user
window_user = Window.partitionBy("user_id").orderBy("event_time")
df_with_gap = df.withColumn(
    "prev_time", F.lag("event_time").over(window_user)
).withColumn(
    "gap_minutes",
    (F.unix_timestamp("event_time") - F.unix_timestamp("prev_time")) / 60
)

# Step 2: Flag new sessions (gap > 30 min or first event)
df_flagged = df_with_gap.withColumn(
    "new_session",
    F.when(
        (F.col("gap_minutes").isNull()) | (F.col("gap_minutes") > 30), 1
    ).otherwise(0)
)

# Step 3: Assign session IDs using cumulative sum of flags
df_sessions = df_flagged.withColumn(
    "session_id",
    F.sum("new_session").over(window_user.rowsBetween(Window.unboundedPreceding, Window.currentRow))
)

# Step 4: Keep first event per session
session_window = Window.partitionBy("user_id", "session_id").orderBy("event_time")
result_session = (
    df_sessions
    .withColumn("rn", F.row_number().over(session_window))
    .filter(F.col("rn") == 1)
    .drop("prev_time", "gap_minutes", "new_session", "session_id", "rn")
)
result_session.orderBy("user_id", "event_time").show(truncate=False)
```

---

## Method 4: Spark SQL

```python
df.createOrReplaceTempView("events")

result_sql = spark.sql("""
    WITH windowed AS (
        SELECT *,
            window(event_time, '30 minutes').start AS window_start,
            ROW_NUMBER() OVER (
                PARTITION BY user_id, window(event_time, '30 minutes').start
                ORDER BY event_time
            ) AS rn
        FROM events
    )
    SELECT user_id, event_time, event_type, page
    FROM windowed
    WHERE rn = 1
    ORDER BY user_id, event_time
""")
result_sql.show(truncate=False)
```

---

## Variation: Keep Last Event Per Window (Instead of First)

```python
# Simply change orderBy to descending
window_last = Window.partitionBy("user_id", "window_start").orderBy(F.desc("event_time"))
result_last = (
    df_windowed
    .withColumn("rn", F.row_number().over(window_last))
    .filter(F.col("rn") == 1)
    .drop("rn")
)
```

## Variation: Aggregate Within Windows

```python
# Instead of keeping one event, aggregate stats per window
window_stats = (
    df_windowed.groupBy("user_id", "window_start")
    .agg(
        F.count("*").alias("event_count"),
        F.min("event_time").alias("first_event"),
        F.max("event_time").alias("last_event"),
        F.collect_set("event_type").alias("event_types"),
    )
)
window_stats.show(truncate=False)
```

---

## Comparison of Methods

| Method | Window Type | Use Case | Complexity |
|--------|-------------|----------|------------|
| Tumbling window + row_number | Fixed time buckets | Standard dedup | Simple |
| Floor-based bucketing | Fixed time buckets | Older Spark versions | Manual |
| Session-based (gap) | Activity-based sessions | User session analysis | More complex |
| Spark SQL | Fixed time buckets | SQL preference | Simple |

## Key Interview Talking Points

1. **Tumbling vs sliding vs session windows:**
   - **Tumbling:** Fixed, non-overlapping (e.g., every 30 min from the hour). An event belongs to exactly one window.
   - **Sliding:** Overlapping windows (e.g., 30 min window every 10 min). An event can belong to multiple windows.
   - **Session:** Dynamic, based on activity gaps. Common for user behavior analysis.
2. **`F.window()` function** (Spark 2.0+) automatically assigns events to time windows. It returns a struct with `start` and `end` fields.
3. **row_number() vs groupBy aggregation:** Use row_number when you want to keep the full original row. Use groupBy when you want aggregated stats per window.
4. This pattern directly maps to **Structured Streaming** with `withWatermark` and `dropDuplicatesWithinWatermark` for real-time dedup.
5. **Floor-based bucketing** is useful in interviews to show you understand the math behind windowing without relying on built-in functions.
