# PySpark Implementation: Reservation Booking Conflicts

## Problem Statement

Detect conflicting reservations or bookings that overlap in time for the same resource. Given a dataset of reservations with start and end times for shared resources (meeting rooms, hotel rooms, rental cars, etc.), find all pairs of conflicting bookings and identify resources that are double-booked. This is a common interview question at hospitality, travel, and scheduling companies (Airbnb, Booking.com, Calendly) and tests your understanding of interval overlap detection and self-joins.

### Sample Data

**Reservations:**

| reservation_id | resource_id | guest_name | start_time          | end_time            |
|----------------|-------------|------------|---------------------|---------------------|
| R001           | Room-A      | Alice      | 2024-03-15 09:00    | 2024-03-15 11:00    |
| R002           | Room-A      | Bob        | 2024-03-15 10:00    | 2024-03-15 12:00    |
| R003           | Room-A      | Carol      | 2024-03-15 13:00    | 2024-03-15 15:00    |
| R004           | Room-B      | Dave       | 2024-03-15 09:00    | 2024-03-15 10:30    |
| R005           | Room-B      | Eve        | 2024-03-15 10:00    | 2024-03-15 11:00    |
| R006           | Room-B      | Frank      | 2024-03-15 11:00    | 2024-03-15 13:00    |
| R007           | Room-C      | Grace      | 2024-03-15 09:00    | 2024-03-15 17:00    |

### Expected Output (Conflicting Pairs)

| resource_id | reservation_1 | guest_1 | reservation_2 | guest_2 | overlap_minutes |
|-------------|---------------|---------|---------------|---------|-----------------|
| Room-A      | R001          | Alice   | R002          | Bob     | 60              |
| Room-B      | R004          | Dave    | R005          | Eve     | 30              |

---

## Method 1: Self-Join for Overlap Detection

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

# Initialize Spark
spark = SparkSession.builder \
    .appName("Reservation Booking Conflicts") \
    .master("local[*]") \
    .getOrCreate()

# --- Sample Data ---
reservations_data = [
    ("R001", "Room-A", "Alice", "2024-03-15 09:00", "2024-03-15 11:00"),
    ("R002", "Room-A", "Bob", "2024-03-15 10:00", "2024-03-15 12:00"),
    ("R003", "Room-A", "Carol", "2024-03-15 13:00", "2024-03-15 15:00"),
    ("R004", "Room-B", "Dave", "2024-03-15 09:00", "2024-03-15 10:30"),
    ("R005", "Room-B", "Eve", "2024-03-15 10:00", "2024-03-15 11:00"),
    ("R006", "Room-B", "Frank", "2024-03-15 11:00", "2024-03-15 13:00"),
    ("R007", "Room-C", "Grace", "2024-03-15 09:00", "2024-03-15 17:00"),
    ("R008", "Room-A", "Helen", "2024-03-15 10:30", "2024-03-15 11:30"),
]

reservations_df = spark.createDataFrame(
    reservations_data,
    ["reservation_id", "resource_id", "guest_name", "start_time", "end_time"]
).withColumn("start_time", F.to_timestamp("start_time")) \
 .withColumn("end_time", F.to_timestamp("end_time"))

print("=== All Reservations ===")
reservations_df.show(truncate=False)

# --- Self-join to find overlapping reservations for the same resource ---
# Two intervals overlap if: A.start < B.end AND A.end > B.start
conflicts = reservations_df.alias("a").join(
    reservations_df.alias("b"),
    (F.col("a.resource_id") == F.col("b.resource_id")) &
    (F.col("a.reservation_id") < F.col("b.reservation_id")) &  # Avoid duplicates
    (F.col("a.start_time") < F.col("b.end_time")) &
    (F.col("a.end_time") > F.col("b.start_time"))
).select(
    F.col("a.resource_id"),
    F.col("a.reservation_id").alias("reservation_1"),
    F.col("a.guest_name").alias("guest_1"),
    F.col("a.start_time").alias("start_1"),
    F.col("a.end_time").alias("end_1"),
    F.col("b.reservation_id").alias("reservation_2"),
    F.col("b.guest_name").alias("guest_2"),
    F.col("b.start_time").alias("start_2"),
    F.col("b.end_time").alias("end_2"),
)

