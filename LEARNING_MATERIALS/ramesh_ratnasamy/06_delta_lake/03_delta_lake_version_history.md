# Delta Lake Version History and Time Travel

## Introduction

Okay, this is one of my favorite features of Delta Lake, and honestly, it's one of the things
that really sets Delta Lake apart from plain Parquet or other traditional data lake formats. We're
talking about time travel, or data versioning. The idea is simple but incredibly powerful: every
time you make a change to a Delta table -- whether it's an INSERT, UPDATE, DELETE, MERGE, or
even a schema change -- Delta Lake creates a new version of the table. And here's the best part:
you can go back and query any previous version.

Think about that for a second. Someone accidentally deletes a bunch of records from a production
table. With plain Parquet, you're in trouble -- you'd have to restore from a backup if you have
one. With Delta Lake, you can just query the table as it was before the delete, or even restore
the table to that version. No backup needed. The history is built into the table itself.

This works because of the transaction log we discussed in the previous lesson. Each commit in the
transaction log represents a version. Version 0 is the initial table creation, version 1 is the
first change, version 2 is the second change, and so on. Since the transaction log is an ordered,
append-only record of changes, Delta Lake can reconstruct the table state at any version by
replaying the log up to that version.

## How Versions Map to Transaction Log Entries

Let's connect the dots between versions and the transaction log. Every JSON commit file in the
`_delta_log/` directory corresponds to exactly one version:

```
+---------------------------------------------------------------+
|                    VERSION TIMELINE                            |
|                                                               |
|  Version 0      Version 1      Version 2      Version 3      |
|  (Create)       (Insert)       (Update)       (Delete)        |
|     |              |              |              |             |
|     v              v              v              v             |
|  +------+       +------+       +------+       +------+        |
|  |000.  |       |001.  |       |002.  |       |003.  |        |
|  |json  |       |json  |       |json  |       |json  |        |
|  +------+       +------+       +------+       +------+        |
|                                                               |
|  _delta_log/00000000000000000000.json  -->  Version 0         |
|  _delta_log/00000000000000000001.json  -->  Version 1         |
|  _delta_log/00000000000000000002.json  -->  Version 2         |
|  _delta_log/00000000000000000003.json  -->  Version 3         |
+---------------------------------------------------------------+
```

To read the table at version 2, Delta Lake replays the log from version 0 through version 2:

```
Version 0: CREATE TABLE, ADD file_a.parquet
Version 1: INSERT, ADD file_b.parquet, ADD file_c.parquet
Version 2: UPDATE (id=42), REMOVE file_a.parquet, ADD file_d.parquet

State at Version 2:
  Active files: file_b.parquet, file_c.parquet, file_d.parquet
```

Notice that file_a.parquet was part of the table at versions 0 and 1, but was replaced by
file_d.parquet in version 2 (because of the UPDATE). If you query version 1, you'd see data from
files a, b, and c. If you query version 2, you'd see data from files b, c, and d. That's time
travel in action.

## DESCRIBE HISTORY Command

Before you can travel through time, you need to know what versions exist and what happened at each
version. That's where `DESCRIBE HISTORY` comes in.

```sql
DESCRIBE HISTORY my_table;
```

This returns a table with one row per version, showing you the complete history of changes:

```
+--------+---------------------+-----------+-------------------+--------+
|version | timestamp           | operation | operationParams   | userId |
+========+=====================+===========+===================+========+
|   5    | 2024-01-20 14:30:00 | DELETE    | {"predicate":     | user@  |
|        |                     |           |  "[id = 99]"}     | co.com |
+--------+---------------------+-----------+-------------------+--------+
|   4    | 2024-01-20 10:00:00 | MERGE     | {"predicate":     | user@  |
|        |                     |           |  "[s.id = t.id]"} | co.com |
+--------+---------------------+-----------+-------------------+--------+
|   3    | 2024-01-19 16:45:00 | UPDATE    | {"predicate":     | etl@   |
|        |                     |           |  "[status =       | co.com |
|        |                     |           |   'pending']"}    |        |
+--------+---------------------+-----------+-------------------+--------+
|   2    | 2024-01-19 09:15:00 | WRITE     | {"mode":          | etl@   |
|        |                     |           |  "Append"}        | co.com |
+--------+---------------------+-----------+-------------------+--------+
|   1    | 2024-01-18 22:00:00 | WRITE     | {"mode":          | etl@   |
|        |                     |           |  "Append"}        | co.com |
+--------+---------------------+-----------+-------------------+--------+
|   0    | 2024-01-18 10:00:00 | CREATE    | ...               | admin@ |
|        |                     | TABLE     |                   | co.com |
+--------+---------------------+-----------+-------------------+--------+
```

