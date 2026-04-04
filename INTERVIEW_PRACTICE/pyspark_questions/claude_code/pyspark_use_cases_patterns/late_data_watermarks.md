# PySpark Implementation: Handling Late-Arriving Data with Watermarks

## Problem Statement

In a **Structured Streaming** application, events may arrive after their expected processing time due to network delays, buffering, or system failures. Demonstrate how to use **watermarks** to handle late-arriving data, control state cleanup, and define acceptable lateness thresholds. This is a critical question for data engineering roles involving real-time pipelines.

### Scenario

You are processing a stream of **e-commerce click events**. Each event has an `event_time` (when the click actually happened) and arrives at the system at `processing_time` (when Spark receives it). Some events arrive late — you need to count clicks per 10-minute window while tolerating up to 15 minutes of lateness.

### Sample Data

**Click events stream (simulated with static data for testing):**
```
event_id  user_id  event_time            page
E001      U001     2025-01-15 10:00:00   /home
E002      U002     2025-01-15 10:02:00   /products
E003      U001     2025-01-15 10:05:00   /cart
E004      U003     2025-01-15 10:12:00   /home
E005      U002     2025-01-15 10:18:00   /checkout
E006      U001     2025-01-15 09:55:00   /home        <-- late by ~25 min (arrives at 10:20)
E007      U003     2025-01-15 10:08:00   /products    <-- late by ~12 min (arrives at 10:20)
E008      U002     2025-01-15 10:22:00   /confirmation
```

### Expected Behavior

- Events within the watermark threshold (15 min late) are **included** in window aggregations.
- Events beyond the watermark threshold are **dropped** (e.g., E006 with event_time 09:55 arriving when max event_time is 10:22 — it is 27 minutes late, exceeding 15-minute watermark).
- State for completed windows is cleaned up after the watermark passes.

---

## Method 1: Watermarked Window Aggregation (Batch Simulation)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, window, count, to_timestamp, lit, current_timestamp
)
from pyspark.sql.types import (
    StructType, StructField, StringType, TimestampType
)

# Initialize Spark session
spark = SparkSession.builder.appName("LateDataWatermarks").getOrCreate()

# Simulate click events with event timestamps
click_data = [
    ("E001", "U001", "2025-01-15 10:00:00", "/home"),
    ("E002", "U002", "2025-01-15 10:02:00", "/products"),
    ("E003", "U001", "2025-01-15 10:05:00", "/cart"),
    ("E004", "U003", "2025-01-15 10:12:00", "/home"),
    ("E005", "U002", "2025-01-15 10:18:00", "/checkout"),
    ("E006", "U001", "2025-01-15 09:55:00", "/home"),       # Late event
    ("E007", "U003", "2025-01-15 10:08:00", "/products"),    # Late event (within threshold)
    ("E008", "U002", "2025-01-15 10:22:00", "/confirmation"),
]

click_df = spark.createDataFrame(click_data, ["event_id", "user_id", "event_time", "page"])
click_df = click_df.withColumn("event_time", to_timestamp("event_time"))

# Step 1: Apply watermark on the event_time column
# This tells Spark: "accept events up to 15 minutes late"
watermarked_df = click_df.withWatermark("event_time", "15 minutes")

# Step 2: Window aggregation — count clicks per 10-minute window
windowed_counts = watermarked_df.groupBy(
    window(col("event_time"), "10 minutes")
).agg(
    count("event_id").alias("click_count")
)

