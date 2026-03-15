# Support for ACID Transactions in Delta Lake

## Introduction

Alright, let's talk about ACID transactions in Delta Lake. This is really the core value
proposition of Delta Lake. Before Delta Lake, data lakes were essentially just directories full
of files. And that's great for flexibility, but it's terrible for reliability. If a Spark job
fails halfway through writing 100 files, you end up with 50 files in your table -- half a write.
Your data is now inconsistent. If two jobs try to write to the same table at the same time, they
might overwrite each other's files or create duplicates. There's no coordination, no isolation,
no guarantees.

ACID transactions fix all of this. ACID is an acronym that comes from the database world -- it
stands for Atomicity, Consistency, Isolation, and Durability. These are the four properties that
guarantee reliable processing of database transactions. Delta Lake brings these guarantees to
data lakes, and it does so using a clever combination of the transaction log, optimistic
concurrency control, and immutable file storage.

Let's break down each property and understand exactly how Delta Lake implements it.

## ACID Properties Explained

```
+==================================================================+
|                     ACID PROPERTIES                              |
|                                                                  |
|  +---------------------------+  +----------------------------+   |
|  |      ATOMICITY            |  |      CONSISTENCY           |   |
|  |                           |  |                            |   |
|  |  "All or Nothing"         |  |  "Valid State to           |   |
|  |                           |  |   Valid State"             |   |
|  |  Either the entire        |  |                            |   |
|  |  transaction succeeds,    |  |  Data always satisfies     |   |
|  |  or none of it does.      |  |  defined rules (schema,    |   |
|  |  No partial writes.       |  |  constraints, invariants). |   |
|  |                           |  |                            |   |
|  +---------------------------+  +----------------------------+   |
|                                                                  |
|  +---------------------------+  +----------------------------+   |
|  |      ISOLATION            |  |      DURABILITY            |   |
|  |                           |  |                            |   |
|  |  "No Interference"        |  |  "Permanent Once           |   |
|  |                           |  |   Committed"               |   |
|  |  Concurrent transactions  |  |                            |   |
|  |  don't see each other's   |  |  Once a transaction is     |   |
|  |  intermediate states.     |  |  committed, the changes    |   |
|  |  Each sees a consistent   |  |  are permanent, even if    |   |
|  |  snapshot.                |  |  the system crashes.       |   |
|  |                           |  |                            |   |
|  +---------------------------+  +----------------------------+   |
|                                                                  |
+==================================================================+
```

## Atomicity: All or Nothing

Atomicity means that a transaction is treated as a single, indivisible unit of work. Either ALL
of its changes are applied, or NONE of them are. There's no state where half the changes are
visible and half are not.

### How Delta Lake Implements Atomicity

Delta Lake achieves atomicity through its commit protocol. Here's the key insight: a transaction
only becomes visible when its commit file (the JSON file in `_delta_log/`) is successfully written.
Until that commit file exists, none of the new data files are visible to readers.

```
Transaction Write Process (Atomicity):

+-----------------------------------------------------------+
|  Step 1: Write data files                                 |
|                                                           |
|  Write new Parquet files to the table directory.          |
|  These files are "orphaned" -- no commit references them. |
|  Readers will NOT see them because the transaction log    |
|  doesn't know about them yet.                            |
+-----------------------------------------------------------+
                        |
                        v
+-----------------------------------------------------------+
|  Step 2: Create commit file (ATOMIC OPERATION)            |
|                                                           |
|  Write the JSON commit file to _delta_log/                |
|  This is a single, atomic file creation.                  |
|                                                           |
|  Before this file exists:                                 |
|    - New data files are invisible                         |
|    - Table is at version N                                |
|                                                           |
|  After this file exists:                                  |
|    - New data files are part of the table                 |
|    - Table is at version N+1                              |
|    - All changes are visible at once                      |
+-----------------------------------------------------------+

If the job crashes during Step 1:
  -> Orphaned Parquet files exist but are not in the log
  -> Readers never see them
  -> VACUUM will eventually clean them up
  -> Table remains in its previous consistent state

If the job crashes during Step 2:
  -> Commit file either exists or doesn't (atomic)
  -> If it exists: transaction committed successfully
  -> If it doesn't: same as crashing during Step 1
```