The output includes additional columns not shown above, such as:

- **operationMetrics**: Statistics like number of rows affected, bytes written, etc.
- **readVersion**: The version of the table that was read before the write.
- **isolationLevel**: The isolation level used (Serializable or WriteSerializable).
- **isBlindAppend**: Whether the write only appended data without reading any existing data.
- **engineInfo**: What engine and Delta Lake version performed the operation.

You can also limit the history:

```sql
-- Only show the last 10 versions
DESCRIBE HISTORY my_table LIMIT 10;
```

## VERSION AS OF Syntax

This is the most direct way to time travel. You specify the exact version number you want to query:

```sql
-- Query the table at version 3
SELECT * FROM my_table VERSION AS OF 3;

-- You can also use the @ syntax in the table path
SELECT * FROM delta.`/path/to/table@v3`;
```

In PySpark:

```python
# Using the version option
df = spark.read.format("delta") \
    .option("versionAsOf", 3) \
    .load("/path/to/delta-table")

# Using the DataFrame API
df = spark.read.format("delta") \
    .option("versionAsOf", 3) \
    .table("my_table")
```

This is incredibly useful when you need to:

- Compare data between two versions to see what changed
- Reproduce the exact results of an analysis that ran at a specific version
- Debug data issues by finding when a problem was introduced

```sql
-- Compare row counts between versions
SELECT 'version_3' as version, COUNT(*) as row_count FROM my_table VERSION AS OF 3
UNION ALL
SELECT 'version_5' as version, COUNT(*) as row_count FROM my_table VERSION AS OF 5;

-- Find rows that were deleted between version 3 and version 5
SELECT * FROM my_table VERSION AS OF 3
EXCEPT
SELECT * FROM my_table VERSION AS OF 5;
```

## TIMESTAMP AS OF Syntax

Sometimes you don't know the version number, but you know when the data was correct. You can
time travel using a timestamp:

```sql
-- Query the table as it was on January 19, 2024 at 3pm
SELECT * FROM my_table TIMESTAMP AS OF '2024-01-19T15:00:00';

-- You can also use date-only format
SELECT * FROM my_table TIMESTAMP AS OF '2024-01-19';
```

In PySpark:

```python
df = spark.read.format("delta") \
    .option("timestampAsOf", "2024-01-19T15:00:00") \
    .load("/path/to/delta-table")
```

When you specify a timestamp, Delta Lake finds the version that was current at that timestamp.
It does this by looking at the timestamps in the commit files. If the timestamp you specify falls
between two commits, Delta Lake uses the version from the earlier commit (the one that was current
at that time).

```
Timestamp mapping:

  Commit 2          Commit 3          Commit 4
  10:00 AM          2:00 PM           6:00 PM
     |                 |                 |
     v                 v                 v
-----+--------+--------+--------+-------+-------> time
              |                 |
          Query at           Query at
          12:00 PM           4:00 PM
          = Version 2        = Version 3
          (latest commit     (latest commit
           before 12:00)      before 4:00)
```

## The RESTORE Command

Time travel is great for querying historical data, but what if you actually want to roll back the
table to a previous version? That's where the RESTORE command comes in.

```sql
-- Restore the table to version 3
RESTORE TABLE my_table TO VERSION AS OF 3;

-- Restore to a timestamp
RESTORE TABLE my_table TO TIMESTAMP AS OF '2024-01-19T15:00:00';
```

Important: RESTORE doesn't delete the versions between the current version and the restore point.
Instead, it creates a NEW version that has the same state as the target version. So if you're at
version 5 and you restore to version 3, the table moves to version 6, but version 6 has the same
data as version 3.

```
Before RESTORE:

Version: 0 --- 1 --- 2 --- 3 --- 4 --- 5 (current)

After RESTORE TO VERSION AS OF 3:

Version: 0 --- 1 --- 2 --- 3 --- 4 --- 5 --- 6 (current)
                              |                    |
                              +--- same state -----+

Version 6 is a NEW commit that makes the table look
exactly like version 3. Versions 4 and 5 are not deleted.
```

This is an important distinction. The history is preserved. You can still query versions 4 and 5
after the restore. And DESCRIBE HISTORY will show the restore operation in the log.

The RESTORE command returns useful metrics:

```
+---------------------------+-------+
| table_size_after_restore  | 50 MB |
+---------------------------+-------+
| num_of_files_after_restore| 10    |
+---------------------------+-------+
| num_removed_files         | 5     |
+---------------------------+-------+
| num_restored_files        | 3     |
+---------------------------+-------+
```

