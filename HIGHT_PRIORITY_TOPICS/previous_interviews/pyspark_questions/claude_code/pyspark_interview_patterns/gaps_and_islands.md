# PySpark Implementation: Gaps and Islands Problem

## Problem Statement

Given a dataset of server monitoring logs where each row records whether a server was **UP** or **DOWN** on a given date, identify **contiguous periods** (islands) where the server had the same status. Collapse consecutive same-status rows into date ranges. This is the classic "Gaps and Islands" pattern — one of the most frequently asked SQL/PySpark interview problems.

### Sample Data

```
server_id  log_date     status
S001       2025-01-01   UP
S001       2025-01-02   UP
S001       2025-01-03   UP
S001       2025-01-04   DOWN
S001       2025-01-05   DOWN
S001       2025-01-06   UP
S001       2025-01-07   UP
S001       2025-01-08   DOWN
S001       2025-01-09   UP
S001       2025-01-10   UP
S001       2025-01-11   UP
```

### Expected Output (Islands)

| server_id | status | start_date | end_date   | duration_days |
|-----------|--------|------------|------------|---------------|
| S001      | UP     | 2025-01-01 | 2025-01-03 | 3             |
| S001      | DOWN   | 2025-01-04 | 2025-01-05 | 2             |
| S001      | UP     | 2025-01-06 | 2025-01-07 | 2             |
| S001      | DOWN   | 2025-01-08 | 2025-01-08 | 1             |
| S001      | UP     | 2025-01-09 | 2025-01-11 | 3             |

---

## Method 1: Row Number Difference Technique (Classic)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_date, row_number, min as spark_min, \
    max as spark_max, datediff, lit
from pyspark.sql.window import Window

# Initialize Spark session
spark = SparkSession.builder.appName("GapsAndIslands").getOrCreate()

# Sample data
data = [
    ("S001", "2025-01-01", "UP"), ("S001", "2025-01-02", "UP"),
    ("S001", "2025-01-03", "UP"), ("S001", "2025-01-04", "DOWN"),
    ("S001", "2025-01-05", "DOWN"), ("S001", "2025-01-06", "UP"),
    ("S001", "2025-01-07", "UP"), ("S001", "2025-01-08", "DOWN"),
    ("S001", "2025-01-09", "UP"), ("S001", "2025-01-10", "UP"),
    ("S001", "2025-01-11", "UP")
]
columns = ["server_id", "log_date", "status"]
df = spark.createDataFrame(data, columns)
df = df.withColumn("log_date", to_date(col("log_date")))

# Step 1: Assign overall row number ordered by date
window_all = Window.partitionBy("server_id").orderBy("log_date")

# Step 2: Assign row number within each status group
window_status = Window.partitionBy("server_id", "status").orderBy("log_date")

df_numbered = df.withColumn("rn_all", row_number().over(window_all)) \
    .withColumn("rn_status", row_number().over(window_status))

# Step 3: The difference (rn_all - rn_status) creates a group identifier
df_grouped = df_numbered.withColumn("island_id", col("rn_all") - col("rn_status"))

# Step 4: Aggregate each island
islands = df_grouped.groupBy("server_id", "status", "island_id").agg(
    spark_min("log_date").alias("start_date"),
    spark_max("log_date").alias("end_date")
).withColumn(
    "duration_days", datediff(col("end_date"), col("start_date")) + 1
).drop("island_id") \
 .orderBy("start_date")

islands.show(truncate=False)
```

### Step-by-Step Explanation

#### Step 1-2: Assign Two Row Numbers

| log_date   | status | rn_all | rn_status |
|------------|--------|--------|-----------|
| 2025-01-01 | UP     | 1      | 1         |
| 2025-01-02 | UP     | 2      | 2         |
| 2025-01-03 | UP     | 3      | 3         |
| 2025-01-04 | DOWN   | 4      | 1         |
| 2025-01-05 | DOWN   | 5      | 2         |
| 2025-01-06 | UP     | 6      | 4         |
| 2025-01-07 | UP     | 7      | 5         |
| 2025-01-08 | DOWN   | 8      | 3         |
| 2025-01-09 | UP     | 9      | 6         |
| 2025-01-10 | UP     | 10     | 7         |
| 2025-01-11 | UP     | 11     | 8         |

#### Step 3: The Magic — rn_all - rn_status

| log_date   | status | rn_all | rn_status | island_id (diff) |
|------------|--------|--------|-----------|------------------|
| 2025-01-01 | UP     | 1      | 1         | **0**            |
| 2025-01-02 | UP     | 2      | 2         | **0**            |
| 2025-01-03 | UP     | 3      | 3         | **0**            |
| 2025-01-04 | DOWN   | 4      | 1         | **3**            |
| 2025-01-05 | DOWN   | 5      | 2         | **3**            |
| 2025-01-06 | UP     | 6      | 4         | **2**            |
| 2025-01-07 | UP     | 7      | 5         | **2**            |
| 2025-01-08 | DOWN   | 8      | 3         | **5**            |
| 2025-01-09 | UP     | 9      | 6         | **3**            |
| 2025-01-10 | UP     | 10     | 7         | **3**            |
| 2025-01-11 | UP     | 11     | 8         | **3**            |

**Key insight:** Consecutive rows with the same status produce the **same difference** value. This difference becomes a group identifier for each "island."

#### Step 4: Group by (server_id, status, island_id)
- Group (UP, 0): Jan 01 → Jan 03 = 3 days
- Group (DOWN, 3): Jan 04 → Jan 05 = 2 days
- Group (UP, 2): Jan 06 → Jan 07 = 2 days
- Group (DOWN, 5): Jan 08 → Jan 08 = 1 day
- Group (UP, 3): Jan 09 → Jan 11 = 3 days

---

## Method 2: Using lag() to Detect Changes

```python
from pyspark.sql.functions import lag, when, sum as spark_sum

