# Structured Streaming - Introduction

## Introduction

Alright, let's talk about Spark Structured Streaming -- the unified streaming engine built into
Apache Spark. If you've ever needed to process data in real-time or near real-time, you've probably
encountered the classic challenge: streaming systems are fundamentally different from batch systems,
and building reliable streaming pipelines has traditionally been much harder than batch ones.
Structured Streaming changes that equation by letting you write streaming queries using the exact
same DataFrame and SQL APIs you already know from batch processing.

The core idea behind Structured Streaming is simple but powerful: treat a live data stream as a
table that's being continuously appended to. Every new piece of data that arrives is like a new
row being added to an unbounded input table. Your query runs against this table, and the results
are written to an output table. Spark takes care of all the complexity -- tracking what data is
new, handling failures, ensuring exactly-once processing -- so you can focus on your
transformation logic.

## The Mental Model: Unbounded Table

This is the most important concept to understand. In traditional batch processing, you have a
finite dataset. You read it, transform it, and write the output. In Structured Streaming, you
have an infinite, continuously growing table:

```
Structured Streaming Mental Model:

Time →
                 Unbounded Input Table
┌──────┬──────┬──────┬──────┬──────┬──────┬───
│ Row 1│ Row 2│ Row 3│ Row 4│ Row 5│ Row 6│ ...
└──────┴──────┴──────┴──────┴──────┴──────┴───
  ▲             ▲             ▲
  │             │             │
  t=0           t=1           t=2
  Trigger 1     Trigger 2     Trigger 3

At t=0: Process rows 1-2 → Write to output
At t=1: Process rows 3-4 → Append to output
At t=2: Process rows 5-6 → Append to output
```

Each time the query is triggered, Spark processes only the new data that has arrived since the
last trigger. This is called **incremental processing** -- Spark doesn't reprocess the entire
dataset every time. It maintains enough state to know exactly where it left off.

## Structured Streaming vs Legacy DStreams

Structured Streaming replaced the older DStream (Discretized Stream) API. Here's why:

```
┌─────────────────────┬─────────────────┬──────────────────────┐
│ Feature             │ DStreams         │ Structured Streaming │
├─────────────────────┼─────────────────┼──────────────────────┤
│ API                 │ RDD-based       │ DataFrame/SQL-based  │
│ Exactly-once        │ At-least-once   │ Exactly-once         │
│ Event-time support  │ Limited         │ Built-in watermarks  │
│ Catalyst optimizer  │ No              │ Yes                  │
│ Unified batch/stream│ No              │ Yes                  │
│ Late data handling  │ Manual          │ Watermarks           │
│ Status              │ Legacy/Deprecated│ Active development  │
└─────────────────────┴─────────────────┴──────────────────────┘
```

For the exam, know that Structured Streaming is the current and recommended approach. DStreams
should never be used for new development.

## Architecture

Here's how Structured Streaming fits into the Spark architecture:

```
Structured Streaming Architecture:

  ┌──────────────────────────────────────────────────────┐
  │                    SOURCES                           │
  │  ┌────────┐  ┌────────┐  ┌────────┐  ┌───────────┐  │
  │  │ Kafka  │  │  Files │  │ Socket │  │ Delta     │  │
  │  │        │  │(S3/GCS)│  │ (test) │  │ Table     │  │
  │  └───┬────┘  └───┬────┘  └───┬────┘  └─────┬─────┘  │
  └──────┼───────────┼───────────┼──────────────┼────────┘
         │           │           │              │
         ▼           ▼           ▼              ▼
  ┌──────────────────────────────────────────────────────┐
  │              STRUCTURED STREAMING ENGINE              │
  │                                                      │
  │   ┌─────────────┐  ┌──────────┐  ┌───────────────┐  │
  │   │ Incremental │  │ Catalyst │  │  State Store  │  │
  │   │ Execution   │  │ Optimizer│  │  (RocksDB)    │  │
  │   │ Plan        │  │          │  │               │  │
  │   └─────────────┘  └──────────┘  └───────────────┘  │
  │                                                      │
  └──────────────────────┬───────────────────────────────┘
                         │
                         ▼
  ┌──────────────────────────────────────────────────────┐
  │                     SINKS                            │
  │  ┌────────┐  ┌────────┐  ┌────────┐  ┌───────────┐  │
  │  │ Kafka  │  │  Files │  │ Console│  │ Delta     │  │
  │  │        │  │        │  │ (test) │  │ Table     │  │
  │  └────────┘  └────────┘  └────────┘  └───────────┘  │
  └──────────────────────────────────────────────────────┘
```

Key components:
- **Sources** -- Where data comes from (Kafka, files in cloud storage, Delta tables, etc.)
- **Sinks** -- Where results go (Delta tables, Kafka, files, console for testing)
- **Incremental Execution Plan** -- Spark only processes new data each trigger
- **Catalyst Optimizer** -- Same optimizer as batch queries, so your streaming job gets the
  same performance optimizations
- **State Store** -- Maintains aggregation state for stateful operations (counts, windows, etc.)

