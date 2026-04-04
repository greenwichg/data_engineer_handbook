# PySpark Implementation: Generate Time Slots from Shifts

## Problem Statement 

Given a dataset of employee work shifts with a **start_time** and **end_time**, expand each shift into **one row per hour** to calculate hourly staffing levels, labor costs, or occupancy. This is the timestamp/hourly version of the `quantity_explode` and `expand_date_ranges` patterns.

### Sample Data

```
employee_id  shift_date   start_time  end_time
E001         2025-01-15   09:00       13:00
E002         2025-01-15   10:00       14:00
E003         2025-01-15   12:00       15:00
E004         2025-01-15   22:00       02:00    (overnight shift)
```

### Expected Output (Hourly Slots)

| employee_id | shift_date | hour_slot |
|-------------|------------|-----------|
| E001        | 2025-01-15 | 09:00     |
| E001        | 2025-01-15 | 10:00     |
| E001        | 2025-01-15 | 11:00     |
| E001        | 2025-01-15 | 12:00     |
| E002        | 2025-01-15 | 10:00     |
| E002        | 2025-01-15 | 11:00     |
| E002        | 2025-01-15 | 12:00     |
| E002        | 2025-01-15 | 13:00     |
| E003        | 2025-01-15 | 12:00     |
| E003        | 2025-01-15 | 13:00     |
| E003        | 2025-01-15 | 14:00     |

(Note: end_time is exclusive — a 09:00-13:00 shift covers hours 09, 10, 11, 12)

---

## Method 1: sequence() + explode() with Timestamps

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_timestamp, explode, sequence, expr, \
    date_format, concat, lit
from pyspark.sql.window import Window

# Initialize Spark session
spark = SparkSession.builder.appName("TimeSlots").getOrCreate()

# Sample data
data = [
    ("E001", "2025-01-15", "09:00", "13:00"),
    ("E002", "2025-01-15", "10:00", "14:00"),
    ("E003", "2025-01-15", "12:00", "15:00")
]
columns = ["employee_id", "shift_date", "start_time", "end_time"]
df = spark.createDataFrame(data, columns)

# Combine date + time into full timestamps
df = df.withColumn(
    "start_ts",
    to_timestamp(concat(col("shift_date"), lit(" "), col("start_time")))
).withColumn(
    "end_ts",
    to_timestamp(concat(col("shift_date"), lit(" "), col("end_time")))
)

# Generate hourly slots using sequence with 1-hour interval
# Note: end_ts - 1 hour because end time is exclusive
hourly_slots = df.withColumn(
    "hour_slot",
    explode(
        sequence(
            col("start_ts"),
            col("end_ts") - expr("interval 1 hour"),
            expr("interval 1 hour")
        )
    )
).select(
    "employee_id",
    "shift_date",
    date_format("hour_slot", "HH:mm").alias("hour_slot")
)

hourly_slots.show(truncate=False)
```

### Step-by-Step Explanation

#### Step 1: Build Timestamps
```
"2025-01-15" + " " + "09:00" → "2025-01-15 09:00:00"
```

#### Step 2: sequence() with Hourly Interval
```python
sequence(start_ts, end_ts - interval 1 hour, interval 1 hour)
```
For E001 (09:00 → 13:00):
- `end_ts - 1 hour` = 12:00 (so we don't include the end hour)
- `sequence(09:00, 12:00, 1 hour)` = `[09:00, 10:00, 11:00, 12:00]`

#### Step 3: explode() turns the array into rows

| employee_id | hour_slot |
|-------------|-----------|
| E001        | 09:00     |
| E001        | 10:00     |
| E001        | 11:00     |
| E001        | 12:00     |

---

## Method 2: Handling Overnight Shifts

```python
from pyspark.sql.functions import when, date_add

# Overnight shifts: end_time < start_time means it crosses midnight
overnight_data = [
    ("E001", "2025-01-15", "09:00", "13:00"),   # Normal
    ("E004", "2025-01-15", "22:00", "02:00"),    # Overnight
    ("E005", "2025-01-15", "23:00", "07:00")     # Overnight
]
overnight_df = spark.createDataFrame(overnight_data, columns)

overnight_df = overnight_df.withColumn(
    "start_ts",
    to_timestamp(concat(col("shift_date"), lit(" "), col("start_time")))
).withColumn(
    "end_ts",
    to_timestamp(concat(col("shift_date"), lit(" "), col("end_time")))
)

# If end_ts <= start_ts, add 1 day to end_ts (overnight shift)
overnight_df = overnight_df.withColumn(
    "end_ts",
    when(col("end_ts") <= col("start_ts"), col("end_ts") + expr("interval 1 day"))
    .otherwise(col("end_ts"))
)

# Now generate hourly slots
overnight_slots = overnight_df.withColumn(
    "hour_slot",
    explode(
        sequence(
            col("start_ts"),
            col("end_ts") - expr("interval 1 hour"),
            expr("interval 1 hour")
        )
    )
).select(
    "employee_id",
    "shift_date",
    date_format("hour_slot", "yyyy-MM-dd HH:mm").alias("hour_slot")
)

