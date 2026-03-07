# PySpark Implementation: Rate of Change Detection

## Problem Statement

Detecting sudden spikes or drops in metrics is critical for monitoring business health, fraud detection, and operational alerting. Given time-series data (e.g., daily revenue, API latency, transaction counts), identify periods where the metric changes by more than a threshold compared to the previous period. This is a common interview question that tests window function skills and analytical thinking.

### Sample Data

```
date       | region | revenue
2024-01-01 | East   | 10000
2024-01-02 | East   | 10500
2024-01-03 | East   | 7500
2024-01-04 | East   | 12000
2024-01-05 | East   | 11800
2024-01-06 | East   | 5000
2024-01-07 | East   | 5200
```

### Expected Output (Alerts for > 20% change)

| date       | region | revenue | prev_revenue | pct_change | alert_type |
|------------|--------|---------|--------------|------------|------------|
| 2024-01-03 | East   | 7500    | 10500        | -28.6      | DROP       |
| 2024-01-04 | East   | 12000   | 7500         | 60.0       | SPIKE      |
| 2024-01-06 | East   | 5000    | 11800        | -57.6      | DROP       |

---

## Method 1: Using lag() for Period-over-Period Change

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, lag, round as spark_round, when, lit, abs as spark_abs
)
from pyspark.sql.window import Window

# Initialize SparkSession
spark = SparkSession.builder \
    .appName("RateOfChangeDetection") \
    .master("local[*]") \
    .getOrCreate()

# Create sample data
data = [
    ("2024-01-01", "East", 10000),
    ("2024-01-02", "East", 10500),
    ("2024-01-03", "East", 7500),
    ("2024-01-04", "East", 12000),
    ("2024-01-05", "East", 11800),
    ("2024-01-06", "East", 5000),
    ("2024-01-07", "East", 5200),
    ("2024-01-01", "West", 8000),
    ("2024-01-02", "West", 8200),
    ("2024-01-03", "West", 8100),
    ("2024-01-04", "West", 2000),
    ("2024-01-05", "West", 7800),
    ("2024-01-06", "West", 8000),
    ("2024-01-07", "West", 7900),
]

df = spark.createDataFrame(data, ["date", "region", "revenue"])

# Define window ordered by date within each region
window_spec = Window.partitionBy("region").orderBy("date")

# Threshold for alerting
THRESHOLD = 20.0  # 20% change

# Calculate rate of change
result = df.withColumn(
    "prev_revenue", lag("revenue", 1).over(window_spec)
).withColumn(
    "pct_change",
    spark_round(
        (col("revenue") - col("prev_revenue")) / col("prev_revenue") * 100, 1
    )
).withColumn(
    "alert_type",
    when(col("pct_change") > THRESHOLD, lit("SPIKE"))
    .when(col("pct_change") < -THRESHOLD, lit("DROP"))
    .otherwise(lit("NORMAL"))
)

print("=== All Data with Rate of Change ===")
result.orderBy("region", "date").show(truncate=False)

print("=== Alerts Only (> 20% change) ===")
result.filter(col("alert_type") != "NORMAL").orderBy("region", "date").show(truncate=False)

spark.stop()
```

## Method 2: Moving Average Baseline Comparison

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, avg, round as spark_round, when, lit, abs as spark_abs
)
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("RateOfChange_MovingAverage") \
    .master("local[*]") \
    .getOrCreate()

data = [
    ("2024-01-01", "East", 10000),
    ("2024-01-02", "East", 10500),
    ("2024-01-03", "East", 10200),
    ("2024-01-04", "East", 10300),
    ("2024-01-05", "East", 10100),
    ("2024-01-06", "East", 5000),   # Sudden drop
    ("2024-01-07", "East", 5200),
    ("2024-01-08", "East", 10000),
    ("2024-01-09", "East", 10500),
    ("2024-01-10", "East", 18000),  # Sudden spike
]

df = spark.createDataFrame(data, ["date", "region", "revenue"])

# Moving average window: previous 3 days (not including current)
ma_window = Window.partitionBy("region") \
    .orderBy("date") \
    .rowsBetween(-3, -1)

THRESHOLD = 25.0

result = df.withColumn(
    "moving_avg_3d",
    spark_round(avg("revenue").over(ma_window), 0)
).withColumn(
    "deviation_pct",
    spark_round(
        (col("revenue") - col("moving_avg_3d")) / col("moving_avg_3d") * 100, 1
    )
).withColumn(
    "alert",
    when(spark_abs(col("deviation_pct")) > THRESHOLD, lit(True))
    .otherwise(lit(False))
).withColumn(
    "alert_type",
    when(col("deviation_pct") > THRESHOLD, lit("SPIKE"))
    .when(col("deviation_pct") < -THRESHOLD, lit("DROP"))
    .otherwise(lit("NORMAL"))
)

print("=== Moving Average Baseline Comparison ===")
result.orderBy("date").show(truncate=False)

print("=== Anomalies Only ===")
result.filter(col("alert") == True).show(truncate=False)

spark.stop()
```

