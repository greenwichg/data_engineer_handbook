# PySpark Implementation: Attribution Modeling

## Problem Statement

Marketing attribution determines which touchpoints (channels, campaigns, ads) deserve credit for a conversion event (purchase, signup). Common models include first-touch (credit to the first interaction), last-touch (credit to the last interaction before conversion), and multi-touch (credit distributed across all touchpoints). Given a dataset of user marketing touchpoints and conversion events, implement these attribution models. This is a frequently asked interview question at adtech, e-commerce, and SaaS companies.

### Sample Data

```
user_id | timestamp           | channel        | event_type
U001    | 2024-01-01 10:00:00 | Google Ads     | click
U001    | 2024-01-03 14:00:00 | Email          | click
U001    | 2024-01-05 09:00:00 | Organic Search | click
U001    | 2024-01-05 10:00:00 | NULL           | purchase
U002    | 2024-01-02 11:00:00 | Facebook Ads   | click
U002    | 2024-01-04 16:00:00 | Google Ads     | click
U002    | 2024-01-06 12:00:00 | NULL           | purchase
U003    | 2024-01-01 09:00:00 | Email          | click
U003    | 2024-01-07 15:00:00 | Organic Search | click
```

### Expected Output (First-Touch Attribution)

| channel        | conversions | revenue_attributed |
|----------------|-------------|--------------------|
| Google Ads     | 1           | 100.00             |
| Facebook Ads   | 1           | 150.00             |

### Expected Output (Last-Touch Attribution)

| channel        | conversions | revenue_attributed |
|----------------|-------------|--------------------|
| Organic Search | 1           | 100.00             |
| Google Ads     | 1           | 150.00             |

---

## Method 1: First-Touch and Last-Touch Attribution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, first, last, sum as spark_sum, count,
    when, row_number, round as spark_round
)
from pyspark.sql.window import Window

# Initialize SparkSession
spark = SparkSession.builder \
    .appName("AttributionModeling") \
    .master("local[*]") \
    .getOrCreate()

# Create touchpoint data
touchpoint_data = [
    ("U001", "2024-01-01 10:00:00", "Google Ads",     "click"),
    ("U001", "2024-01-03 14:00:00", "Email",          "click"),
    ("U001", "2024-01-05 09:00:00", "Organic Search", "click"),
    ("U001", "2024-01-05 10:00:00", None,             "purchase"),
    ("U002", "2024-01-02 11:00:00", "Facebook Ads",   "click"),
    ("U002", "2024-01-04 16:00:00", "Google Ads",     "click"),
    ("U002", "2024-01-06 12:00:00", None,             "purchase"),
    ("U003", "2024-01-01 09:00:00", "Email",          "click"),
    ("U003", "2024-01-07 15:00:00", "Organic Search", "click"),
    # U003 has no purchase - should not be attributed
]

df = spark.createDataFrame(
    touchpoint_data,
    ["user_id", "timestamp", "channel", "event_type"]
)

# Conversion data with revenue
conversion_data = [
    ("U001", "2024-01-05 10:00:00", 100.00),
    ("U002", "2024-01-06 12:00:00", 150.00),
]

conversions = spark.createDataFrame(
    conversion_data,
    ["user_id", "conversion_time", "revenue"]
)

# Separate clicks from conversions
clicks = df.filter(col("event_type") == "click")

# Only consider users who converted
converting_users = conversions.select("user_id").distinct()
relevant_clicks = clicks.join(converting_users, "user_id", "inner")

# Window for ordering touchpoints per user
user_window = Window.partitionBy("user_id").orderBy("timestamp")
user_window_desc = Window.partitionBy("user_id").orderBy(col("timestamp").desc())

# First-touch: first click per user
first_touch = relevant_clicks.withColumn(
    "rn", row_number().over(user_window)
).filter(col("rn") == 1).select(
    "user_id", col("channel").alias("first_touch_channel")
)

# Last-touch: last click per user before conversion
last_touch = relevant_clicks.withColumn(
    "rn", row_number().over(user_window_desc)
).filter(col("rn") == 1).select(
    "user_id", col("channel").alias("last_touch_channel")
)

# Join with conversions
attributed = conversions \
    .join(first_touch, "user_id", "left") \
    .join(last_touch, "user_id", "left")

print("=== Per-User Attribution ===")
attributed.show(truncate=False)

