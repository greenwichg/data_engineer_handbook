# PySpark Implementation: Kafka Structured Streaming

## Problem Statement

Build a **real-time streaming pipeline** that reads JSON events from a Kafka topic, deserializes the payload, applies windowed aggregations (tumbling and sliding windows), handles late-arriving data with watermarks, and writes results to a Delta table. Demonstrate the full end-to-end pattern from Kafka ingestion through stateful processing to reliable output with exactly-once semantics. Kafka + Structured Streaming is the most commonly asked real-time data engineering interview combination.

### Sample Data

**Kafka message schema:**

```
Kafka Topic: "user_events"

Each message has:
  key:   (string) user_id
  value: (JSON string)
        {
          "event_time": "2025-01-15 10:03:00",
          "user_id": "U001",
          "action": "purchase",
          "amount": 49.99
        }
```

**Sample messages arriving on the topic:**

```
key      value (JSON)
U001     {"event_time": "2025-01-15 10:00:00", "user_id": "U001", "action": "click",    "amount": 0.0}
U002     {"event_time": "2025-01-15 10:03:00", "user_id": "U002", "action": "purchase", "amount": 29.99}
U001     {"event_time": "2025-01-15 10:07:00", "user_id": "U001", "action": "purchase", "amount": 49.99}
U003     {"event_time": "2025-01-15 10:12:00", "user_id": "U003", "action": "click",    "amount": 0.0}
U002     {"event_time": "2025-01-15 10:18:00", "user_id": "U002", "action": "purchase", "amount": 15.00}
U001     {"event_time": "2025-01-15 09:58:00", "user_id": "U001", "action": "click",    "amount": 0.0}   <-- late event
U003     {"event_time": "2025-01-15 10:22:00", "user_id": "U003", "action": "purchase", "amount": 99.99}
```

### Expected Output (10-minute tumbling window)

| window_start         | window_end           | event_count | total_amount |
|----------------------|----------------------|-------------|--------------|
| 2025-01-15 09:50:00  | 2025-01-15 10:00:00  | 1           | 0.00         |
| 2025-01-15 10:00:00  | 2025-01-15 10:10:00  | 3           | 79.98        |
| 2025-01-15 10:10:00  | 2025-01-15 10:20:00  | 2           | 15.00        |
| 2025-01-15 10:20:00  | 2025-01-15 10:30:00  | 1           | 99.99        |

---

## Method 1: Basic Kafka Read + JSON Deserialization

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, from_json, to_timestamp, window, count, sum as _sum
)
from pyspark.sql.types import (
    StructType, StructField, StringType, DoubleType, TimestampType
)

# Initialize Spark session with Kafka and Delta packages
spark = SparkSession.builder \
    .appName("KafkaStructuredStreaming") \
    .config("spark.jars.packages",
            "org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.0,"
            "io.delta:delta-spark_2.12:3.1.0") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog",
            "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .getOrCreate()

# Step 1: Define the schema for the JSON payload inside Kafka value
event_schema = StructType([
    StructField("event_time", StringType()),
    StructField("user_id", StringType()),
    StructField("action", StringType()),
    StructField("amount", DoubleType())
])

# Step 2: Read from Kafka topic
raw_stream = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "broker1:9092,broker2:9092") \
    .option("subscribe", "user_events") \
    .option("startingOffsets", "latest") \
    .option("failOnDataLoss", "false") \
    .load()

# Step 3: Kafka gives us key, value, topic, partition, offset, timestamp
# The value column is binary — cast to string, then parse JSON
events = raw_stream.select(
    col("key").cast("string").alias("kafka_key"),
    from_json(col("value").cast("string"), event_schema).alias("data"),
    col("topic"),
    col("partition"),
    col("offset"),
    col("timestamp").alias("kafka_timestamp")
).select(
    "kafka_key",
    to_timestamp(col("data.event_time")).alias("event_time"),
    col("data.user_id").alias("user_id"),
    col("data.action").alias("action"),
    col("data.amount").alias("amount"),
    "topic",
    "partition",
    "offset",
    "kafka_timestamp"
)

