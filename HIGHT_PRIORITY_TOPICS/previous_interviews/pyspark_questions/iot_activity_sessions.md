# PySpark Implementation: IoT Sensor Activity Sessions

## Problem Statement

Given a stream of IoT sensor readings with timestamps, **group readings into activity sessions**. A new session begins when the gap between consecutive readings from the same device exceeds a **5-minute inactivity threshold**. Then compute session-level metrics: duration, reading count, and average value. This is the IoT/manufacturing version of the `sessionize_clickstream` pattern — same `lag → flag → cumsum` technique, different business context.

### Sample Data

```
device_id  reading_time          sensor_value  sensor_type
D001       2025-01-15 08:00:00   72.5          temperature
D001       2025-01-15 08:01:30   73.1          temperature
D001       2025-01-15 08:02:45   74.8          temperature
D001       2025-01-15 08:03:10   75.2          temperature
D001       2025-01-15 08:15:00   68.3          temperature
D001       2025-01-15 08:16:00   67.9          temperature
D002       2025-01-15 08:00:00   45.2          humidity
D002       2025-01-15 08:02:00   46.1          humidity
D002       2025-01-15 08:20:00   50.3          humidity
```

### Expected Output (Session Summary)

| device_id | session_id | session_start       | session_end         | duration_sec | readings | avg_value | max_value |
|-----------|------------|---------------------|---------------------|-------------|----------|-----------|-----------|
| D001      | 1          | 08:00:00            | 08:03:10            | 190         | 4        | 73.9      | 75.2      |
| D001      | 2          | 08:15:00            | 08:16:00            | 60          | 2        | 68.1      | 68.3      |
| D002      | 1          | 08:00:00            | 08:02:00            | 120         | 2        | 45.65     | 46.1      |
| D002      | 2          | 08:20:00            | 08:20:00            | 0           | 1        | 50.3      | 50.3      |

---

## PySpark Code Solution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lag, when, sum as spark_sum, to_timestamp, \
    unix_timestamp, min as spark_min, max as spark_max, count, avg, \
    round as spark_round
from pyspark.sql.window import Window

# Initialize Spark session
spark = SparkSession.builder.appName("IoTSessions").getOrCreate()

# Sample data
data = [
    ("D001", "2025-01-15 08:00:00", 72.5, "temperature"),
    ("D001", "2025-01-15 08:01:30", 73.1, "temperature"),
    ("D001", "2025-01-15 08:02:45", 74.8, "temperature"),
    ("D001", "2025-01-15 08:03:10", 75.2, "temperature"),
    ("D001", "2025-01-15 08:15:00", 68.3, "temperature"),
    ("D001", "2025-01-15 08:16:00", 67.9, "temperature"),
    ("D002", "2025-01-15 08:00:00", 45.2, "humidity"),
    ("D002", "2025-01-15 08:02:00", 46.1, "humidity"),
    ("D002", "2025-01-15 08:20:00", 50.3, "humidity")
]
columns = ["device_id", "reading_time", "sensor_value", "sensor_type"]
df = spark.createDataFrame(data, columns)
df = df.withColumn("reading_time", to_timestamp("reading_time"))

# Inactivity threshold: 5 minutes = 300 seconds
INACTIVITY_THRESHOLD = 5 * 60

# Step 1: Window ordered by device and time
window_device = Window.partitionBy("device_id").orderBy("reading_time")

# Step 2: Get previous reading time using lag
df_with_lag = df.withColumn(
    "prev_reading_time", lag("reading_time").over(window_device)
)

# Step 3: Calculate gap in seconds
df_with_gap = df_with_lag.withColumn(
    "gap_seconds",
    unix_timestamp(col("reading_time")) - unix_timestamp(col("prev_reading_time"))
)

# Step 4: Flag new sessions (gap > threshold OR first reading)
df_flagged = df_with_gap.withColumn(
    "new_session",
    when(
        (col("gap_seconds") > INACTIVITY_THRESHOLD) | col("prev_reading_time").isNull(),
        1
    ).otherwise(0)
)

# Step 5: Cumulative sum of flags = session_id
df_sessioned = df_flagged.withColumn(
    "session_id",
    spark_sum("new_session").over(window_device)
)

# Step 6: Session-level aggregation
session_summary = df_sessioned.groupBy("device_id", "session_id", "sensor_type").agg(
    spark_min("reading_time").alias("session_start"),
    spark_max("reading_time").alias("session_end"),
    spark_round(
        (unix_timestamp(spark_max("reading_time")) -
         unix_timestamp(spark_min("reading_time"))), 0
    ).alias("duration_sec"),
    count("*").alias("readings"),
    spark_round(avg("sensor_value"), 2).alias("avg_value"),
    spark_max("sensor_value").alias("max_value"),
    spark_min("sensor_value").alias("min_value")
).orderBy("device_id", "session_id")

session_summary.show(truncate=False)
```

### Step-by-Step Explanation (Same Pattern as sessionize_clickstream)

#### The Core Pattern: lag → flag → cumulative sum

| reading_time | device | prev_time | gap_sec | new_session | session_id |
|-------------|--------|-----------|---------|-------------|------------|
| 08:00:00    | D001   | null      | null    | 1           | 1          |
| 08:01:30    | D001   | 08:00:00  | 90      | 0           | 1          |
| 08:02:45    | D001   | 08:01:30  | 75      | 0           | 1          |
| 08:03:10    | D001   | 08:02:45  | 25      | 0           | 1          |
| 08:15:00    | D001   | 08:03:10  | **710** | 1           | 2          |
| 08:16:00    | D001   | 08:15:00  | 60      | 0           | 2          |

Gap of 710 seconds (11.8 min) > 300 second threshold → new session.

---

## IoT-Specific Extension: Anomaly Detection per Session

```python
from pyspark.sql.functions import stddev, abs as spark_abs

