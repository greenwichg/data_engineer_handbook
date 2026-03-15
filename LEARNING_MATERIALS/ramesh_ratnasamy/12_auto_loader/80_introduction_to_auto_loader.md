# Introduction to Auto Loader

## Introduction

Alright, let's talk about Auto Loader -- one of the most powerful and practical features in
Databricks for ingesting data from cloud storage. If you've ever had to build a pipeline that
picks up new files as they land in S3 or GCS, you know how much complexity is involved. You need
to track which files you've already processed, handle failures gracefully, deal with duplicate
files, and make sure you don't miss anything. Auto Loader solves all of these problems out of
the box.

Auto Loader is a Databricks feature that provides an optimized, scalable way to incrementally
ingest new data files as they arrive in cloud storage. Instead of you manually tracking which
files are new, Auto Loader does it for you automatically. It uses Structured Streaming under
the hood, which means it runs as a streaming job that continuously monitors a directory for new
files and processes them incrementally.

The key thing to understand is that Auto Loader is not just a "file watcher." It's a production-grade
ingestion framework that handles schema inference, schema evolution, file tracking, error handling,
and scalability -- all with minimal configuration. This is why Databricks recommends Auto Loader
as the preferred method for ingesting files from cloud storage.

## Why Auto Loader?

Before Auto Loader, the typical approach to file ingestion was using `COPY INTO` or building custom
logic with `spark.read` inside a loop. Let's compare these approaches:

```
Traditional Approaches vs Auto Loader:

┌─────────────────────┬───────────────┬──────────────┬─────────────────┐
│ Feature             │ spark.read    │ COPY INTO    │ Auto Loader     │
├─────────────────────┼───────────────┼──────────────┼─────────────────┤
│ File tracking       │ Manual        │ Built-in     │ Built-in        │
│ Scalable discovery  │ No            │ No           │ Yes             │
│ Schema inference    │ Per-read      │ No           │ Once + evolve   │
│ Schema evolution    │ No            │ No           │ Yes             │
│ Streaming support   │ No            │ No           │ Yes             │
│ Exactly-once        │ Manual        │ Idempotent   │ Yes             │
│ Handles millions    │ Slow listing  │ Slow listing │ Notification    │
│ of files            │               │              │ mode            │
└─────────────────────┴───────────────┴──────────────┴─────────────────┘
```

The biggest advantage of Auto Loader over `COPY INTO` is scalability. `COPY INTO` works by
listing the entire directory every time it runs to figure out which files are new. When you have
millions of files, this listing operation becomes extremely expensive. Auto Loader avoids this
problem entirely through its file notification mode.

## How Auto Loader Works

Auto Loader uses the `cloudFiles` source in Structured Streaming. Here's the basic syntax:

```python
# Basic Auto Loader read
df = (spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "json")
    .option("cloudFiles.schemaLocation", "/mnt/schema/orders")
    .load("/mnt/landing/orders/")
)

# Write to a Delta table
(df.writeStream
    .option("checkpointLocation", "/mnt/checkpoints/orders")
    .trigger(availableNow=True)
    .toTable("catalog.schema.orders")
)
```

Let's break down what's happening here:

1. **`format("cloudFiles")`** -- This tells Spark to use Auto Loader as the streaming source
2. **`cloudFiles.format`** -- The format of the incoming files (JSON, CSV, Parquet, Avro, etc.)
3. **`cloudFiles.schemaLocation`** -- Where Auto Loader stores the inferred/evolved schema
4. **`.load(path)`** -- The cloud storage path to monitor for new files
5. **`checkpointLocation`** -- Where Structured Streaming stores its progress (critical for
   exactly-once processing)
6. **`trigger(availableNow=True)`** -- Process all available files, then stop (batch-like behavior)

## File Discovery Modes

Auto Loader has two modes for discovering new files:

### Directory Listing Mode (Default)

```
Directory Listing Mode:

  Auto Loader        Cloud Storage (S3/GCS)
  ┌──────────┐       ┌─────────────────────┐
  │          │──LIST──│  /landing/orders/   │
  │  Spark   │       │   file1.json ✓      │
  │ Streaming│       │   file2.json ✓      │
  │   Job    │       │   file3.json (NEW)  │
  │          │──READ──│                     │
  └──────────┘       └─────────────────────┘
       │
       │ Tracks processed files in
       │ checkpoint/RocksDB
       ▼
  ┌──────────┐
  │Checkpoint│
  └──────────┘
```

In directory listing mode, Auto Loader periodically lists the contents of the input directory
to identify new files. It uses an internal RocksDB-based state store to track which files have
already been processed, so it doesn't reprocess them.

This mode works well for directories with up to tens of thousands of files. Beyond that,
the listing operation can become slow. Databricks has optimized this mode with incremental
listing (using lexicographic ordering of file names), but for very large directories, you
should use file notification mode.

### File Notification Mode

