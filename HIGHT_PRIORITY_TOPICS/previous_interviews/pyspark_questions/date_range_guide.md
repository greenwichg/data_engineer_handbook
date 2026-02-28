# PySpark Implementation: Generate Weekdays and Weekends Dynamically

## Problem Statement

Generate a complete list of all dates within a dynamic range (e.g., 30 days before and after today), classify each date as either **"Weekday"** or **"Weekend"**, and include the day name — **without hardcoding any dates**. This tests your ability to generate date sequences dynamically and apply conditional transformations.

### Sample Data

No input data — dates are generated dynamically from the current date.

### Expected Output (partial, assuming today is 2026-02-15)

| date       | day_name  | day_of_week | day_type |
|------------|-----------|-------------|----------|
| 2026-01-16 | Friday    | 6           | Weekday  |
| 2026-01-17 | Saturday  | 7           | Weekend  |
| 2026-01-18 | Sunday    | 1           | Weekend  |
| 2026-01-19 | Monday    | 2           | Weekday  |
| ...        | ...       | ...         | ...      |
| 2026-03-17 | Tuesday   | 3           | Weekday  |

The output contains 61 days (30 before + today + 30 after), each classified by day type.

---

## PySpark Code Solution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, date_format, dayofweek, when
from datetime import datetime, timedelta

spark = SparkSession.builder.appName("WeekdaysWeekends").getOrCreate()

# Calculate date range dynamically (no hardcoded dates)
start_date = datetime.now().date() - timedelta(days=30)
end_date = datetime.now().date() + timedelta(days=30)

# Generate date sequence using Spark SQL sequence() + explode()
dates = spark.sql(f"""
    SELECT explode(sequence(
        to_date('{start_date}'),
        to_date('{end_date}'),
        interval 1 day
    )) AS date
""")

# Add day name, day number, and weekday/weekend classification
result = dates.withColumn("day_name", date_format(col("date"), "EEEE")) \
              .withColumn("day_of_week", dayofweek(col("date"))) \
              .withColumn("day_type",
                         when(col("day_of_week").isin(1, 7), "Weekend")
                         .otherwise("Weekday")) \
              .orderBy("date")

result.show(61, truncate=False)
```

---

## Step-by-Step Explanation with Intermediate DataFrames

### Step 1: Generate Date Sequence

- **What happens:** `sequence(start_date, end_date, interval 1 day)` creates an array of consecutive dates. `explode()` converts the array into individual rows — one row per date.
- **Output (dates):**

  | date       |
  |------------|
  | 2026-01-16 |
  | 2026-01-17 |
  | 2026-01-18 |
  | ...        |
  | 2026-03-17 |

  (61 rows total)

### Step 2: Add Day Name

- **What happens:** `date_format(col("date"), "EEEE")` formats the date as the full day name (Monday, Tuesday, etc.). The format pattern `"EEEE"` is Java's SimpleDateFormat for full weekday name.
- **Output (after adding day_name):**

  | date       | day_name  |
  |------------|-----------|
  | 2026-01-16 | Friday    |
  | 2026-01-17 | Saturday  |
  | 2026-01-18 | Sunday    |
  | 2026-01-19 | Monday    |
  | ...        | ...       |

### Step 3: Add Day of Week Number

- **What happens:** `dayofweek(col("date"))` returns 1 (Sunday) through 7 (Saturday). Note: PySpark follows the US convention where Sunday = 1.
- **Output (after adding day_of_week):**

  | date       | day_name  | day_of_week |
  |------------|-----------|-------------|
  | 2026-01-16 | Friday    | 6           |
  | 2026-01-17 | Saturday  | 7           |
  | 2026-01-18 | Sunday    | 1           |
  | 2026-01-19 | Monday    | 2           |
  | ...        | ...       | ...         |

### Step 4: Classify as Weekday or Weekend

- **What happens:** `when(col("day_of_week").isin(1, 7), "Weekend").otherwise("Weekday")` checks if the day is Sunday (1) or Saturday (7) and labels accordingly.
- **Final Output (result):**

  | date       | day_name  | day_of_week | day_type |
  |------------|-----------|-------------|----------|
  | 2026-01-16 | Friday    | 6           | Weekday  |
  | 2026-01-17 | Saturday  | 7           | Weekend  |
  | 2026-01-18 | Sunday    | 1           | Weekend  |
  | 2026-01-19 | Monday    | 2           | Weekday  |
  | 2026-01-20 | Tuesday   | 3           | Weekday  |
  | ...        | ...       | ...         | ...      |

---

## Alternative: Pure DataFrame API (No Spark SQL)

```python
from pyspark.sql.functions import explode, sequence, to_date, lit

# Generate dates using DataFrame API instead of spark.sql()
dates_df = spark.range(1).select(
    explode(
        sequence(
            to_date(lit(str(start_date))),
            to_date(lit(str(end_date)))
        )
    ).alias("date")
)

# Same classification logic
result_alt = dates_df.withColumn("day_name", date_format(col("date"), "EEEE")) \
    .withColumn("day_of_week", dayofweek(col("date"))) \
    .withColumn("day_type",
                when(col("day_of_week").isin(1, 7), "Weekend")
                .otherwise("Weekday")) \
    .orderBy("date")

result_alt.show(61, truncate=False)
```

This avoids f-string SQL injection risks by using the DataFrame API with `lit()` for literal values. `spark.range(1)` creates a single-row DataFrame as a starting point for the `sequence()` call.

---

## Key Interview Talking Points

1. **sequence() + explode() pattern:** This is the standard PySpark idiom for generating date ranges. `sequence(start, end, interval)` creates an array, and `explode()` converts it to rows. No recursive CTEs needed (unlike SQL).

2. **dayofweek() numbering:** PySpark's `dayofweek()` returns 1=Sunday through 7=Saturday (US convention). PostgreSQL's `EXTRACT(DOW)` returns 0=Sunday through 6=Saturday. This is a common interview trap — always confirm the numbering convention.

3. **Dynamic vs hardcoded dates:** The solution uses `datetime.now()` and `timedelta` to compute dates at runtime. In production, you'd parameterize the range (e.g., from a config table or job argument) rather than using relative offsets.

4. **SQL injection risk:** The f-string approach (`f"to_date('{start_date}')"`) is safe here because `start_date` comes from `datetime`, not user input. For user-supplied dates, use parameterized queries or the DataFrame API alternative.