# Calculate session statistics and flag anomalous sessions
anomaly_sessions = df_sessioned.groupBy("device_id", "session_id").agg(
    count("*").alias("readings"),
    avg("sensor_value").alias("avg_value"),
    stddev("sensor_value").alias("stddev_value"),
    spark_max("sensor_value").alias("max_value"),
    spark_min("sensor_value").alias("min_value")
).withColumn(
    "value_range", col("max_value") - col("min_value")
).withColumn(
    "is_anomalous",
    when(
        (col("value_range") > 10) |           # Large swing within session
        (col("readings") > 100) |              # Unusually many readings
        (col("stddev_value") > 5),             # High variance
        True
    ).otherwise(False)
)

anomaly_sessions.show(truncate=False)
```

---

## IoT-Specific Extension: Device Uptime Calculation

```python
# Calculate uptime: time device was actively sending readings vs total time
from pyspark.sql.functions import first, last

device_uptime = session_summary.groupBy("device_id").agg(
    count("*").alias("total_sessions"),
    spark_sum("duration_sec").alias("total_active_sec"),
    spark_sum("readings").alias("total_readings"),
    spark_min("session_start").alias("first_reading"),
    spark_max("session_end").alias("last_reading")
).withColumn(
    "total_span_sec",
    unix_timestamp(col("last_reading")) - unix_timestamp(col("first_reading"))
).withColumn(
    "uptime_pct",
    spark_round(col("total_active_sec") / col("total_span_sec") * 100, 1)
)

device_uptime.show(truncate=False)
```

---

## IoT-Specific Extension: Reading Rate per Session

```python
# Calculate readings-per-minute for each session
session_with_rate = session_summary.withColumn(
    "readings_per_min",
    when(col("duration_sec") > 0,
         spark_round(col("readings") / (col("duration_sec") / 60), 2)
    ).otherwise(None)
)

session_with_rate.select(
    "device_id", "session_id", "readings", "duration_sec", "readings_per_min"
).show(truncate=False)
```

---

## Method 2: Using SQL

```python
df.createOrReplaceTempView("sensor_readings")

spark.sql("""
    WITH with_gaps AS (
        SELECT *,
            LAG(reading_time) OVER (
                PARTITION BY device_id ORDER BY reading_time
            ) AS prev_time,
            UNIX_TIMESTAMP(reading_time) - UNIX_TIMESTAMP(
                LAG(reading_time) OVER (
                    PARTITION BY device_id ORDER BY reading_time
                )
            ) AS gap_seconds
        FROM sensor_readings
    ),
    flagged AS (
        SELECT *,
            CASE WHEN gap_seconds > 300 OR prev_time IS NULL
                 THEN 1 ELSE 0 END AS new_session
        FROM with_gaps
    ),
    sessioned AS (
        SELECT *,
            SUM(new_session) OVER (
                PARTITION BY device_id ORDER BY reading_time
            ) AS session_id
        FROM flagged
    )
    SELECT
        device_id,
        session_id,
        sensor_type,
        MIN(reading_time) AS session_start,
        MAX(reading_time) AS session_end,
        COUNT(*) AS readings,
        ROUND(AVG(sensor_value), 2) AS avg_value,
        MAX(sensor_value) AS max_value
    FROM sessioned
    GROUP BY device_id, session_id, sensor_type
    ORDER BY device_id, session_id
""").show(truncate=False)
```

---

## Connection to Parent Pattern (sessionize_clickstream)

| Concept | sessionize_clickstream | iot_activity_sessions |
|---------|----------------------|----------------------|
| **Entity** | User (user_id) | Device (device_id) |
| **Events** | Page views | Sensor readings |
| **Timeout** | 30 minutes | 5 minutes |
| **Session metric** | Pages viewed, bounce rate | Avg/max value, reading rate |
| **Core technique** | lag → flag → cumsum | lag → flag → cumsum (identical) |

Same three-step pattern, different:
- Partition key (user vs device)
- Timeout threshold (30 min vs 5 min)
- Aggregation metrics (count/duration vs sensor statistics)

---

## Key Interview Talking Points

1. **Same pattern, different domain:** This is the exact `lag → flag → cumsum` technique from clickstream sessionization. The only differences are the partition key, timeout threshold, and aggregation metrics.

2. **Configurable thresholds:** In production, the inactivity threshold varies by sensor type. Temperature sensors might use 5 minutes, while vibration sensors might use 30 seconds. Make it a parameter.

3. **IoT-specific metrics beyond clickstream:**
   - **Reading rate** (readings per minute) — detects sensor malfunction
   - **Value range within session** — detects anomalies
   - **Device uptime** — operational monitoring
   - **Session gap analysis** — detect communication failures

4. **Scale considerations:** IoT data is often massive (millions of readings per device per day). The window function approach is efficient — it's a single sort + single pass. Partition by device_id keeps partitions manageable.

5. **Real-world use cases:**
   - Factory equipment monitoring (vibration/temperature sessions)
   - Vehicle trip detection from GPS pings
   - Smart home device usage sessions
   - Network traffic burst detection
   - Medical device monitoring (patient vital sessions)