## Practical Use Cases for Time Travel

### 1. Audit and Compliance

In regulated industries, you might need to prove what your data looked like at a specific point
in time. Time travel makes this trivial:

```sql
-- What did the customer data look like at the end of Q4?
SELECT * FROM customers
TIMESTAMP AS OF '2024-12-31T23:59:59';

-- How many active accounts did we report at the end of Q3?
SELECT COUNT(*) FROM accounts
TIMESTAMP AS OF '2024-09-30T23:59:59'
WHERE status = 'active';
```

### 2. Rollback After Bad Writes

Someone ran a bad ETL job that corrupted data? Roll it back:

```sql
-- Check what the table looked like before the bad write
DESCRIBE HISTORY my_table;
-- Find the version before the bad write (say it's version 10)

-- Restore to the good version
RESTORE TABLE my_table TO VERSION AS OF 10;
```

### 3. Reproduce ML Experiments

In machine learning, reproducibility is critical. You need to know exactly what data was used
to train a model:

```python
# Log the version used for training
table_version = spark.sql("SELECT max(version) FROM (DESCRIBE HISTORY training_data)").first()[0]
mlflow.log_param("data_version", table_version)

# Later, reproduce with the exact same data
training_df = spark.read.format("delta") \
    .option("versionAsOf", table_version) \
    .load("/path/to/training_data")
```

### 4. Debugging Data Pipelines

When downstream reports show unexpected numbers, time travel helps you find when the problem
was introduced:

```sql
-- Binary search through versions to find when the issue started
SELECT COUNT(*) as row_count, SUM(amount) as total
FROM orders VERSION AS OF 10;

SELECT COUNT(*) as row_count, SUM(amount) as total
FROM orders VERSION AS OF 15;

-- Found that version 13 is where things went wrong
SELECT * FROM orders VERSION AS OF 13
EXCEPT
SELECT * FROM orders VERSION AS OF 12;
-- Now you can see exactly what changed in version 13
```

### 5. Creating Consistent Snapshots for Downstream Processing

When multiple tables need to be read at a consistent point in time:

```python
# Read all tables at the same version/timestamp for consistency
orders = spark.read.format("delta") \
    .option("timestampAsOf", "2024-01-20T00:00:00") \
    .load("/data/orders")

customers = spark.read.format("delta") \
    .option("timestampAsOf", "2024-01-20T00:00:00") \
    .load("/data/customers")

products = spark.read.format("delta") \
    .option("timestampAsOf", "2024-01-20T00:00:00") \
    .load("/data/products")
```

## CONCEPT GAP: Time Travel Retention Period

Time travel isn't free. It requires keeping old data files and transaction log entries around.
By default, Delta Lake keeps data files for 7 days and log entries for 30 days, but these are
separate configurations that interact in nuanced ways.

The key retention settings:

```
+------------------------------------------+------------+---------+
| Property                                 | Default    | Affects |
+==========================================+============+=========+
| delta.logRetentionDuration               | 30 days    | Log     |
|   (interval string, e.g., "interval     |            | entries |
|    30 days")                             |            |         |
+------------------------------------------+------------+---------+
| delta.deletedFileRetentionDuration       | 7 days     | Data    |
|   (interval string, e.g., "interval     |            | files   |
|    7 days")                              |            |         |
+------------------------------------------+------------+---------+
```

These defaults mean:

- Transaction log entries are kept for 30 days. You can query DESCRIBE HISTORY going back 30 days.
- Deleted data files are eligible for removal by VACUUM after 7 days.

But here's the catch: even if log entries exist for 30 days, time travel to an old version will
fail if VACUUM has already removed the data files needed for that version. So the effective time
travel window is controlled by BOTH settings.

```
+------------------------------------------------------------------+
|             TIME TRAVEL AVAILABILITY                             |
|                                                                  |
|  |<---------- 30 days (log retention) ---------->|               |
|  |<--- 7 days (file retention) --->|             |               |
|  |                                 |             |               |
|  |  Data files   |  Data files     |  Log entries|               |
|  |  may be       |  guaranteed     |  exist but  |  No time      |
|  |  vacuumed     |  to exist       |  data files |  travel       |
|  |               |  (if no VACUUM) |  may be gone|  possible     |
|  |               |                 |             |               |
+------------------------------------------------------------------+
|                                                                  |
|  Effective time travel window = min(logRetention, fileRetention) |
|                                                                  |
|  With defaults: effectively 7 days (limited by VACUUM)           |
|  (assuming VACUUM is run regularly)                              |
+------------------------------------------------------------------+
```

To extend the time travel window, you need to adjust BOTH settings:

