# Trigger & OutputMode

## Introduction

Let's talk about two critical configuration options in Structured Streaming that you absolutely
need to understand for the exam: **triggers** and **output modes**. These two settings control
*when* your streaming query processes data and *how* results are written to the sink. Getting
these right is essential for building reliable streaming pipelines.

## Triggers

The trigger defines **when** a streaming query processes the next batch of data. Think of it as
the heartbeat of your streaming pipeline.

### Available Trigger Types

```
Trigger Types:

┌──────────────────────┬────────────────────────────────────────────────────┐
│ Trigger              │ Behavior                                         │
├──────────────────────┼────────────────────────────────────────────────────┤
│ Default (unspecified) │ Starts next micro-batch as soon as previous one  │
│                      │ finishes. Continuous processing.                  │
├──────────────────────┼────────────────────────────────────────────────────┤
│ Fixed interval       │ Waits for the specified duration before starting  │
│ (processingTime)     │ the next micro-batch. If previous batch takes     │
│                      │ longer, next starts immediately after.            │
├──────────────────────┼────────────────────────────────────────────────────┤
│ availableNow         │ Processes ALL available data in multiple batches, │
│                      │ then stops. Batch-like semantics.                 │
├──────────────────────┼────────────────────────────────────────────────────┤
│ once (deprecated)    │ Processes ONE micro-batch of available data,      │
│                      │ then stops. Replaced by availableNow.             │
└──────────────────────┴────────────────────────────────────────────────────┘
```

### Default Trigger (No Trigger Specified)

```python
# Default trigger -- runs continuously, starts next batch immediately
query = (df.writeStream
    .format("delta")
    .option("checkpointLocation", "/checkpoints/events")
    .toTable("catalog.schema.events")
)
```

```
Default Trigger Timeline:

Batch 1      Batch 2      Batch 3      Batch 4
|──────|     |─────|      |──────────| |───|
  2s          1.5s           4s          1s

→ No gap between batches. Each starts as soon as previous completes.
→ Minimizes latency but uses cluster resources continuously.
```

Use this for **low-latency** scenarios where you need results as fast as possible.

### Fixed Interval Trigger (processingTime)

```python
# Process every 30 seconds
query = (df.writeStream
    .format("delta")
    .option("checkpointLocation", "/checkpoints/events")
    .trigger(processingTime="30 seconds")
    .toTable("catalog.schema.events")
)

# Can also use shorthand
.trigger(processingTime="1 minute")
.trigger(processingTime="5 minutes")
```

```
Fixed Interval Trigger (30 seconds):

  |──Batch 1──|         |──Batch 2──|         |──Batch 3──|
  |    2s     |  WAIT   |    1.5s   |  WAIT   |    2s     |
  |───────────|─────────|───────────|─────────|───────────|
  0s         2s        30s        31.5s      60s        62s

→ If batch finishes early, waits until the interval elapses.
→ If batch takes LONGER than interval, next batch starts immediately.

Example: batch takes 45 seconds with 30-second trigger:
  |──────Batch 1──────|──Batch 2──|         |──Batch 3──|
  |       45s         |   2s      |  WAIT   |   3s      |
  |───────────────────|───────────|─────────|───────────|
  0s                 45s        47s        75s        78s

→ Batch 2 starts immediately (no 30s wait since previous overran).
```

Use this to **balance latency and resource usage**. Common in production pipelines that don't
need sub-second latency.

### Available Now Trigger

```python
# Process all available data, then stop
query = (df.writeStream
    .format("delta")
    .option("checkpointLocation", "/checkpoints/events")
    .trigger(availableNow=True)
    .toTable("catalog.schema.events")
)

# Block until complete
query.awaitTermination()
```

```
availableNow Trigger:

Available data: 10,000 files

  |──Batch 1──|──Batch 2──|──Batch 3──|  STOP
  |  3,000    |  3,000    |  4,000    |
  |  files    |  files    |  files    |
  |───────────|───────────|───────────|──▶ Stream terminates

→ Processes ALL available data across multiple micro-batches
→ Respects maxFilesPerTrigger (splits into manageable batches)
→ Stops when all available data is processed
→ Perfect for scheduled jobs (e.g., run every hour via Databricks Jobs)
```

This is the **most commonly used trigger in Databricks production pipelines**. It gives you
batch-like semantics while maintaining all the benefits of Structured Streaming (checkpointing,
exactly-once, incremental processing).

