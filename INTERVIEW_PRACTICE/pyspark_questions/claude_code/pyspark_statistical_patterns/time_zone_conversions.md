# PySpark Implementation: Time Zone Conversions

## Problem Statement

Working with timestamps across multiple time zones is a common challenge in data engineering, especially for global applications. Given a dataset of events recorded in various time zones, convert all timestamps to a standard time zone (UTC), handle daylight saving time transitions, and normalize event times for consistent analysis. This is a frequently asked interview question at companies with distributed systems or global user bases.

### Sample Data

```
event_id | event_time          | source_timezone
1        | 2024-03-10 01:30:00 | America/New_York
2        | 2024-03-10 03:30:00 | America/New_York
3        | 2024-07-15 14:00:00 | America/Los_Angeles
4        | 2024-11-03 01:30:00 | America/Chicago
5        | 2024-12-25 09:00:00 | Europe/London
6        | 2024-06-15 18:00:00 | Asia/Tokyo
7        | 2024-03-31 02:30:00 | Europe/Berlin
```

### Expected Output

| event_id | original_time       | source_timezone      | utc_time            | est_time            |
|----------|---------------------|----------------------|---------------------|---------------------|
| 1        | 2024-03-10 01:30:00 | America/New_York     | 2024-03-10 06:30:00 | 2024-03-10 01:30:00 |
| 2        | 2024-03-10 03:30:00 | America/New_York     | 2024-03-10 07:30:00 | 2024-03-10 03:30:00 |
| 3        | 2024-07-15 14:00:00 | America/Los_Angeles  | 2024-07-15 21:00:00 | 2024-07-15 17:00:00 |
| 4        | 2024-11-03 01:30:00 | America/Chicago      | 2024-11-03 07:30:00 | 2024-11-03 01:30:00 |
| 5        | 2024-12-25 09:00:00 | Europe/London        | 2024-12-25 09:00:00 | 2024-12-25 04:00:00 |
| 6        | 2024-06-15 18:00:00 | Asia/Tokyo           | 2024-06-15 09:00:00 | 2024-06-15 05:00:00 |

---

## Method 1: Using from_utc_timestamp and to_utc_timestamp

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, to_timestamp, from_utc_timestamp, to_utc_timestamp,
    lit, expr, date_format
)

# Initialize SparkSession
spark = SparkSession.builder \
    .appName("TimeZoneConversions") \
    .master("local[*]") \
    .getOrCreate()

# Create sample data
data = [
    (1, "2024-03-10 01:30:00", "America/New_York"),
    (2, "2024-03-10 03:30:00", "America/New_York"),
    (3, "2024-07-15 14:00:00", "America/Los_Angeles"),
    (4, "2024-11-03 01:30:00", "America/Chicago"),
    (5, "2024-12-25 09:00:00", "Europe/London"),
    (6, "2024-06-15 18:00:00", "Asia/Tokyo"),
    (7, "2024-03-31 02:30:00", "Europe/Berlin"),
]

df = spark.createDataFrame(data, ["event_id", "event_time", "source_timezone"])

# Convert string to timestamp
df = df.withColumn("event_ts", to_timestamp("event_time"))

# Step 1: Convert local time to UTC using to_utc_timestamp
# Note: to_utc_timestamp treats the input timestamp as being in the given timezone
# and converts it to UTC
# For dynamic timezone column, use expr with SQL
df_with_utc = df.withColumn(
    "utc_time",
    expr("to_utc_timestamp(event_ts, source_timezone)")
)

# Step 2: Convert UTC to target timezone (e.g., US/Eastern)
df_result = df_with_utc.withColumn(
    "est_time",
    from_utc_timestamp(col("utc_time"), "America/New_York")
)

df_result.select(
    "event_id",
    date_format("event_ts", "yyyy-MM-dd HH:mm:ss").alias("original_time"),
    "source_timezone",
    date_format("utc_time", "yyyy-MM-dd HH:mm:ss").alias("utc_time"),
    date_format("est_time", "yyyy-MM-dd HH:mm:ss").alias("est_time")
).show(truncate=False)