# Step 4: Write deserialized events to console for debugging
query = events.writeStream \
    .outputMode("append") \
    .format("console") \
    .option("truncate", "false") \
    .start()

# query.awaitTermination()
```

### Key Kafka Read Options

| Option | Description | Common Values |
|--------|-------------|---------------|
| `kafka.bootstrap.servers` | Comma-separated broker addresses | `"broker1:9092,broker2:9092"` |
| `subscribe` | Single topic or comma-separated topics | `"topic1"` or `"topic1,topic2"` |
| `subscribePattern` | Regex pattern to match topics | `"events-.*"` |
| `startingOffsets` | Where to start reading | `"latest"`, `"earliest"`, or JSON |
| `failOnDataLoss` | Fail query if data is lost (offsets out of range) | `"true"` (default), `"false"` |
| `maxOffsetsPerTrigger` | Rate limit — max offsets per trigger | `"10000"` |
| `kafka.group.id` | Consumer group (Spark manages offsets separately) | `"my-group"` |

### Kafka DataFrame Schema (What You Get From `.format("kafka")`)

```
root
 |-- key: binary
 |-- value: binary        <-- your JSON payload lives here
 |-- topic: string
 |-- partition: integer
 |-- offset: long
 |-- timestamp: timestamp  <-- Kafka broker timestamp
 |-- timestampType: integer
```

---

## Method 2: Tumbling Window Aggregation

```python
# Tumbling window: fixed, non-overlapping 10-minute windows
# Count events and sum amounts per window

windowed_agg = events \
    .groupBy(
        window(col("event_time"), "10 minutes")
    ).agg(
        count("*").alias("event_count"),
        _sum("amount").alias("total_amount")
    )

# Extract window bounds for readability
result = windowed_agg.select(
    col("window.start").alias("window_start"),
    col("window.end").alias("window_end"),
    col("event_count"),
    col("total_amount")
)

# Complete mode: emits entire result table every trigger
# Required here because there is no watermark to finalize windows
query = result.writeStream \
    .outputMode("complete") \
    .format("console") \
    .option("truncate", "false") \
    .trigger(processingTime="30 seconds") \
    .start()
```

### Tumbling Window Visualization

```
Event times:  09:58  10:00  10:03  10:07  10:12  10:18  10:22
                |      |      |      |      |      |      |
Windows:    |---09:50-10:00---|
                       |---10:00-10:10---|
                                         |---10:10-10:20---|
                                                           |---10:20-10:30---|

Each event falls into exactly ONE window.
```

### Tumbling vs Sliding Window

```python
# TUMBLING: Non-overlapping, one argument (window duration)
window(col("event_time"), "10 minutes")

# SLIDING: Overlapping, two arguments (window duration, slide interval)
window(col("event_time"), "10 minutes", "5 minutes")
```

---

## Method 3: Sliding Window with Watermark for Late Data

```python
# Sliding window: 10-minute window, sliding every 5 minutes
# Watermark: accept events up to 15 minutes late

windowed_with_watermark = events \
    .withWatermark("event_time", "15 minutes") \
    .groupBy(
        window(col("event_time"), "10 minutes", "5 minutes"),
        col("action")
    ).agg(
        count("*").alias("event_count"),
        _sum("amount").alias("total_amount")
    )

result = windowed_with_watermark.select(
    col("window.start").alias("window_start"),
    col("window.end").alias("window_end"),
    col("action"),
    col("event_count"),
    col("total_amount")
)

# Update mode: emits only changed rows — efficient with watermarks
query = result.writeStream \
    .outputMode("update") \
    .format("console") \
    .option("truncate", "false") \
    .trigger(processingTime="30 seconds") \
    .start()
```

### Sliding Window Visualization

```
Event time: 10:07

Window duration: 10 min, Slide interval: 5 min
This event belongs to TWO windows:
  [10:00 - 10:10)  <-- 10:07 falls here
  [10:05 - 10:15)  <-- 10:07 also falls here

All sliding windows for a stream:
|----10min----|
      |----10min----|
            |----10min----|
Slides every 5 minutes — windows overlap.
```

### How the Watermark Interacts with Windows

```
Timeline of arriving events:

Trigger 1:
  Receives: (10:00), (10:03), (10:07)
  Max event_time = 10:07
  Watermark = 10:07 - 15 min = 09:52
  → All events accepted (all event_times >= 09:52)

Trigger 2:
  Receives: (10:12), (10:18), (09:58)  ← late event
  Max event_time = 10:18
  Watermark = 10:18 - 15 min = 10:03
  → (10:12) and (10:18) accepted
  → (09:58) is BEFORE watermark 10:03 → DROPPED

Trigger 3:
  Receives: (10:22)
  Max event_time = 10:22
  Watermark = 10:22 - 15 min = 10:07
  → State for windows ending before 10:07 is CLEANED UP
  → Window [09:50-10:00) state released from memory
```

---

## Method 4: Writing to Delta with Checkpointing and Exactly-Once Semantics

```python
from delta.tables import DeltaTable

# Option A: Direct Delta sink with append mode
# (use with watermarked aggregations for finalized windows)
query_delta = windowed_with_watermark.writeStream \
    .outputMode("append") \
    .format("delta") \
    .option("checkpointLocation", "/checkpoints/kafka_to_delta") \
    .trigger(processingTime="1 minute") \
    .start("/output/delta/event_aggregations")


# Option B: foreachBatch for custom logic (upsert/merge into Delta)
def upsert_to_delta(batch_df, batch_id):
    """Merge each micro-batch into the Delta table."""
    if batch_df.isEmpty():
        return

    # Ensure the target table exists
    target_path = "/output/delta/event_aggregations"
    try:
        delta_table = DeltaTable.forPath(spark, target_path)
    except Exception:
        # First batch — create the table
        batch_df.write.format("delta").mode("overwrite").save(target_path)
        return

    # Merge: update existing windows, insert new ones
    delta_table.alias("target").merge(
        batch_df.alias("source"),
        """target.window_start = source.window_start
           AND target.window_end = source.window_end
           AND target.action = source.action"""
    ).whenMatchedUpdate(
        set={
            "event_count": "source.event_count",
            "total_amount": "source.total_amount"
        }
    ).whenNotMatchedInsertAll(
    ).execute()

query_upsert = result.writeStream \
    .outputMode("update") \
    .foreachBatch(upsert_to_delta) \
    .option("checkpointLocation", "/checkpoints/kafka_to_delta_upsert") \
    .trigger(processingTime="1 minute") \
    .start()
```

### Checkpointing and Exactly-Once Explained

```
Checkpoint directory structure:
/checkpoints/kafka_to_delta/
  ├── metadata        # Query metadata (id, schema)
  ├── offsets/         # Kafka offsets per micro-batch
  │   ├── 0           # Batch 0: {"user_events": {"0": 0, "1": 0}}
  │   ├── 1           # Batch 1: {"user_events": {"0": 150, "1": 142}}
  │   └── ...
  ├── commits/         # Which batches completed successfully
  │   ├── 0
  │   ├── 1
  │   └── ...
  ├── state/           # Stateful operation state (aggregations)
  └── sources/         # Source metadata

Exactly-once flow:
1. Read offsets from Kafka → record in offsets/
2. Process the micro-batch
3. Write output to Delta (atomic commit)
4. Record batch as committed in commits/
5. If failure at any step → replay from last committed batch
```

### Why Delta Enables Exactly-Once

| Component | Role in Exactly-Once |
|-----------|---------------------|
| **Checkpoint offsets/** | Tracks which Kafka offsets have been read |
| **Checkpoint commits/** | Tracks which batches completed end-to-end |
| **Delta atomic writes** | Output writes are all-or-nothing (no partial writes) |
| **Replayability** | On failure, Spark replays from last committed offset |
| **Idempotent sink** | Delta MERGE / append is idempotent when replayed |

---

## Method 5: Reading from Specific Offsets

```python
# LATEST: Start reading from the newest available offset (default for new queries)
stream_latest = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "broker1:9092") \
    .option("subscribe", "user_events") \
    .option("startingOffsets", "latest") \
    .load()

# EARLIEST: Start reading from the very beginning of the topic
stream_earliest = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "broker1:9092") \
    .option("subscribe", "user_events") \
    .option("startingOffsets", "earliest") \
    .load()