### Once Trigger (Deprecated)

```python
# DEPRECATED -- use availableNow instead
query = (df.writeStream
    .format("delta")
    .option("checkpointLocation", "/checkpoints/events")
    .trigger(once=True)
    .toTable("catalog.schema.events")
)
```

```
once vs availableNow:

Available data: 10,000 files (maxFilesPerTrigger=1000)

trigger(once=True):
  |──Batch 1──|  STOP
  |  1,000    |
  |  files    |           ← Only processes ONE batch (1,000 files)
  |───────────|──▶        ← Remaining 9,000 files left unprocessed!

trigger(availableNow=True):
  |──B1──|──B2──| ... |──B10──|  STOP
  | 1000 | 1000 |     | 1000  |
  |──────|──────|─────|───────|──▶  ← Processes ALL 10,000 files
```

**Critical exam distinction**: `once=True` processes only one micro-batch and stops.
`availableNow=True` processes all available data across multiple batches and stops. This means
`once` might leave unprocessed data behind, while `availableNow` guarantees all available data
is processed.

### Trigger Comparison Summary

```
┌────────────────────────┬──────────┬──────────┬───────────────────────────┐
│ Trigger                │ Stops?   │ Batches  │ Best For                  │
├────────────────────────┼──────────┼──────────┼───────────────────────────┤
│ Default                │ No       │ Infinite │ Low-latency continuous    │
│ processingTime("30s")  │ No       │ Infinite │ Balanced latency/cost     │
│ availableNow=True      │ Yes      │ Multiple │ Scheduled batch-like jobs │
│ once=True (deprecated) │ Yes      │ Single   │ Don't use -- deprecated   │
└────────────────────────┴──────────┴──────────┴───────────────────────────┘
```

## Output Modes

The output mode defines **what data** gets written to the sink on each trigger. This is
especially important when your query involves aggregations.

### Three Output Modes

```
┌──────────┬──────────────────────────────────────────────────────────────┐
│ Mode     │ What Gets Written                                          │
├──────────┼──────────────────────────────────────────────────────────────┤
│ append   │ Only NEW rows that were added since the last trigger.      │
│          │ Rows once written are never changed.                       │
│          │ DEFAULT mode. Cannot be used with aggregations that might  │
│          │ update previous results (unless using watermarks).         │
├──────────┼──────────────────────────────────────────────────────────────┤
│ complete │ The ENTIRE result table is written every trigger.          │
│          │ Only works with aggregation queries.                       │
│          │ Previous output is overwritten entirely.                   │
├──────────┼──────────────────────────────────────────────────────────────┤
│ update   │ Only CHANGED rows since the last trigger.                  │
│          │ Like append, but also includes updated aggregation results.│
│          │ More efficient than complete for large result tables.      │
└──────────┴──────────────────────────────────────────────────────────────┘
```

### Append Mode (Default)

```python
.outputMode("append")
```

```
Append Mode Example (no aggregation):

Trigger 1: New events [e1, e2, e3]
  → Write: [e1, e2, e3]                  Sink total: [e1, e2, e3]

Trigger 2: New events [e4, e5]
  → Write: [e4, e5]                      Sink total: [e1, e2, e3, e4, e5]

Trigger 3: New events [e6]
  → Write: [e6]                          Sink total: [e1, e2, e3, e4, e5, e6]

→ Each trigger only writes the NEW rows. Simple, efficient.
→ Perfect for ETL pipelines with no aggregations.
```

Append mode is the **default** and **most commonly used** mode. It works with:
- Simple transformations (filter, select, withColumn)
- Stream-static joins
- Map-like operations

It does **not** work with aggregations unless you use a watermark (because aggregation results
might change as more data arrives).

### Complete Mode

```python
.outputMode("complete")
```

```
Complete Mode Example (with aggregation -- count by event_type):

Trigger 1: New events [{type: click}, {type: purchase}]
  Aggregation result: {click: 1, purchase: 1}
  → Write ENTIRE result: {click: 1, purchase: 1}

Trigger 2: New events [{type: click}, {type: click}]
  Aggregation result: {click: 3, purchase: 1}
  → Write ENTIRE result: {click: 3, purchase: 1}  ← Overwrites!

Trigger 3: New events [{type: purchase}]
  Aggregation result: {click: 3, purchase: 2}
  → Write ENTIRE result: {click: 3, purchase: 2}  ← Overwrites!

→ Every trigger writes ALL rows in the result table.
→ Previous output is completely replaced.
→ Required for aggregations without watermarks.
```

