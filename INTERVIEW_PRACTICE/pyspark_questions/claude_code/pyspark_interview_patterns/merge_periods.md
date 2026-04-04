# PySpark Implementation: Merge Overlapping Subscription Periods

## Problem Statement 

Given a dataset of user subscription periods that may **overlap or be contiguous**, merge them into the smallest set of **non-overlapping consolidated periods**. For example, if a user has subscriptions from Jan 1-15 and Jan 10-25, merge into a single period Jan 1-25. This is the **merge intervals** variant of the gaps-and-islands pattern — instead of finding islands based on status changes, you're merging date ranges that touch or overlap.

### Sample Data

```
user_id  plan       start_date   end_date
U001     Premium    2025-01-01   2025-01-15
U001     Premium    2025-01-10   2025-01-25
U001     Premium    2025-02-01   2025-02-10
U001     Basic      2025-02-08   2025-02-20
U002     Premium    2025-01-05   2025-01-12
U002     Premium    2025-01-12   2025-01-20
U002     Premium    2025-01-25   2025-01-31
```

### Expected Output (Merged Periods)

| user_id | merged_start | merged_end | duration_days |
|---------|-------------|------------|---------------|
| U001    | 2025-01-01  | 2025-01-25 | 25            |
| U001    | 2025-02-01  | 2025-02-20 | 20            |
| U002    | 2025-01-05  | 2025-01-20 | 16            |
| U002    | 2025-01-25  | 2025-01-31 | 7             |

**Explanation:**
- U001: Jan 1-15 and Jan 10-25 overlap → merged to Jan 1-25. Feb 1-10 and Feb 8-20 overlap → merged to Feb 1-20.
- U002: Jan 5-12 and Jan 12-20 are contiguous (touching) → merged to Jan 5-20. Jan 25-31 is separate.

---

## Method 1: Running Max End + Cumulative Sum (Same as overlapping_intervals merge)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_date, lag, when, sum as spark_sum, \
    max as spark_max, min as spark_min, datediff
from pyspark.sql.window import Window

# Initialize Spark session
spark = SparkSession.builder.appName("MergeOverlappingPeriods").getOrCreate()

# Sample data
data = [
    ("U001", "Premium", "2025-01-01", "2025-01-15"),
    ("U001", "Premium", "2025-01-10", "2025-01-25"),
    ("U001", "Premium", "2025-02-01", "2025-02-10"),
    ("U001", "Basic", "2025-02-08", "2025-02-20"),
    ("U002", "Premium", "2025-01-05", "2025-01-12"),
    ("U002", "Premium", "2025-01-12", "2025-01-20"),
    ("U002", "Premium", "2025-01-25", "2025-01-31")
]
columns = ["user_id", "plan", "start_date", "end_date"]
df = spark.createDataFrame(data, columns)
df = df.withColumn("start_date", to_date("start_date")) \
       .withColumn("end_date", to_date("end_date"))

# Step 1: Sort by user and start_date, find running max end_date
window_user = Window.partitionBy("user_id").orderBy("start_date")

df_with_prev_max = df.withColumn(
    "prev_max_end",
    spark_max("end_date").over(
        Window.partitionBy("user_id").orderBy("start_date")
        .rowsBetween(Window.unboundedPreceding, -1)
    )
)

# Step 2: Flag new groups — start_date > prev_max_end means no overlap
df_flagged = df_with_prev_max.withColumn(
    "is_new_group",
    when(
        col("prev_max_end").isNull() | (col("start_date") > col("prev_max_end")),
        1
    ).otherwise(0)
)

# Step 3: Assign group IDs using cumulative sum
df_grouped = df_flagged.withColumn(
    "group_id",
    spark_sum("is_new_group").over(window_user)
)

# Step 4: Merge — take min start and max end per group
merged = df_grouped.groupBy("user_id", "group_id").agg(
    spark_min("start_date").alias("merged_start"),
    spark_max("end_date").alias("merged_end")
).withColumn(
    "duration_days", datediff(col("merged_end"), col("merged_start")) + 1
).drop("group_id") \
 .orderBy("user_id", "merged_start")

merged.show(truncate=False)
```

### Step-by-Step Walkthrough (U001)

#### Step 1-2: Detect Group Boundaries

| start_date | end_date   | prev_max_end | is_new_group | group_id |
|------------|-----------|-------------|-------------|----------|
| 2025-01-01 | 2025-01-15 | null        | 1           | 1        |
| 2025-01-10 | 2025-01-25 | 2025-01-15 | 0 (Jan 10 ≤ Jan 15) | 1 |
| 2025-02-01 | 2025-02-10 | 2025-01-25 | 1 (Feb 01 > Jan 25) | 2 |
| 2025-02-08 | 2025-02-20 | 2025-02-10 | 0 (Feb 08 ≤ Feb 10) | 2 |

**Key insight:** `prev_max_end` tracks the furthest end date seen so far. If the current `start_date` is beyond that, there's a gap → new group. Otherwise, it overlaps with something in the current group.

#### Step 3: Merge Results

- Group 1 (U001): min(Jan 01, Jan 10) → Jan 01, max(Jan 15, Jan 25) → Jan 25
- Group 2 (U001): min(Feb 01, Feb 08) → Feb 01, max(Feb 10, Feb 20) → Feb 20

---

## Method 2: lag() Based Approach

```python
# Alternative: use lag to compare with previous row only
# Note: This only works if intervals are sorted and don't chain across 3+ overlaps
# For chaining overlaps, Method 1 (running max) is required