This is elegant because it reduces atomicity to a single atomic operation: creating a file.
Cloud storage systems (S3, GCS) provide atomic file creation, and Delta Lake leverages
this primitive to build transaction atomicity.

## Consistency: Valid State to Valid State

Consistency means that a transaction takes the database from one valid state to another valid
state. All defined rules and constraints are enforced.

### How Delta Lake Implements Consistency

Delta Lake enforces consistency through several mechanisms:

1. **Schema Enforcement**: Every write is checked against the table's schema. If the data doesn't
   match (wrong column types, missing required columns, extra columns), the write is rejected.

2. **CHECK Constraints**: You can define constraints on columns:

   ```sql
   ALTER TABLE my_table ADD CONSTRAINT valid_amount CHECK (amount > 0);
   ALTER TABLE my_table ADD CONSTRAINT valid_status CHECK (status IN ('active', 'inactive'));
   ```

3. **NOT NULL Constraints**: Enforced through the schema definition.

4. **Protocol Enforcement**: The protocol version ensures that readers and writers are compatible.
   If a writer uses features not supported by the table's protocol, the write fails rather than
   creating incompatible data.

```
Consistency Enforcement Flow:

+-------------------+
| Incoming Write    |
+--------+----------+
         |
         v
+--------+----------+    FAIL
| Schema Check      +--------> Write rejected:
| (column types,    |          "Schema mismatch"
|  column names)    |
+--------+----------+
         | PASS
         v
+--------+----------+    FAIL
| Constraint Check  +--------> Write rejected:
| (CHECK, NOT NULL) |          "Constraint violation"
+--------+----------+
         | PASS
         v
+--------+----------+    FAIL
| Protocol Check    +--------> Write rejected:
| (reader/writer    |          "Protocol incompatible"
|  versions)        |
+--------+----------+
         | PASS
         v
+--------+----------+
| Write Proceeds    |
+-------------------+
```

The key point is that these checks happen BEFORE the commit. If any check fails, the transaction
is aborted and the table remains in its previous valid state. You never end up with bad data in
the table.

## Isolation: No Interference

Isolation is about what happens when multiple transactions run concurrently. In a traditional
data lake without any concurrency control, two concurrent writes could interfere with each other
in unpredictable ways. Delta Lake provides isolation guarantees so that concurrent operations
don't step on each other.

### How Delta Lake Implements Isolation

Delta Lake uses **snapshot isolation** for reads and **optimistic concurrency control** for writes.

**For readers**: When you start reading a Delta table, you see a consistent snapshot of the table
at a specific version. Even if another writer commits changes while you're reading, you continue
to see the same snapshot. You never see a partially committed state.

```
Reader Isolation:

Time --->

Reader starts         Writer commits          Reader finishes
reading v5            v6                      reading v5
    |                    |                        |
    v                    v                        v
----+--------------------+------------------------+----->
    |                    |                        |
    | Reader sees        | Reader still sees      |
    | snapshot at v5     | snapshot at v5          |
    |                    | (NOT v6)               |
    |                    |                        |
    +<--- Consistent snapshot throughout -------->+
```

**For writers**: Delta Lake uses optimistic concurrency control (OCC). Multiple writers can work
simultaneously. Each writer reads the current table version, does its work, and then tries to
commit. At commit time, if another writer has already committed, the first writer's commit might
fail. It then re-reads the current state, checks for conflicts, and retries if there's no conflict.

```
Optimistic Concurrency Control:

Writer A                    Writer B
   |                           |
   | Read current version (5)  | Read current version (5)
   |                           |
   | Write data files          | Write data files
   |                           |
   | Try to commit v6          |
   | SUCCESS!                  |
   |                           | Try to commit v6
   |                           | FAIL! (v6 already exists)
   |                           |
   |                           | Re-read current version (6)
   |                           | Check for conflicts with v6
   |                           |
   |                           | No conflict? Try to commit v7
   |                           | SUCCESS!
   |                           |
   |                           | Conflict? ABORT and throw error
```

### Isolation Levels

Delta Lake supports two isolation levels:

**WriteSerializable** (default): This is the default isolation level. It provides snapshot isolation
for reads and serializable isolation for writes. Multiple writers can succeed concurrently as long
as their changes don't conflict. This is the best choice for most workloads because it allows
higher concurrency.