# Calculate overlap duration
conflicts = conflicts.withColumn(
    "overlap_start",
    F.greatest(F.col("start_1"), F.col("start_2"))
).withColumn(
    "overlap_end",
    F.least(F.col("end_1"), F.col("end_2"))
).withColumn(
    "overlap_minutes",
    (F.unix_timestamp("overlap_end") - F.unix_timestamp("overlap_start")) / 60
)

print("=== Conflicting Reservations ===")
conflicts.select(
    "resource_id", "reservation_1", "guest_1",
    "reservation_2", "guest_2", "overlap_minutes"
).show(truncate=False)

# --- Resources with the most conflicts ---
conflict_summary = conflicts.groupBy("resource_id").agg(
    F.count("*").alias("conflict_count"),
    F.round(F.sum("overlap_minutes"), 0).alias("total_overlap_minutes")
).orderBy(F.desc("conflict_count"))

print("=== Conflict Summary by Resource ===")
conflict_summary.show()

# --- Reservations involved in conflicts ---
conflicted_ids = conflicts.select(
    F.col("reservation_1").alias("reservation_id")
).union(
    conflicts.select(F.col("reservation_2").alias("reservation_id"))
).distinct()

conflicted_reservations = reservations_df.join(conflicted_ids, "reservation_id")
clean_reservations = reservations_df.join(conflicted_ids, "reservation_id", "left_anti")

print(f"Conflicted reservations: {conflicted_reservations.count()}")
print(f"Clean reservations: {clean_reservations.count()}")

spark.stop()
```

## Method 2: SQL Approach with Conflict Resolution

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("Booking Conflicts - SQL") \
    .master("local[*]") \
    .getOrCreate()

# --- Data ---
reservations_data = [
    ("R001", "Room-A", "Alice", "2024-03-15 09:00", "2024-03-15 11:00", "2024-03-10"),
    ("R002", "Room-A", "Bob", "2024-03-15 10:00", "2024-03-15 12:00", "2024-03-12"),
    ("R003", "Room-A", "Carol", "2024-03-15 13:00", "2024-03-15 15:00", "2024-03-11"),
    ("R004", "Room-B", "Dave", "2024-03-15 09:00", "2024-03-15 10:30", "2024-03-08"),
    ("R005", "Room-B", "Eve", "2024-03-15 10:00", "2024-03-15 11:00", "2024-03-13"),
    ("R006", "Room-B", "Frank", "2024-03-15 11:00", "2024-03-15 13:00", "2024-03-09"),
    ("R007", "Room-C", "Grace", "2024-03-15 09:00", "2024-03-15 17:00", "2024-03-07"),
]

df = spark.createDataFrame(
    reservations_data,
    ["reservation_id", "resource_id", "guest_name", "start_time", "end_time", "booked_on"]
)
df = df.withColumn("start_time", F.to_timestamp("start_time")) \
       .withColumn("end_time", F.to_timestamp("end_time")) \
       .withColumn("booked_on", F.to_date("booked_on"))

df.createOrReplaceTempView("reservations")

# --- Find conflicts ---
conflicts = spark.sql("""
    SELECT
        a.resource_id,
        a.reservation_id AS res_1,
        a.guest_name AS guest_1,
        a.start_time AS start_1,
        a.end_time AS end_1,
        a.booked_on AS booked_1,
        b.reservation_id AS res_2,
        b.guest_name AS guest_2,
        b.start_time AS start_2,
        b.end_time AS end_2,
        b.booked_on AS booked_2,
        ROUND(
            (UNIX_TIMESTAMP(LEAST(a.end_time, b.end_time)) -
             UNIX_TIMESTAMP(GREATEST(a.start_time, b.start_time))) / 60
        , 0) AS overlap_minutes
    FROM reservations a
    JOIN reservations b
        ON a.resource_id = b.resource_id
        AND a.reservation_id < b.reservation_id
        AND a.start_time < b.end_time
        AND a.end_time > b.start_time
    ORDER BY a.resource_id, a.start_time
""")

print("=== Conflicts (SQL) ===")
conflicts.show(truncate=False)

# --- Conflict resolution: first-come-first-served (by booking date) ---
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

print("=== Conflict Resolution (First-Come-First-Served) ===")
resolution.show(truncate=False)

spark.stop()
```