spark.stop()
```

## Method 2: Using Spark SQL Expressions

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("TimeZoneConversions_SQL") \
    .master("local[*]") \
    .getOrCreate()

data = [
    (1, "2024-03-10 01:30:00", "America/New_York"),
    (2, "2024-03-10 03:30:00", "America/New_York"),
    (3, "2024-07-15 14:00:00", "America/Los_Angeles"),
    (4, "2024-11-03 01:30:00", "America/Chicago"),
    (5, "2024-12-25 09:00:00", "Europe/London"),
    (6, "2024-06-15 18:00:00", "Asia/Tokyo"),
    (7, "2024-03-31 02:30:00", "Europe/Berlin"),
]

df = spark.createDataFrame(data, ["event_id", "event_time", "source_timezone"])
df.createOrReplaceTempView("events")

result = spark.sql("""
    SELECT
        event_id,
        event_time AS original_time,
        source_timezone,
        -- Convert local time to UTC
        to_utc_timestamp(
            to_timestamp(event_time),
            source_timezone
        ) AS utc_time,
        -- Convert to multiple target time zones
        from_utc_timestamp(
            to_utc_timestamp(to_timestamp(event_time), source_timezone),
            'America/New_York'
        ) AS eastern_time,
        from_utc_timestamp(
            to_utc_timestamp(to_timestamp(event_time), source_timezone),
            'America/Los_Angeles'
        ) AS pacific_time,
        from_utc_timestamp(
            to_utc_timestamp(to_timestamp(event_time), source_timezone),
            'Europe/London'
        ) AS london_time,
        -- Extract UTC offset info
        date_format(
            from_utc_timestamp(
                to_utc_timestamp(to_timestamp(event_time), source_timezone),
                source_timezone
            ),
            'yyyy-MM-dd HH:mm:ss'
        ) AS roundtrip_check
    FROM events
""")

result.show(truncate=False)

spark.stop()
```

## Method 3: Handling DST Transitions and Edge Cases

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, to_timestamp, expr, when, hour, dayofyear,
    date_format, lit, from_utc_timestamp, to_utc_timestamp
)

spark = SparkSession.builder \
    .appName("TimeZoneConversions_DST") \
    .master("local[*]") \
    .getOrCreate()

# Data specifically chosen around DST boundaries
# US Spring Forward: 2024-03-10 at 2:00 AM EST -> 3:00 AM EDT
# US Fall Back: 2024-11-03 at 2:00 AM EDT -> 1:00 AM EST
dst_data = [
    (1, "2024-03-10 01:30:00", "America/New_York", "Before spring forward"),
    (2, "2024-03-10 02:30:00", "America/New_York", "During spring forward gap"),
    (3, "2024-03-10 03:30:00", "America/New_York", "After spring forward"),
    (4, "2024-11-03 00:30:00", "America/New_York", "Before fall back"),
    (5, "2024-11-03 01:30:00", "America/New_York", "During fall back ambiguity"),
    (6, "2024-11-03 02:30:00", "America/New_York", "After fall back"),
]

df = spark.createDataFrame(
    dst_data,
    ["event_id", "event_time", "timezone", "description"]
)

# Convert and annotate DST status
result = df.withColumn("event_ts", to_timestamp("event_time")) \
    .withColumn(
        "utc_time",
        expr("to_utc_timestamp(event_ts, timezone)")
    ) \
    .withColumn(
        "back_to_local",
        expr("from_utc_timestamp(utc_time, timezone)")
    ) \
    .withColumn(
        "utc_offset_hours",
        (col("event_ts").cast("long") -
         expr("to_utc_timestamp(event_ts, timezone)").cast("long")) / 3600
    )

result.select(
    "event_id",
    "description",
    date_format("event_ts", "yyyy-MM-dd HH:mm:ss").alias("local_time"),
    date_format("utc_time", "yyyy-MM-dd HH:mm:ss").alias("utc_time"),
    date_format("back_to_local", "yyyy-MM-dd HH:mm:ss").alias("roundtrip"),
    "utc_offset_hours"
).show(truncate=False)

spark.stop()
```

## Key Concepts

- **to_utc_timestamp(ts, tz)**: Treats the input timestamp as being in the specified timezone and converts it to UTC. This is used when your data stores local times and you need to normalize to UTC.
- **from_utc_timestamp(ts, tz)**: Converts a UTC timestamp to the specified timezone. Use this when displaying UTC data in a user's local time.
- **DST Spring Forward**: Times in the "gap" (e.g., 2:00-3:00 AM) do not actually exist. Spark typically shifts them forward.
- **DST Fall Back**: Times in the "overlap" (e.g., 1:00-2:00 AM occurs twice) are ambiguous. Spark uses the standard (non-DST) offset by default.
- **Dynamic Timezone Column**: Use `expr("to_utc_timestamp(ts, tz_column)")` when the timezone varies per row. The direct function `to_utc_timestamp(col, "literal")` only accepts literal timezone strings.
- **Interview Tip**: Always mention that timestamps should be stored in UTC in your data warehouse, with the original timezone preserved as metadata. Convert to local time only at the presentation layer.
