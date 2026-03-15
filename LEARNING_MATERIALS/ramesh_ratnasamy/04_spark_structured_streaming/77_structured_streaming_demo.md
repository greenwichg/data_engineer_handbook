# Structured Streaming - Demo

## Introduction

Alright, now let's get hands-on with Structured Streaming. In this lesson, we'll walk through
a complete end-to-end streaming pipeline that you'd actually build in a Databricks environment.
We'll start with reading streaming data, apply transformations, write to a Delta table, and
monitor the stream. This mirrors what you'd do in a real production pipeline and covers the
practical details that show up on the exam.

## Setting Up the Demo Environment

Let's say we have JSON event files landing continuously in an S3 bucket. Each file contains
user activity events from a web application:

```json
{"event_id": "e001", "user_id": "u100", "event_type": "page_view", "page": "/home", "timestamp": "2025-01-15T10:30:00Z"}
{"event_id": "e002", "user_id": "u101", "event_type": "purchase", "page": "/checkout", "amount": 49.99, "timestamp": "2025-01-15T10:30:05Z"}
{"event_id": "e003", "user_id": "u100", "event_type": "page_view", "page": "/products", "timestamp": "2025-01-15T10:30:10Z"}
```

## Step 1: Reading the Stream

There are two main approaches to read files as a stream:

### Approach A: Using Auto Loader (Recommended)

```python
# Auto Loader -- best for production file ingestion
raw_stream = (spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "json")
    .option("cloudFiles.schemaLocation", "/mnt/schemas/user_events")
    .option("cloudFiles.inferColumnTypes", "true")
    .load("s3://data-lake/landing/user_events/")
)
```

### Approach B: Using the Built-in File Source

```python
from pyspark.sql.types import StructType, StructField, StringType, DoubleType, TimestampType

# Define schema explicitly (required for file source streaming)
event_schema = StructType([
    StructField("event_id", StringType(), True),
    StructField("user_id", StringType(), True),
    StructField("event_type", StringType(), True),
    StructField("page", StringType(), True),
    StructField("amount", DoubleType(), True),
    StructField("timestamp", TimestampType(), True)
])

# File source -- requires explicit schema
raw_stream = (spark.readStream
    .format("json")
    .schema(event_schema)
    .load("s3://data-lake/landing/user_events/")
)
```

**Key difference**: The built-in file source requires you to provide the schema explicitly --
it does not support schema inference in streaming mode. Auto Loader handles schema inference
automatically.

## Step 2: Inspecting the Stream

Before writing transformations, you'll often want to peek at what's coming through. The
`display()` function in Databricks works with streaming DataFrames:

```python
# In a Databricks notebook -- shows live updating results
display(raw_stream)
```

For testing outside notebooks, use the console or memory sink:

```python
# Console sink -- prints to stdout (testing only)
debug_query = (raw_stream.writeStream
    .format("console")
    .option("truncate", False)
    .start()
)

# Memory sink -- writes to a temp table you can query (testing only)
debug_query = (raw_stream.writeStream
    .format("memory")
    .queryName("debug_events")
    .start()
)

# Then query the in-memory table
spark.sql("SELECT * FROM debug_events LIMIT 10").show()
```

## Step 3: Applying Transformations

Streaming DataFrames support the same transformations as batch DataFrames. Let's build a
pipeline that enriches and filters the events:

```python
from pyspark.sql.functions import col, current_timestamp, to_date, when, lit

# Apply transformations -- identical to batch API
transformed_stream = (raw_stream
    # Add ingestion metadata
    .withColumn("ingested_at", current_timestamp())
    .withColumn("event_date", to_date(col("timestamp")))

    # Categorize events
    .withColumn("event_category",
        when(col("event_type") == "purchase", lit("transaction"))
        .when(col("event_type").isin("page_view", "click"), lit("engagement"))
        .otherwise(lit("other"))
    )

    # Filter out test users
    .filter(~col("user_id").startswith("test_"))

    # Select and reorder columns
    .select(
        "event_id", "user_id", "event_type", "event_category",
        "page", "amount", "timestamp", "event_date", "ingested_at"
    )
)
```

