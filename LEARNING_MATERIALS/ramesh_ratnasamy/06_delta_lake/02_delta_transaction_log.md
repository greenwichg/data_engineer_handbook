# Delta Transaction Log

## Introduction

Alright, now we're going to dig into what I consider the most important concept in Delta Lake --
the transaction log. If you understand the transaction log, you understand how Delta Lake works.
Everything else -- ACID transactions, time travel, schema enforcement -- all of it is built on
top of the transaction log. It's the foundation of the entire system.

So what is the transaction log? It's a directory called `_delta_log/` that sits inside your Delta
table directory. This directory contains an ordered sequence of JSON files, each representing a
single commit (a single transaction). Every time you write to, delete from, update, or change the
schema of a Delta table, a new JSON file gets added to this directory. That's it. That's the core
idea. A simple, append-only log of changes.

But don't let the simplicity fool you. This simple design enables everything that makes Delta Lake
powerful. Let's walk through exactly how it works.

## The _delta_log Directory Structure

When you create a Delta table and start writing to it, here's what the directory structure looks
like on your cloud storage:

```
my_delta_table/
|
+-- _delta_log/
|   |
|   +-- 00000000000000000000.json       <-- Commit 0 (table creation)
|   +-- 00000000000000000001.json       <-- Commit 1
|   +-- 00000000000000000002.json       <-- Commit 2
|   +-- 00000000000000000003.json       <-- Commit 3
|   +-- 00000000000000000004.json       <-- Commit 4
|   +-- 00000000000000000005.json       <-- Commit 5
|   +-- 00000000000000000006.json       <-- Commit 6
|   +-- 00000000000000000007.json       <-- Commit 7
|   +-- 00000000000000000008.json       <-- Commit 8
|   +-- 00000000000000000009.json       <-- Commit 9
|   +-- 00000000000000000010.json       <-- Commit 10
|   +-- 00000000000000000010.checkpoint.parquet  <-- Checkpoint!
|   +-- _last_checkpoint                <-- Pointer to latest checkpoint
|   +-- 00000000000000000000.crc        <-- CRC checksum file
|   +-- 00000000000000000001.crc        <-- CRC checksum file
|   +-- ...
|
+-- part-00000-abc123.snappy.parquet    <-- Data file (active)
+-- part-00001-def456.snappy.parquet    <-- Data file (active)
+-- part-00002-ghi789.snappy.parquet    <-- Data file (removed by a DELETE)
+-- part-00003-jkl012.snappy.parquet    <-- Data file (active)
+-- ...
```

Notice a few things here:

1. The JSON files are named with zero-padded numbers. This numbering is critical -- it defines the
   order of commits, which is the order of versions.

2. Every 10 commits, a checkpoint file is created (more on this below).

3. There's a `_last_checkpoint` file that tells the reader where the latest checkpoint is.

4. There are `.crc` files which contain checksums for verifying data integrity.

5. The data files (Parquet) live alongside the `_delta_log/` directory. Some of them might be
   "active" (part of the current version of the table) and some might be "removed" (no longer
   part of the table, but the physical file still exists until VACUUM cleans it up).

## The Transaction Log as Single Source of Truth

Here's a critical concept: the transaction log is the **single source of truth** for the state
of a Delta table. When you read a Delta table, the Delta Lake library doesn't just list all the
Parquet files in the directory and read them. Instead, it reads the transaction log to figure out
which Parquet files are currently part of the table.

Why does this matter? Because when you do an UPDATE or DELETE operation on a Delta table, Delta
Lake doesn't modify the existing Parquet files (Parquet files are immutable). Instead, it writes
new Parquet files with the updated data and records in the transaction log that the old files are
"removed" and the new files are "added." The old files still physically exist on disk, but the
transaction log tells readers to ignore them.