# This simpler approach works when intervals don't chain:
df_with_lag = df.withColumn(
    "prev_end", lag("end_date").over(window_user)
).withColumn(
    "is_new_group",
    when(
        col("prev_end").isNull() | (col("start_date") > col("prev_end")),
        1
    ).otherwise(0)
).withColumn(
    "group_id",
    spark_sum("is_new_group").over(window_user)
)

# CAUTION: This fails when A overlaps B and B overlaps C but A doesn't overlap C
# Example: A=[1,5], B=[3,8], C=[6,10]
# lag() would compare C.start(6) with B.end(8) → overlap → same group ✓
# But if B=[3,4], C=[6,10] → lag compares C.start(6) with B.end(4) → new group ✓
# The running max approach handles all cases correctly
```

---

## Method 3: Handling Contiguous (Touching) Periods

```python
# Sometimes you want to merge periods that TOUCH but don't overlap
# e.g., Jan 1-12 and Jan 12-20 should merge (contiguous)
# vs Jan 1-12 and Jan 13-20 should merge (1-day gap tolerance)

# For touching: use >= instead of >
df_touch = df_with_prev_max.withColumn(
    "is_new_group",
    when(
        col("prev_max_end").isNull() | (col("start_date") > col("prev_max_end")),
        1
    ).otherwise(0)
)
# start_date > prev_max_end: strict gap → new group
# start_date <= prev_max_end: overlapping OR touching → same group

# For 1-day gap tolerance:
from pyspark.sql.functions import date_add

df_gap_tolerance = df_with_prev_max.withColumn(
    "is_new_group",
    when(
        col("prev_max_end").isNull() |
        (col("start_date") > date_add(col("prev_max_end"), 1)),  # Allow 1-day gap
        1
    ).otherwise(0)
)
```

---

## Method 4: Using SQL

```python
df.createOrReplaceTempView("subscriptions")

spark.sql("""
    WITH with_prev_max AS (
        SELECT *,
            MAX(end_date) OVER (
                PARTITION BY user_id ORDER BY start_date
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            ) AS prev_max_end
        FROM subscriptions
    ),
    flagged AS (
        SELECT *,
            CASE WHEN prev_max_end IS NULL OR start_date > prev_max_end
                 THEN 1 ELSE 0 END AS is_new_group
        FROM with_prev_max
    ),
    grouped AS (
        SELECT *,
            SUM(is_new_group) OVER (
                PARTITION BY user_id ORDER BY start_date
            ) AS group_id
        FROM flagged
    )
    SELECT
        user_id,
        MIN(start_date) AS merged_start,
        MAX(end_date) AS merged_end,
        DATEDIFF(MAX(end_date), MIN(start_date)) + 1 AS duration_days
    FROM grouped
    GROUP BY user_id, group_id
    ORDER BY user_id, merged_start
""").show(truncate=False)
```

---

## Practical Application: Calculate Total Active Days per User

```python
from pyspark.sql.functions import sum as spark_sum

# After merging, sum the durations
total_active = merged.groupBy("user_id").agg(
    spark_sum("duration_days").alias("total_active_days"),
    spark_min("merged_start").alias("first_active"),
    spark_max("merged_end").alias("last_active")
).withColumn(
    "total_span_days",
    datediff(col("last_active"), col("first_active")) + 1
).withColumn(
    "activity_rate",
    col("total_active_days") / col("total_span_days") * 100
)

total_active.show(truncate=False)
```

---

## Practical Application: Insurance Coverage Gap Analysis

```python
# Find gaps between merged periods
window_merged = Window.partitionBy("user_id").orderBy("merged_start")

gaps = merged.withColumn(
    "prev_merged_end", lag("merged_end").over(window_merged)
).filter(
    col("prev_merged_end").isNotNull()
).withColumn(
    "gap_start", date_add(col("prev_merged_end"), 1)
).withColumn(
    "gap_end", date_add(col("merged_start"), -1)
).withColumn(
    "gap_days", datediff(col("merged_start"), col("prev_merged_end")) - 1
).filter(
    col("gap_days") > 0
).select("user_id", "gap_start", "gap_end", "gap_days")

gaps.show(truncate=False)
```

---

## Connection to Parent Pattern (gaps_and_islands)

| Concept | gaps_and_islands | merge_overlapping_periods |
|---------|-----------------|--------------------------|
| **Input** | Discrete events with categories | Date ranges (start/end) |
| **Grouping logic** | row_number difference OR lag+cumsum | Running max end + cumsum |
| **Key insight** | Same category = same island | start ≤ prev_max_end = same group |
| **Output** | Consolidated date ranges per status | Consolidated date ranges per user |
| **Core technique** | `is_new_island` flag → `cumsum` | `is_new_group` flag → `cumsum` |

Both use the same three-step pattern: **detect boundaries → flag → cumulative sum → aggregate**.

---

## Key Interview Talking Points

1. **Running max, not just lag:** The critical mistake is comparing only with the previous row's end date. If A=[1,10], B=[3,5], C=[6,8], then C doesn't overlap B but overlaps A. You need `max(end_date) over (... ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)`.

2. **Contiguous vs overlapping:** Decide whether touching intervals (end = next start) should merge. In subscription billing, they usually should. In meeting scheduling, they usually shouldn't.

3. **Real-world use cases:**
   - Insurance coverage period consolidation
   - Subscription billing: calculate total active days
   - Employee tenure: merge overlapping employment periods
   - Network downtime consolidation
   - Hotel room occupancy merging

4. **Performance:** This is O(n log n) — one sort + one pass with window functions. Much better than O(n²) pairwise comparison.

5. **Edge case — fully contained intervals:** A=[1,20], B=[5,10]. B is fully inside A. The running max handles this correctly: prev_max_end for B is 20, and B.start(5) ≤ 20, so same group.
