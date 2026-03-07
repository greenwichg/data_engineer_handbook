# PySpark Implementation: Calendar Table Generation

## Problem Statement
Generate a complete calendar dimension table for the year 2024. Each row represents one
day and includes computed attributes: day_of_week, is_weekend, quarter, week_number,
fiscal_year (assuming fiscal year starts in October), month_name, and a flag indicating
whether the date is a US federal holiday.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import StringType, DateType, StructType, StructField

spark = SparkSession.builder.appName("calendar_table").getOrCreate()

# US Federal holidays for 2024
holidays_data = [
    ("2024-01-01", "New Year's Day"),
    ("2024-01-15", "Martin Luther King Jr. Day"),
    ("2024-02-19", "Presidents' Day"),
    ("2024-05-27", "Memorial Day"),
    ("2024-06-19", "Juneteenth"),
    ("2024-07-04", "Independence Day"),
    ("2024-09-02", "Labor Day"),
    ("2024-10-14", "Columbus Day"),
    ("2024-11-11", "Veterans Day"),
    ("2024-11-28", "Thanksgiving Day"),
    ("2024-12-25", "Christmas Day"),
]
holidays_schema = StructType([
    StructField("holiday_date", StringType()),
    StructField("holiday_name", StringType()),
])
holidays_df = spark.createDataFrame(holidays_data, holidays_schema) \
    .withColumn("holiday_date", F.to_date("holiday_date"))
```

### Expected Output (first few rows)

| date       | day_of_week | day_name  | is_weekend | month_name | quarter | week_number | fiscal_year | is_holiday | holiday_name    |
|------------|-------------|-----------|------------|------------|---------|-------------|-------------|------------|-----------------|
| 2024-01-01 | 2           | Monday    | false      | January    | 1       | 1           | 2024        | true       | New Year's Day  |
| 2024-01-02 | 3           | Tuesday   | false      | January    | 1       | 1           | 2024        | false      | null            |
| ...        | ...         | ...       | ...        | ...        | ...     | ...         | ...         | ...        | ...             |
| 2024-10-01 | 3           | Tuesday   | false      | October    | 4       | 40          | 2025        | false      | null            |

---

## Method 1: sequence + explode + Date Functions (Recommended)

```python
from pyspark.sql import functions as F

# Step 1: Generate a row for every day in 2024
calendar_df = spark.range(1).select(
    F.explode(
        F.sequence(
            F.to_date(F.lit("2024-01-01")),
            F.to_date(F.lit("2024-12-31")),
            F.expr("INTERVAL 1 DAY")
        )
    ).alias("date")
)

# Step 2: Add date attribute columns
calendar_df = calendar_df \
    .withColumn("day_of_week", F.dayofweek("date")) \
    .withColumn("day_name", F.date_format("date", "EEEE")) \
    .withColumn("is_weekend", F.dayofweek("date").isin(1, 7)) \
    .withColumn("month_name", F.date_format("date", "MMMM")) \
    .withColumn("month_num", F.month("date")) \
    .withColumn("year", F.year("date")) \
    .withColumn("quarter", F.quarter("date")) \
    .withColumn("week_number", F.weekofyear("date")) \
    .withColumn("day_of_month", F.dayofmonth("date")) \
    .withColumn("day_of_year", F.dayofyear("date"))

# Step 3: Compute fiscal year (Oct-Sep fiscal calendar: Oct 2024 -> FY2025)
calendar_df = calendar_df \
    .withColumn(
        "fiscal_year",
        F.when(F.month("date") >= 10, F.year("date") + 1)
         .otherwise(F.year("date"))
    ) \
    .withColumn(
        "fiscal_quarter",
        F.when(F.month("date").isin(10, 11, 12), 1)
         .when(F.month("date").isin(1, 2, 3), 2)
         .when(F.month("date").isin(4, 5, 6), 3)
         .otherwise(4)
    )

# Step 4: Left join with holidays
calendar_df = calendar_df \
    .join(holidays_df, calendar_df["date"] == holidays_df["holiday_date"], "left") \
    .withColumn("is_holiday", F.col("holiday_name").isNotNull()) \
    .drop("holiday_date")

# Step 5: Add business day flag
calendar_df = calendar_df \
    .withColumn(
        "is_business_day",
        (~F.col("is_weekend")) & (~F.col("is_holiday"))
    )

