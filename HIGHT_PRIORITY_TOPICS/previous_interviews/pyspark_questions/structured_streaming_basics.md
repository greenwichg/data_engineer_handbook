# PySpark Implementation: Structured Streaming Basics

## Problem Statement

Demonstrate the fundamentals of **Spark Structured Streaming** — reading from a streaming source, applying transformations, windowed aggregations with watermarks, and writing to a sink. Given a stream of user clickstream events, compute real-time metrics like events per window, active users, and page popularity. Structured Streaming is increasingly asked in data engineering interviews as real-time processing becomes standard.

### Conceptual Input Stream

```
Arriving events (continuous):
{"user_id": "U001", "page": "/home", "event_time": "2025-01-15 10:00:00"}
{"user_id": "U002", "page": "/products", "event_time": "2025-01-15 10:01:00"}
{"user_id": "U001", "page": "/checkout", "event_time": "2025-01-15 10:02:00"}
...
```

### Expected Output (5-minute window aggregation)

| window_start        | window_end          | event_count | unique_users |
|---------------------|---------------------|-------------|-------------|
| 2025-01-15 10:00:00 | 2025-01-15 10:05:00 | 15          | 8           |
| 2025-01-15 10:05:00 | 2025-01-15 10:10:00 | 22          | 12          |

---

## Part 1: Basic Streaming Read and Write

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, from_json, window, count, countDistinct, \
    current_timestamp, to_timestamp, expr
from pyspark.sql.types import StructType, StructField, StringType, TimestampType

# Initialize Spark session
spark = SparkSession.builder \
    .appName("StructuredStreaming") \
    .getOrCreate()

# Define schema for incoming JSON events
event_schema = StructType([
    StructField("user_id", StringType()),
    StructField("page", StringType()),
    StructField("event_time", StringType())
])

# Read from a streaming source (e.g., Kafka)
# For Kafka:
kafka_stream = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "localhost:9092") \
    .option("subscribe", "clickstream") \
    .option("startingOffsets", "latest") \
    .load()

# Parse the JSON value
events = kafka_stream.select(
    from_json(col("value").cast("string"), event_schema).alias("data")
).select(
    col("data.user_id"),
    col("data.page"),
    to_timestamp(col("data.event_time")).alias("event_time")
)

# Simple aggregation: count events per page
page_counts = events.groupBy("page").count()

# Write to console (for debugging)
query = page_counts.writeStream \
    .outputMode("complete") \
    .format("console") \
    .option("truncate", "false") \
    .start()

# query.awaitTermination()
```

### Key Concepts

| Concept | Description |
|---------|-------------|
| `readStream` | Creates a streaming DataFrame (vs `read` for batch) |
| `writeStream` | Starts a streaming query (vs `write` for batch) |
| `.format("kafka")` | Streaming source — can be Kafka, files, socket |
| `.outputMode("complete")` | How results are emitted (see below) |
| `.start()` | Begins the streaming computation |

---

## Part 2: Simulating a Stream with Files (For Practice)

```python
import json
import os

# Create sample JSON files to simulate a stream
sample_dir = "/tmp/streaming_input"
os.makedirs(sample_dir, exist_ok=True)

# Write batch 1
batch1 = [
    {"user_id": "U001", "page": "/home", "event_time": "2025-01-15 10:00:00"},
    {"user_id": "U002", "page": "/products", "event_time": "2025-01-15 10:01:00"},
    {"user_id": "U001", "page": "/checkout", "event_time": "2025-01-15 10:02:00"},
    {"user_id": "U003", "page": "/home", "event_time": "2025-01-15 10:03:00"},
    {"user_id": "U002", "page": "/cart", "event_time": "2025-01-15 10:04:00"}
]

with open(f"{sample_dir}/batch1.json", "w") as f:
    for event in batch1:
        f.write(json.dumps(event) + "\n")

# Read as a stream from directory
file_stream = spark.readStream \
    .schema(event_schema) \
    .json(sample_dir)