```sql
-- Extend both to 90 days for full 90-day time travel support
ALTER TABLE my_table SET TBLPROPERTIES (
    'delta.logRetentionDuration' = 'interval 90 days',
    'delta.deletedFileRetentionDuration' = 'interval 90 days'
);
```

Keep in mind that longer retention means more storage costs, since old data files won't be cleaned
up by VACUUM.

## CONCEPT GAP: VACUUM Interaction with Time Travel

VACUUM is the command that physically removes old data files that are no longer needed:

```sql
-- Remove files no longer referenced and older than default retention (7 days)
VACUUM my_table;

-- Remove files older than 24 hours (not recommended for production)
VACUUM my_table RETAIN 24 HOURS;

-- Dry run to see what would be deleted
VACUUM my_table DRY RUN;
```

The critical interaction between VACUUM and time travel:

```
Before VACUUM:
+------------------------------------------------------+
| Data files on disk:                                  |
|                                                      |
| file_a.parquet (added v0, removed v2) -- OLD         |
| file_b.parquet (added v1, still active)              |
| file_c.parquet (added v1, still active)              |
| file_d.parquet (added v2, still active)              |
| file_e.parquet (added v3, removed v4) -- OLD         |
| file_f.parquet (added v4, still active)              |
|                                                      |
| Time travel to v0: reads file_a         -- WORKS     |
| Time travel to v1: reads file_a,b,c     -- WORKS     |
| Time travel to v3: reads file_b,c,d,e   -- WORKS     |
+------------------------------------------------------+

After VACUUM (assuming files a and e are older than retention):
+------------------------------------------------------+
| Data files on disk:                                  |
|                                                      |
| file_b.parquet (added v1, still active)              |
| file_c.parquet (added v1, still active)              |
| file_d.parquet (added v2, still active)              |
| file_f.parquet (added v4, still active)              |
|                                                      |
| Time travel to v0: FAILS (file_a deleted)            |
| Time travel to v1: FAILS (file_a deleted)            |
| Time travel to v3: FAILS (file_e deleted)            |
| Current version (v4): reads file_b,c,d,f -- WORKS    |
+------------------------------------------------------+
```

This is why VACUUM is a dangerous operation from a time travel perspective. Once you vacuum, you
permanently lose the ability to time travel to versions that depend on the deleted files. Always
use `VACUUM DRY RUN` first to see what would be deleted, and never set the retention period lower
than 7 days without understanding the consequences.

Delta Lake has a safety check that prevents you from vacuuming files newer than 7 days by default.
You can override this, but Databricks strongly discourages it:

```sql
-- This will FAIL by default (retention too short)
VACUUM my_table RETAIN 0 HOURS;

-- To override the safety check (DANGEROUS):
SET spark.databricks.delta.retentionDurationCheck.enabled = false;
VACUUM my_table RETAIN 0 HOURS;
```

## CONCEPT GAP: delta.logRetentionDuration vs delta.deletedFileRetentionDuration

This distinction trips people up, so let's be very clear:

**delta.logRetentionDuration** (default: 30 days)
- Controls how long TRANSACTION LOG entries (the JSON files in `_delta_log/`) are retained.
- After this period, old JSON commit files and old checkpoint files are eligible for cleanup.
- Cleanup happens automatically during checkpoint creation, not on a schedule.
- Affects: `DESCRIBE HISTORY` output, ability to reconstruct old versions from the log.

