# PySpark Implementation: Work Hours Calculation (Excluding Breaks)

## Problem Statement

Given an employee attendance dataset with IN and OUT punch records, calculate the **total working hours per employee**, excluding break time. Each work session starts with an "IN" punch and ends with an "OUT" punch. Time between "OUT" and the next "IN" is a break and should not be counted.

This is a common interview problem that tests your ability to use **window functions** (`lag`), **timestamp arithmetic**, and **conditional filtering**.

### Sample Data

```
id   punch_time           punch_type
1    2024-10-15 08:00:00  IN
1    2024-10-15 12:00:00  OUT
1    2024-10-15 13:00:00  IN
1    2024-10-15 17:00:00  OUT
2    2024-10-15 09:00:00  IN
2    2024-10-15 11:30:00  OUT
2    2024-10-15 12:30:00  IN
2    2024-10-15 16:30:00  OUT
```

### Expected Output

| id | total_seconds | total_hours |
|----|---------------|-------------|
| 1  | 28800         | 8.0         |
| 2  | 23400         | 6.5         |

---

## PySpark Code Solution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_timestamp, lag, unix_timestamp, sum as spark_sum
from pyspark.sql.types import StructType, StructField, IntegerType, StringType
from pyspark.sql.window import Window

# Initialize Spark session
spark = SparkSession.builder.appName("WorkHoursCalculation").getOrCreate()

# Sample data
data = [
    (1, "2024-10-15 08:00:00", "IN"),
    (1, "2024-10-15 12:00:00", "OUT"),
    (1, "2024-10-15 13:00:00", "IN"),
    (1, "2024-10-15 17:00:00", "OUT"),
    (2, "2024-10-15 09:00:00", "IN"),
    (2, "2024-10-15 11:30:00", "OUT"),
    (2, "2024-10-15 12:30:00", "IN"),
    (2, "2024-10-15 16:30:00", "OUT")
]

schema = StructType([
    StructField("id", IntegerType(), True),
    StructField("punch_time", StringType(), True),
    StructField("punch_type", StringType(), True)
])

df = spark.createDataFrame(data, schema)
df = df.withColumn("punch_time", to_timestamp(col("punch_time")))

# Step 1: Define window partitioned by employee, ordered by time
window_spec = Window.partitionBy("id").orderBy("punch_time")

# Step 2: Compute time difference from previous punch using lag()
df_with_diff = df.withColumn(
    "time_diff_seconds",
    unix_timestamp("punch_time") - unix_timestamp(lag("punch_time", 1).over(window_spec))
)

# Step 3: Keep only OUT rows (these hold the actual work session durations)
df_out = df_with_diff.filter(col("punch_type") == "OUT")

# Step 4: Sum work time per employee and convert to hours
total = df_out.groupBy("id").agg(
    spark_sum("time_diff_seconds").alias("total_seconds")
)
total = total.withColumn("total_hours", col("total_seconds") / 3600)

