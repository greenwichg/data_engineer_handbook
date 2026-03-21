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

## Variation: Overlap Duration & Conflict Summary

When you need to quantify how much overlap exists and summarize conflicts per resource:

```python
from pyspark.sql import functions as F

# Add overlap duration in minutes to conflict pairs
conflicts_with_duration = conflicts.withColumn(
    "overlap_minutes",
    F.round(
        (F.unix_timestamp("overlap_end") - F.unix_timestamp("overlap_start")) / 60, 0
    )
)

conflicts_with_duration.show(truncate=False)

# Conflict summary: count and total overlap per resource
conflict_summary = conflicts_with_duration.groupBy("room").agg(
    F.count("*").alias("conflict_count"),
    F.round(F.sum("overlap_minutes"), 0).alias("total_overlap_minutes")
).orderBy(F.desc("conflict_count"))

conflict_summary.show()

# Identify conflicted vs. clean bookings using left_anti join
conflicted_ids = conflicts.select(
    F.col("booking_1").alias("booking_id")
).union(
    conflicts.select(F.col("booking_2").alias("booking_id"))
).distinct()

conflicted_bookings = df.join(conflicted_ids, "booking_id")
clean_bookings = df.join(conflicted_ids, "booking_id", "left_anti")

print(f"Conflicted bookings: {conflicted_bookings.count()}")
print(f"Clean bookings: {clean_bookings.count()}")
```

---

## Variation: Capacity-Based Conflict Detection

When a resource type has capacity > 1 (e.g., a hotel has 2 Standard rooms), pairwise conflict detection is not enough. Use the event-sweep approach and compare against capacity:

```python
from pyspark.sql import functions as F
from pyspark.sql.window import Window

# Hotel rooms with capacity
reservations_data = [
    ("R001", "Standard", "Alice", "2024-03-15", "2024-03-18"),
    ("R002", "Standard", "Bob", "2024-03-16", "2024-03-19"),
    ("R003", "Standard", "Carol", "2024-03-17", "2024-03-20"),
    ("R004", "Standard", "Dave", "2024-03-15", "2024-03-16"),
    ("R005", "Deluxe", "Eve", "2024-03-15", "2024-03-18"),
    ("R006", "Deluxe", "Frank", "2024-03-16", "2024-03-17"),
]

df_hotel = spark.createDataFrame(
    reservations_data,
    ["reservation_id", "room_type", "guest_name", "check_in", "check_out"]
).withColumn("check_in", F.to_date("check_in")) \
 .withColumn("check_out", F.to_date("check_out"))

# Room capacity
capacity_data = [("Standard", 2), ("Deluxe", 1)]
capacity_df = spark.createDataFrame(capacity_data, ["room_type", "capacity"])

# Event-based approach: +1 at check-in, -1 at check-out
events = df_hotel.select(
    "room_type",
    F.col("check_in").alias("event_date"),
    F.lit(1).alias("change")
).union(
    df_hotel.select(
        "room_type",
        F.col("check_out").alias("event_date"),
        F.lit(-1).alias("change")
    )
)

# Running sum of concurrent bookings
w = Window.partitionBy("room_type").orderBy("event_date") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

concurrent = events.groupBy("room_type", "event_date").agg(
    F.sum("change").alias("daily_change")
).withColumn(
    "concurrent_bookings", F.sum("daily_change").over(w)
)

# Check for capacity violations
violations = concurrent.join(capacity_df, "room_type") \
    .filter(F.col("concurrent_bookings") > F.col("capacity"))

print("=== Capacity Violations ===")
violations.show()

# Peak concurrent bookings per room type
peak = concurrent.groupBy("room_type").agg(
    F.max("concurrent_bookings").alias("peak_concurrent")
).join(capacity_df, "room_type") \
 .withColumn(
    "over_capacity",
    F.when(F.col("peak_concurrent") > F.col("capacity"), True).otherwise(False)
)

print("=== Peak Utilization ===")
peak.show()
```

---

## Variation: First-Come-First-Served Conflict Resolution

When bookings have a `booked_on` date, resolve conflicts by keeping the earlier booking:

```python
# Add a booked_on column to reservations for priority
# (Assume df has columns: reservation_id, resource_id, guest_name, start_time, end_time, booked_on)

df.createOrReplaceTempView("reservations")

resolution = spark.sql("""
    WITH conflicts AS (
        SELECT
            a.reservation_id AS keep_id,
            b.reservation_id AS reject_id,
            a.resource_id,
            a.guest_name AS keep_guest,
            b.guest_name AS reject_guest,
            a.booked_on AS keep_booked,
            b.booked_on AS reject_booked
        FROM reservations a
        JOIN reservations b
            ON a.resource_id = b.resource_id
            AND a.reservation_id != b.reservation_id
            AND a.start_time < b.end_time
            AND a.end_time > b.start_time
            AND a.booked_on < b.booked_on  -- Earlier booking wins
    )
    SELECT DISTINCT
        resource_id,
        keep_id,
        keep_guest,
        reject_id,
        reject_guest,
        'Earlier booking wins' AS resolution_rule
    FROM conflicts
    ORDER BY resource_id
""")

resolution.show(truncate=False)
```

---

## Variation: Conflict Resolution — Find Alternative Rooms

For each conflicting booking, find rooms that are FREE during that time slot:

```python
from pyspark.sql.functions import col

# Get all conflicting booking IDs (take the later-created / lower-priority one)
conflicting_ids = conflicts.select("booking_2").distinct() \
    .withColumnRenamed("booking_2", "booking_id")

conflicting_bookings = df.join(conflicting_ids, on="booking_id")
all_rooms = df.select("room").distinct()

# Cross join conflicting bookings with all rooms
alternatives = conflicting_bookings.crossJoin(
    all_rooms.withColumnRenamed("room", "alt_room")
).filter(
    col("alt_room") != col("room")  # Skip the original room
)

# Left join with existing bookings to find rooms with no conflicts
room_check = alternatives.alias("alt").join(
    df.alias("existing"),
    (col("alt.alt_room") == col("existing.room")) &
    (col("alt.start_time") < col("existing.end_time")) &
    (col("alt.end_time") > col("existing.start_time")),
    "left"
).filter(
    col("existing.booking_id").isNull()  # No conflict → room is free
).select(
    col("alt.booking_id"),
    col("alt.start_time"),
    col("alt.end_time"),
    col("alt.alt_room").alias("suggested_room")
)

print("=== ALTERNATIVE ROOMS ===")
room_check.show(truncate=False)
```

---

## Variation: Conflict Resolution — Find Next Available Time Slot

Use `lead()` to find gaps between consecutive bookings and suggest reschedule times:

```python
from pyspark.sql.functions import lead, unix_timestamp, round as spark_round
from pyspark.sql.window import Window

# For each room, find gaps between consecutive bookings
window_room = Window.partitionBy("room").orderBy("start_time")

gaps = df.withColumn(
    "next_start", lead("start_time").over(window_room)
).withColumn(
    "gap_minutes",
    spark_round(
        (unix_timestamp("next_start") - unix_timestamp("end_time")) / 60, 0
    )
).filter(
    col("gap_minutes") > 0  # There's a gap
).select(
    "room",
    col("end_time").alias("gap_start"),
    col("next_start").alias("gap_end"),
    col("gap_minutes")
)

print("=== FREE SLOTS PER ROOM ===")
gaps.orderBy("room", "gap_start").show(truncate=False)

# For a specific conflicting booking, find the next available slot
# in the same room that fits the meeting duration
conflicting_with_duration = conflicting_bookings.withColumn(
    "duration_min",
    spark_round(
        (unix_timestamp("end_time") - unix_timestamp("start_time")) / 60, 0
    )
)

# Join with gaps to find slots that fit
suggested_times = conflicting_with_duration.alias("cb").join(
    gaps.alias("g"),
    (col("cb.room") == col("g.room")) &
    (col("g.gap_minutes") >= col("cb.duration_min")) &
    (col("g.gap_start") >= col("cb.start_time")),  # Only suggest future slots
    "inner"
).select(
    col("cb.booking_id"),
    col("cb.room"),
    col("cb.duration_min"),
    col("g.gap_start").alias("suggested_start"),
    col("g.gap_end").alias("suggested_end_latest")
)

print("=== SUGGESTED RESCHEDULE TIMES ===")
suggested_times.show(truncate=False)
```

---

## Key Interview Talking Points

1. **The overlap condition is universal:** `A.start < B.end AND A.end > B.start`. Memorize this — it works for any interval type (dates, times, numeric ranges).

2. **Merging requires tracking running max end:** The key insight is that a new interval starts a new group only if its start is beyond the maximum end seen so far. This handles chains of overlaps (A overlaps B, B overlaps C → all three merge).

3. **Self-join for detection, window functions for merging:** Use self-join when you need to identify specific conflicting pairs. Use the running-max + cumulative-sum approach when you need to merge intervals.

4. **Event sweep for concurrency:** Converting intervals to +1/-1 events and computing a running sum is the most efficient way to find peak concurrency — O(n log n) vs O(n^2) for pairwise comparison.

5. **Inclusive vs. exclusive boundaries:** Clarify whether time bounds are inclusive or exclusive. Hotels typically use [check_in, check_out) where check-out day is not a conflict. This changes the overlap condition to `A.start < B.end AND A.end > B.start` (strict) vs `A.start <= B.end AND A.end >= B.start` (inclusive).

6. **Capacity check:** For resources with capacity > 1, pairwise self-join is not sufficient. Use the event-based approach to count concurrent bookings and compare against the capacity threshold.

7. **Conflict resolution strategies:**
   - **First-come-first-served:** Earlier `booked_on` date wins
   - **Alternative room:** Cross-join conflicting bookings with all rooms, then left join + null filter to find free rooms
   - **Alternative time:** Find gaps between bookings using `lead()`, then match gaps that fit the meeting duration
   - **Priority-based:** Executive meetings win over standups, etc.
   - **Manual review queue:** Flag conflicts for human resolution

8. **Performance:** The self-join is O(n^2) per resource. For resources with many bookings, consider **time-bucket pre-filtering** to reduce join candidates.

9. **Real-time systems:** For real-time booking systems, mention using database transactions with row-level locks to prevent race conditions.

10. **Common real-world use cases:**
    - Meeting room scheduling conflicts
    - Hotel/Airbnb double-booking detection
    - Employee shift overlap detection
    - Insurance policy coverage periods
    - Subscription active/inactive periods
    - Network bandwidth allocation
    - Date range consolidation in data warehousing
    - Recurring meeting conflict detection
    - Buffer time between bookings (e.g., 5 min for room changeover)