**Serializable**: This is the strictest isolation level. It behaves as if all transactions were
executed one at a time. This provides the strongest guarantees but reduces concurrency. Use this
when you need to ensure that reads and writes are fully serializable.

```sql
-- Set isolation level for a table
ALTER TABLE my_table SET TBLPROPERTIES ('delta.isolationLevel' = 'Serializable');

-- Or use the default WriteSerializable
ALTER TABLE my_table SET TBLPROPERTIES ('delta.isolationLevel' = 'WriteSerializable');
```

The key difference:

```
+-----------------------------+---------------------+---------------------+
|  Scenario                   | WriteSerializable   | Serializable        |
+=============================+=====================+=====================+
| Two blind appends           | Both succeed        | Both succeed        |
| (no reads, just appends)    |                     |                     |
+-----------------------------+---------------------+---------------------+
| Append + read-then-write    | Both may succeed    | Second writer must  |
| (e.g., UPDATE)              | (if no conflict)    | retry/abort         |
+-----------------------------+---------------------+---------------------+
| Two UPDATEs on different    | Both succeed        | One aborts          |
| partitions                  | (no conflict)       | (must serialize)    |
+-----------------------------+---------------------+---------------------+
| Two UPDATEs on same rows    | One aborts          | One aborts          |
| (conflict detected)         |                     |                     |
+-----------------------------+---------------------+---------------------+
```

## Durability: Permanent Once Committed

Durability means that once a transaction is committed, the changes are permanent. Even if the
system crashes immediately after the commit, the data won't be lost.

### How Delta Lake Implements Durability

Delta Lake achieves durability by leveraging the durability guarantees of the underlying cloud
storage system. When you write to S3 or GCS, those systems replicate your data across
multiple availability zones (and often multiple data centers). Once a write is acknowledged, the
data is durable.

Since Delta Lake commits are just file writes to cloud storage, they inherit this durability. Once
the commit file (JSON in `_delta_log/`) is successfully written, the transaction is durable:

```
Durability Chain:

+-------------------+
| Delta Lake Commit |
| (write JSON file) |
+--------+----------+
         |
         v
+--------+----------+
| Cloud Storage     |
| Write Acknowledgment |
+--------+----------+
         |
         v
+--------+----------+
| Data Replicated   |
| Across AZs/DCs    |
| by cloud provider |
+-------------------+

Once the cloud storage acknowledges the write,
the commit is durable. Even if:
  - The Spark driver crashes
  - The cluster is terminated
  - There's a network partition
The data is safe because it's replicated in cloud storage.
```

## Optimistic Concurrency Control (OCC)

Now let's go deeper into how optimistic concurrency control works in Delta Lake, because this is
a crucial concept for interviews.

The philosophy behind OCC is: "assume the best, check at the end." Instead of acquiring locks
before doing work (like pessimistic concurrency control does), OCC lets all writers work freely
and only checks for conflicts at commit time. This is a good fit for data lakes because:

1. **Write operations are long-running**: A Spark job might take minutes or hours. Holding locks
   for that long would block other operations.

2. **Conflicts are rare**: In most data lake workloads, different jobs write to different partitions
   or different tables. Actual conflicts are uncommon.

3. **Cloud storage doesn't support locks**: S3 and GCS don't have native locking mechanisms.
   OCC doesn't require locks.

### The OCC Process in Detail

```
+------------------------------------------------------------------+
|                OPTIMISTIC CONCURRENCY CONTROL                    |
|                                                                  |
|  Phase 1: READ                                                   |
|  +------------------------------------------------------------+ |
|  | - Read the current table version (e.g., version N)          | |
|  | - Read the data needed for the operation                    | |
|  | - Record which files were read (the "read set")             | |
|  +------------------------------------------------------------+ |
|                                                                  |
|  Phase 2: WRITE                                                  |
|  +------------------------------------------------------------+ |
|  | - Perform the computation (transforms, filters, etc.)       | |
|  | - Write new data files to the table directory               | |
|  | - Prepare the commit (list of ADD/REMOVE actions)           | |
|  +------------------------------------------------------------+ |
|                                                                  |
|  Phase 3: VALIDATE & COMMIT                                      |
|  +------------------------------------------------------------+ |
|  | - Check if the table version has changed since Phase 1      | |
|  | - If changed: check the "conflict detection matrix"         | |
|  |   - Does the concurrent commit conflict with our changes?   | |
|  |   - If NO conflict: rebase our commit on the new version    | |
|  |   - If YES conflict: abort and throw exception              | |
|  | - If unchanged: commit directly as version N+1              | |
|  | - Commit = atomic write of JSON file to _delta_log/         | |
|  +------------------------------------------------------------+ |
|                                                                  |
+------------------------------------------------------------------+
```