# Aggregate by channel
print("=== First-Touch Attribution Summary ===")
attributed.groupBy("first_touch_channel").agg(
    count("*").alias("conversions"),
    spark_round(spark_sum("revenue"), 2).alias("revenue_attributed")
).show(truncate=False)

print("=== Last-Touch Attribution Summary ===")
attributed.groupBy("last_touch_channel").agg(
    count("*").alias("conversions"),
    spark_round(spark_sum("revenue"), 2).alias("revenue_attributed")
).show(truncate=False)

spark.stop()
```

## Method 2: Linear Multi-Touch Attribution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, count, sum as spark_sum, round as spark_round,
    row_number, lit
)
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("Attribution_Linear") \
    .master("local[*]") \
    .getOrCreate()

touchpoint_data = [
    ("U001", "2024-01-01 10:00:00", "Google Ads",     "click"),
    ("U001", "2024-01-03 14:00:00", "Email",          "click"),
    ("U001", "2024-01-05 09:00:00", "Organic Search", "click"),
    ("U002", "2024-01-02 11:00:00", "Facebook Ads",   "click"),
    ("U002", "2024-01-04 16:00:00", "Google Ads",     "click"),
]

clicks = spark.createDataFrame(
    touchpoint_data,
    ["user_id", "timestamp", "channel", "event_type"]
)

conversions = spark.createDataFrame([
    ("U001", 100.00),
    ("U002", 150.00),
], ["user_id", "revenue"])

# Count touchpoints per user
touchpoint_counts = clicks.groupBy("user_id").agg(
    count("*").alias("num_touchpoints")
)

# Join to get credit per touchpoint
linear = clicks.join(touchpoint_counts, "user_id") \
    .join(conversions, "user_id") \
    .withColumn(
        "credit",
        spark_round(lit(1.0) / col("num_touchpoints"), 4)
    ).withColumn(
        "revenue_credit",
        spark_round(col("revenue") / col("num_touchpoints"), 2)
    )

print("=== Linear Attribution (Equal Credit) ===")
linear.select(
    "user_id", "channel", "credit", "revenue_credit"
).show(truncate=False)

# Aggregate by channel
print("=== Channel Summary (Linear) ===")
linear.groupBy("channel").agg(
    spark_round(spark_sum("credit"), 2).alias("total_credit"),
    spark_round(spark_sum("revenue_credit"), 2).alias("total_revenue")
).orderBy(col("total_revenue").desc()).show(truncate=False)

spark.stop()
```

## Method 3: Time-Decay Attribution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, count, sum as spark_sum, round as spark_round,
    datediff, to_timestamp, exp, lit, max as spark_max
)
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("Attribution_TimeDecay") \
    .master("local[*]") \
    .getOrCreate()

touchpoint_data = [
    ("U001", "2024-01-01 10:00:00", "Google Ads"),
    ("U001", "2024-01-03 14:00:00", "Email"),
    ("U001", "2024-01-05 09:00:00", "Organic Search"),
    ("U002", "2024-01-02 11:00:00", "Facebook Ads"),
    ("U002", "2024-01-04 16:00:00", "Google Ads"),
]

clicks = spark.createDataFrame(
    touchpoint_data,
    ["user_id", "timestamp", "channel"]
).withColumn("timestamp", to_timestamp("timestamp"))

conversions = spark.createDataFrame([
    ("U001", "2024-01-05 10:00:00", 100.00),
    ("U002", "2024-01-06 12:00:00", 150.00),
], ["user_id", "conversion_time", "revenue"]
).withColumn("conversion_time", to_timestamp("conversion_time"))

# Join clicks with conversions
joined = clicks.join(conversions, "user_id")

# Calculate days before conversion for each touchpoint
joined = joined.withColumn(
    "days_before_conversion",
    datediff(col("conversion_time"), col("timestamp")).cast("double")
)

# Time-decay weight: more recent touchpoints get more credit
# Using exponential decay with half-life of 7 days
HALF_LIFE = 7.0
joined = joined.withColumn(
    "raw_weight",
    exp(-0.693 * col("days_before_conversion") / lit(HALF_LIFE))
)

# Normalize weights per user so they sum to 1
user_weight_sum = Window.partitionBy("user_id")
joined = joined.withColumn(
    "weight_sum", spark_sum("raw_weight").over(user_weight_sum)
).withColumn(
    "normalized_weight",
    spark_round(col("raw_weight") / col("weight_sum"), 4)
).withColumn(
    "revenue_credit",
    spark_round(col("revenue") * col("normalized_weight"), 2)
)

