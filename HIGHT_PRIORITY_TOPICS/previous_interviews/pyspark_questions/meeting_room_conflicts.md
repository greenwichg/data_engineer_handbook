# PySpark Implementation: Meeting Room Scheduling Conflicts & Resolution

## Problem Statement 

Given a dataset of meeting room booking requests, **detect all scheduling conflicts** (double-bookings) and **suggest resolutions** — either by finding an alternative room or an alternative time slot. This is the scheduling/resource-allocation version of the `overlapping_intervals` pattern — same overlap detection logic (self-join with `A.start < B.end AND A.end > B.start`), but extended with conflict resolution logic.

### Sample Data

```
booking_id  room   organizer  meeting_name     start_time           end_time
B001        R101   Alice      Team Standup     2025-01-15 09:00     2025-01-15 09:30
B002        R101   Bob        Design Review    2025-01-15 09:15     2025-01-15 10:00
B003        R101   Charlie    Sprint Planning  2025-01-15 10:00     2025-01-15 11:00
B004        R102   Alice      1:1 Meeting      2025-01-15 09:00     2025-01-15 09:30
B005        R102   Diana      HR Sync          2025-01-15 09:00     2025-01-15 10:00
B006        R103   Eve        Workshop         2025-01-15 09:00     2025-01-15 12:00
B007        R101   Frank      Quick Sync       2025-01-15 14:00     2025-01-15 14:30
```

### Expected Output: Conflicts

| booking_1 | booking_2 | room | conflict_start    | conflict_end      | overlap_min |
|-----------|-----------|------|-------------------|-------------------|------------|
| B001      | B002      | R101 | 09:15             | 09:30             | 15         |
| B004      | B005      | R102 | 09:00             | 09:30             | 30         |

---

## PySpark Code Solution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_timestamp, greatest, least, \
    unix_timestamp, round as spark_round, lit, count, min as spark_min, \
    max as spark_max, when, collect_list
from pyspark.sql.window import Window

# Initialize Spark session
spark = SparkSession.builder.appName("MeetingConflicts").getOrCreate()

# Sample data
data = [
    ("B001", "R101", "Alice", "Team Standup", "2025-01-15 09:00", "2025-01-15 09:30"),
    ("B002", "R101", "Bob", "Design Review", "2025-01-15 09:15", "2025-01-15 10:00"),
    ("B003", "R101", "Charlie", "Sprint Planning", "2025-01-15 10:00", "2025-01-15 11:00"),
    ("B004", "R102", "Alice", "1:1 Meeting", "2025-01-15 09:00", "2025-01-15 09:30"),
    ("B005", "R102", "Diana", "HR Sync", "2025-01-15 09:00", "2025-01-15 10:00"),
    ("B006", "R103", "Eve", "Workshop", "2025-01-15 09:00", "2025-01-15 12:00"),
    ("B007", "R101", "Frank", "Quick Sync", "2025-01-15 14:00", "2025-01-15 14:30")
]
columns = ["booking_id", "room", "organizer", "meeting_name", "start_time", "end_time"]
df = spark.createDataFrame(data, columns)
df = df.withColumn("start_time", to_timestamp("start_time")) \
       .withColumn("end_time", to_timestamp("end_time"))

# =========================================
# Part 1: Detect Conflicts (Self-Join)
# =========================================

a = df.alias("a")
b = df.alias("b")

conflicts = a.join(
    b,
    (col("a.room") == col("b.room")) &              # Same room
    (col("a.booking_id") < col("b.booking_id")) &   # Avoid duplicates/self
    (col("a.start_time") < col("b.end_time")) &     # Overlap condition
    (col("a.end_time") > col("b.start_time")),       # Overlap condition
    "inner"
).select(
    col("a.booking_id").alias("booking_1"),
    col("a.meeting_name").alias("meeting_1"),
    col("a.organizer").alias("organizer_1"),
    col("b.booking_id").alias("booking_2"),
    col("b.meeting_name").alias("meeting_2"),
    col("b.organizer").alias("organizer_2"),
    col("a.room"),
    greatest(col("a.start_time"), col("b.start_time")).alias("conflict_start"),
    least(col("a.end_time"), col("b.end_time")).alias("conflict_end")
).withColumn(
    "overlap_min",
    spark_round(
        (unix_timestamp("conflict_end") - unix_timestamp("conflict_start")) / 60, 0
    )
)

print("=== CONFLICTS DETECTED ===")
conflicts.show(truncate=False)
```

---

## Part 2: Find Alternative Rooms

```python
# =========================================
# Part 2: Suggest Alternative Rooms
# =========================================

# For each conflicting booking, find rooms that are FREE during that time
all_rooms = df.select("room").distinct()

# Get all conflicting booking IDs
conflicting_ids = conflicts.select("booking_2").distinct() \
    .withColumnRenamed("booking_2", "booking_id")

# For each conflicting booking, check every room
conflicting_bookings = df.join(conflicting_ids, on="booking_id")