# Process and write
query = file_stream.writeStream \
    .outputMode("append") \
    .format("console") \
    .start()

# New files dropped into sample_dir will be automatically picked up
```

---

## Part 3: Windowed Aggregation

```python
# Tumbling window: non-overlapping 5-minute windows
windowed_counts = events.groupBy(
    window(col("event_time"), "5 minutes"),
    col("page")
).agg(
    count("*").alias("event_count"),
    countDistinct("user_id").alias("unique_users")
)

# Extract window start/end for readability
windowed_result = windowed_counts.select(
    col("window.start").alias("window_start"),
    col("window.end").alias("window_end"),
    col("page"),
    col("event_count"),
    col("unique_users")
)

query = windowed_result.writeStream \
    .outputMode("complete") \
    .format("console") \
    .option("truncate", "false") \
    .start()
```

### Window Types

```python
# TUMBLING WINDOW: Fixed, non-overlapping
# |---5min---|---5min---|---5min---|
window(col("event_time"), "5 minutes")

# SLIDING WINDOW: Overlapping windows
# |---10min---|
#       |---10min---|
#             |---10min---|
# Slides every 5 minutes
window(col("event_time"), "10 minutes", "5 minutes")

# SESSION WINDOW (Spark 3.2+): Gap-based
# Events within 10 minutes of each other form a session
session_window(col("event_time"), "10 minutes")
```

---

## Part 4: Watermarks — Handling Late Data

```python
# Without watermark: Spark keeps ALL state forever (memory grows unbounded)
# With watermark: Spark drops state for windows older than the watermark

# Allow events up to 10 minutes late
events_with_watermark = events \
    .withWatermark("event_time", "10 minutes")

# Now aggregations will handle late data up to 10 minutes
windowed_with_watermark = events_with_watermark.groupBy(
    window(col("event_time"), "5 minutes")
).agg(
    count("*").alias("event_count"),
    countDistinct("user_id").alias("unique_users")
)

query = windowed_with_watermark.writeStream \
    .outputMode("update") \
    .format("console") \
    .start()
```

### How Watermarks Work

```
Event Time:     10:00  10:02  10:08  10:11  10:15
                  |      |      |      |      |
                  v      v      v      v      v
Max Event Time: 10:00  10:02  10:08  10:11  10:15
Watermark:      09:50  09:52  09:58  10:01  10:05
(max - 10min)

At 10:15, watermark = 10:05
→ Any event with event_time < 10:05 is "too late" and may be dropped
→ State for windows ending before 10:05 can be cleaned up
```

---

## Part 5: Output Modes

```python
# APPEND: Only new rows since last trigger (no aggregations or with watermark)
query = result.writeStream.outputMode("append")

# COMPLETE: Entire result table every trigger (required for groupBy without watermark)
query = result.writeStream.outputMode("complete")

# UPDATE: Only changed rows since last trigger (good for aggregations with watermark)
query = result.writeStream.outputMode("update")
```

| Output Mode | When to Use | Aggregations? | State Cleanup? |
|-------------|-------------|---------------|----------------|
| `append` | No aggregations, or with watermark | Limited | Yes (with watermark) |
| `complete` | All aggregation results needed | Yes | No (keeps all state) |
| `update` | Only changed results needed | Yes | Yes (with watermark) |

---

## Part 6: Writing to Different Sinks

```python
# Write to Parquet files
query_parquet = windowed_result.writeStream \
    .outputMode("append") \
    .format("parquet") \
    .option("path", "/output/streaming_results") \
    .option("checkpointLocation", "/checkpoints/streaming") \
    .start()

# Write to Delta Lake
query_delta = windowed_result.writeStream \
    .outputMode("append") \
    .format("delta") \
    .option("checkpointLocation", "/checkpoints/delta") \
    .start("/output/delta_results")

# Write to Kafka
query_kafka = windowed_result.writeStream \
    .outputMode("update") \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "localhost:9092") \
    .option("topic", "output_topic") \
    .option("checkpointLocation", "/checkpoints/kafka") \
    .start()

