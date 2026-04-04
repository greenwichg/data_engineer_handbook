# PySpark Implementation: Outlier Detection

## Problem Statement

Outlier detection is a critical data quality and analytics task where you identify data points that significantly deviate from the majority of observations. In data engineering interviews, you may be asked to implement outlier detection using statistical methods like IQR (Interquartile Range), Z-score, or standard deviation in PySpark. This tests your knowledge of window functions, aggregate statistics, and how to handle data quality at scale.

Given a dataset of sensor readings (or any numerical data), detect outliers using multiple statistical methods and flag or filter them accordingly.

### Sample Data

```
sensor_id | timestamp           | reading
--------- | ------------------- | -------
A         | 2024-01-01 08:00:00 | 22.1
A         | 2024-01-01 09:00:00 | 23.4
A         | 2024-01-01 10:00:00 | 21.8
A         | 2024-01-01 11:00:00 | 98.5
A         | 2024-01-01 12:00:00 | 22.9
A         | 2024-01-01 13:00:00 | 23.1
B         | 2024-01-01 08:00:00 | 55.2
B         | 2024-01-01 09:00:00 | 56.8
B         | 2024-01-01 10:00:00 | 54.1
B         | 2024-01-01 11:00:00 | 2.0
B         | 2024-01-01 12:00:00 | 55.9
B         | 2024-01-01 13:00:00 | 57.3
```

### Expected Output (IQR Method)

| sensor_id | timestamp           | reading | is_outlier |
|-----------|---------------------|---------|------------|
| A         | 2024-01-01 11:00:00 | 98.5    | true       |
| B         | 2024-01-01 11:00:00 | 2.0     | true       |

---

## Method 1: IQR (Interquartile Range) Method

The IQR method flags values below Q1 - 1.5*IQR or above Q3 + 1.5*IQR.

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, percentile_approx, when, lit
from pyspark.sql.window import Window

# Initialize SparkSession
spark = SparkSession.builder \
    .appName("Outlier Detection - IQR Method") \
    .master("local[*]") \
    .getOrCreate()

# Create sample data
data = [
    ("A", "2024-01-01 08:00:00", 22.1),
    ("A", "2024-01-01 09:00:00", 23.4),
    ("A", "2024-01-01 10:00:00", 21.8),
    ("A", "2024-01-01 11:00:00", 98.5),
    ("A", "2024-01-01 12:00:00", 22.9),
    ("A", "2024-01-01 13:00:00", 23.1),
    ("B", "2024-01-01 08:00:00", 55.2),
    ("B", "2024-01-01 09:00:00", 56.8),
    ("B", "2024-01-01 10:00:00", 54.1),
    ("B", "2024-01-01 11:00:00", 2.0),
    ("B", "2024-01-01 12:00:00", 55.9),
    ("B", "2024-01-01 13:00:00", 57.3),
]

df = spark.createDataFrame(data, ["sensor_id", "timestamp", "reading"])

# Compute Q1, Q3, IQR per sensor using groupBy + percentile_approx
from pyspark.sql.functions import expr

stats_df = df.groupBy("sensor_id").agg(
    percentile_approx("reading", 0.25).alias("q1"),
    percentile_approx("reading", 0.75).alias("q3")
).withColumn("iqr", col("q3") - col("q1")) \
 .withColumn("lower_bound", col("q1") - 1.5 * col("iqr")) \
 .withColumn("upper_bound", col("q3") + 1.5 * col("iqr"))

print("=== IQR Statistics per Sensor ===")
stats_df.show(truncate=False)

# Join back and flag outliers
result_iqr = df.join(stats_df, on="sensor_id") \
    .withColumn("is_outlier",
        when((col("reading") < col("lower_bound")) | (col("reading") > col("upper_bound")),
             lit(True)).otherwise(lit(False))
    )

print("=== All Records with Outlier Flag (IQR Method) ===")
result_iqr.select("sensor_id", "timestamp", "reading", "lower_bound", "upper_bound", "is_outlier") \
    .orderBy("sensor_id", "timestamp").show(truncate=False)

print("=== Outliers Only ===")
result_iqr.filter(col("is_outlier") == True) \
    .select("sensor_id", "timestamp", "reading") \
    .show(truncate=False)