## Conflict Resolution

When a writer discovers that another writer has committed since it started, it needs to determine
whether there's a conflict. Not all concurrent writes conflict! The conflict detection depends on
what the two writers did.

### The Conflict Detection Matrix

```
+-----------------------+----------+----------+----------+----------+
|                       | Other:   | Other:   | Other:   | Other:   |
|  My Operation         | Append   | DELETE   | UPDATE   | MERGE    |
+=======================+==========+==========+==========+==========+
| Append (blind)        | OK       | OK       | OK       | OK       |
| (no data read)        |          |          |          |          |
+-----------------------+----------+----------+----------+----------+
| Append (with read)    | OK       | CONFLICT | CONFLICT | CONFLICT |
| (read data first)     |          | (if same | (if same | (if same |
|                       |          |  files)  |  files)  |  files)  |
+-----------------------+----------+----------+----------+----------+
| DELETE                | OK       | CONFLICT | CONFLICT | CONFLICT |
|                       |          | (if same | (if same | (if same |
|                       |          |  files)  |  files)  |  files)  |
+-----------------------+----------+----------+----------+----------+
| UPDATE                | OK       | CONFLICT | CONFLICT | CONFLICT |
|                       |          | (if same | (if same | (if same |
|                       |          |  files)  |  files)  |  files)  |
+-----------------------+----------+----------+----------+----------+
| MERGE                 | OK       | CONFLICT | CONFLICT | CONFLICT |
|                       |          | (if same | (if same | (if same |
|                       |          |  files)  |  files)  |  files)  |
+-----------------------+----------+----------+----------+----------+

Key: OK = no conflict, can proceed
     CONFLICT = potential conflict, must check affected files
```

The critical distinction is between **blind appends** and operations that read data:

- **Blind append**: Just adding new data without reading any existing data. This NEVER conflicts
  with anything because it doesn't depend on the current state of the table.

- **Operations that read data**: UPDATE, DELETE, MERGE, and conditional appends all read existing
  data first. If another writer modifies the files they read, there's a conflict.

### Conflict Resolution Example

```
Writer A (UPDATE):                Writer B (DELETE):
  Reads version 5                   Reads version 5
  Reads files: [f1, f2, f3]        Reads files: [f3, f4, f5]
  Modifies: f1                      Modifies: f3
  Writes: f1' (new version of f1)   Writes: (removes f3)

                                    Writer B commits first: version 6
                                    (REMOVE f3, REMOVE f4, REMOVE f5)

Writer A tries to commit:
  - Detects version changed (5 -> 6)
  - Checks: did version 6 modify any files that A read?
  - A read: [f1, f2, f3]
  - Version 6 removed: [f3, f4, f5]
  - Overlap: f3!
  - CONFLICT! Writer A must abort.

If Writer A only read [f1, f2] and Writer B only modified [f4, f5]:
  - No overlap
  - No conflict
  - Writer A can commit as version 7
```

## Write Serialization

Even with optimistic concurrency, writes to the transaction log are serialized. Only one commit
can be written for a given version number. This is enforced by the atomic put-if-absent operation
on cloud storage.

```
Serialized Commit Order:

         Version 6          Version 7          Version 8
            |                   |                   |
Writer A ---+                   |                   |
                                |                   |
Writer B --(retry)---(retry)----+                   |
                                                    |
Writer C --(retry)---(retry)---(retry)--(retry)-----+

Each writer may need to retry multiple times until it
can successfully claim the next version number.
The result is a strict serial order of commits.
```

This serialization is what gives the transaction log its total ordering property. There's no
ambiguity about which changes happened first -- the version number tells you.

## How Delta Lake Handles Concurrent Reads and Writes

A common question is: what happens when someone is reading a Delta table while someone else is
writing to it? The answer is that readers and writers don't interfere with each other at all.