calendar_df.select(
    "date", "day_name", "is_weekend", "month_name", "quarter",
    "week_number", "fiscal_year", "fiscal_quarter", "is_holiday",
    "holiday_name", "is_business_day"
).show(10, truncate=False)
```

### Step-by-Step Explanation

**After Step 1 — Generate date spine:**

| date       |
|------------|
| 2024-01-01 |
| 2024-01-02 |
| 2024-01-03 |
| ...        |
| 2024-12-31 |

366 rows (2024 is a leap year).

**After Step 2 — Add date attributes:**

| date       | day_of_week | day_name  | is_weekend | month_name | quarter | week_number |
|------------|-------------|-----------|------------|------------|---------|-------------|
| 2024-01-01 | 2           | Monday    | false      | January    | 1       | 1           |
| 2024-01-06 | 7           | Saturday  | true       | January    | 1       | 1           |
| 2024-01-07 | 1           | Sunday    | true       | January    | 1       | 2           |

Note: Spark's `dayofweek` returns 1 = Sunday, 7 = Saturday.

**After Step 3 — Fiscal year:**

| date       | fiscal_year | fiscal_quarter |
|------------|-------------|----------------|
| 2024-01-15 | 2024        | 2              |
| 2024-06-01 | 2024        | 3              |
| 2024-10-01 | 2025        | 1              |
| 2024-12-25 | 2025        | 1              |

**After Step 4 — Join holidays:**

| date       | is_holiday | holiday_name       |
|------------|------------|--------------------|
| 2024-01-01 | true       | New Year's Day     |
| 2024-01-02 | false      | null               |
| 2024-07-04 | true       | Independence Day   |

---

## Method 2: Python dateutil + UDF Approach

```python
from pyspark.sql import functions as F
from pyspark.sql.types import (
    StructType, StructField, DateType, StringType,
    IntegerType, BooleanType
)
from datetime import date, timedelta

# Generate all dates in Python, create DataFrame directly
start = date(2024, 1, 1)
end = date(2024, 12, 31)
all_dates = []
d = start
while d <= end:
    all_dates.append((d,))
    d += timedelta(days=1)

date_schema = StructType([StructField("date", DateType())])
calendar_df = spark.createDataFrame(all_dates, date_schema)

# Then add computed columns the same way as Method 1
calendar_df = calendar_df \
    .withColumn("day_of_week", F.dayofweek("date")) \
    .withColumn("day_name", F.date_format("date", "EEEE")) \
    .withColumn("is_weekend", F.dayofweek("date").isin(1, 7)) \
    .withColumn("month_name", F.date_format("date", "MMMM")) \
    .withColumn("quarter", F.quarter("date")) \
    .withColumn("week_number", F.weekofyear("date")) \
    .withColumn("fiscal_year",
        F.when(F.month("date") >= 10, F.year("date") + 1)
         .otherwise(F.year("date"))) \
    .join(holidays_df, calendar_df["date"] == holidays_df["holiday_date"], "left") \
    .withColumn("is_holiday", F.col("holiday_name").isNotNull()) \
    .drop("holiday_date")

calendar_df.show(5, truncate=False)
```

---

## Key Interview Talking Points

1. **`F.sequence` with date intervals** is the cleanest way to generate a date spine
   without collecting data to the driver. It keeps everything distributed.

2. **`dayofweek` convention** — Spark returns 1 = Sunday, 7 = Saturday. This catches
   many candidates off guard. Always verify with a known date.

3. **Fiscal year logic** — the formula `WHEN month >= fiscal_start THEN year + 1` is a
   common pattern. Mention that real-world fiscal calendars (e.g., 4-4-5 retail) are
   more complex and often loaded from reference tables.

4. **Left join for holidays** — ensures non-holiday dates are preserved. Using an inner
   join would drop 355 rows. Always mention the join type deliberately.

5. **Calendar tables are dimension tables** — in a star schema they are joined to fact
   tables via date keys. Mention partitioning fact tables by date for performance.

6. **Idempotency** — calendar tables should be regenerated (not appended) since the
   same date range always produces the same output. This makes them safe to overwrite.

7. **Performance** — a calendar table for a full year is only 365-366 rows. It should
   be broadcast-joined to large fact tables using `F.broadcast(calendar_df)`.

8. **Edge cases** — leap years (Feb 29), year boundaries (week 1 vs week 52/53),
   ISO week numbering vs US week numbering. Mention `weekofyear` follows ISO 8601.