total.show()
```

---

## Step-by-Step Explanation with Intermediate DataFrames

### Step 1: Define Window Specification

- **What happens:** Creates a window partitioned by `id` and ordered by `punch_time`. This ensures `lag()` looks at the previous punch **for the same employee** in chronological order.

### Step 2: Compute Time Difference Using lag()

- **What happens:** For each row, `lag("punch_time", 1)` retrieves the previous punch time. Subtracting the two `unix_timestamp` values gives the elapsed seconds since the last punch.
- **Why this works:** Every "OUT" punch is immediately preceded by an "IN" punch, so the difference on OUT rows equals the work session duration. Differences on "IN" rows represent break time.
- **Output (df_with_diff):**

  | id | punch_time          | punch_type | time_diff_seconds |
  |----|---------------------|------------|-------------------|
  | 1  | 2024-10-15 08:00:00 | IN         | null              |
  | 1  | 2024-10-15 12:00:00 | OUT        | 14400             |
  | 1  | 2024-10-15 13:00:00 | IN         | 3600              |
  | 1  | 2024-10-15 17:00:00 | OUT        | 14400             |
  | 2  | 2024-10-15 09:00:00 | IN         | null              |
  | 2  | 2024-10-15 11:30:00 | OUT        | 9000              |
  | 2  | 2024-10-15 12:30:00 | IN         | 3600              |
  | 2  | 2024-10-15 16:30:00 | OUT        | 14400             |

  - `14400 sec = 4 hours` (work session)
  - `9000 sec = 2.5 hours` (work session)
  - `3600 sec = 1 hour` (break — will be filtered out)
  - `null` = first punch per employee (no previous row)

### Step 3: Filter to OUT Rows Only

- **What happens:** Keeps only "OUT" rows. These are the ones where `time_diff_seconds` represents actual work time (IN → OUT). The "IN" rows (which carry break durations or nulls) are discarded.
- **Output (df_out):**

  | id | punch_time          | punch_type | time_diff_seconds |
  |----|---------------------|------------|-------------------|
  | 1  | 2024-10-15 12:00:00 | OUT        | 14400             |
  | 1  | 2024-10-15 17:00:00 | OUT        | 14400             |
  | 2  | 2024-10-15 11:30:00 | OUT        | 9000              |
  | 2  | 2024-10-15 16:30:00 | OUT        | 14400             |

### Step 4: Aggregate and Convert to Hours

- **What happens:** Groups by `id`, sums the work session seconds, then divides by 3600 to get hours.
- **Output (total):**

  | id | total_seconds | total_hours |
  |----|---------------|-------------|
  | 1  | 28800         | 8.0         |
  | 2  | 23400         | 6.5         |

  - Employee 1: 4h + 4h = **8.0 hours**
  - Employee 2: 2.5h + 4h = **6.5 hours**

---

## Alternative: Using Pair-Based Approach (Explicit IN/OUT Matching)

```python
from pyspark.sql.functions import lead, when

# Window per employee ordered by time
window_spec = Window.partitionBy("id").orderBy("punch_time")

# For each IN row, look ahead to the next row (which should be OUT)
df_paired = df.filter(col("punch_type") == "IN") \
    .withColumn("out_time", lead("punch_time", 1).over(
        Window.partitionBy("id").orderBy("punch_time")
    ))

# Wait — this doesn't work because lead() on filtered data loses the OUT rows.
# Correct approach: pair on the full DataFrame

df_paired = df.withColumn("next_time", lead("punch_time", 1).over(window_spec)) \
              .withColumn("next_type", lead("punch_type", 1).over(window_spec))

# Keep only IN rows where the next punch is OUT
df_sessions = df_paired.filter(
    (col("punch_type") == "IN") & (col("next_type") == "OUT")
).withColumn(
    "session_seconds",
    unix_timestamp("next_time") - unix_timestamp("punch_time")
)

# Aggregate
total_alt = df_sessions.groupBy("id").agg(
    spark_sum("session_seconds").alias("total_seconds")
).withColumn("total_hours", col("total_seconds") / 3600)

total_alt.show()
```

This approach explicitly pairs each IN with its following OUT using `lead()`, which is more readable and robust if punch records are not strictly alternating.

---

## Key Interview Talking Points

1. **lag() vs lead():** The main solution uses `lag()` on OUT rows to look back at the IN time. The alternative uses `lead()` on IN rows to look ahead at the OUT time. Both are valid — pick whichever reads more naturally to you.

2. **Why filter by punch_type?** Without filtering, you'd accidentally sum break times (OUT → IN differences). The filter ensures you only aggregate actual work sessions.

3. **Edge cases to discuss:**
   - **Missing OUT punch** (employee forgot to clock out): The `lag` approach would give null or incorrect diffs. You'd need to handle this with `coalesce()` or flag incomplete sessions.
   - **Multiple days:** If punches span multiple days, the current approach still works — `unix_timestamp` subtraction handles date boundaries correctly.
   - **Out-of-order punches:** The `orderBy("punch_time")` in the window handles this as long as timestamps are accurate.

4. **Performance:** Window functions with `partitionBy("id")` ensure each employee's data is processed independently. For large datasets, ensure `id` has reasonable cardinality to avoid skewed partitions.