```
Concurrent Read + Write:

+------------------------------------------------------------+
|                                                            |
|  Reader starts at t1:                                      |
|    - Reads _last_checkpoint                                |
|    - Reads checkpoint + JSON commits                       |
|    - Determines table is at version 5                      |
|    - Gets list of active files: [f1, f2, f3, f4]          |
|    - Starts reading data from those files                  |
|                                                            |
|  Writer commits at t2 (during Reader's scan):              |
|    - Writes new file f5                                    |
|    - Commits version 6: ADD f5, REMOVE f2                  |
|    - Now the table has files: [f1, f3, f4, f5]             |
|                                                            |
|  Reader continues at t3:                                   |
|    - Still reading files [f1, f2, f3, f4]                  |
|    - Reader does NOT see f5 (it wasn't in version 5)       |
|    - Reader DOES see f2 (it was in version 5)              |
|    - Reader sees a CONSISTENT snapshot of version 5        |
|                                                            |
+------------------------------------------------------------+
```

This works because:

1. The reader determined the table state (which files to read) at the beginning of the query.
2. The data files are immutable -- they're never modified or deleted during normal operations.
3. The writer only adds new files and records REMOVE actions in the log. It doesn't physically
   delete old files (that's VACUUM's job, and VACUUM respects retention periods).

So readers and writers can work simultaneously without any coordination. This is one of the key
benefits of Delta Lake's design.

## CONCEPT GAP: Optimistic Concurrency Control Deep Dive

Let's go deeper into the mechanics of OCC in Delta Lake, because interview questions often probe
the edge cases.

### Retry Behavior

When a commit fails due to a conflict, Delta Lake doesn't always give up immediately. The
behavior depends on the type of conflict:

```
Conflict Type        | Retry Behavior
=====================+============================================
Version conflict     | Automatic retry (read new version, recheck)
(no data conflict)   | Up to a configurable number of retries
---------------------+--------------------------------------------
Data conflict        | Throws ConcurrentModificationException
(same files modified)| Application must handle retry logic
---------------------+--------------------------------------------
Metadata conflict    | Throws MetadataChangedException
(schema changed)     | Application must handle
---------------------+--------------------------------------------
Protocol conflict    | Throws ProtocolChangedException
(protocol upgraded)  | Application must handle
```

For automatic retries, Delta Lake does the following:

1. Read the new table version
2. Check if the concurrent commit conflicts with our operation
3. If no conflict, re-compute the commit actions (rebase) and try again
4. If there is a conflict, abort

The number of automatic retries is controlled by `spark.databricks.delta.maxCommitAttempts`
(default varies by engine).

### Rebase Operation

When a writer needs to retry, it performs a "rebase" -- similar to git rebase. It takes its
changes and applies them on top of the new table state:

```
Original plan:
  Base: version 5
  Changes: REMOVE f1, ADD f1' (updated version of f1)
  Target: version 6

After discovering version 6 already exists (another writer committed):
  New base: version 6
  Check: did version 6 touch f1? No -> no conflict
  Rebase changes: REMOVE f1, ADD f1' (same changes, new base)
  Target: version 7

The rebased commit has the same logical changes but is applied
on top of the newer base version.
```

### Why OCC Works Well for Data Lakes

Optimistic concurrency control is preferred over pessimistic (lock-based) concurrency for data
lakes for several reasons:

1. **No lock manager needed**: Cloud storage doesn't have built-in lock services (though
   DynamoDB-based locks exist for S3). OCC works with just the atomic put-if-absent primitive.

2. **No deadlocks possible**: Since there are no locks, there can't be deadlocks.

3. **Long operations don't block others**: A 2-hour ETL job doesn't hold any locks that would
   block other writers.

4. **High throughput for non-conflicting writes**: When writes don't conflict (which is the
   common case), there's zero overhead from the concurrency control mechanism.

The downside is that when conflicts DO happen, work is wasted (the conflicting writer has to redo
its work). But for data lake workloads, this is rare enough that OCC is clearly the right choice.

## CONCEPT GAP: Conflict Detection Matrix

Let's formalize what exactly constitutes a conflict. The conflict detection depends on the
relationship between the **read predicates** of one operation and the **write predicates** of
the concurrent operation.

