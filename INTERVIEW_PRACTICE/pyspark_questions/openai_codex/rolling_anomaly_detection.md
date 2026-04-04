# PySpark Implementation: Time-Series Anomaly Detection with Rolling Statistics

## Problem Statement 

For each device, compute rolling mean and standard deviation of metric values over the last 1 hour and flag anomalies where:
`abs(value - rolling_mean) > 3 * rolling_stddev`.

### Sample Input

| device_id | event_time           | temperature |
|-----------|----------------------|-------------|
| D1        | 2025-01-15 10:00:00  | 20.0        |
| D1        | 2025-01-15 10:10:00  | 21.2        |
| D1        | 2025-01-15 10:20:00  | 39.0        |

---

## PySpark Code Solution

```python
from pyspark.sql import functions as F
from pyspark.sql.window import Window

w = Window.partitionBy("device_id").orderBy(F.col("event_time").cast("long")).rangeBetween(-3600, 0)

out = readings.withColumn("rolling_mean", F.avg("temperature").over(w))     .withColumn("rolling_std", F.stddev_pop("temperature").over(w))     .withColumn(
        "is_anomaly",
        F.when(F.col("rolling_std") > 0,
               F.abs(F.col("temperature") - F.col("rolling_mean")) > 3 * F.col("rolling_std")
        ).otherwise(F.lit(False))
    )
```
