# PySpark Implementation: Overlapping Intervals (Merge & Detect Conflicts)

## Problem Statement

Given a dataset of meeting room bookings with start and end times, **detect all overlapping (conflicting) bookings** for the same room and **merge overlapping intervals** into consolidated time blocks. This is a classic interval problem that appears in scheduling, resource allocation, and date-range analysis interviews.

### Sample Data

```
booking_id  room   start_time           end_time
B001        R101   2025-01-15 09:00     2025-01-15 10:30
B002        R101   2025-01-15 10:00     2025-01-15 11:00
B003        R101   2025-01-15 11:30     2025-01-15 12:30
B004        R101   2025-01-15 12:00     2025-01-15 13:00
B005        R101   2025-01-15 14:00     2025-01-15 15:00
B006        R102   2025-01-15 09:00     2025-01-15 10:00
B007        R102   2025-01-15 09:30     2025-01-15 10:30
```

### Expected Output 1: Conflicting Pairs

| booking_1 | booking_2 | room | overlap_start        | overlap_end          |
|-----------|-----------|------|----------------------|----------------------|
| B001      | B002      | R101 | 2025-01-15 10:00     | 2025-01-15 10:30     |
| B003      | B004      | R101 | 2025-01-15 12:00     | 2025-01-15 12:30     |
| B006      | B007      | R102 | 2025-01-15 09:30     | 2025-01-15 10:00     |

### Expected Output 2: Merged Intervals

| room | merged_start         | merged_end           |
|------|----------------------|----------------------|
| R101 | 2025-01-15 09:00     | 2025-01-15 11:00     |
| R101 | 2025-01-15 11:30     | 2025-01-15 13:00     |
| R101 | 2025-01-15 14:00     | 2025-01-15 15:00     |
| R102 | 2025-01-15 09:00     | 2025-01-15 10:30     |

---

## Method 1: Detect Overlapping Pairs (Self-Join)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_timestamp, greatest, least

# Initialize Spark session
spark = SparkSession.builder.appName("OverlappingIntervals").getOrCreate()

# Sample data
data = [
    ("B001", "R101", "2025-01-15 09:00", "2025-01-15 10:30"),
    ("B002", "R101", "2025-01-15 10:00", "2025-01-15 11:00"),
    ("B003", "R101", "2025-01-15 11:30", "2025-01-15 12:30"),
    ("B004", "R101", "2025-01-15 12:00", "2025-01-15 13:00"),
    ("B005", "R101", "2025-01-15 14:00", "2025-01-15 15:00"),
    ("B006", "R102", "2025-01-15 09:00", "2025-01-15 10:00"),
    ("B007", "R102", "2025-01-15 09:30", "2025-01-15 10:30")
]
columns = ["booking_id", "room", "start_time", "end_time"]
df = spark.createDataFrame(data, columns)
df = df.withColumn("start_time", to_timestamp("start_time")) \
       .withColumn("end_time", to_timestamp("end_time"))

# Self-join to find overlapping pairs in the same room
a = df.alias("a")
b = df.alias("b")

conflicts = a.join(
    b,
    (col("a.room") == col("b.room")) &
    (col("a.booking_id") < col("b.booking_id")) &  # Avoid duplicates/self
    (col("a.start_time") < col("b.end_time")) &     # Overlap condition
    (col("a.end_time") > col("b.start_time")),       # Overlap condition
    "inner"
).select(
    col("a.booking_id").alias("booking_1"),
    col("b.booking_id").alias("booking_2"),
    col("a.room"),
    greatest(col("a.start_time"), col("b.start_time")).alias("overlap_start"),
    least(col("a.end_time"), col("b.end_time")).alias("overlap_end")
)

conflicts.show(truncate=False)
```

### Step-by-Step Explanation

#### The Overlap Condition
Two intervals [A_start, A_end] and [B_start, B_end] overlap if and only if:
```
A_start < B_end  AND  A_end > B_start
```

Visual representation:
```
Overlap:      |---A---|
                  |---B---|
              A_start < B_end ✓  AND  A_end > B_start ✓

No overlap:   |---A---|
                        |---B---|
              A_start < B_end ✓  BUT  A_end > B_start ✗
```

#### The Overlap Region
- **overlap_start** = `greatest(A_start, B_start)` — later of the two starts
- **overlap_end** = `least(A_end, B_end)` — earlier of the two ends

- **Output:**

  | booking_1 | booking_2 | room | overlap_start        | overlap_end          |
  |-----------|-----------|------|----------------------|----------------------|
  | B001      | B002      | R101 | 2025-01-15 10:00:00  | 2025-01-15 10:30:00  |
  | B003      | B004      | R101 | 2025-01-15 12:00:00  | 2025-01-15 12:30:00  |
  | B006      | B007      | R102 | 2025-01-15 09:30:00  | 2025-01-15 10:00:00  |

  B005 has no conflicts — it doesn't overlap with anything.

---

## Method 2: Merge Overlapping Intervals

```python
from pyspark.sql.functions import lag, max as spark_max, min as spark_min, \
    when, sum as spark_sum, lit
from pyspark.sql.window import Window

# Step 1: Sort by room and start_time
window_room = Window.partitionBy("room").orderBy("start_time")

# Step 2: Find the running maximum end_time seen so far
# If current start_time > max_end_so_far, it's a new group
df_sorted = df.withColumn(
    "prev_max_end",
    spark_max("end_time").over(
        Window.partitionBy("room").orderBy("start_time")
        .rowsBetween(Window.unboundedPreceding, -1)
    )
)