```

## Method 2: Z-Score Method

The Z-score method flags values where the absolute Z-score exceeds a threshold (commonly 2 or 3).

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, avg, stddev, abs as spark_abs, when, lit
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("Outlier Detection - Z-Score Method") \
    .master("local[*]") \
    .getOrCreate()

data = [
    ("A", "2024-01-01 08:00:00", 22.1),
    ("A", "2024-01-01 09:00:00", 23.4),
    ("A", "2024-01-01 10:00:00", 21.8),
    ("A", "2024-01-01 11:00:00", 98.5),
    ("A", "2024-01-01 12:00:00", 22.9),
    ("A", "2024-01-01 13:00:00", 23.1),
    ("B", "2024-01-01 08:00:00", 55.2),
    ("B", "2024-01-01 09:00:00", 56.8),
    ("B", "2024-01-01 10:00:00", 54.1),
    ("B", "2024-01-01 11:00:00", 2.0),
    ("B", "2024-01-01 12:00:00", 55.9),
    ("B", "2024-01-01 13:00:00", 57.3),
]

df = spark.createDataFrame(data, ["sensor_id", "timestamp", "reading"])

# Compute mean and stddev per sensor group using window functions
w = Window.partitionBy("sensor_id")

df_with_stats = df \
    .withColumn("mean_reading", avg("reading").over(w)) \
    .withColumn("stddev_reading", stddev("reading").over(w))

# Compute Z-score: (value - mean) / stddev
Z_THRESHOLD = 2.0

df_with_zscore = df_with_stats \
    .withColumn("z_score",
        (col("reading") - col("mean_reading")) / col("stddev_reading")
    ) \
    .withColumn("abs_z_score", spark_abs(col("z_score"))) \
    .withColumn("is_outlier",
        when(col("abs_z_score") > Z_THRESHOLD, lit(True)).otherwise(lit(False))
    )

print("=== All Records with Z-Score (threshold = 2.0) ===")
df_with_zscore.select("sensor_id", "timestamp", "reading", "mean_reading",
                       "stddev_reading", "z_score", "is_outlier") \
    .orderBy("sensor_id", "timestamp").show(truncate=False)

print("=== Outliers Only (Z-Score Method) ===")
df_with_zscore.filter(col("is_outlier") == True) \
    .select("sensor_id", "timestamp", "reading", "z_score") \
    .show(truncate=False)
```

## Method 3: Standard Deviation Method (Mean +/- N*StdDev)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, avg, stddev, when, lit
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("Outlier Detection - StdDev Method") \
    .master("local[*]") \
    .getOrCreate()

data = [
    ("A", "2024-01-01 08:00:00", 22.1),
    ("A", "2024-01-01 09:00:00", 23.4),
    ("A", "2024-01-01 10:00:00", 21.8),
    ("A", "2024-01-01 11:00:00", 98.5),
    ("A", "2024-01-01 12:00:00", 22.9),
    ("A", "2024-01-01 13:00:00", 23.1),
    ("B", "2024-01-01 08:00:00", 55.2),
    ("B", "2024-01-01 09:00:00", 56.8),
    ("B", "2024-01-01 10:00:00", 54.1),
    ("B", "2024-01-01 11:00:00", 2.0),
    ("B", "2024-01-01 12:00:00", 55.9),
    ("B", "2024-01-01 13:00:00", 57.3),
]

df = spark.createDataFrame(data, ["sensor_id", "timestamp", "reading"])

N_STDDEV = 2  # Number of standard deviations from mean

# Compute stats per group
stats = df.groupBy("sensor_id").agg(
    avg("reading").alias("mean_val"),
    stddev("reading").alias("stddev_val")
).withColumn("lower_bound", col("mean_val") - N_STDDEV * col("stddev_val")) \
 .withColumn("upper_bound", col("mean_val") + N_STDDEV * col("stddev_val"))

# Join and flag
result = df.join(stats, on="sensor_id") \
    .withColumn("is_outlier",
        when((col("reading") < col("lower_bound")) | (col("reading") > col("upper_bound")),
             lit(True)).otherwise(lit(False))
    )

print("=== StdDev Method Results (N=2) ===")
result.select("sensor_id", "timestamp", "reading", "lower_bound", "upper_bound", "is_outlier") \
    .orderBy("sensor_id", "timestamp").show(truncate=False)

spark.stop()
```

## Key Concepts

- **IQR Method**: Robust to extreme outliers since quartiles are resistant to skew. Best for non-normally distributed data. The 1.5x multiplier is standard but can be adjusted.
- **Z-Score Method**: Assumes approximately normal distribution. Threshold of 2 catches ~5% tails; threshold of 3 catches ~0.3% tails.
- **StdDev Method**: Similar to Z-score but expressed differently. Easy to understand and explain in interviews.
- **Window functions** (`partitionBy`) let you compute per-group statistics without a separate groupBy + join step.
- **`percentile_approx`** is used because exact percentiles require a full sort, which is expensive at scale. The approximation is accurate enough for outlier detection.
- **Choosing a method**: IQR is preferred for skewed data; Z-score/StdDev for roughly normal distributions. In interviews, mention the assumptions of each.

## Interview Tips

- Always clarify whether outlier detection should be global or per-group (e.g., per sensor, per category).
- Mention that outliers may be valid data (e.g., a legitimate spike) vs. data quality issues — the business context determines how to handle them.
- Discuss options for handling outliers: flag, filter, cap/floor (winsorize), or replace with median/mean.
- At scale, `percentile_approx` is preferred over exact percentile computations.
