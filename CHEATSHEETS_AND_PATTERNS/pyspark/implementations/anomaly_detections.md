I'll explain this anomaly detection problem in streaming data using Spark Structured Streaming.

## Problem Understanding

You have **streaming sensor data** (e.g., temperature sensors, IoT devices) coming in real-time, and you need to detect **anomalies** (unusual values) as they occur. Anomalies might indicate equipment failure, security issues, or unusual events.

**Key Challenges:**
- Data arrives continuously in real-time
- Need to detect outliers without knowing the full dataset
- Must balance sensitivity (catching anomalies) vs false positives

## Solution Breakdown

```python
windowed = df.groupBy(window("timestamp", "5 minutes")).agg(avg("value"), stddev("value"))

anomalies = windowed.filter("value > avg + 3 * stddev")
```

### Step-by-Step Explanation:

**1. Sliding Window on Timestamp:**
```python
window("timestamp", "5 minutes")
```
- Creates 5-minute time windows
- Groups data within each 5-minute interval
- Windows can overlap (sliding) or be distinct (tumbling)

**2. Statistical Aggregations:**
```python
.agg(avg("value"), stddev("value"))
```
- `avg("value")`: Calculate mean of sensor values in the window
- `stddev("value")`: Calculate standard deviation in the window
- These establish the "normal" range for data in this window

**3. Anomaly Detection (3-Sigma Rule):**
```python
filter("value > avg + 3 * stddev")
```
- Detects values more than 3 standard deviations above the mean
- Based on normal distribution: ~99.7% of data falls within ±3σ
- Values beyond this are considered anomalies

### Visual Example:

**Streaming Sensor Data:**
```
timestamp           | sensor_id | value
--------------------|-----------|-------
2026-01-20 10:00:00 | sensor_1  | 22.5
2026-01-20 10:01:00 | sensor_1  | 23.1
2026-01-20 10:02:00 | sensor_1  | 22.8
2026-01-20 10:03:00 | sensor_1  | 23.5
2026-01-20 10:04:00 | sensor_1  | 85.0   ← Anomaly!
2026-01-20 10:05:00 | sensor_1  | 22.9
2026-01-20 10:06:00 | sensor_1  | 23.2
```

**Window Aggregation (5-minute window: 10:00-10:05):**
```
window_start        | window_end          | avg   | stddev
--------------------|---------------------|-------|-------
2026-01-20 10:00:00 | 2026-01-20 10:05:00 | 35.38 | 26.12
```

**Anomaly Detection:**
```
Upper threshold = avg + 3 * stddev = 35.38 + 3 * 26.12 = 113.74
```

For each value in the window:
- 22.5, 23.1, 22.8, 23.5, 22.9 → Normal (all < 113.74)
- 85.0 → Flagged as anomaly (but actually < threshold)

**Wait, there's an issue with the code!** Let me clarify...

## Corrected Understanding:

The original code has a conceptual issue. Let me show both the **actual implementation** and what was likely intended:

### Issue with Original Code:

```python
# This doesn't quite work as shown
anomalies = windowed.filter("value > avg + 3 * stddev")
```

The problem: After aggregation, we no longer have individual `value` entries - we only have the window statistics.

### Proper Implementation:

```python
from pyspark.sql.functions import window, avg, stddev, col

# Step 1: Calculate window statistics
windowed_stats = df.groupBy(
    window("timestamp", "5 minutes"),
    "sensor_id"  # Group by sensor too
).agg(
    avg("value").alias("avg_value"),
    stddev("value").alias("stddev_value")
)

# Step 2: Join back to original data
df_with_stats = df.join(
    windowed_stats,
    (df.sensor_id == windowed_stats.sensor_id) &
    (df.timestamp >= windowed_stats.window.start) &
    (df.timestamp < windowed_stats.window.end)
)

# Step 3: Detect anomalies
anomalies = df_with_stats.filter(
    col("value") > (col("avg_value") + 3 * col("stddev_value"))
)
```