## Basic API

Reading and writing a stream uses almost the same API as batch:

```python
# BATCH (for comparison)
df = spark.read.format("json").load("/data/events/")
df.write.format("delta").save("/output/events/")

# STREAMING -- notice readStream and writeStream
df = spark.readStream.format("json").load("/data/events/")
df.writeStream.format("delta").start("/output/events/")
```

The key differences:
- `spark.read` → `spark.readStream`
- `df.write` → `df.writeStream`
- `.save()` or `.toTable()` → `.start()` or `.toTable()` (returns a `StreamingQuery` object)

Your transformations in between are identical:

```python
# This transformation works in both batch AND streaming
df = spark.readStream.format("cloudFiles").option("cloudFiles.format", "json") \
    .option("cloudFiles.schemaLocation", "/schemas/events") \
    .load("/landing/events/")

result = (df
    .filter(col("event_type") == "purchase")
    .groupBy("product_id")
    .agg(sum("amount").alias("total_revenue"))
)

(result.writeStream
    .format("delta")
    .option("checkpointLocation", "/checkpoints/revenue")
    .outputMode("complete")
    .toTable("catalog.schema.product_revenue")
)
```

## Sources and Sinks

### Common Sources

```python
# File source (CSV, JSON, Parquet, ORC, text)
df = spark.readStream.format("json").schema(mySchema).load("/data/")

# Auto Loader (cloudFiles -- covered in Section 12)
df = spark.readStream.format("cloudFiles") \
    .option("cloudFiles.format", "json") \
    .load("/landing/data/")

# Kafka source
df = spark.readStream.format("kafka") \
    .option("kafka.bootstrap.servers", "broker:9092") \
    .option("subscribe", "events-topic") \
    .load()

# Delta table as source
df = spark.readStream.table("catalog.schema.source_table")

# Rate source (for testing -- generates rows per second)
df = spark.readStream.format("rate").option("rowsPerSecond", 100).load()
```

### Common Sinks

```python
# Delta table sink
query = df.writeStream.format("delta") \
    .option("checkpointLocation", "/checkpoints/output") \
    .toTable("catalog.schema.target_table")

# Kafka sink
query = df.writeStream.format("kafka") \
    .option("kafka.bootstrap.servers", "broker:9092") \
    .option("topic", "output-topic") \
    .option("checkpointLocation", "/checkpoints/kafka") \
    .start()

# Console sink (for testing/debugging only)
query = df.writeStream.format("console").start()

# Memory sink (for testing/debugging only)
query = df.writeStream.format("memory").queryName("test_table").start()
# Then: spark.sql("SELECT * FROM test_table")
```

## Micro-Batch vs Continuous Processing

Structured Streaming primarily uses **micro-batch** processing:

```
Micro-Batch Execution:

Time:    |-------|-------|-------|-------|
Trigger: |  T1   |  T2   |  T3   |  T4  |

T1: Collect all data since last trigger
    → Plan query → Execute → Write output → Commit

T2: Collect new data since T1
    → Plan query → Execute → Write output → Commit

Latency: Typically 100ms - seconds per micro-batch
```

Each micro-batch:
1. Discovers new data from the source
2. Plans and optimizes the query (using Catalyst)
3. Executes the transformations
4. Writes results to the sink
5. Commits the offset (updates the checkpoint)

Spark also has an experimental **continuous processing** mode with lower latency (~1ms), but
it has limitations (no aggregations) and is rarely used in practice. For the exam, focus on
micro-batch processing.

## The StreamingQuery Object

When you start a stream, you get back a `StreamingQuery` object that lets you monitor and
control the stream:

```python
query = df.writeStream.format("delta") \
    .option("checkpointLocation", "/checkpoints/output") \
    .toTable("target")

# Monitor the stream
query.status          # Current status (processing, waiting, etc.)
query.lastProgress    # Metrics from the last micro-batch
query.isActive        # Is the stream still running?

# Control the stream
query.awaitTermination()    # Block until stream stops
query.stop()                # Stop the stream gracefully

# Get the unique ID
query.id              # Persistent across restarts (from checkpoint)
query.runId            # Unique to this particular run
```

## Key Exam Points

1. **Structured Streaming treats a stream as an unbounded table** that's continuously appended to
2. **Same DataFrame/SQL API** as batch -- only `readStream`/`writeStream` differ
3. **Exactly-once processing** is guaranteed through checkpointing
4. **Micro-batch** is the default execution model (not continuous)
5. **Sources**: Kafka, files (JSON/CSV/Parquet), Delta tables, cloudFiles (Auto Loader), rate (test)
6. **Sinks**: Delta tables, Kafka, files, console (test), memory (test)
7. **Structured Streaming replaced DStreams** -- DStreams are legacy/deprecated
8. **Catalyst optimizer** applies to streaming queries just like batch queries
9. **`writeStream.start()`** returns a `StreamingQuery` object for monitoring and control
10. **Incremental processing** -- only new data is processed each trigger, not the full dataset