```
+------------------------------------------------------------------+
|             CONFLICT DETECTION LOGIC                             |
|                                                                  |
|  Given:                                                          |
|    - Transaction T1 reads files matching predicate P1            |
|    - Transaction T2 (committed concurrently) writes/removes      |
|      files matching predicate P2                                 |
|                                                                  |
|  Conflict exists if and only if:                                 |
|    P1 and P2 overlap (they reference the same files)             |
|                                                                  |
|  Example:                                                        |
|    T1: UPDATE t SET x=1 WHERE date='2024-01-15'                  |
|    T1's read predicate: date='2024-01-15'                        |
|    T1 reads files in partition date=2024-01-15                   |
|                                                                  |
|    T2: DELETE FROM t WHERE date='2024-01-16'                     |
|    T2's write predicate: date='2024-01-16'                       |
|    T2 removes files in partition date=2024-01-16                 |
|                                                                  |
|    No overlap (different partitions) --> NO CONFLICT             |
|    Both can commit successfully                                  |
+------------------------------------------------------------------+
```

This is why partitioning is important for concurrency. If different jobs work on different
partitions, they'll never conflict, even under the strict Serializable isolation level.

### Anti-Dependency Conflicts (Serializable Only)

Under the Serializable isolation level, there's an additional type of conflict called an
anti-dependency conflict. This happens when:

- Transaction T1 reads a range of data (e.g., `SELECT * FROM t WHERE id > 100`)
- Transaction T2 inserts data into that range (e.g., `INSERT INTO t VALUES (150, ...)`)

Under WriteSerializable, this is NOT a conflict (T1 would just miss the new rows). Under
Serializable, this IS a conflict because the result of T1 would be different if it ran after T2.

## CONCEPT GAP: What Happens During Write Conflicts

When a conflict is detected and cannot be resolved by retrying, Delta Lake throws an exception.
Let's walk through the different types of conflicts and what happens:

```
+------------------------------------------------------------------+
|  Conflict Type: ConcurrentAppendException                        |
|                                                                  |
|  Cause: Two operations tried to add files to the same partition  |
|         and the isolation level is Serializable.                 |
|                                                                  |
|  Solution: Retry the operation, or use WriteSerializable          |
|            isolation level if blind appends are acceptable.       |
+------------------------------------------------------------------+

+------------------------------------------------------------------+
|  Conflict Type: ConcurrentDeleteReadException                    |
|                                                                  |
|  Cause: A concurrent operation deleted a file that your          |
|         operation read.                                          |
|                                                                  |
|  Example: You ran an UPDATE that read file X, but another        |
|           operation deleted file X before you committed.         |
|                                                                  |
|  Solution: Retry the entire operation from scratch.              |
+------------------------------------------------------------------+

+------------------------------------------------------------------+
|  Conflict Type: ConcurrentDeleteDeleteException                  |
|                                                                  |
|  Cause: Two operations both tried to delete the same file.       |
|                                                                  |
|  Example: Two DELETE operations with overlapping predicates.     |
|                                                                  |
|  Solution: Retry the operation.                                  |
+------------------------------------------------------------------+

+------------------------------------------------------------------+
|  Conflict Type: MetadataChangedException                         |
|                                                                  |
|  Cause: The table metadata (schema, properties) was changed      |
|         by another operation during your transaction.            |
|                                                                  |
|  Solution: Retry the operation with the new metadata.            |
+------------------------------------------------------------------+

+------------------------------------------------------------------+
|  Conflict Type: ProtocolChangedException                         |
|                                                                  |
|  Cause: The table protocol version was upgraded by another       |
|         operation. Your writer may not support the new protocol. |
|                                                                  |
|  Solution: Upgrade your Delta Lake version to support the        |
|            new protocol, then retry.                             |
+------------------------------------------------------------------+
```

## CONCEPT GAP: Row-Level Concurrency and Deletion Vectors

Traditional Delta Lake uses file-level conflict detection. If two writers modify different rows
but those rows happen to be in the same file, it's treated as a conflict. This is a limitation
because it's overly conservative -- the operations don't actually conflict at the row level.

**Deletion Vectors** are a Databricks feature that enables row-level concurrency. Instead of
rewriting an entire Parquet file to delete or update a few rows, Delta Lake marks the affected
rows as deleted in a separate deletion vector file. This has two benefits:

1. **Better write performance**: You don't need to rewrite the entire file for a few row changes.
2. **Better concurrency**: Two operations that modify different rows in the same file no longer
   conflict, because each records its deletions independently.

```
Without Deletion Vectors (file-level):

  File: data_00001.parquet (contains rows 1-1000)

  Writer A: UPDATE row 42    --> Must rewrite entire file
  Writer B: DELETE row 789   --> Must rewrite entire file
  Result: CONFLICT (both modify the same file)

With Deletion Vectors (row-level):

  File: data_00001.parquet (contains rows 1-1000)

  Writer A: UPDATE row 42
    --> Create deletion vector marking row 42 as deleted
    --> Write new file with updated row 42
    --> Original file unchanged

  Writer B: DELETE row 789
    --> Create deletion vector marking row 789 as deleted
    --> Original file unchanged

  Result: NO CONFLICT (different rows, different deletion vectors)
```

Deletion vectors are stored alongside the data files:

```
my_delta_table/
+-- _delta_log/
|   +-- ...
+-- data_00001.snappy.parquet           <-- Original data file
+-- deletion_vector_abc123.bin          <-- Deletion vector for data_00001
+-- data_00002.snappy.parquet           <-- New file with updated rows
```

To enable deletion vectors:

```sql
ALTER TABLE my_table SET TBLPROPERTIES (
    'delta.enableDeletionVectors' = true
);
```

Note that deletion vectors are a Databricks feature and may not be fully available in
open-source Delta Lake. They also require a higher protocol version (reader version 3,
writer version 7 with the `deletionVectors` table feature).

### Row-Level Concurrency in Practice

With deletion vectors enabled, Delta Lake can provide row-level concurrency for certain
operations:

```
+-----------------------------------------------------------+
|  Row-Level Concurrency Support Matrix                     |
|                                                           |
|  Operation Pairs          | Row-Level Concurrency?        |
|  =========================+=============================  |
|  DELETE + DELETE           | Yes (different rows)          |
|  DELETE + UPDATE           | Yes (different rows)          |
|  UPDATE + UPDATE           | Yes (different rows)          |
|  MERGE + MERGE             | Yes (different rows)          |
|  DELETE + MERGE            | Yes (different rows)          |
|  UPDATE + MERGE            | Yes (different rows)          |
|                           |                               |
|  Same rows = still        |                               |
|  conflicts!               |                               |
+-----------------------------------------------------------+
```

Row-level concurrency is particularly valuable for:

- Large tables where multiple ETL pipelines update different subsets of rows
- Real-time updates where many small writes happen concurrently
- MERGE operations with non-overlapping match conditions

## Bringing It All Together

Let's trace through a complete example that demonstrates all four ACID properties:

```
Scenario: Two concurrent MERGE operations

Pipeline A: MERGE new_orders INTO orders
  WHEN MATCHED THEN UPDATE SET status = 'fulfilled'
  WHEN NOT MATCHED THEN INSERT *

Pipeline B: DELETE FROM orders WHERE created_at < '2023-01-01'

Both start at version 10.

ATOMICITY:
  - Pipeline A writes 5 new Parquet files (partial results)
  - If Pipeline A crashes after writing 3 of 5 files:
    -> No commit file written
    -> The 3 files are orphaned
    -> Table stays at version 10 (all or nothing)

CONSISTENCY:
  - Pipeline A's MERGE checks schema compatibility
  - If new_orders has a column "total DOUBLE" but orders has "total INT":
    -> Schema enforcement catches the mismatch
    -> MERGE fails with schema error
    -> Table stays consistent

ISOLATION:
  - Pipeline A sees version 10 snapshot throughout its execution
  - Pipeline B also sees version 10 snapshot
  - Neither sees the other's intermediate results
  - Pipeline A commits version 11 first
  - Pipeline B tries to commit version 11 -> fails
  - Pipeline B re-reads version 11, checks for conflicts:
    -> Did version 11 modify any files that B read?
    -> If yes (A and B operated on same partitions): CONFLICT, abort
    -> If no (different partitions): rebase and commit version 12

DURABILITY:
  - Pipeline A's commit (version 11 JSON file) is written to S3
  - S3 replicates across availability zones
  - Even if the Spark cluster crashes right after commit:
    -> The commit file persists in cloud storage
    -> Next reader will see version 11
```

## Interview Q&A