## Complete Working Example:

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import window, avg, stddev, col, abs
from pyspark.sql.types import StructType, StructField, TimestampType, StringType, DoubleType

# Define schema for streaming data
schema = StructType([
    StructField("timestamp", TimestampType(), True),
    StructField("sensor_id", StringType(), True),
    StructField("value", DoubleType(), True)
])

# Read from streaming source (e.g., Kafka, socket, file stream)
streaming_df = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "localhost:9092") \
    .option("subscribe", "sensor-data") \
    .load()

# Parse JSON data
from pyspark.sql.functions import from_json

sensor_data = streaming_df.select(
    from_json(col("value").cast("string"), schema).alias("data")
).select("data.*")

# Calculate rolling statistics per sensor
windowed_stats = sensor_data.groupBy(
    window("timestamp", "5 minutes", "1 minute"),  # 5-min window, 1-min slide
    "sensor_id"
).agg(
    avg("value").alias("avg_value"),
    stddev("value").alias("stddev_value")
)

# Join streaming data with its window statistics
enriched_data = sensor_data.alias("current").join(
    windowed_stats.alias("stats"),
    (col("current.sensor_id") == col("stats.sensor_id")) &
    (col("current.timestamp") >= col("stats.window.start")) &
    (col("current.timestamp") < col("stats.window.end")),
    "left"
)

# Detect anomalies (Z-score > 3)
anomalies = enriched_data.withColumn(
    "z_score",
    (col("value") - col("avg_value")) / col("stddev_value")
).filter(
    abs(col("z_score")) > 3
)

# Write anomalies to output sink
query = anomalies.writeStream \
    .outputMode("append") \
    .format("console") \
    .start()

query.awaitTermination()
```

## Understanding the Z-Score Method:

**Z-Score Formula:**
```
Z = (value - mean) / standard_deviation
```

**Interpretation:**
- Z-score tells you how many standard deviations a value is from the mean
- Z > 3 or Z < -3: Anomaly (only ~0.3% of normal data falls here)
- Z between -3 and 3: Normal

### Example Calculation:

```
Window data: [22, 23, 22, 24, 85]
Mean: 35.2
Std Dev: 26.6

For value = 85:
Z = (85 - 35.2) / 26.6 = 49.8 / 26.6 ≈ 1.87 (not anomaly with 3-sigma)

For more normal scenario:
Window data: [22, 23, 22, 24, 23]
Mean: 22.8
Std Dev: 0.84

For value = 85 (if it appeared):
Z = (85 - 22.8) / 0.84 = 74.0 (definitely an anomaly!)
```

## Different Window Types:

### 1. Tumbling Window (Non-overlapping):
```python
# Each window is distinct, no overlap
window("timestamp", "5 minutes")  # 10:00-10:05, 10:05-10:10, etc.
```

### 2. Sliding Window (Overlapping):
```python
# Windows overlap for smoother detection
window("timestamp", "5 minutes", "1 minute")
# Windows: 10:00-10:05, 10:01-10:06, 10:02-10:07, etc.
```

**Visual Comparison:**
```
Tumbling Windows:
[10:00-10:05][10:05-10:10][10:10-10:15]

Sliding Windows (5-min window, 1-min slide):
[10:00-10:05]
  [10:01-10:06]
    [10:02-10:07]
      [10:03-10:08]
```

## Alternative Anomaly Detection Methods:

### Method 1: Interquartile Range (IQR):
```python
from pyspark.sql.functions import expr, percentile_approx

windowed_stats = sensor_data.groupBy(
    window("timestamp", "5 minutes"),
    "sensor_id"
).agg(
    expr("percentile_approx(value, 0.25)").alias("q1"),
    expr("percentile_approx(value, 0.75)").alias("q3")
)