overnight_slots.show(truncate=False)
```

- **Output (E004 overnight):**

  | employee_id | shift_date | hour_slot        |
  |-------------|------------|-----------------|
  | E004        | 2025-01-15 | 2025-01-15 22:00 |
  | E004        | 2025-01-15 | 2025-01-15 23:00 |
  | E004        | 2025-01-15 | 2025-01-16 00:00 |
  | E004        | 2025-01-15 | 2025-01-16 01:00 |

---

## Method 3: 15-Minute or 30-Minute Intervals

```python
# Generate 30-minute slots instead of hourly
half_hour_slots = df.withColumn(
    "slot",
    explode(
        sequence(
            col("start_ts"),
            col("end_ts") - expr("interval 30 minutes"),
            expr("interval 30 minutes")
        )
    )
).select(
    "employee_id",
    date_format("slot", "HH:mm").alias("time_slot")
)

half_hour_slots.show(truncate=False)
```

- **Output (E001, 09:00-13:00):**

  | employee_id | time_slot |
  |-------------|-----------|
  | E001        | 09:00     |
  | E001        | 09:30     |
  | E001        | 10:00     |
  | E001        | 10:30     |
  | E001        | 11:00     |
  | E001        | 11:30     |
  | E001        | 12:00     |
  | E001        | 12:30     |

---

## Method 4: Using SQL

```python
df.createOrReplaceTempView("shifts")

spark.sql("""
    SELECT
        employee_id,
        shift_date,
        date_format(hour_slot, 'HH:mm') AS hour_slot
    FROM shifts
    LATERAL VIEW explode(
        sequence(
            start_ts,
            end_ts - interval 1 hour,
            interval 1 hour
        )
    ) t AS hour_slot
    ORDER BY employee_id, hour_slot
""").show(truncate=False)
```

---

## Practical Application: Hourly Staffing Levels

```python
from pyspark.sql.functions import count

# Count how many employees are working each hour
staffing = hourly_slots.groupBy("hour_slot").agg(
    count("*").alias("employees_on_duty")
).orderBy("hour_slot")

staffing.show(truncate=False)
```

- **Output:**

  | hour_slot | employees_on_duty |
  |-----------|------------------|
  | 09:00     | 1                |
  | 10:00     | 2                |
  | 11:00     | 2                |
  | 12:00     | 3                |
  | 13:00     | 2                |
  | 14:00     | 1                |

---

## Practical Application: Hourly Labor Cost

```python
from pyspark.sql.functions import sum as spark_sum

# Add hourly rate and calculate cost per slot
rate_data = [
    ("E001", "2025-01-15", "09:00", "13:00", 25.00),
    ("E002", "2025-01-15", "10:00", "14:00", 30.00),
    ("E003", "2025-01-15", "12:00", "15:00", 28.00)
]
rate_df = spark.createDataFrame(
    rate_data, ["employee_id", "shift_date", "start_time", "end_time", "hourly_rate"]
)
rate_df = rate_df.withColumn(
    "start_ts",
    to_timestamp(concat(col("shift_date"), lit(" "), col("start_time")))
).withColumn(
    "end_ts",
    to_timestamp(concat(col("shift_date"), lit(" "), col("end_time")))
)

# Expand to hourly and calculate cost
hourly_cost = rate_df.withColumn(
    "hour_slot",
    explode(
        sequence(
            col("start_ts"),
            col("end_ts") - expr("interval 1 hour"),
            expr("interval 1 hour")
        )
    )
)

# Total labor cost per hour
cost_per_hour = hourly_cost.groupBy(
    date_format("hour_slot", "HH:mm").alias("hour")
).agg(
    spark_sum("hourly_rate").alias("total_labor_cost"),
    count("*").alias("staff_count")
).orderBy("hour")

cost_per_hour.show(truncate=False)
```

- **Output:**

  | hour  | total_labor_cost | staff_count |
  |-------|-----------------|-------------|
  | 09:00 | 25.00           | 1           |
  | 10:00 | 55.00           | 2           |
  | 11:00 | 55.00           | 2           |
  | 12:00 | 83.00           | 3           |
  | 13:00 | 58.00           | 2           |
  | 14:00 | 28.00           | 1           |

---

## Key Interview Talking Points

1. **Same explode pattern, different interval:** This is `quantity_explode` and `expand_date_ranges` applied to timestamps. The only difference is `sequence(start, end, interval 1 hour)` instead of `array_repeat` or daily `sequence`.

2. **Exclusive vs inclusive end:** Most shift/booking systems treat end_time as exclusive (a 09:00-10:00 shift is 1 hour, not 2). Subtract one interval from end before generating: `end_ts - interval 1 hour`.

3. **Overnight shifts:** Check if `end_ts <= start_ts` and add 1 day to `end_ts`. This is a common edge case interviewers test.

4. **Interval options:**
   - 15-minute: `interval 15 minutes`
   - 30-minute: `interval 30 minutes`
   - Hourly: `interval 1 hour`
   - Custom: `interval N minutes`

5. **Real-world use cases:**
   - Call center staffing optimization
   - Hospital shift coverage analysis
   - Parking lot occupancy per hour
   - Server resource allocation per time slot
   - Electricity usage billing per hour
