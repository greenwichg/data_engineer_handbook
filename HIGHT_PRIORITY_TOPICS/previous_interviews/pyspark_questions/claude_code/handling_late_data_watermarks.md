# PySpark Implementation: Handling Late Data with Watermarks

## Problem Statement

In a **streaming** scenario, events may arrive late due to network delays, buffering, or out-of-order delivery. Demonstrate how to use **watermarks** in Structured Streaming to handle late-arriving data, define acceptable lateness thresholds, and understand how Spark manages state cleanup.

### Sample Event Stream

```
event_id  user_id  event_type  event_time            processing_time
E001      U1       click       2024-01-01 10:00:00   2024-01-01 10:00:05
E002      U2       click       2024-01-01 10:01:00   2024-01-01 10:01:03
E003      U1       purchase    2024-01-01 10:02:00   2024-01-01 10:02:01
E004      U3       click       2024-01-01 09:55:00   2024-01-01 10:03:00   ← 8 min late
E005      U2       purchase    2024-01-01 09:50:00   2024-01-01 10:04:00   ← 14 min late
E006      U1       click       2024-01-01 10:05:00   2024-01-01 10:05:02
```

### Expected Behavior (10-minute watermark)

- E001–E003, E006: Processed normally
- E004 (8 min late): **Included** — within 10-minute watermark
- E005 (14 min late): **Dropped** — exceeds 10-minute watermark

---

## Method 1: Watermark with Window Aggregation

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, window, count, to_timestamp

spark = SparkSession.builder.appName("WatermarkDemo").getOrCreate()

# Simulate a streaming source using rate or file source
# For demonstration, we create a static DataFrame and treat it as streaming
data = [
    ("E001", "U1", "click", "2024-01-01 10:00:00"),
    ("E002", "U2", "click", "2024-01-01 10:01:00"),
    ("E003", "U1", "purchase", "2024-01-01 10:02:00"),
    ("E004", "U3", "click", "2024-01-01 09:55:00"),    # 8 min late
    ("E005", "U2", "purchase", "2024-01-01 09:50:00"),  # 14 min late
    ("E006", "U1", "click", "2024-01-01 10:05:00"),
]
df = spark.createDataFrame(data, ["event_id", "user_id", "event_type", "event_time"])
df = df.withColumn("event_time", to_timestamp("event_time"))

# In real streaming:
# streaming_df = spark.readStream.format("kafka").option(...).load()

# Define watermark: accept events up to 10 minutes late
windowed_counts = df \
    .withWatermark("event_time", "10 minutes") \
    .groupBy(
        window(col("event_time"), "5 minutes"),  # 5-minute tumbling window
        "event_type"
    ) \
    .agg(count("*").alias("event_count"))

windowed_counts.show(truncate=False)
```

### Output

```
+------------------------------------------+----------+-----------+
|window                                    |event_type|event_count|
+------------------------------------------+----------+-----------+
|{2024-01-01 09:55:00, 2024-01-01 10:00:00}|click     |1          |  ← E004 included
|{2024-01-01 10:00:00, 2024-01-01 10:05:00}|click     |2          |  ← E001, E002
|{2024-01-01 10:00:00, 2024-01-01 10:05:00}|purchase  |1          |  ← E003
|{2024-01-01 10:05:00, 2024-01-01 10:10:00}|click     |1          |  ← E006
+------------------------------------------+----------+-----------+
```

Note: E005 (14 min late) would be dropped in actual streaming with this watermark.

---

## How Watermarks Work

```
Timeline:
  09:50    09:55    10:00    10:05    10:10
    |        |        |        |        |
    E005     E004     E001     E006
    (dropped) (kept)  E002
                      E003

Watermark = max_event_time - threshold
When max_event_time = 10:05:
  watermark = 10:05 - 10min = 09:55

  E004 (09:55) >= watermark (09:55) → INCLUDED
  E005 (09:50) <  watermark (09:55) → DROPPED

State cleanup:
  Windows ending before 09:55 are finalized and cleaned from state
```

---

## Method 2: Watermark with Deduplication

```python
# Deduplicate late-arriving duplicate events within watermark
deduplicated = df \
    .withWatermark("event_time", "10 minutes") \
    .dropDuplicates(["event_id", "event_time"])