# Cross join conflicting bookings with all rooms
alternatives = conflicting_bookings.crossJoin(
    all_rooms.withColumnRenamed("room", "alt_room")
).filter(
    col("alt_room") != col("room")  # Skip the original room
)

# Remove rooms that already have a conflicting booking at that time
busy_rooms = alternatives.join(
    df.alias("existing"),
    (col("alt_room") == col("existing.room")) &
    (col("start_time") < col("existing.end_time")) &
    (col("end_time") > col("existing.start_time")),
    "left_anti"  # Keep only rows that DON'T match (room is free)
)

# Actually we need a different approach — left_anti on the room check
# Let's use a left join and filter for nulls
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
    col("alt.meeting_name"),
    col("alt.start_time"),
    col("alt.end_time"),
    col("alt.alt_room").alias("suggested_room")
)

print("=== ALTERNATIVE ROOMS ===")
room_check.show(truncate=False)
```

---

## Part 3: Find Next Available Time Slot in Same Room

```python
# =========================================
# Part 3: Find Next Free Slot in the Same Room
# =========================================

from pyspark.sql.functions import lead

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
    col("cb.meeting_name"),
    col("cb.room"),
    col("cb.duration_min"),
    col("g.gap_start").alias("suggested_start"),
    col("g.gap_end").alias("suggested_end_latest")
)

print("=== SUGGESTED RESCHEDULE TIMES ===")
suggested_times.show(truncate=False)
```

---

## Part 4: Peak Concurrency (Event Sweep)

```python
from pyspark.sql.functions import sum as spark_sum

# Find peak booking concurrency per room using +1/-1 sweep
starts = df.select("room", col("start_time").alias("event_time"), lit(1).alias("delta"))
ends = df.select("room", col("end_time").alias("event_time"), lit(-1).alias("delta"))
events = starts.unionAll(ends)

window_sweep = Window.partitionBy("room").orderBy("event_time") \
    .rowsBetween(Window.unboundedPreceding, Window.currentRow)

concurrent = events.withColumn(
    "active_bookings", spark_sum("delta").over(window_sweep)
)

peak = concurrent.groupBy("room").agg(
    spark_max("active_bookings").alias("max_concurrent")
)

print("=== PEAK CONCURRENCY PER ROOM ===")
peak.show(truncate=False)
```

---

## Method 2: Using SQL

```python
df.createOrReplaceTempView("bookings")

# Detect conflicts
spark.sql("""
    SELECT
        a.booking_id AS booking_1,
        a.meeting_name AS meeting_1,
        b.booking_id AS booking_2,
        b.meeting_name AS meeting_2,
        a.room,
        GREATEST(a.start_time, b.start_time) AS conflict_start,
        LEAST(a.end_time, b.end_time) AS conflict_end,
        ROUND(
            (UNIX_TIMESTAMP(LEAST(a.end_time, b.end_time)) -
             UNIX_TIMESTAMP(GREATEST(a.start_time, b.start_time))) / 60
        ) AS overlap_min
    FROM bookings a
    JOIN bookings b
        ON a.room = b.room
        AND a.booking_id < b.booking_id
        AND a.start_time < b.end_time
        AND a.end_time > b.start_time
    ORDER BY a.room
""").show(truncate=False)
```

---

## Connection to Parent Pattern (overlapping_intervals)

| Concept | overlapping_intervals | meeting_room_conflicts |
|---------|----------------------|----------------------|
| **Overlap detection** | Self-join with A.start < B.end AND A.end > B.start | Identical |
| **Overlap region** | greatest(starts), least(ends) | Identical |
| **Merge intervals** | Running max + cumsum | Same technique for finding free slots |
| **Peak concurrency** | +1/-1 event sweep | Identical |
| **Extension** | N/A | Alternative room suggestion, reschedule suggestions |

The core conflict detection is identical. This file extends it with resolution logic (alternative rooms, alternative times).

---

## Key Interview Talking Points

1. **Overlap condition is universal:** `A.start < B.end AND A.end > B.start`. This is the same condition used in overlapping_intervals. It works for any interval type — dates, times, or numeric ranges.

2. **Self-join deduplication:** Use `a.booking_id < b.booking_id` to avoid (A,B) and (B,A) duplicates and to avoid self-matches. This is the same trick from self_join_comparisons.

3. **Resolution strategies:**
   - **Alternative room:** Cross-join conflicting bookings with all rooms, then left-anti-join to find rooms with no overlaps
   - **Alternative time:** Find gaps between bookings using `lead()`, then match gaps that fit the meeting duration

4. **Event sweep for capacity planning:** Converting bookings to +1 (start) / -1 (end) events and computing a running sum efficiently finds peak concurrency. Useful for determining if you need more rooms.

5. **Real-world extensions:**
   - Room capacity matching (meetings need rooms of sufficient size)
   - Priority-based conflict resolution (exec meetings win over standups)
   - Recurring meeting conflict detection
   - Buffer time between bookings (e.g., 5 min for room changeover)
