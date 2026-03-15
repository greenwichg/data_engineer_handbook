# Checkpointing

## Introduction

Let's talk about checkpointing -- the mechanism that makes Structured Streaming reliable. Without
checkpointing, a streaming query would have no memory. If it crashed and restarted, it wouldn't
know which data it had already processed, leading to data loss or duplication. Checkpointing
solves this by persisting the query's progress to durable storage, enabling exactly-once
processing guarantees even across failures and restarts.

This is a shorter topic, but it's foundational. Every production streaming pipeline depends on
checkpointing, and the exam tests your understanding of what it is, how it works, and what
happens when things go wrong.

## What Is a Checkpoint?

A checkpoint is a persistent record of a streaming query's progress stored on durable storage
(S3, GCS, etc.). It tracks:

```
Checkpoint Contents:

/checkpoints/my_stream/
├── offsets/          ← Which data has been PLANNED for processing
│   ├── 0            ← Batch 0 offset (which files/records to process)
│   ├── 1            ← Batch 1 offset
│   └── 2            ← Batch 2 offset
│
├── commits/          ← Which batches have been COMMITTED (completed)
│   ├── 0            ← Batch 0 committed ✓
│   ├── 1            ← Batch 1 committed ✓
│   └── 2            ← Batch 2 committed ✓
│
├── metadata          ← Query metadata (ID, run ID)
│
├── sources/          ← Source-specific state
│   └── 0/           ← State for source 0 (e.g., file list for cloudFiles)
│
└── state/            ← State store data (for stateful operations)
    └── 0/            ← Aggregation state, deduplication state, etc.
        └── ...
```

## How Checkpointing Enables Exactly-Once

The checkpoint mechanism works through a two-phase commit protocol:

```
Two-Phase Checkpoint Protocol:

Phase 1: PLAN
  ├── Determine which new data to process (offsets)
  ├── Write offset to /offsets/{batchId}
  └── This records "I intend to process this data"

Phase 2: COMMIT
  ├── Execute the micro-batch (read, transform, write)
  ├── Write commit marker to /commits/{batchId}
  └── This records "I successfully processed this data"

Failure Scenarios:

1. Crash BEFORE offset written:
   → No record exists → Data will be processed in next run ✓

2. Crash AFTER offset but BEFORE commit:
   → Offset exists but no commit → Replay the entire batch ✓
   → Exactly-once: sink must be idempotent (Delta Lake is)

3. Crash AFTER commit:
   → Both offset and commit exist → Move to next batch ✓
   → No data loss, no duplication
```

```
Example Recovery Flow:

Before crash:
  Batch 0: offset ✓, commit ✓  (fully processed)
  Batch 1: offset ✓, commit ✓  (fully processed)
  Batch 2: offset ✓, commit ✗  (planned but not committed)

After restart:
  → Reads checkpoint
  → Sees Batch 2 has offset but no commit
  → REPLAYS Batch 2 from scratch
  → Batch 2: offset ✓, commit ✓  (now fully processed)
  → Continues with Batch 3
```

## Setting Up Checkpointing

Checkpointing is configured with a single option:

```python
query = (df.writeStream
    .format("delta")
    .option("checkpointLocation", "/mnt/checkpoints/my_pipeline")
    .trigger(availableNow=True)
    .toTable("catalog.schema.target")
)
```

### Critical Rules for Checkpoint Locations

```
Checkpoint Location Rules:

1. UNIQUE per query
   ✓ Stream A → /checkpoints/stream_a
   ✓ Stream B → /checkpoints/stream_b
   ✗ Stream A → /checkpoints/shared    ← NEVER share checkpoints!
   ✗ Stream B → /checkpoints/shared

2. DURABLE storage (cloud storage, not local disk)
   ✓ s3://my-bucket/checkpoints/stream_a
   ✓ /mnt/checkpoints/stream_a  (mount point to S3/GCS)
   ✗ /tmp/checkpoints/stream_a  (local -- lost on node failure)

3. NEVER delete or modify manually
   → Deleting checkpoint = stream loses all memory
   → Stream will reprocess ALL data from scratch
   → Can cause massive data duplication in the target

4. CONSISTENT across restarts
   → Must use the same checkpoint location when restarting a query
   → Changing the checkpoint = starting from scratch
```

## What Happens When You Delete a Checkpoint?

This is important to understand because it's a common mistake:

```
Deleting Checkpoint Scenario:

Before deletion:
  Checkpoint says: "Processed files 1-1000"
  Target table has: data from files 1-1000

After deleting checkpoint and restarting:
  Checkpoint says: (nothing -- it's gone)
  Stream thinks: "I've never processed anything"
  Stream processes: files 1-1000 AGAIN
  Target table now has: DUPLICATE data from files 1-1000!

Recovery:
  → If target is a Delta table, you can use time travel to restore
  → Then recreate the checkpoint by reprocessing from scratch
  → Or use COPY INTO with idempotent semantics instead
```

**Rule**: Never delete a checkpoint unless you also delete (or TRUNCATE) the target table and
intend to reprocess everything from the beginning.

## Checkpoint and Query Identity

The checkpoint establishes the **identity** of a streaming query:

```python
# This query has identity tied to its checkpoint
query = (df.writeStream
    .option("checkpointLocation", "/checkpoints/orders_pipeline")
    .toTable("catalog.schema.orders")
)

# query.id -- persistent UUID stored in checkpoint metadata
# Remains the same across restarts as long as same checkpoint is used

# query.runId -- unique UUID for THIS specific run
# Changes every time the stream is restarted
```

```
Query Identity:

Run 1: id=abc-123, runId=run-001  → checkpoint at /checkpoints/orders
  (stream processes batches 0-50, then stops)

Run 2: id=abc-123, runId=run-002  → same checkpoint
  (stream resumes from batch 51, same identity)

Run 3 with NEW checkpoint: id=xyz-789, runId=run-003
  (stream starts from scratch -- new identity!)
```

## Changing the Streaming Query

What happens if you change the query logic but keep the same checkpoint?

```
Safe Changes (checkpoint compatible):
  ✓ Adding new columns with withColumn
  ✓ Changing filter conditions
  ✓ Adding or removing map-like transformations
  ✓ Changing trigger type or interval
  ✓ Changing output mode (with caveats)

Unsafe Changes (may break checkpoint):
  ✗ Changing the source (e.g., different Kafka topic)
  ✗ Changing the number of input sources
  ✗ Changing aggregation keys in stateful queries
  ✗ Changing the type of stateful operation
  ✗ Changing the schema of the state store
```

When you make an incompatible change, the stream will fail with an error on restart. In that
case, you need to delete the checkpoint and start fresh (which means reprocessing all data).

## Checkpoint Storage Size

Checkpoints can grow over time, especially for stateful operations:

```
Checkpoint Size Factors:

Stateless queries (filter, select, map):
  → Small checkpoint (just offsets and commits)
  → Size grows slowly with number of batches

Stateful queries (aggregations, deduplication, joins):
  → Can be large (state store holds aggregation data)
  → Size depends on number of keys/groups
  → RocksDB state store is more efficient than default

Example:
  Stream with 1M unique aggregation keys:
  → State store could be hundreds of MB to GB
  → Stored in checkpoint /state/ directory
```

## Checkpointing with Auto Loader

When using Auto Loader, the checkpoint serves double duty:

```
Auto Loader Checkpoint:

/checkpoints/auto_loader_pipeline/
├── offsets/            ← Standard Structured Streaming offsets
├── commits/            ← Standard commit markers
├── sources/
│   └── 0/
│       └── rocksdb/    ← Auto Loader's file tracking state
│           └── ...     ← Tracks which files have been discovered
└── ...

The sources/0/rocksdb/ contains:
  → List of all files that have been discovered
  → Which files have been processed
  → This is how Auto Loader knows which files are "new"
```

If you delete this checkpoint, Auto Loader loses track of which files it has already processed
and will attempt to reprocess all files in the source directory.

## Key Exam Points

1. **Checkpoint location is required** for production streaming queries -- it enables
   exactly-once processing
2. **Checkpoints store**: offsets (what to process), commits (what's done), metadata, and
   state (for aggregations)
3. **Two-phase protocol**: write offset first (plan), then commit after successful processing
4. **Never share checkpoints** between different streaming queries -- each query needs its own
5. **Never delete checkpoints** unless you intend to reprocess all data from scratch
6. **Deleting a checkpoint** causes the stream to reprocess everything, potentially creating
   duplicates in the target
7. **Checkpoint location must be on durable storage** (S3, GCS) -- not local disk
8. **query.id** persists across restarts (from checkpoint); **query.runId** is unique per run
9. **Compatible query changes** (adding filters, columns) work with existing checkpoints;
   **incompatible changes** (different source, changed aggregation keys) require a new checkpoint
10. **Auto Loader stores file tracking state** in the checkpoint -- deleting it means
    re-discovering and reprocessing all files