Complete mode **only works with aggregation queries**. If your query has no aggregation,
Spark will reject it. This mode is useful when:
- You have a small number of aggregation groups
- Downstream consumers need the full picture every time
- You're writing to a sink that supports overwrites

### Update Mode

```python
.outputMode("update")
```

```
Update Mode Example (with aggregation -- count by event_type):

Trigger 1: New events [{type: click}, {type: purchase}]
  Changed results: {click: 1, purchase: 1}
  → Write: {click: 1, purchase: 1}          Both are new

Trigger 2: New events [{type: click}, {type: click}]
  Changed results: {click: 3}               Only click changed
  → Write: {click: 3}                       Only the CHANGED row

Trigger 3: New events [{type: purchase}]
  Changed results: {purchase: 2}             Only purchase changed
  → Write: {purchase: 2}                    Only the CHANGED row

→ Only writes rows that were ADDED or CHANGED.
→ More efficient than complete for large result tables.
```

Update mode is more efficient than complete mode because it only sends changed rows to the
sink. However, it requires the sink to support updates (not all sinks do).

### Output Mode Compatibility

```
Output Mode vs Query Type Compatibility:

┌────────────────────────────┬────────┬──────────┬────────┐
│ Query Type                 │ Append │ Complete │ Update │
├────────────────────────────┼────────┼──────────┼────────┤
│ No aggregation (map-only)  │   ✓    │    ✗     │   ✓    │
│ Aggregation (no watermark) │   ✗    │    ✓     │   ✓    │
│ Aggregation (w/ watermark) │   ✓*   │    ✓     │   ✓    │
│ flatMapGroupsWithState     │   ✓    │    ✗     │   ✓    │
└────────────────────────────┴────────┴──────────┴────────┘

* Append with watermarked aggregation: rows are only appended AFTER
  the watermark passes, meaning results are delayed but immutable.
```

### Choosing the Right Output Mode

```
Decision Tree:

Does your query have aggregations?
├── NO → Use "append" (default, most common)
│
└── YES → Do you need ALL results every trigger?
    ├── YES → Use "complete"
    │         (small result sets, full snapshots needed)
    │
    └── NO → Use "update"
              (large result sets, sink supports upserts)
```

## Combining Trigger and Output Mode

Here are the most common real-world combinations:

```python
# 1. ETL Pipeline (most common)
# Append new records, run on schedule
(df.writeStream
    .format("delta")
    .outputMode("append")
    .trigger(availableNow=True)
    .option("checkpointLocation", "/checkpoints/etl")
    .toTable("catalog.schema.silver_table")
)

# 2. Real-time Dashboard Aggregation
# Update aggregations continuously
(agg_df.writeStream
    .format("delta")
    .outputMode("complete")
    .trigger(processingTime="30 seconds")
    .option("checkpointLocation", "/checkpoints/dashboard")
    .toTable("catalog.schema.dashboard_metrics")
)

# 3. Near Real-time Event Processing
# Append events with low latency
(df.writeStream
    .format("delta")
    .outputMode("append")
    .trigger(processingTime="10 seconds")
    .option("checkpointLocation", "/checkpoints/events")
    .toTable("catalog.schema.events")
)
```

## Key Exam Points

1. **Four trigger types**: default (continuous), `processingTime` (fixed interval),
   `availableNow` (process all then stop), `once` (deprecated -- single batch)
2. **`availableNow=True` is preferred over `once=True`** -- it processes ALL available data
   across multiple batches, while `once` processes only one batch
3. **`availableNow`** is the most common trigger for scheduled Databricks jobs
4. **Three output modes**: `append` (new rows only), `complete` (all rows every time),
   `update` (changed rows only)
5. **`append` is the default** output mode and works with non-aggregation queries
6. **`complete` only works with aggregations** -- writes the entire result table each trigger
7. **Aggregations without watermarks** cannot use `append` mode (results might change)
8. **Aggregations with watermarks** can use any output mode
9. **`processingTime` trigger**: if a batch takes longer than the interval, the next batch
   starts immediately (no waiting)
10. **Output mode + trigger are independent** -- you can combine any trigger with any
    compatible output mode