## Method 3: Maximum Concurrent Bookings (Capacity Check)

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("Booking Conflicts - Capacity") \
    .master("local[*]") \
    .getOrCreate()

# --- Hotel rooms with capacity ---
reservations_data = [
    ("R001", "Standard", "Alice", "2024-03-15", "2024-03-18"),
    ("R002", "Standard", "Bob", "2024-03-16", "2024-03-19"),
    ("R003", "Standard", "Carol", "2024-03-17", "2024-03-20"),
    ("R004", "Standard", "Dave", "2024-03-15", "2024-03-16"),
    ("R005", "Deluxe", "Eve", "2024-03-15", "2024-03-18"),
    ("R006", "Deluxe", "Frank", "2024-03-16", "2024-03-17"),
]

df = spark.createDataFrame(
    reservations_data,
    ["reservation_id", "room_type", "guest_name", "check_in", "check_out"]
).withColumn("check_in", F.to_date("check_in")) \
 .withColumn("check_out", F.to_date("check_out"))

# Room capacity
capacity_data = [("Standard", 2), ("Deluxe", 1)]
capacity_df = spark.createDataFrame(capacity_data, ["room_type", "capacity"])

# --- Event-based approach: +1 at check-in, -1 at check-out ---
events = df.select(
    "room_type",
    F.col("check_in").alias("event_date"),
    F.lit(1).alias("change")
).union(
    df.select(
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

print("=== Concurrent Bookings Over Time ===")
concurrent.orderBy("room_type", "event_date").show(20)

# --- Check for capacity violations ---
violations = concurrent.join(capacity_df, "room_type") \
    .filter(F.col("concurrent_bookings") > F.col("capacity"))

print("=== Capacity Violations ===")
violations.show()

# --- Peak concurrent bookings per room type ---
peak = concurrent.groupBy("room_type").agg(
    F.max("concurrent_bookings").alias("peak_concurrent")
).join(capacity_df, "room_type") \
 .withColumn(
    "over_capacity",
    F.when(F.col("peak_concurrent") > F.col("capacity"), True).otherwise(False)
)

print("=== Peak Utilization ===")
peak.show()

spark.stop()
```

## Key Concepts

- **Interval Overlap Condition**: Two intervals [A_start, A_end) and [B_start, B_end) overlap if and only if `A_start < B_end AND A_end > B_start`.
- **Self-Join Pattern**: Join the reservations table with itself on the same resource, with `a.id < b.id` to avoid duplicate pairs and self-matches.
- **Overlap Duration**: `overlap_start = max(A_start, B_start)`, `overlap_end = min(A_end, B_end)`, `duration = overlap_end - overlap_start`.
- **Event-Based Counting**: Convert intervals to events (+1 at start, -1 at end), then compute running sum to find concurrent bookings at any point.
- **Capacity Check**: Compare concurrent bookings against resource capacity to find violations.

## Interview Tips

- Clarify whether time bounds are **inclusive or exclusive**. Hotels typically use [check_in, check_out) where check-out day is not a conflict.
- The self-join approach finds pairwise conflicts. For capacity > 1 resources, use the **event-based approach** to count concurrent bookings.
- Discuss **conflict resolution strategies**: first-come-first-served, priority-based, or manual review queue.
- For **real-time booking systems**, mention using database transactions with row-level locks to prevent race conditions.
- Performance: the self-join is O(n^2) per resource. For resources with many bookings, consider **time-bucket pre-filtering** to reduce join candidates.
- Mention that this problem is equivalent to the classic **interval scheduling** problem in computer science.