**delta.deletedFileRetentionDuration** (default: 7 days)
- Controls how long VACUUM retains deleted DATA files (the Parquet files outside `_delta_log/`).
- VACUUM will not delete files that were removed less than this duration ago.
- Cleanup only happens when you explicitly run VACUUM (it's not automatic).
- Affects: ability to actually READ old versions of the table.

The relationship:

```
+-------------------------------------------------------+
|  For time travel to work, you need BOTH:              |
|                                                       |
|  1. Transaction log entries (to know WHICH files      |
|     to read for that version)                         |
|     --> Controlled by delta.logRetentionDuration      |
|                                                       |
|  2. Data files (to actually READ the data)            |
|     --> Controlled by delta.deletedFileRetention      |
|         Duration (and when you run VACUUM)             |
|                                                       |
|  If either is missing, time travel fails.             |
+-------------------------------------------------------+
```

Common scenarios:

```
Scenario 1: Log retained, files vacuumed
  - DESCRIBE HISTORY shows the old version
  - But querying that version FAILS because data files are gone
  - Error: "The data files for this version have been deleted"

Scenario 2: Log cleaned up, files still on disk
  - DESCRIBE HISTORY does NOT show the old version
  - You can't even specify the version number because
    Delta Lake doesn't know it existed
  - The data files are orphaned (no log references them)
  - VACUUM will eventually clean them up

Scenario 3: Both log and files retained
  - Time travel works perfectly
  - You can query any version in the retained window
```

For production systems where you need a specific time travel window, always set BOTH properties
to the same value:

```sql
ALTER TABLE my_table SET TBLPROPERTIES (
    'delta.logRetentionDuration' = 'interval 60 days',
    'delta.deletedFileRetentionDuration' = 'interval 60 days'
);
```

And make sure you're not running VACUUM more aggressively than your retention settings.

## Interview Q&A

**Q: What is time travel in Delta Lake, and how does it work?**
A: Time travel is the ability to query previous versions of a Delta table. Every write operation
creates a new version in the transaction log. To time travel, Delta Lake replays the transaction
log up to the requested version to determine which data files were active at that point, then reads
those files. You can query by version number using `VERSION AS OF` or by timestamp using
`TIMESTAMP AS OF`. This works because Delta Lake keeps old data files on disk (until VACUUM removes
them) and maintains an ordered history of changes in the transaction log.

**Q: What is the difference between VERSION AS OF and TIMESTAMP AS OF?**
A: `VERSION AS OF` lets you query a specific version number (e.g., `SELECT * FROM t VERSION AS OF 5`).
`TIMESTAMP AS OF` lets you query the table as it was at a specific point in time (e.g.,
`SELECT * FROM t TIMESTAMP AS OF '2024-01-15'`). When using TIMESTAMP AS OF, Delta Lake finds the
latest version whose commit timestamp is at or before the specified timestamp. VERSION AS OF is
useful when you know the exact version, while TIMESTAMP AS OF is useful when you know the date/time
of interest.

**Q: How does the RESTORE command work, and does it delete history?**
A: RESTORE creates a new version of the table that has the same state as the target version. For
example, if you're at version 5 and RESTORE to version 3, a new version 6 is created with the
same data as version 3. Importantly, RESTORE does NOT delete history -- versions 4 and 5 still
exist and can still be queried via time travel. The RESTORE operation itself is recorded in the
transaction log as another commit, maintaining the complete audit trail.

**Q: What are the default retention periods for time travel, and how do they interact?**
A: There are two separate retention settings: `delta.logRetentionDuration` (default 30 days) which
controls how long transaction log entries are kept, and `delta.deletedFileRetentionDuration`
(default 7 days) which controls how long VACUUM retains deleted data files. Time travel requires
BOTH the log entries (to know which files to read) AND the data files (to actually read the data).
The effective time travel window is the minimum of these two values -- with defaults, it's
effectively 7 days if VACUUM is run regularly.

**Q: What happens if you try to time travel to a version whose data files have been vacuumed?**
A: The query will fail with an error indicating that the data files referenced by that version no
longer exist. Even though the transaction log entry may still exist (if within the log retention
period), Delta Lake cannot read the actual data because VACUUM has physically deleted the Parquet
files. This is why it's important to align your VACUUM retention period with your time travel needs
and always use `VACUUM DRY RUN` before running VACUUM in production.

**Q: How would you use time travel to debug a data pipeline issue?**
A: I would use DESCRIBE HISTORY to see the recent operations on the table and identify suspicious
changes. Then I'd compare data across versions using queries like `SELECT * FROM table VERSION AS OF N
EXCEPT SELECT * FROM table VERSION AS OF (N-1)` to see exactly what changed in each version. This
binary-search approach helps pinpoint the exact version where the problem was introduced. Once
identified, I can examine the commit info (operation, user, parameters) to understand what caused
the issue, and if needed, RESTORE the table to a known good version.

**Q: Can you use time travel with streaming reads on a Delta table?**
A: Yes. When using Delta Lake as a streaming source, you can specify a starting version or timestamp
using the `startingVersion` or `startingTimestamp` options. This allows the stream to process only
changes made after a specific point in time, which is useful for replaying or catching up a stream.
For example: `spark.readStream.format("delta").option("startingVersion", 5).load(path)`. The stream
will process all changes from version 5 onward.

**Q: What is the DESCRIBE HISTORY command, and what information does it provide?**
A: DESCRIBE HISTORY returns a table showing the complete history of operations performed on a
Delta table, one row per version. Each row includes: the version number, timestamp, operation type
(WRITE, UPDATE, DELETE, MERGE, etc.), operation parameters (like predicates and modes), user info,
operation metrics (rows affected, bytes written), isolation level, engine info, and whether it was
a blind append. This is invaluable for auditing, compliance, and debugging. You can limit the
output with the LIMIT clause.