## Method 3: Z-Score Based Anomaly Detection

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, avg, stddev, round as spark_round, when, lit, abs as spark_abs
)
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("RateOfChange_ZScore") \
    .master("local[*]") \
    .getOrCreate()

data = [
    ("2024-01-01", 10000), ("2024-01-02", 10500), ("2024-01-03", 10200),
    ("2024-01-04", 10300), ("2024-01-05", 10100), ("2024-01-06", 5000),
    ("2024-01-07", 10400), ("2024-01-08", 10000), ("2024-01-09", 10500),
    ("2024-01-10", 18000), ("2024-01-11", 10200), ("2024-01-12", 10100),
    ("2024-01-13", 10300), ("2024-01-14", 10000), ("2024-01-15", 10400),
]

df = spark.createDataFrame(data, ["date", "revenue"])

# Rolling window for mean and stddev (previous 7 days)
rolling_window = Window.orderBy("date").rowsBetween(-7, -1)

Z_THRESHOLD = 2.0  # Flag if more than 2 standard deviations away

result = df.withColumn(
    "rolling_mean", spark_round(avg("revenue").over(rolling_window), 0)
).withColumn(
    "rolling_stddev", spark_round(stddev("revenue").over(rolling_window), 0)
).withColumn(
    "z_score",
    spark_round(
        (col("revenue") - col("rolling_mean")) / col("rolling_stddev"), 2
    )
).withColumn(
    "is_anomaly",
    when(spark_abs(col("z_score")) > Z_THRESHOLD, lit(True))
    .otherwise(lit(False))
).withColumn(
    "alert_type",
    when(col("z_score") > Z_THRESHOLD, lit("SPIKE"))
    .when(col("z_score") < -Z_THRESHOLD, lit("DROP"))
    .otherwise(lit("NORMAL"))
)

print("=== Z-Score Based Anomaly Detection ===")
result.orderBy("date").show(truncate=False)

print("=== Detected Anomalies ===")
result.filter(col("is_anomaly") == True).show(truncate=False)

spark.stop()
```

## Method 4: Consecutive Change Detection

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lag, when, lit, sum as spark_sum, round as spark_round
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("RateOfChange_Consecutive") \
    .master("local[*]") \
    .getOrCreate()

data = [
    ("2024-01-01", 10000), ("2024-01-02", 9500),
    ("2024-01-03", 9000),  ("2024-01-04", 8500),  # 3 consecutive drops
    ("2024-01-05", 9000),  ("2024-01-06", 9500),
    ("2024-01-07", 10000), ("2024-01-08", 10500),
    ("2024-01-09", 11000), ("2024-01-10", 11500),  # 3 consecutive rises
]

df = spark.createDataFrame(data, ["date", "revenue"])

window_spec = Window.orderBy("date")

# Detect direction of change
result = df.withColumn(
    "prev_revenue", lag("revenue").over(window_spec)
).withColumn(
    "change", col("revenue") - col("prev_revenue")
).withColumn(
    "direction",
    when(col("change") > 0, lit("UP"))
    .when(col("change") < 0, lit("DOWN"))
    .otherwise(lit("FLAT"))
).withColumn(
    "direction_changed",
    when(
        col("direction") != lag("direction").over(window_spec),
        lit(1)
    ).otherwise(lit(0))
).withColumn(
    # Create groups for consecutive same-direction changes
    "streak_group",
    spark_sum("direction_changed").over(
        Window.orderBy("date").rowsBetween(Window.unboundedPreceding, Window.currentRow)
    )
)

# Count consecutive days in same direction
from pyspark.sql.functions import row_number
streak_window = Window.partitionBy("streak_group").orderBy("date")
result = result.withColumn(
    "consecutive_days", row_number().over(streak_window)
)

print("=== Consecutive Change Detection ===")
result.orderBy("date").show(truncate=False)

# Alert on 3+ consecutive drops
print("=== Consecutive Drop Streaks (3+ days) ===")
result.filter(
    (col("direction") == "DOWN") & (col("consecutive_days") >= 3)
).show(truncate=False)

spark.stop()
```

## Key Concepts

- **Period-over-period**: The simplest approach using `lag()` to compare current vs. previous value. Good for detecting sudden single-period changes.
- **Moving average baseline**: Compares current value to a trailing average. More robust against noise because outliers in the baseline are smoothed out.
- **Z-score method**: Normalizes the deviation by the rolling standard deviation. A z-score > 2 means the current value is more than 2 standard deviations from the rolling mean, indicating an anomaly.
- **Consecutive changes**: Detects sustained trends (e.g., 3+ consecutive days of decline) which may be more concerning than a single spike.

## Interview Tips

- Discuss the choice of threshold: fixed percentage vs. statistical (z-score) vs. business-defined.
- Mention that the choice of lookback window size significantly affects sensitivity. Shorter windows react faster but produce more false positives.
- In production, these checks feed into alerting systems (PagerDuty, Slack) and dashboards.
- For very large time-series datasets, consider using Spark Structured Streaming with watermarks for near-real-time anomaly detection.