```
File Notification Mode:

  Cloud Storage         Event Service         Auto Loader
  ┌────────────┐      ┌───────────────┐      ┌──────────┐
  │   S3       │─────▶│  SQS Queue    │─────▶│  Spark   │
  │  Bucket    │ Event│  (or GCS      │ Poll │ Streaming│
  │            │ Notif│  Pub/Sub)     │      │   Job    │
  │ New file   │      │               │      │          │
  │ lands!     │      │  file3.json   │      │          │
  └────────────┘      └───────────────┘      └──────────┘
```

In file notification mode, Auto Loader automatically sets up cloud-native event notification
services:
- **AWS**: S3 Events → SQS Queue (or SNS → SQS)
- **GCP**: GCS Notifications → Pub/Sub

When a new file lands, the cloud storage service pushes an event to a message queue. Auto Loader
polls the queue to discover new files instead of listing the entire directory. This is dramatically
more efficient for directories with millions of files.

To enable file notification mode:

```python
df = (spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "json")
    .option("cloudFiles.useNotifications", "true")
    .option("cloudFiles.schemaLocation", "/mnt/schema/orders")
    .load("s3://my-bucket/landing/orders/")
)
```

Auto Loader will automatically create and manage the required cloud resources (SQS queue,
S3 event notifications). It can also clean them up when the stream is deleted.

## Trigger Modes

Auto Loader can run in different trigger modes depending on your use case:

```python
# Continuous processing -- runs forever, processes files as they arrive
df.writeStream.trigger(processingTime="10 seconds").toTable("target")

# Available now -- processes all available files, then stops
df.writeStream.trigger(availableNow=True).toTable("target")

# Once -- processes one micro-batch of available files, then stops
# (deprecated in favor of availableNow)
df.writeStream.trigger(once=True).toTable("target")
```

The `availableNow=True` trigger is the most commonly used in production because it gives you
batch-like semantics while still leveraging Auto Loader's incremental file tracking. You can
schedule it to run periodically (e.g., every hour) using a Databricks job, and each run
picks up only the files that arrived since the last run.

## Exactly-Once Processing

Auto Loader guarantees exactly-once processing through the combination of:

1. **Checkpoint tracking** -- Structured Streaming's checkpoint records exactly which files
   have been committed to the output
2. **Idempotent writes** -- If a job fails and restarts, it picks up from the last checkpoint
   and reprocesses only the uncommitted files
3. **File-level tracking** -- Each file is tracked individually, so partial failures don't
   cause data loss or duplication

```
Failure Recovery:

Batch 1: [file1, file2, file3] → Committed ✓ (checkpoint updated)
Batch 2: [file4, file5, file6] → FAILURE at file5!

After restart:
Batch 2: [file4, file5, file6] → Reprocessed from checkpoint → Committed ✓
Batch 3: [file7, file8]        → Committed ✓
```

## Auto Loader vs COPY INTO

This is a common exam question. Here's when to use each:

```
┌────────────────────────┬──────────────┬──────────────────────┐
│ Scenario               │ COPY INTO    │ Auto Loader          │
├────────────────────────┼──────────────┼──────────────────────┤
│ Small number of files  │ ✓ Simple     │ Works but overkill   │
│ Millions of files      │ Slow listing │ ✓ Use notifications  │
│ Need schema evolution  │ Not built-in │ ✓ Built-in           │
│ Streaming pipeline     │ Batch only   │ ✓ Native streaming   │
│ One-time load          │ ✓ Good fit   │ Works but overkill   │
│ Continuous ingestion   │ Requires     │ ✓ Designed for this  │
│                        │ scheduling   │                      │
│ Near real-time         │ Not ideal    │ ✓ Sub-minute latency │
└────────────────────────┴──────────────┴──────────────────────┘
```

**Rule of thumb**: Use Auto Loader for any production file ingestion pipeline. Use `COPY INTO`
for ad-hoc or one-time loads of small datasets.

## Supported File Formats

Auto Loader supports the following file formats:

- **JSON** -- Including nested/semi-structured JSON
- **CSV** -- With configurable delimiters, headers, etc.
- **Parquet** -- Columnar format, schema embedded in files
- **Avro** -- Schema embedded, common in Kafka ecosystems
- **ORC** -- Another columnar format
- **Text** -- Raw text files (one row per line)
- **Binary** -- Binary files (one row per file, content as bytes)
- **XML** -- XML files (added in newer Databricks runtimes)

## Key Exam Points

1. **Auto Loader uses `cloudFiles` format** in Structured Streaming -- this is the most
   commonly tested syntax detail
2. **Two file discovery modes**: directory listing (default) and file notification (for scale)
3. **`cloudFiles.schemaLocation`** is required for schema tracking and evolution
4. **`checkpointLocation`** is required for exactly-once processing guarantees
5. **`trigger(availableNow=True)`** is the recommended trigger for scheduled batch-like
   processing
6. **Auto Loader is preferred over COPY INTO** for production pipelines, especially at scale
7. **File notification mode** uses cloud-native services (SQS on AWS, Pub/Sub on GCP)
8. **Exactly-once semantics** through checkpointing and idempotent writes
9. **Auto Loader incrementally processes files** -- it only picks up new files since the last run