# Detect where status changes from previous row
window_ordered = Window.partitionBy("server_id").orderBy("log_date")

df_changes = df.withColumn(
    "prev_status", lag("status").over(window_ordered)
).withColumn(
    "is_new_island",
    when(
        (col("status") != col("prev_status")) | col("prev_status").isNull(), 1
    ).otherwise(0)
)

# Cumulative sum of change flags = island group number
df_islands = df_changes.withColumn(
    "island_num",
    spark_sum("is_new_island").over(window_ordered)
)

# Aggregate
islands_v2 = df_islands.groupBy("server_id", "status", "island_num").agg(
    spark_min("log_date").alias("start_date"),
    spark_max("log_date").alias("end_date")
).withColumn(
    "duration_days", datediff(col("end_date"), col("start_date")) + 1
).drop("island_num") \
 .orderBy("start_date")

islands_v2.show(truncate=False)
```

### How lag() Method Works

| log_date   | status | prev_status | is_new_island | island_num |
|------------|--------|-------------|---------------|------------|
| 2025-01-01 | UP     | null        | 1             | 1          |
| 2025-01-02 | UP     | UP          | 0             | 1          |
| 2025-01-03 | UP     | UP          | 0             | 1          |
| 2025-01-04 | DOWN   | UP          | 1             | 2          |
| 2025-01-05 | DOWN   | DOWN        | 0             | 2          |
| 2025-01-06 | UP     | DOWN        | 1             | 3          |
| 2025-01-07 | UP     | UP          | 0             | 3          |
| 2025-01-08 | DOWN   | UP          | 1             | 4          |
| 2025-01-09 | UP     | DOWN        | 1             | 5          |
| 2025-01-10 | UP     | UP          | 0             | 5          |
| 2025-01-11 | UP     | UP          | 0             | 5          |

**Logic:** Flag a new island whenever the status changes from the previous row. Cumulative sum of flags gives each island a unique number.

---

## Method 3: Using SQL

```python
df.createOrReplaceTempView("server_logs")

islands_sql = spark.sql("""
    WITH numbered AS (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY server_id ORDER BY log_date) -
            ROW_NUMBER() OVER (PARTITION BY server_id, status ORDER BY log_date) AS island_id
        FROM server_logs
    )
    SELECT
        server_id,
        status,
        MIN(log_date) AS start_date,
        MAX(log_date) AS end_date,
        DATEDIFF(MAX(log_date), MIN(log_date)) + 1 AS duration_days
    FROM numbered
    GROUP BY server_id, status, island_id
    ORDER BY start_date
""")

islands_sql.show(truncate=False)
```

---

## Variation: Finding Gaps (Missing Dates)

```python
from pyspark.sql.functions import date_add

# Given a series of dates where a user was active, find the inactive gaps
active_data = [
    ("U001", "2025-01-01"), ("U001", "2025-01-02"), ("U001", "2025-01-03"),
    ("U001", "2025-01-07"), ("U001", "2025-01-08"),
    ("U001", "2025-01-12"), ("U001", "2025-01-13"), ("U001", "2025-01-14")
]
active_df = spark.createDataFrame(active_data, ["user_id", "active_date"])
active_df = active_df.withColumn("active_date", to_date(col("active_date")))

# Find gaps using lag
window_user = Window.partitionBy("user_id").orderBy("active_date")

gaps = active_df.withColumn("prev_date", lag("active_date").over(window_user)) \
    .filter(datediff(col("active_date"), col("prev_date")) > 1) \
    .withColumn("gap_start", date_add(col("prev_date"), 1)) \
    .withColumn("gap_end", date_add(col("active_date"), -1)) \
    .withColumn("gap_days", datediff(col("active_date"), col("prev_date")) - 1) \
    .select("user_id", "gap_start", "gap_end", "gap_days")

gaps.show(truncate=False)
```

- **Output:**

  | user_id | gap_start  | gap_end    | gap_days |
  |---------|------------|------------|----------|
  | U001    | 2025-01-04 | 2025-01-06 | 3        |
  | U001    | 2025-01-09 | 2025-01-11 | 3        |

---

## When to Use Which Method

| Method | Pros | Cons |
|--------|------|------|
| Row number difference | Classic, interviewers expect it | Harder to explain intuitively |
| lag() + cumulative sum | Intuitive, easy to explain | Slightly more code |
| SQL | Compact, familiar to SQL users | Same logic, different syntax |

## Key Interview Talking Points

1. **Why the row number trick works:** Both row numbers increment by 1 for consecutive rows. When a status change happens, `rn_status` resets but `rn_all` doesn't — so the difference changes, creating a new group identifier.

2. **This pattern generalizes to any sequence problem:** Replace "status" with any categorical column and "date" with any ordered column. Works for stock price trends, employee attendance streaks, subscription status periods, etc.

3. **Performance:** Both methods use window functions with a single pass over the data (O(n log n) for sorting). The groupBy at the end is a standard aggregation.

4. **Common variations:**
   - "Find the longest consecutive login streak per user"
   - "Merge overlapping date ranges into continuous periods"
   - "Detect consecutive days of high/low temperature"
   - "Find subscription active/inactive periods"
   - "Identify consecutive winning/losing streaks in sports data"

5. **Edge cases to handle:**
   - Single-day islands (start_date = end_date)
   - Multiple servers/users (partition correctly)
   - Gaps in the date sequence (not every day has a record)