### What Transformations Are Supported?

```
Supported in Streaming:
  ✓ select, filter, where
  ✓ withColumn, drop
  ✓ join (with static DataFrames -- stream-static join)
  ✓ union (between streaming DataFrames)
  ✓ Aggregations (with output mode complete or update)
  ✓ Window functions (with watermarks)
  ✓ UDFs (User Defined Functions)
  ✓ SQL expressions

Not Supported / Limited in Streaming:
  ✗ limit / take
  ✗ distinct / dropDuplicates (without watermark)
  ✗ Sorting (only in complete output mode)
  ✗ Multiple streaming aggregations (chained)
  ✗ Stream-stream outer joins (without watermarks)
```

## Step 4: Writing to a Delta Table

Now let's write the transformed stream to a Delta table:

```python
# Write stream to a Delta table
query = (transformed_stream.writeStream
    .format("delta")
    .option("checkpointLocation", "/mnt/checkpoints/user_events")
    .outputMode("append")
    .trigger(availableNow=True)
    .toTable("catalog.schema.user_events_silver")
)

# Wait for the current batch to finish
query.awaitTermination()
```

Let's break down each part:

```
writeStream configuration:

.format("delta")
  └─ Output format -- Delta Lake table

.option("checkpointLocation", "/mnt/checkpoints/user_events")
  └─ Where to store processing state (offsets, commits)
  └─ REQUIRED for production -- enables exactly-once guarantees
  └─ Must be a unique path per query

.outputMode("append")
  └─ How results are written to the sink
  └─ "append" = only new rows are written (most common)

.trigger(availableNow=True)
  └─ Process all available data, then stop
  └─ Perfect for scheduled batch-like execution

.toTable("catalog.schema.user_events_silver")
  └─ Target Delta table (creates if not exists)
```

## Step 5: Stream-Static Joins

A very common pattern is enriching streaming data with a static (batch) dimension table:

```python
# Read a static dimension table
users_dim = spark.read.table("catalog.schema.dim_users")

# Join streaming events with static user data
enriched_stream = (transformed_stream
    .join(users_dim, on="user_id", how="left")
    .select(
        "event_id", "user_id", "event_type",
        "page", "amount", "timestamp",
        users_dim["user_name"],
        users_dim["user_region"],
        users_dim["signup_date"]
    )
)
```

```
Stream-Static Join:

Streaming Events (continuously arriving):
┌──────────┬─────────┬────────────┐
│ event_id │ user_id │ event_type │
├──────────┼─────────┼────────────┤
│ e001     │ u100    │ page_view  │
│ e002     │ u101    │ purchase   │
└──────────┴─────────┴────────────┘
           │
           │  LEFT JOIN on user_id
           ▼
Static Users Table (read once at start):
┌─────────┬───────────┬─────────────┐
│ user_id │ user_name │ user_region │
├─────────┼───────────┼─────────────┤
│ u100    │ Alice     │ us-east     │
│ u101    │ Bob       │ eu-west     │
└─────────┴───────────┴─────────────┘
           │
           ▼
Enriched Output:
┌──────────┬─────────┬────────────┬───────────┬─────────────┐
│ event_id │ user_id │ event_type │ user_name │ user_region │
├──────────┼─────────┼────────────┼───────────┼─────────────┤
│ e001     │ u100    │ page_view  │ Alice     │ us-east     │
│ e002     │ u101    │ purchase   │ Bob       │ eu-west     │
└──────────┴─────────┴────────────┴───────────┴─────────────┘
```

**Important**: In a stream-static join, the static DataFrame is read once when the stream starts.
If the dimension table changes, you need to restart the stream to pick up the changes (or use
Delta table as source with `spark.readStream` for both sides).

## Step 6: Streaming Aggregations

For aggregations, you typically use windowed computations with watermarks:

```python
from pyspark.sql.functions import window, count, sum, avg

# Windowed aggregation with watermark
agg_stream = (raw_stream
    # Watermark: allow up to 10 minutes of late data
    .withWatermark("timestamp", "10 minutes")

    # Group by 5-minute tumbling windows
    .groupBy(
        window(col("timestamp"), "5 minutes"),
        col("event_type")
    )
    .agg(
        count("*").alias("event_count"),
        sum("amount").alias("total_amount"),
        avg("amount").alias("avg_amount")
    )
)

# Aggregations can use "update" or "complete" output mode
(agg_stream.writeStream
    .format("delta")
    .option("checkpointLocation", "/mnt/checkpoints/event_aggs")
    .outputMode("complete")
    .trigger(availableNow=True)
    .toTable("catalog.schema.event_aggregates")
)
```

```
Watermark and Windows:

Event Timeline:
10:00  10:05  10:10  10:15  10:20
  |------|------|------|------|
  │ W1   │ W2   │ W3   │ W4   │   ← 5-minute windows

Watermark = 10 minutes:
  At 10:20, the watermark is 10:10
  → Window W1 (10:00-10:05) is finalized (10:05 < 10:10)
  → Late events before 10:10 are dropped
  → Window W2 might still get late data
```

## Step 7: Monitoring the Stream

### Using the StreamingQuery Object

```python
query = transformed_stream.writeStream \
    .format("delta") \
    .option("checkpointLocation", "/checkpoints/events") \
    .toTable("catalog.schema.events")

# Check if the stream is active
print(query.isActive)

# Get current status
print(query.status)
# Output: {'message': 'Processing new data', 'isDataAvailable': True, ...}

# Get last progress report (detailed metrics)
print(query.lastProgress)
# Output includes:
#   - inputRowsPerSecond
#   - processedRowsPerSecond
#   - numInputRows
#   - batchDuration
#   - stateOperators info
```

### In Databricks UI

Databricks provides a visual streaming dashboard in notebooks that shows:
- Input rate (rows/second)
- Processing rate (rows/second)
- Batch duration
- State store metrics (for stateful operations)

```
Databricks Streaming Dashboard:

Input Rate:     ████████████████████  250 rows/sec
Processing:     ██████████████████████ 300 rows/sec
Batch Duration: ██████                 1.2 sec
State Rows:     ████████████           15,000
```

## Complete End-to-End Pipeline

Here's a complete, production-ready streaming pipeline putting it all together:

```python
from pyspark.sql.functions import col, current_timestamp, to_date, when, lit

# 1. Read streaming data with Auto Loader
raw_events = (spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "json")
    .option("cloudFiles.schemaLocation", "/mnt/schemas/events")
    .option("cloudFiles.rescuedDataColumn", "_rescued_data")
    .option("cloudFiles.schemaEvolutionMode", "addNewColumns")
    .load("s3://data-lake/landing/events/")
)

# 2. Transform
silver_events = (raw_events
    .withColumn("ingested_at", current_timestamp())
    .withColumn("event_date", to_date(col("timestamp")))
    .filter(col("event_id").isNotNull())
)

# 3. Write to Delta (Bronze → Silver)
query = (silver_events.writeStream
    .format("delta")
    .option("checkpointLocation", "/mnt/checkpoints/silver_events")
    .option("mergeSchema", "true")
    .outputMode("append")
    .trigger(availableNow=True)
    .toTable("catalog.schema.silver_events")
)

query.awaitTermination()
print(f"Stream completed. Processed in batch mode.")
```

## Key Exam Points

1. **Auto Loader (`cloudFiles`) is the recommended source** for file-based streaming ingestion
2. **Built-in file source requires explicit schema** -- it cannot infer schema in streaming mode
3. **Streaming DataFrames support the same transformations** as batch (select, filter, join, etc.)
4. **Stream-static joins** work out of the box; the static DataFrame is read once at stream start
5. **Console and memory sinks** are for testing only -- never use in production
6. **`display()` in Databricks** works with streaming DataFrames and shows live-updating results
7. **Watermarks are required** for windowed aggregations and late data handling
8. **`checkpointLocation` is required** for production streaming writes
9. **`query.awaitTermination()`** blocks until the stream stops -- useful with `availableNow=True`
10. **`StreamingQuery` object** provides `status`, `lastProgress`, `isActive`, `stop()` for
    monitoring and control