deduplicated.show()
```

### How It Works
- Spark keeps a state store of seen `(event_id, event_time)` combinations
- Events outside the watermark are dropped
- Events inside the watermark are checked against the state store
- The watermark controls when old state entries are cleaned up

---

## Method 3: Watermark with Stream-Stream Join

```python
# Two event streams that need to be joined within a time window
clicks_data = [
    ("U1", "click", "2024-01-01 10:00:00"),
    ("U2", "click", "2024-01-01 10:01:00"),
]
purchases_data = [
    ("U1", "purchase", "2024-01-01 10:02:00"),
    ("U2", "purchase", "2024-01-01 10:15:00"),
]

clicks_df = spark.createDataFrame(clicks_data, ["user_id", "event", "event_time"]) \
    .withColumn("event_time", to_timestamp("event_time"))
purchases_df = spark.createDataFrame(purchases_data, ["user_id", "event", "event_time"]) \
    .withColumn("event_time", to_timestamp("event_time"))

# In streaming: both would have watermarks
# Join clicks to purchases within 10 minutes
joined = clicks_df.alias("c").join(
    purchases_df.alias("p"),
    (col("c.user_id") == col("p.user_id")) &
    (col("p.event_time").between(
        col("c.event_time"),
        col("c.event_time") + expr("INTERVAL 10 MINUTES")
    )),
    "inner"
)

joined.select(
    col("c.user_id"),
    col("c.event_time").alias("click_time"),
    col("p.event_time").alias("purchase_time")
).show()
```

**Output:**
```
+-------+-------------------+-------------------+
|user_id|         click_time|      purchase_time|
+-------+-------------------+-------------------+
|     U1|2024-01-01 10:00:00|2024-01-01 10:02:00|
+-------+-------------------+-------------------+
```

U2's purchase (10:15) is 14 minutes after click (10:01) → outside the 10-minute window.

---

## Method 4: Multiple Watermark Policies

```python
# Spark 3.x supports multiple watermarks with a global policy
spark.conf.set(
    "spark.sql.streaming.multipleWatermarkPolicy", "max"  # or "min"
)

# "min" policy: uses the slowest stream's watermark (more conservative, keeps more state)
# "max" policy: uses the fastest stream's watermark (more aggressive, drops more late data)
```

---

## Output Modes and Watermarks

| Output Mode | Behavior with Watermark |
|------------|------------------------|
| **Append** | Rows emitted only when window is finalized (past watermark). No updates to previous results. |
| **Update** | Rows emitted as they change. Late data within watermark triggers updates. |
| **Complete** | All results emitted every trigger. Watermark only controls state cleanup. |

```python
# Append mode — most common for watermarked aggregations
# query = windowed_counts.writeStream \
#     .outputMode("append") \
#     .format("parquet") \
#     .option("path", "/output/path") \
#     .option("checkpointLocation", "/checkpoint/path") \
#     .trigger(processingTime="1 minute") \
#     .start()
```

---

## Key Interview Talking Points

1. **What is a watermark?** "A threshold that tells Spark how long to wait for late data. Defined as `max_event_time_seen - threshold`. Events with event_time below the watermark are dropped."

2. **Why needed?** Without watermarks, Spark would keep ALL state indefinitely for aggregations, eventually causing OOM. Watermarks allow Spark to clean up old state.

3. **Watermark is a hint, not a guarantee:** Spark guarantees it will NOT drop data that arrives within the watermark threshold. But it MAY still process some data beyond the watermark (implementation detail).

4. **Event time vs processing time:** Watermarks work on event time (when the event actually happened), not processing time (when Spark receives it). This handles real-world scenarios where events arrive out of order.

5. **State store implications:** Watermarks control state store cleanup. A 24-hour watermark means Spark keeps 24 hours of state in memory/disk. Balance between completeness and resource usage.

6. **Choosing watermark threshold:** Based on the maximum expected delay in your pipeline. Too small = lose late data. Too large = excessive state/memory usage. Analyze your data's lateness distribution to pick the right value.