# Write using foreachBatch (custom logic per micro-batch)
def process_batch(batch_df, batch_id):
    """Custom processing for each micro-batch."""
    # Write to multiple sinks
    batch_df.write.format("delta").mode("append").save("/output/delta")
    batch_df.write.format("jdbc") \
        .option("url", "jdbc:postgresql://localhost/db") \
        .option("dbtable", "streaming_results") \
        .mode("append").save()

query_custom = windowed_result.writeStream \
    .foreachBatch(process_batch) \
    .option("checkpointLocation", "/checkpoints/custom") \
    .start()
```

---

## Part 7: Stream-to-Batch Join (Stream Enrichment)

```python
# Static (batch) dimension table
dim_pages = spark.createDataFrame([
    ("/home", "Homepage", "Navigation"),
    ("/products", "Product Listing", "Browse"),
    ("/cart", "Shopping Cart", "Purchase"),
    ("/checkout", "Checkout", "Purchase")
], ["page", "page_name", "category"])

# Join streaming events with static dimension
enriched_stream = events.join(dim_pages, on="page", how="left")

# Aggregate enriched stream
category_metrics = enriched_stream.groupBy(
    window(col("event_time"), "5 minutes"),
    col("category")
).agg(
    count("*").alias("event_count")
)

query = category_metrics.writeStream \
    .outputMode("complete") \
    .format("console") \
    .start()
```

---

## Part 8: Monitoring and Managing Streams

```python
# Check stream status
print(query.status)
print(query.lastProgress)

# List all active streams
for q in spark.streams.active:
    print(f"Stream: {q.name}, ID: {q.id}, Status: {q.status}")

# Stop a stream gracefully
query.stop()

# Trigger modes
# Default: Process as fast as possible (continuous micro-batches)
query = result.writeStream.trigger(processingTime="10 seconds").start()

# Process one batch and stop (useful for testing)
query = result.writeStream.trigger(once=True).start()

# Available processing time (Spark 3.3+)
query = result.writeStream.trigger(availableNow=True).start()
```

---

## Batch vs Streaming Comparison

| Aspect | Batch (read/write) | Streaming (readStream/writeStream) |
|--------|-------------------|-----------------------------------|
| Input | Fixed dataset | Continuous / incremental |
| Processing | One-time | Continuous triggers |
| State | Stateless | Stateful (for aggregations) |
| Output | Overwrite / Append | Append / Complete / Update |
| Late data | N/A | Handled with watermarks |
| Checkpoint | Not needed | Required for fault tolerance |

## Key Interview Talking Points

1. **Structured Streaming = micro-batch by default:** Spark processes streaming data as a series of small batch jobs. It's NOT true event-at-a-time processing (unlike Flink). Continuous processing mode exists but is experimental.

2. **Watermarks are critical:** Without watermarks, Spark maintains ALL state indefinitely → memory grows unbounded. Watermarks define how long to wait for late data before cleaning up state.

3. **Checkpointing:** Required for fault tolerance. Stores the state and offset information. If a stream fails, it resumes from the checkpoint. **Always set checkpointLocation in production.**

4. **Exactly-once semantics:** Structured Streaming provides exactly-once guarantees when using idempotent sinks (Delta Lake, databases with upsert). End-to-end exactly-once requires both checkpoint and idempotent sink.

5. **foreachBatch vs foreach:** `foreachBatch` gives you the entire micro-batch as a DataFrame (preferred). `foreach` processes row-by-row (slower). Use `foreachBatch` for writing to multiple sinks or custom logic.

6. **Common sources:** Kafka (most common), files (JSON/CSV/Parquet), Delta Lake (change data feed), socket (testing only).

7. **Spark vs Flink for streaming:**
   - Spark: Better for batch + streaming unified pipeline, easier learning curve
   - Flink: True event-at-a-time, lower latency, better for complex event processing