**Q: Explain the ACID properties and how Delta Lake implements each one.**
A: Atomicity is achieved through the commit protocol -- data files are written first (invisible to
readers), then a single atomic commit file is written to the transaction log. Either the commit file
exists (all changes visible) or it doesn't (no changes visible). Consistency is enforced through
schema validation, CHECK constraints, and protocol checks before each commit. Isolation is provided
by snapshot isolation for reads (readers see a consistent version throughout their query) and
optimistic concurrency control for writes (concurrent writers check for conflicts at commit time).
Durability is inherited from the underlying cloud storage, which replicates data across availability
zones.

**Q: What is optimistic concurrency control, and why does Delta Lake use it?**
A: Optimistic concurrency control (OCC) is a concurrency strategy where transactions proceed
without acquiring locks, and conflicts are detected only at commit time. Delta Lake uses OCC
because: (1) cloud storage doesn't have native locking mechanisms, (2) data lake operations are
long-running (holding locks would block other operations), (3) conflicts are rare in practice
(different jobs usually work on different partitions), and (4) it avoids deadlocks entirely. The
trade-off is that when conflicts do occur, work is wasted and must be retried, but this is rare
enough to be acceptable.

**Q: How does Delta Lake detect conflicts between concurrent writers?**
A: Delta Lake detects conflicts by comparing the read set of one transaction with the write set
of the concurrent transaction. When a writer tries to commit and discovers the table version has
changed, it checks whether the files it read overlap with the files modified by the concurrent
commit. If there's overlap (e.g., both operations touched files in the same partition), a conflict
is detected and the operation must be retried or aborted. If there's no overlap, the commit can
proceed by rebasing on top of the new version.

**Q: What is the difference between Serializable and WriteSerializable isolation levels?**
A: WriteSerializable (the default) provides snapshot isolation for reads and serializable isolation
for writes. It allows concurrent operations that don't modify the same files to succeed. Serializable
is stricter -- it additionally detects anti-dependency conflicts where one transaction reads a range
and another inserts into that range. Serializable guarantees that the result is equivalent to some
serial execution of all transactions, while WriteSerializable only guarantees this for write
operations. Most workloads use WriteSerializable because it allows higher concurrency.

**Q: What happens when a Delta Lake write encounters a conflict?**
A: When a conflict is detected, Delta Lake throws a specific exception depending on the conflict
type: ConcurrentDeleteReadException (another operation deleted files you read),
ConcurrentDeleteDeleteException (two operations deleted the same files), MetadataChangedException
(schema was changed), or ProtocolChangedException (protocol version was upgraded). For version
conflicts without data conflicts, Delta Lake automatically retries by re-reading the current
version and rebasing the commit. For data conflicts, the application must handle the exception
and decide whether to retry the entire operation.

**Q: What are deletion vectors, and how do they improve concurrency?**
A: Deletion vectors are a Databricks feature that enables row-level conflict detection instead of
file-level. Without deletion vectors, two operations that modify different rows in the same Parquet
file are treated as conflicting because they both need to rewrite that file. With deletion vectors,
deletions are recorded in a separate bitmap file instead of rewriting the entire data file. This
means two operations can modify different rows in the same file without conflicting. Deletion
vectors require enabling the feature via table properties and upgrading the table protocol.

**Q: Can readers and writers operate on a Delta table simultaneously? How?**
A: Yes, readers and writers can operate simultaneously without any interference. When a reader
starts a query, it determines the table state (which files are active) from the transaction log
at a specific version. The reader then reads those files, which are immutable Parquet files. Even
if a writer commits new changes during the read, the reader continues to see its original snapshot
because the writer only adds new files and records changes in the log -- it never modifies or
deletes the files the reader is using. This is snapshot isolation at work.

**Q: How does Delta Lake ensure atomicity when a Spark job fails partway through writing?**
A: When a Spark job writes to a Delta table, it first writes new Parquet data files to the table
directory. These files are not yet referenced by the transaction log, so they are invisible to
readers. Only after all data files are written does the job attempt to write the commit file (the
JSON entry in `_delta_log/`). If the job fails before the commit file is written, the data files
become orphaned -- they exist on disk but are not part of any table version. The table remains at
its previous version, completely unaffected. The orphaned files are cleaned up the next time VACUUM
runs.