# Step 3: Flag new groups (no overlap with any previous interval)
df_flagged = df_sorted.withColumn(
    "is_new_group",
    when(
        col("prev_max_end").isNull() | (col("start_time") > col("prev_max_end")),
        1
    ).otherwise(0)
)

# Step 4: Assign group IDs using cumulative sum of flags
df_grouped = df_flagged.withColumn(
    "group_id",
    spark_sum("is_new_group").over(window_room)
)

# Step 5: Merge — take min start and max end per group
merged = df_grouped.groupBy("room", "group_id").agg(
    spark_min("start_time").alias("merged_start"),
    spark_max("end_time").alias("merged_end")
).drop("group_id") \
 .orderBy("room", "merged_start")

merged.show(truncate=False)
```

### How Merging Works Step by Step

**Room R101 sorted by start_time:**

| booking_id | start_time | end_time   | prev_max_end | is_new_group | group_id |
|------------|-----------|------------|-------------|-------------|---------|
| B001       | 09:00     | 10:30      | null        | 1           | 1       |
| B002       | 10:00     | 11:00      | 10:30       | 0 (10:00 ≤ 10:30) | 1 |
| B003       | 11:30     | 12:30      | 11:00       | 1 (11:30 > 11:00) | 2 |
| B004       | 12:00     | 13:00      | 12:30       | 0 (12:00 ≤ 12:30) | 2 |
| B005       | 14:00     | 15:00      | 13:00       | 1 (14:00 > 13:00) | 3 |

**Merged result:**
- Group 1: 09:00 → 11:00 (B001 + B002 merged)
- Group 2: 11:30 → 13:00 (B003 + B004 merged)
- Group 3: 14:00 → 15:00 (B005 alone)

- **Output:**

  | room | merged_start         | merged_end           |
  |------|----------------------|----------------------|
  | R101 | 2025-01-15 09:00:00  | 2025-01-15 11:00:00  |
  | R101 | 2025-01-15 11:30:00  | 2025-01-15 13:00:00  |
  | R101 | 2025-01-15 14:00:00  | 2025-01-15 15:00:00  |
  | R102 | 2025-01-15 09:00:00  | 2025-01-15 10:30:00  |

---

## Method 3: Using SQL

```python
df.createOrReplaceTempView("bookings")

# Detect conflicts
spark.sql("""
    SELECT
        a.booking_id AS booking_1,
        b.booking_id AS booking_2,
        a.room,
        GREATEST(a.start_time, b.start_time) AS overlap_start,
        LEAST(a.end_time, b.end_time) AS overlap_end
    FROM bookings a
    JOIN bookings b
        ON a.room = b.room
        AND a.booking_id < b.booking_id
        AND a.start_time < b.end_time
        AND a.end_time > b.start_time
    ORDER BY a.room, a.booking_id
""").show(truncate=False)

# Merge overlapping intervals
spark.sql("""
    WITH sorted AS (
        SELECT *,
            MAX(end_time) OVER (
                PARTITION BY room ORDER BY start_time
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            ) AS prev_max_end
        FROM bookings
    ),
    flagged AS (
        SELECT *,
            CASE WHEN prev_max_end IS NULL OR start_time > prev_max_end
                 THEN 1 ELSE 0 END AS is_new_group
        FROM sorted
    ),
    grouped AS (
        SELECT *,
            SUM(is_new_group) OVER (
                PARTITION BY room ORDER BY start_time
            ) AS group_id
        FROM flagged
    )
    SELECT
        room,
        MIN(start_time) AS merged_start,
        MAX(end_time) AS merged_end
    FROM grouped
    GROUP BY room, group_id
    ORDER BY room, merged_start
""").show(truncate=False)
```

---

## Variation: Count Maximum Concurrent Bookings

```python
from pyspark.sql.functions import unix_timestamp, explode, sequence, \
    date_trunc

# Alternative: Find peak concurrency (max bookings at any point)
# Use the "event sweep" technique

# Create +1 for start, -1 for end
starts = df.select("room", col("start_time").alias("event_time"), lit(1).alias("delta"))
ends = df.select("room", col("end_time").alias("event_time"), lit(-1).alias("delta"))

events = starts.unionAll(ends)

# Running sum of deltas = concurrent bookings at each point
window_sweep = Window.partitionBy("room").orderBy("event_time") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

concurrent = events.withColumn(
    "active_bookings", spark_sum("delta").over(window_sweep)
)

# Find the maximum
max_concurrent = concurrent.groupBy("room").agg(
    spark_max("active_bookings").alias("max_concurrent")
)

max_concurrent.show()
```

- **Output:**

  | room | max_concurrent |
  |------|---------------|
  | R101 | 2             |
  | R102 | 2             |

---

## Key Interview Talking Points

1. **The overlap condition is universal:** `A.start < B.end AND A.end > B.start`. Memorize this — it works for any interval type (dates, times, numeric ranges).

2. **Merging requires tracking running max end:** The key insight is that a new interval starts a new group only if its start is beyond the maximum end seen so far. This handles chains of overlaps (A overlaps B, B overlaps C → all three merge).

3. **Self-join for detection, window functions for merging:** Use self-join when you need to identify specific conflicting pairs. Use the running-max + cumulative-sum approach when you need to merge intervals.

4. **Event sweep for concurrency:** Converting intervals to +1/-1 events and computing a running sum is the most efficient way to find peak concurrency — O(n log n) vs O(n^2) for pairwise comparison.

5. **Common real-world use cases:**
   - Meeting room scheduling conflicts
   - Employee shift overlap detection
   - Insurance policy coverage periods
   - Subscription active/inactive periods
   - Network bandwidth allocation
   - Date range consolidation in data warehousing