```
+---------------------------------------------------------------+
|                Transaction Log (Source of Truth)               |
|                                                               |
|  Version 0: ADD file1.parquet                                 |
|  Version 1: ADD file2.parquet, ADD file3.parquet              |
|  Version 2: REMOVE file1.parquet, ADD file4.parquet (UPDATE)  |
|  Version 3: REMOVE file2.parquet (DELETE)                     |
+---------------------------------------------------------------+
         |
         | "Which files are currently active?"
         |
         v
+---------------------------------------------------------------+
|              Current State of the Table                       |
|                                                               |
|  Active files: file3.parquet, file4.parquet                   |
|                                                               |
|  (file1.parquet and file2.parquet still exist on disk         |
|   but are not part of the current table version)              |
+---------------------------------------------------------------+
```

This is a fundamental design pattern. The physical files on disk don't tell you the state of the
table. Only the transaction log does.

## JSON Log Files (Commit Files)

Each JSON file in the `_delta_log/` directory represents a single commit. Let's look at what's
actually inside one of these files. A commit file contains one or more **actions**, each on a
separate line (it's a JSON-lines format, not a single JSON object).

Here are the types of actions that can appear in a commit file:

### ADD Action

Records that a new data file has been added to the table.

```json
{
  "add": {
    "path": "part-00000-abc123.snappy.parquet",
    "partitionValues": {"date": "2024-01-15"},
    "size": 1048576,
    "modificationTime": 1705312000000,
    "dataChange": true,
    "stats": "{\"numRecords\":10000,\"minValues\":{\"id\":1},\"maxValues\":{\"id\":10000}}"
  }
}
```

Notice that the ADD action includes **statistics** about the file, like the number of records and
min/max values for each column. These statistics enable data skipping -- when you run a query with
a filter, Delta Lake can skip files that don't contain matching data without reading them.

### REMOVE Action

Records that a data file is no longer part of the table.

```json
{
  "remove": {
    "path": "part-00000-old123.snappy.parquet",
    "deletionTimestamp": 1705312000000,
    "dataChange": true,
    "extendedFileMetadata": true,
    "partitionValues": {"date": "2024-01-14"},
    "size": 524288
  }
}
```

Important: a REMOVE action doesn't delete the physical file. It just marks it as no longer part
of the table. The physical file stays on disk until VACUUM removes it.

### Metadata Action

Records changes to the table's metadata, including the schema.

```json
{
  "metaData": {
    "id": "unique-table-id",
    "format": {"provider": "parquet", "options": {}},
    "schemaString": "{\"type\":\"struct\",\"fields\":[{\"name\":\"id\",\"type\":\"integer\"},...]}",
    "partitionColumns": ["date"],
    "configuration": {
      "delta.autoOptimize.optimizeWrite": "true"
    },
    "createdTime": 1705000000000
  }
}
```

### Protocol Action

Records the minimum reader and writer protocol versions required to read or write the table.

```json
{
  "protocol": {
    "minReaderVersion": 1,
    "minWriterVersion": 2
  }
}
```

Protocol versioning is how Delta Lake handles backwards and forwards compatibility. When new
features are added (like Deletion Vectors or Column Mapping), the protocol version is bumped.
Older readers that don't understand the new protocol will fail with a clear error message rather
than silently producing incorrect results.

### CommitInfo Action

Records metadata about the commit itself -- who did it, what operation, when.

```json
{
  "commitInfo": {
    "timestamp": 1705312000000,
    "operation": "WRITE",
    "operationParameters": {"mode": "Append", "partitionBy": "[\"date\"]"},
    "readVersion": 4,
    "isolationLevel": "WriteSerializable",
    "isBlindAppend": true,
    "operationMetrics": {
      "numFiles": "3",
      "numOutputRows": "50000",
      "numOutputBytes": "2097152"
    },
    "engineInfo": "Apache-Spark/3.5.0 Delta-Lake/3.0.0",
    "txnId": "abc-123-def-456"
  }
}
```

## How Atomic Commits Work

Now let's talk about how Delta Lake guarantees atomicity -- how it ensures that either all of a
commit succeeds or none of it does. This is where the design gets clever.

Here's the step-by-step process of a write operation:

```
Step 1: Read current version
+------------------------------------------+
| Reader sees: version 5 is latest         |
| (00000000000000000005.json)              |
+------------------------------------------+
                    |
                    v
Step 2: Write data files (Parquet)
+------------------------------------------+
| Write new Parquet files to the table     |
| directory. These files are not yet       |
| "visible" because the transaction log    |
| doesn't reference them.                  |
+------------------------------------------+
                    |
                    v
Step 3: Write commit file (atomic rename)
+------------------------------------------+
| Attempt to write:                        |
| 00000000000000000006.json                |
|                                          |
| This uses an atomic "put-if-absent"      |
| operation on cloud storage.              |
|                                          |
| SUCCESS: Commit is done! The new data    |
|          files are now part of the table. |
|                                          |
| FAILURE: Another writer committed first. |
|          Go back to Step 1 and retry.    |
+------------------------------------------+
```

The key insight is in Step 3. The commit is atomic because it's a single file write operation.
On cloud storage, you can do a "put-if-absent" (or equivalent) operation that either succeeds or
fails atomically. If two writers try to create the same commit file at the same time, only one
will succeed. The other will fail and have to retry.

This is optimistic concurrency control (OCC). Writers optimistically assume they won't conflict.
They do their work, and only at the very end (at commit time) do they check for conflicts. If
there's a conflict, they retry. We'll cover this in detail in the ACID transactions lesson.

## Checkpoint Files

Reading the entire transaction log from the beginning to reconstruct the table state would be
very slow for tables with thousands of commits. That's where checkpoint files come in.

Every 10 commits (by default), Delta Lake creates a checkpoint file. A checkpoint is a Parquet
file that contains the complete state of the table at that point in time -- all the ADD and REMOVE
actions, metadata, and protocol information, but compacted into a single file.

```
Checkpoint Creation Process:

Version 0  ----+
Version 1  ----+
Version 2  ----+
Version 3  ----+
Version 4  ----+
Version 5  ----+----> Checkpoint at version 10
Version 6  ----+      (complete table state as Parquet)
Version 7  ----+
Version 8  ----+
Version 9  ----+
Version 10 ----+

To read the current table state at version 15:
  1. Read checkpoint at version 10
  2. Read JSON files for versions 11, 12, 13, 14, 15
  3. Apply them on top of the checkpoint state

Instead of reading all 16 JSON files (versions 0-15),
you only read 1 checkpoint + 5 JSON files. Much faster!
```

Why is the checkpoint in Parquet format? Because Parquet is a columnar format that Spark can read
very efficiently. The checkpoint file contains one row per action, and Spark can read it in parallel
across multiple executors. For tables with millions of files, this is much faster than reading
thousands of small JSON files.

The checkpoint frequency of 10 is the default. You can configure it with:

```sql
ALTER TABLE my_table SET TBLPROPERTIES ('delta.checkpointInterval' = '20');
```

## Reconstructing Table State

When a reader needs to query a Delta table, here's the complete process:

```
+-------------------------------------------------------+
|  Step 1: Find latest checkpoint                       |
|  Read _last_checkpoint file to find the latest        |
|  checkpoint version (e.g., version 20)                |
+-------------------------------------------------------+
                        |
                        v
+-------------------------------------------------------+
|  Step 2: Read checkpoint file                         |
|  Read 00000000000000000020.checkpoint.parquet         |
|  This gives us the complete table state at v20        |
+-------------------------------------------------------+
                        |
                        v
+-------------------------------------------------------+
|  Step 3: Read subsequent JSON commits                 |
|  Read JSON files for versions 21, 22, 23, ...         |
|  until we find the latest version                     |
+-------------------------------------------------------+
                        |
                        v
+-------------------------------------------------------+
|  Step 4: Apply actions                                |
|  Start with the checkpoint state, then apply          |
|  ADD and REMOVE actions from the JSON files           |
|  to get the current table state                       |
+-------------------------------------------------------+
                        |
                        v
+-------------------------------------------------------+
|  Step 5: Read data files                              |
|  Now we know which Parquet files are active.           |
|  Read those files to answer the query.                |
+-------------------------------------------------------+
```

This process is called **log replay** or **state reconstruction**. It's what happens every time
you run a query against a Delta table. The good news is that Delta Lake caches this state in
memory, so subsequent queries on the same table don't need to re-read the entire transaction log.

## Ordered Record of Transactions

The transaction log is an ordered, append-only log. This ordering is critical for several reasons:

1. **Version numbers are sequential**: Version 0, then 1, then 2, and so on. There are no gaps.
   If version 5 exists, versions 0 through 4 must also exist (or have been compacted into a
   checkpoint).

2. **Later versions take precedence**: If version 3 adds a file and version 5 removes it, the
   file is not part of the table at version 5 or later. The ordering determines the final state.

3. **Enables time travel**: Because versions are ordered and immutable, you can reconstruct the
   table state at any historical version by replaying the log up to that version.

4. **Serializes concurrent writes**: Even though multiple writers might be working simultaneously,
   the transaction log serializes their commits into a strict order. Writer A gets version 6,
   Writer B gets version 7. There's no ambiguity.

```
Timeline of operations:

Writer A starts    Writer B starts    Writer A commits   Writer B commits
writing            writing            (version 6)        (version 7)
    |                  |                   |                   |
    v                  v                   v                   v
----+------------------+-------------------+-------------------+---> time
    |                  |                   |                   |
    |                  |                   |                   |
    |                  |          +--------+--------+  +-------+--------+
    |                  |          | 000...006.json  |  | 000...007.json |
    |                  |          | Writer A's      |  | Writer B's     |
    |                  |          | changes         |  | changes        |
    |                  |          +-----------------+  +----------------+
```

## CONCEPT GAP: Transaction Log Compaction

Transaction log compaction is closely related to checkpointing, but it's a broader concept.
Over time, the `_delta_log/` directory can accumulate thousands of JSON files. Even with
checkpoints every 10 commits, you might have JSON files from long ago that are no longer needed
for state reconstruction.

**Log compaction** refers to the process of consolidating the transaction log. In Delta Lake,
this primarily happens through the checkpoint mechanism. Once a checkpoint is created, the JSON
files before it are no longer needed for reading the current state (though they're still needed
for time travel to those versions).

The key configuration parameters are:

- `delta.logRetentionDuration`: How long to keep transaction log entries. Default is 30 days.
  After this period, old JSON files and checkpoints can be cleaned up.

- `delta.checkpointInterval`: How often to create checkpoints. Default is every 10 commits.

Log cleanup happens automatically during writes. When a new checkpoint is created, Delta Lake
checks if there are log entries older than the retention duration and removes them. This is
separate from VACUUM, which cleans up data files.

## CONCEPT GAP: Log Retention and Cleanup

Let's be precise about what gets cleaned up and when:

```
+---------------------------------------------------+
|              Log Retention Timeline                |
|                                                   |
|   |<--- Older than retention period --->|         |
|   |     (default: 30 days)              |         |
|   |                                     |         |
|   v                                     v         |
|   +----+----+----+----+    +----+----+----+----+  |
|   |JSON|JSON|JSON|CKPT|    |JSON|JSON|JSON|CKPT|  |
|   | 01 | 02 | 03 | 04 |    | 95 | 96 | 97 | 98 |  |
|   +----+----+----+----+    +----+----+----+----+  |
|   |                   |    |                   |  |
|   | Can be cleaned up |    |  Must be kept     |  |
|   | (but only during  |    |                   |  |
|   |  checkpoint write)|    |                   |  |
+---------------------------------------------------+
```

Important nuances:

1. **Log cleanup happens lazily**: Old log entries are cleaned up when a new checkpoint is written,
   not on a separate schedule. If no writes happen, no cleanup happens.

2. **Log cleanup is separate from VACUUM**: VACUUM removes old data files. Log cleanup removes
   old transaction log entries. They are independent operations.

3. **Time travel depends on log retention**: If you clean up log entries older than 30 days, you
   can't time travel to versions older than 30 days. The data files might still exist (if you
   haven't run VACUUM), but without the log entries, Delta Lake can't reconstruct the table state.

## CONCEPT GAP: CRC Files Purpose

You might have noticed `.crc` files in the `_delta_log/` directory. CRC stands for Cyclic
Redundancy Check. These files contain checksums for the corresponding JSON commit files.

```
_delta_log/
+-- 00000000000000000000.json
+-- 00000000000000000000.crc    <-- Checksum for commit 0
+-- 00000000000000000001.json
+-- 00000000000000000001.crc    <-- Checksum for commit 1
```

The CRC files serve two purposes:

1. **Data integrity verification**: When reading a commit file, Delta Lake can verify that the
   file wasn't corrupted during storage or transfer by checking the CRC.

2. **Quick metadata access**: The CRC file also contains summary information about the commit,
   like the table size and number of files after that commit. This allows certain metadata queries
   to be answered without reading the full commit file.

A CRC file typically contains:

```json
{
  "tableSizeBytes": 10485760,
  "numFiles": 5,
  "numMetadata": 1,
  "numProtocol": 1,
  "numTransactions": 0
}
```

CRC files are optional and don't affect correctness. If they're missing, Delta Lake will still
work correctly -- it just might need to read more data to answer certain metadata queries.

## CONCEPT GAP: The _last_checkpoint File

The `_last_checkpoint` file is a small JSON file that tells readers where to find the most recent
checkpoint. Without this file, a reader would have to list all files in the `_delta_log/` directory
and scan for the latest checkpoint file, which could be slow in directories with many files.

```json
{
  "version": 20,
  "size": 5,
  "sizeInBytes": 12345,
  "numOfAddFiles": 100,
  "checkpointSchema": {
    "type": "struct",
    "fields": [...]
  }
}
```

The `_last_checkpoint` file contains:

- **version**: The version number of the latest checkpoint
- **size**: The number of parts (for multi-part checkpoints)
- **sizeInBytes**: The size of the checkpoint file
- **numOfAddFiles**: The number of active files in the table at that checkpoint

When Delta Lake needs to read a table, the very first thing it does is read `_last_checkpoint`
to find the starting point. Then it reads the checkpoint and any subsequent JSON files to
reconstruct the current state.

Multi-part checkpoints are used when the checkpoint is too large for a single file. Instead of
one file like `00000000000000000020.checkpoint.parquet`, you might see:

```
00000000000000000020.checkpoint.0000000001.0000000003.parquet
00000000000000000020.checkpoint.0000000002.0000000003.parquet
00000000000000000020.checkpoint.0000000003.0000000003.parquet
```

This is a 3-part checkpoint. The naming convention is `version.checkpoint.partN.totalParts.parquet`.

## Putting It All Together

Let's trace through a complete example to tie everything together. Suppose you have a Delta table
and you run an UPDATE statement:

```sql
UPDATE my_table SET status = 'active' WHERE id = 42;
```

Here's what happens behind the scenes:

```
Step 1: Read transaction log
+---> Find latest checkpoint (version 10)
+---> Read checkpoint + JSON commits 11-15
+---> Current state: files A, B, C, D are active
+---> Table is at version 15

Step 2: Find affected data
+---> Use file statistics to identify which files
      might contain id = 42 (data skipping)
+---> Read file B (which contains id = 42)

Step 3: Write new data
+---> Write file E (copy of B with id 42 updated)
+---> File E is written to the table directory
      but is NOT yet visible (no log entry)

Step 4: Commit (atomic)
+---> Write 00000000000000000016.json containing:
      {REMOVE file B, ADD file E, commitInfo}
+---> If successful: transaction is committed
+---> If file already exists: another writer got
      there first, retry from Step 1

Step 5: Table is now at version 16
+---> Active files: A, C, D, E
+---> File B still exists physically but is marked
      as removed in the transaction log
```

This is the copy-on-write pattern. Delta Lake doesn't modify files in place. It writes new files
and updates the transaction log. The old files stick around until VACUUM cleans them up, which
is what enables time travel.

## Interview Q&A

**Q: What is the Delta Transaction Log, and where is it stored?**
A: The Delta Transaction Log is an ordered, append-only record of every change made to a Delta
table. It is stored in the `_delta_log/` subdirectory within the Delta table's directory in cloud
storage. It consists of JSON files (one per commit/version), checkpoint files (Parquet files created
every 10 commits by default), and supporting files like `_last_checkpoint` and `.crc` files. The
transaction log serves as the single source of truth for the table's state.

**Q: What types of actions are recorded in a transaction log commit file?**
A: A commit file (JSON) can contain the following action types: (1) ADD -- records that a new data
file has been added to the table, including file statistics for data skipping, (2) REMOVE -- marks
a data file as no longer part of the table, (3) metaData -- records changes to the table schema
or configuration, (4) protocol -- sets the minimum reader/writer protocol versions, and
(5) commitInfo -- records metadata about the commit itself such as the operation type, timestamp,
user, and operation metrics.

**Q: What are checkpoint files, and why are they important?**
A: Checkpoint files are Parquet files created every 10 commits (by default) that contain a snapshot
of the complete table state at that version. They are important because they dramatically speed up
state reconstruction. Without checkpoints, reading a table with 10,000 commits would require
reading all 10,000 JSON files. With checkpoints, you only need to read the latest checkpoint plus
the JSON files after it (at most 9 files). Checkpoints are in Parquet format so Spark can read them
efficiently using distributed processing.

**Q: How does Delta Lake achieve atomic commits?**
A: Delta Lake achieves atomic commits by using a put-if-absent (conditional write) operation on
cloud storage. The commit process is: (1) read the current table version, (2) write new data files,
(3) attempt to atomically write the next sequentially-numbered JSON commit file. If step 3 succeeds,
the commit is done and the new data is visible. If it fails (because another writer already created
that file), the writer retries from step 1. This approach uses optimistic concurrency control,
where conflict detection only happens at commit time.

**Q: How does Delta Lake reconstruct the current table state when reading?**
A: The process is: (1) read the `_last_checkpoint` file to find the latest checkpoint version,
(2) read the checkpoint file (Parquet) to get the complete table state at that version, (3) read
all JSON commit files after the checkpoint, (4) apply the ADD and REMOVE actions from those JSON
files on top of the checkpoint state to determine which data files are currently active, (5) read
those active data files to answer the query. This process is called log replay or state
reconstruction, and the result is cached in memory for subsequent queries.

**Q: What is the difference between log retention cleanup and VACUUM?**
A: Log retention cleanup removes old transaction log entries (JSON files and old checkpoint files)
from the `_delta_log/` directory. It is controlled by `delta.logRetentionDuration` (default 30
days) and happens automatically during writes. VACUUM removes old data files (Parquet files) that
are no longer referenced by the current version of the table. It is controlled by
`delta.deletedFileRetentionDuration` (default 7 days) and must be run manually. Both affect time
travel: without log entries you can't reconstruct old versions, and without old data files you
can't read the data from those versions.

**Q: What is the purpose of the _last_checkpoint file?**
A: The `_last_checkpoint` file is a small JSON file that tells readers the version number of the
most recent checkpoint. It exists as an optimization so that readers don't have to list all files
in the `_delta_log/` directory to find the latest checkpoint. When Delta Lake opens a table, the
first thing it reads is `_last_checkpoint`, then it goes directly to the indicated checkpoint file
and reads forward from there. It also contains metadata like the number of parts in multi-part
checkpoints and the number of active files at that checkpoint version.

**Q: Why is the transaction log called the "single source of truth" for a Delta table?**
A: Because the physical presence of Parquet files in the table directory does not determine the
table's content. When an UPDATE or DELETE occurs, Delta Lake doesn't modify or remove the old
Parquet files -- it writes new files and records ADD/REMOVE actions in the transaction log. The
old files remain on disk but are logically removed. Only by reading the transaction log can you
determine which files are actually part of the current (or any historical) version of the table.
This design enables time travel, atomic commits, and safe concurrent operations.