print("=== Time-Decay Attribution ===")
joined.select(
    "user_id", "channel", "days_before_conversion",
    "normalized_weight", "revenue_credit"
).orderBy("user_id", "timestamp").show(truncate=False)

# Channel summary
print("=== Channel Summary (Time-Decay) ===")
joined.groupBy("channel").agg(
    spark_round(spark_sum("normalized_weight"), 2).alias("total_credit"),
    spark_round(spark_sum("revenue_credit"), 2).alias("total_revenue")
).orderBy(col("total_revenue").desc()).show(truncate=False)

spark.stop()
```

## Method 4: Position-Based (U-Shaped) Attribution

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, count, sum as spark_sum, round as spark_round,
    row_number, when, lit
)
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("Attribution_PositionBased") \
    .master("local[*]") \
    .getOrCreate()

touchpoint_data = [
    ("U001", "2024-01-01 10:00:00", "Google Ads"),
    ("U001", "2024-01-03 14:00:00", "Email"),
    ("U001", "2024-01-04 11:00:00", "Social Media"),
    ("U001", "2024-01-05 09:00:00", "Organic Search"),
    ("U002", "2024-01-02 11:00:00", "Facebook Ads"),
    ("U002", "2024-01-04 16:00:00", "Google Ads"),
]

clicks = spark.createDataFrame(touchpoint_data, ["user_id", "timestamp", "channel"])

conversions = spark.createDataFrame([
    ("U001", 100.00),
    ("U002", 150.00),
], ["user_id", "revenue"])

# Position-based: 40% to first, 40% to last, 20% split among middle
window_asc = Window.partitionBy("user_id").orderBy("timestamp")
window_desc = Window.partitionBy("user_id").orderBy(col("timestamp").desc())

touchpoint_counts = clicks.groupBy("user_id").agg(
    count("*").alias("total_touchpoints")
)

positioned = clicks.join(touchpoint_counts, "user_id") \
    .withColumn("pos_asc", row_number().over(window_asc)) \
    .withColumn("pos_desc", row_number().over(window_desc))

# Assign weights
attributed = positioned.join(conversions, "user_id").withColumn(
    "weight",
    when(col("total_touchpoints") == 1, lit(1.0))
    .when(col("total_touchpoints") == 2,
          when(col("pos_asc") == 1, lit(0.5)).otherwise(lit(0.5)))
    .when(col("pos_asc") == 1, lit(0.4))                    # First touch: 40%
    .when(col("pos_desc") == 1, lit(0.4))                   # Last touch: 40%
    .otherwise(lit(0.2) / (col("total_touchpoints") - 2))   # Middle: split 20%
).withColumn(
    "revenue_credit",
    spark_round(col("revenue") * col("weight"), 2)
)

print("=== Position-Based (U-Shaped) Attribution ===")
attributed.select(
    "user_id", "channel", "pos_asc", "total_touchpoints",
    "weight", "revenue_credit"
).orderBy("user_id", "pos_asc").show(truncate=False)

# Channel summary
print("=== Channel Summary (Position-Based) ===")
attributed.groupBy("channel").agg(
    spark_round(spark_sum("weight"), 2).alias("total_credit"),
    spark_round(spark_sum("revenue_credit"), 2).alias("total_revenue")
).orderBy(col("total_revenue").desc()).show(truncate=False)

spark.stop()
```

## Key Concepts

- **First-touch**: Credits the channel that first brought the user. Good for understanding awareness drivers.
- **Last-touch**: Credits the channel that directly preceded conversion. Good for understanding closing channels.
- **Linear**: Equal credit to all touchpoints. Simple but does not account for position or timing.
- **Time-decay**: More credit to touchpoints closer to conversion. Uses exponential decay with a configurable half-life.
- **Position-based (U-shaped)**: 40/20/40 split giving more credit to first and last touchpoints.

## Interview Tips

- Discuss the **conversion window**: How far back should you look for touchpoints? Common choices are 7, 14, or 30 days.
- Mention that **data-driven attribution** (e.g., Shapley values or Markov chains) is the gold standard but computationally expensive.
- Talk about **cross-device tracking** challenges: the same user may interact via mobile and desktop.
- Explain that attribution results vary significantly by model, which is why companies often run multiple models in parallel for comparison.
- In production, attribution pipelines often run as batch jobs (daily/weekly) with results feeding into BI dashboards and campaign optimization tools.