# IQR = Q3 - Q1
# Outliers: < Q1 - 1.5*IQR or > Q3 + 1.5*IQR
anomalies = enriched_data.filter(
    (col("value") < col("q1") - 1.5 * (col("q3") - col("q1"))) |
    (col("value") > col("q3") + 1.5 * (col("q3") - col("q1")))
)
```

### Method 2: Dynamic Threshold:
```python
# Adjust threshold based on recent patterns
windowed_stats = sensor_data.groupBy(
    window("timestamp", "5 minutes"),
    "sensor_id"
).agg(
    avg("value").alias("avg_value"),
    stddev("value").alias("stddev_value"),
    max("value").alias("max_value")
)

# Anomaly if value is significantly higher than recent max
anomalies = enriched_data.filter(
    col("value") > col("max_value") * 1.5
)
```

### Method 3: Multiple Sigma Levels:
```python
from pyspark.sql.functions import when

# Classify severity
anomalies = enriched_data.withColumn(
    "z_score",
    (col("value") - col("avg_value")) / col("stddev_value")
).withColumn(
    "severity",
    when(abs(col("z_score")) > 4, "critical")
    .when(abs(col("z_score")) > 3, "high")
    .when(abs(col("z_score")) > 2, "medium")
    .otherwise("normal")
).filter(col("severity") != "normal")
```

## Complete Streaming Pipeline:

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import *

spark = SparkSession.builder \
    .appName("AnomalyDetection") \
    .getOrCreate()

# Read streaming data
sensor_stream = spark.readStream \
    .format("socket") \
    .option("host", "localhost") \
    .option("port", 9999) \
    .load()

# Parse CSV: timestamp,sensor_id,value
from pyspark.sql.types import StructType, StructField, TimestampType, StringType, DoubleType

schema = StructType([
    StructField("timestamp", TimestampType(), True),
    StructField("sensor_id", StringType(), True),
    StructField("value", DoubleType(), True)
])

sensor_data = sensor_stream.select(
    from_csv(col("value"), schema).alias("data")
).select("data.*")

# Calculate statistics with sliding window
windowed_stats = sensor_data.groupBy(
    window("timestamp", "5 minutes", "1 minute"),
    "sensor_id"
).agg(
    avg("value").alias("mean"),
    stddev("value").alias("std"),
    count("value").alias("count")
)

# Join and detect anomalies
anomalies = sensor_data.alias("s").join(
    windowed_stats.alias("w"),
    (col("s.sensor_id") == col("w.sensor_id")) &
    (col("s.timestamp") >= col("w.window.start")) &
    (col("s.timestamp") < col("w.window.end"))
).select(
    col("s.timestamp"),
    col("s.sensor_id"),
    col("s.value"),
    col("w.mean"),
    col("w.std"),
    ((col("s.value") - col("w.mean")) / col("w.std")).alias("z_score")
).filter(
    abs(col("z_score")) > 3
)

# Output anomalies
query = anomalies.writeStream \
    .outputMode("append") \
    .format("console") \
    .option("truncate", False) \
    .start()

query.awaitTermination()
```

## Key Considerations:

| Aspect | Recommendation |
|--------|---------------|
| **Window Size** | Larger = smoother but slower detection; Smaller = faster but more sensitive |
| **Sigma Threshold** | 3σ = strict (fewer false positives); 2σ = lenient (more detections) |
| **Sliding Interval** | Smaller = more frequent updates but higher computation |
| **Cold Start** | First few windows may have unreliable statistics |
| **Sensor-Specific** | Always partition by sensor_id for accurate baselines |

## Performance Optimization:

```python
# Use watermarking to handle late data
sensor_data.withWatermark("timestamp", "10 minutes")

# Optimize window operations
windowed_stats = sensor_data \
    .withWatermark("timestamp", "10 minutes") \
    .groupBy(
        window("timestamp", "5 minutes", "1 minute"),
        "sensor_id"
    ).agg(...)
```

Does this clarify how to detect anomalies in streaming sensor data using Spark Structured Streaming and statistical methods?