# Step 3: Display results
windowed_counts.select(
    col("window.start").alias("window_start"),
    col("window.end").alias("window_end"),
    "click_count"
).orderBy("window_start").show(truncate=False)
```

### Step-by-Step Explanation

#### Step 1: withWatermark("event_time", "15 minutes")

- **What it does:** Declares that Spark should track the maximum observed `event_time` and use it to determine which late events to accept.
- **Watermark formula:** `watermark = max(event_time) - threshold`
- **Example:** If max event_time seen so far is `10:22`, then watermark = `10:22 - 15 min = 10:07`. Events with event_time before `10:07` are dropped.

#### Step 2: Window aggregation

- **10-minute tumbling windows:** `[10:00-10:10)`, `[10:10-10:20)`, `[10:20-10:30)`
- Events are placed into windows based on their `event_time`, not arrival time.

#### Step 3: Expected Output

| window_start         | window_end           | click_count |
|---------------------|---------------------|-------------|
| 2025-01-15 09:50:00 | 2025-01-15 10:00:00 | 1           |
| 2025-01-15 10:00:00 | 2025-01-15 10:10:00 | 4           |
| 2025-01-15 10:10:00 | 2025-01-15 10:20:00 | 2           |
| 2025-01-15 10:20:00 | 2025-01-15 10:30:00 | 1           |

**Note:** In batch mode, all data is processed at once so the watermark may not drop events. The dropping behavior is enforced in streaming mode where data arrives incrementally.

---

## Method 2: Structured Streaming with Watermarks (Full Streaming Example)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, window, count, from_json, to_timestamp
)
from pyspark.sql.types import (
    StructType, StructField, StringType, TimestampType
)

spark = SparkSession.builder.appName("StreamingWatermark").getOrCreate()

# Define schema for incoming JSON events
event_schema = StructType([
    StructField("event_id", StringType()),
    StructField("user_id", StringType()),
    StructField("event_time", StringType()),
    StructField("page", StringType())
])

# Step 1: Read from a streaming source (e.g., Kafka)
raw_stream = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "localhost:9092") \
    .option("subscribe", "click_events") \
    .load()

# Step 2: Parse JSON and apply watermark
parsed_stream = raw_stream.select(
    from_json(col("value").cast("string"), event_schema).alias("data")
).select("data.*") \
    .withColumn("event_time", to_timestamp("event_time")) \
    .withWatermark("event_time", "15 minutes")

# Step 3: Windowed aggregation with page breakdown
windowed_counts = parsed_stream.groupBy(
    window(col("event_time"), "10 minutes"),
    col("page")
).agg(
    count("event_id").alias("click_count")
)

# Step 4: Write to output sink
query = windowed_counts.writeStream \
    .outputMode("update") \
    .format("console") \
    .option("truncate", "false") \
    .trigger(processingTime="30 seconds") \
    .start()

query.awaitTermination()
```

### Output Modes with Watermarks

```
outputMode("update"):
  - Emits only rows that changed since last trigger
  - Works with watermarks — most efficient for dashboards

outputMode("append"):
  - Emits rows ONLY after the watermark passes their window
  - Guarantees no future updates — best for writing to storage
  - Row appears only when Spark is certain no more late data can arrive

outputMode("complete"):
  - Emits entire result table every trigger
  - Does NOT benefit from watermarks (keeps all state)
  - Use only for small result sets
```

---

## Method 3: Watermark with Streaming Deduplication

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_timestamp

spark = SparkSession.builder.appName("StreamingDedup").getOrCreate()

# Duplicate events are common in streaming (at-least-once delivery)
events_with_dupes = [
    ("E001", "U001", "2025-01-15 10:00:00", "/home"),
    ("E001", "U001", "2025-01-15 10:00:00", "/home"),      # Duplicate
    ("E002", "U002", "2025-01-15 10:02:00", "/products"),
    ("E002", "U002", "2025-01-15 10:02:00", "/products"),   # Duplicate
    ("E003", "U001", "2025-01-15 10:05:00", "/cart"),
]

events_df = spark.createDataFrame(
    events_with_dupes, ["event_id", "user_id", "event_time", "page"]
).withColumn("event_time", to_timestamp("event_time"))

# Step 1: Watermark + dropDuplicates
# Watermark limits how long Spark remembers event_ids for dedup
deduped = events_df \
    .withWatermark("event_time", "15 minutes") \
    .dropDuplicates(["event_id", "event_time"])

deduped.show(truncate=False)
```

### Output

| event_id | user_id | event_time          | page      |
|----------|---------|---------------------|-----------|
| E001     | U001    | 2025-01-15 10:00:00 | /home     |
| E002     | U002    | 2025-01-15 10:02:00 | /products |
| E003     | U001    | 2025-01-15 10:05:00 | /cart     |

**Key insight:** Without a watermark, `dropDuplicates` in streaming mode would keep state forever (unbounded memory). The watermark lets Spark drop dedup state for events older than the threshold.

---

## Method 4: Sliding Windows with Watermarks

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, window, count, to_timestamp

spark = SparkSession.builder.appName("SlidingWindowWatermark").getOrCreate()

click_data = [
    ("E001", "U001", "2025-01-15 10:00:00", "/home"),
    ("E002", "U002", "2025-01-15 10:02:00", "/products"),
    ("E003", "U001", "2025-01-15 10:05:00", "/cart"),
    ("E004", "U003", "2025-01-15 10:08:00", "/home"),
    ("E005", "U002", "2025-01-15 10:12:00", "/checkout"),
    ("E006", "U001", "2025-01-15 10:15:00", "/confirmation"),
]

click_df = spark.createDataFrame(click_data, ["event_id", "user_id", "event_time", "page"])
click_df = click_df.withColumn("event_time", to_timestamp("event_time"))

# Sliding window: 10-minute window, sliding every 5 minutes
# With 15-minute watermark for late data
result = click_df \
    .withWatermark("event_time", "15 minutes") \
    .groupBy(
        window(col("event_time"), "10 minutes", "5 minutes")  # window size, slide interval
    ).agg(
        count("event_id").alias("click_count")
    )

result.select(
    col("window.start").alias("window_start"),
    col("window.end").alias("window_end"),
    "click_count"
).orderBy("window_start").show(truncate=False)
```