# SPECIFIC OFFSETS: Start from exact partition offsets (JSON format)
# Format: {"topic": {"partition": offset}}
stream_specific = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "broker1:9092") \
    .option("subscribe", "user_events") \
    .option("startingOffsets",
            '{"user_events": {"0": 100, "1": 200, "2": 150}}') \
    .load()

# ENDING OFFSETS (batch read only — for backfill):
batch_df = spark.read \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "broker1:9092") \
    .option("subscribe", "user_events") \
    .option("startingOffsets", "earliest") \
    .option("endingOffsets",
            '{"user_events": {"0": 500, "1": 500, "2": 500}}') \
    .load()
```

### Important: startingOffsets vs Checkpoint

```
First run (no checkpoint):
  → startingOffsets determines where to begin reading

Subsequent runs (checkpoint exists):
  → startingOffsets is IGNORED
  → Spark resumes from the last committed offset in the checkpoint
  → This is what provides exactly-once guarantees across restarts
```

---

## Output Modes Reference

| Output Mode | Behavior | Use Case | Watermark Required? |
|-------------|----------|----------|-------------------|
| `append` | Emits rows only after watermark finalizes the window | Writing to storage (Delta, Parquet) | Yes (for aggregations) |
| `update` | Emits only rows that changed since last trigger | Dashboards, real-time monitoring | No (but recommended) |
| `complete` | Emits entire result table every trigger | Small result sets, testing | No (keeps all state) |

---

## Trigger Modes Reference

```python
# PROCESSING TIME: Trigger every N seconds (micro-batch)
.trigger(processingTime="30 seconds")

# ONCE: Process all available data in one batch, then stop
# Useful for cost-efficient scheduled runs
.trigger(once=True)

# AVAILABLE NOW (Spark 3.3+): Process all available data, then stop
# Like once=True but creates multiple batches (better for large backlogs)
.trigger(availableNow=True)

# DEFAULT (no trigger specified): Process as fast as possible
# Starts next micro-batch immediately after previous completes
```

---

## Key Interview Talking Points

1. **"How do you read from Kafka in Spark?"** "Use `spark.readStream.format('kafka')` with `kafka.bootstrap.servers` and `subscribe` options. Kafka provides the message as binary key/value — cast the value to string and use `from_json` with a defined `StructType` schema to deserialize the JSON payload into typed columns."

2. **"How do you handle late data?"** "Apply a watermark using `withWatermark('event_time', 'threshold')` before the aggregation. The watermark tracks the maximum observed event time and accepts events within the threshold. Events arriving later than the threshold may be dropped, and Spark cleans up state for finalized windows — preventing unbounded memory growth."

3. **"What's the difference between output modes?"** "Append emits rows only after the watermark finalizes them — best for writing to storage. Update emits only changed rows each trigger — best for dashboards. Complete emits the entire result table every trigger — only suitable for small result sets. For windowed aggregations, append requires a watermark; complete does not but keeps all state in memory indefinitely."

4. **"How do you guarantee exactly-once processing?"** "End-to-end exactly-once requires three things: (a) a replayable source like Kafka, (b) checkpointing to track offsets and committed batches, and (c) an idempotent sink like Delta Lake. If a failure occurs, Spark replays from the last committed checkpoint offset. Delta's atomic writes ensure no partial or duplicate output."

5. **Checkpoint is sacred:** "Never delete or modify the checkpoint directory in production. It stores the Kafka offsets and stateful operation state. If you need to reset, stop the query, delete the checkpoint, and restart — but understand this may cause data reprocessing or loss."

6. **foreachBatch for advanced sinks:** "When writing to a sink that needs custom logic (like MERGE/upsert into Delta, or writing to multiple tables), use `foreachBatch`. It gives you each micro-batch as a regular DataFrame — you can run arbitrary DataFrame/SQL operations on it."

7. **Kafka offset management:** "Spark manages offsets internally via checkpoints — it does NOT commit offsets back to Kafka consumer groups by default. The `startingOffsets` option only matters on the first run; after that, the checkpoint determines where to resume."