### Output

| window_start         | window_end           | click_count |
|---------------------|---------------------|-------------|
| 2025-01-15 09:55:00 | 2025-01-15 10:05:00 | 2           |
| 2025-01-15 10:00:00 | 2025-01-15 10:10:00 | 4           |
| 2025-01-15 10:05:00 | 2025-01-15 10:15:00 | 3           |
| 2025-01-15 10:10:00 | 2025-01-15 10:20:00 | 2           |
| 2025-01-15 10:15:00 | 2025-01-15 10:25:00 | 1           |

**Sliding windows** create overlapping windows. Each event can belong to multiple windows. The watermark still controls late data acceptance and state cleanup.

---

## How Watermarks Work Internally

```
Timeline of events arriving at Spark:

Trigger 1 (processing_time = 10:10):
  Receives: E001(10:00), E002(10:02), E003(10:05)
  Max event_time = 10:05
  Watermark = 10:05 - 15 min = 09:50
  → All events accepted (all >= 09:50)

Trigger 2 (processing_time = 10:20):
  Receives: E004(10:12), E005(10:18), E006(09:55), E007(10:08)
  Max event_time = 10:18
  Watermark = 10:18 - 15 min = 10:03
  → E004, E005, E007 accepted (>= 10:03)
  → E006 (09:55) DROPPED (< 10:03 watermark)

Trigger 3 (processing_time = 10:30):
  Receives: E008(10:22)
  Max event_time = 10:22
  Watermark = 10:22 - 15 min = 10:07
  → State for windows ending before 10:07 is CLEANED UP
  → Window [09:50-10:00) state is released from memory
```

---

## Watermark Guarantees and Limitations

| Aspect | Detail |
|--------|--------|
| **Guarantee** | Events arriving within the watermark threshold are NEVER dropped |
| **Best-effort** | Events beyond the threshold MAY be dropped (not guaranteed to be dropped in all cases) |
| **Monotonic** | The watermark only moves forward — it never goes back |
| **Per-partition** | Spark tracks max event_time across all partitions globally |
| **State cleanup** | Spark only cleans up state for windows that are fully past the watermark |

---

## Choosing the Right Watermark Threshold

```
Too short (e.g., "1 minute"):
  ✗ Drops many legitimate late events
  ✓ Low memory usage (fast state cleanup)
  → Use when: Lateness is minimal, memory constrained

Too long (e.g., "24 hours"):
  ✓ Accepts almost all late events
  ✗ High memory usage (state kept for 24 hours)
  → Use when: Completeness is critical, resources available

Just right (e.g., "15 minutes"):
  ✓ Balances completeness vs resource usage
  → Determine by analyzing your actual data lateness distribution
```

### How to Determine the Right Threshold

```python
# Analyze lateness in historical data
from pyspark.sql.functions import unix_timestamp

# Compare event_time vs ingestion_time
lateness_analysis = historical_df.withColumn(
    "lateness_seconds",
    unix_timestamp("ingestion_time") - unix_timestamp("event_time")
)

# Find P99 lateness — set watermark slightly above this
lateness_analysis.selectExpr(
    "percentile_approx(lateness_seconds, 0.99) as p99_lateness_sec",
    "percentile_approx(lateness_seconds, 0.999) as p999_lateness_sec",
    "max(lateness_seconds) as max_lateness_sec"
).show()
```

---

## Key Interview Talking Points

1. **What is a watermark?** "A watermark is a moving threshold based on the maximum observed event time minus a tolerance interval. It tells Spark how long to wait for late data before considering a time window complete and cleaning up its state."

2. **Why are watermarks necessary?** "Without watermarks, streaming aggregations would keep state forever — eventually causing OutOfMemoryError. Watermarks allow Spark to garbage-collect state for windows that can no longer receive late events."

3. **Watermark vs processing time:** "Watermarks are based on event time (when the event actually occurred), not processing time (when Spark receives it). This handles out-of-order delivery correctly."

4. **Output modes matter:** "In `append` mode, results are emitted only after the watermark passes the window boundary — guaranteeing finality. In `update` mode, partial results are emitted immediately and updated as late data arrives."

5. **State management trade-off:** "A larger watermark threshold keeps more state in memory but accepts more late events. A smaller threshold uses less memory but drops more late events. Analyze your P99 lateness to choose the right value."

6. **Real-world patterns:**
   - IoT sensor data: Sensors may buffer and send in batches — lateness of minutes to hours
   - Mobile app events: Offline users sync later — lateness of hours to days
   - Cross-datacenter replication: Network partitions cause variable lateness
   - Kafka consumer lag: Consumer falling behind introduces processing delays
