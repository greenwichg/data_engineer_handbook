# Remove Unused Files - VACUUM

## Introduction

Alright, let's talk about VACUUM -- one of the most important maintenance commands in Delta Lake.
If you've been following along through the Delta Lake lessons, you know that Delta Lake never
modifies or deletes files in place. When you UPDATE, DELETE, MERGE, or OPTIMIZE, Delta Lake writes
new files and marks old files as removed in the transaction log. But those old files are still
sitting on disk, taking up storage space.

Over time, this can add up significantly. A table that gets updated daily might have 10x its
actual data size in obsolete files. VACUUM is the command that cleans up these obsolete files and
reclaims storage space. But you need to use it carefully, because once you vacuum files, you lose
the ability to time travel to versions that depend on those files.

## Why Files Accumulate

Let's trace through why files accumulate in Delta Lake:

```
File Accumulation Over Time:

Version 0: CREATE TABLE
  Files: [A.parquet, B.parquet]               Total: 2 files

Version 1: UPDATE (modifies rows in A)
  Files: [A.parquet(removed), B.parquet, C.parquet(new)]
  On disk: A, B, C                            Total: 3 files

Version 2: DELETE (removes rows from B)
  Files: [B.parquet(removed), C.parquet, D.parquet(new)]
  On disk: A, B, C, D                         Total: 4 files

Version 3: OPTIMIZE
  Files: [C.parquet(removed), D.parquet(removed), E.parquet(new)]
  On disk: A, B, C, D, E                      Total: 5 files

Current version uses ONLY: E.parquet
Obsolete files on disk: A, B, C, D  (4 files wasting storage!)
```

```
+====================================================================+
|                FILES ON DISK vs ACTIVE FILES                       |
+====================================================================+
|                                                                    |
|  Transaction Log says:                                             |
|  "Current table = [E.parquet]"                                     |
|                                                                    |
|  Disk actually has:                                                |
|  [A.parquet] [B.parquet] [C.parquet] [D.parquet] [E.parquet]       |
|       |           |           |           |           |            |
|    obsolete    obsolete    obsolete    obsolete    ACTIVE           |
|                                                                    |
|  VACUUM removes the obsolete files:                                |
|  [A.parquet] [B.parquet] [C.parquet] [D.parquet]  --> DELETED      |
|                                                                    |
|  After VACUUM:                                                     |
|  [E.parquet]  --> Only active file remains                         |
|                                                                    |
+====================================================================+
```

## VACUUM Command

### Basic Syntax

```sql
-- VACUUM with default retention (7 days)
VACUUM my_table;

-- VACUUM with custom retention period (in hours)
VACUUM my_table RETAIN 168 HOURS;  -- 7 days = 168 hours

-- VACUUM with custom retention (in days via interval)
VACUUM my_table RETAIN 720 HOURS;  -- 30 days

-- Dry run: see what would be deleted without actually deleting
VACUUM my_table DRY RUN;

-- Dry run with custom retention
VACUUM my_table RETAIN 168 HOURS DRY RUN;
```

### How VACUUM Works

```
VACUUM Execution Flow:

+-------------------------------------------+
|  1. Determine retention threshold         |
|     - Default: 7 days (168 hours)         |
|     - Or custom RETAIN value              |
|     - Files older than threshold are      |
|       eligible for deletion               |
+-------------------------------------------+
            |
            v
+-------------------------------------------+
|  2. List all files on disk                |
|     - Scan the table directory            |
|     - Include all Parquet files           |
+-------------------------------------------+
            |
            v
+-------------------------------------------+
|  3. Identify files NOT in current version |
|     - Check transaction log               |
|     - Files not referenced by any commit  |
|       within retention period = eligible  |
+-------------------------------------------+
            |
            v
+-------------------------------------------+
|  4. Delete eligible files                 |
|     - Remove obsolete files from disk     |
|     - This is PERMANENT and IRREVERSIBLE  |
+-------------------------------------------+
```

### The Retention Period

The retention period is critical. It controls how far back in time you can travel after VACUUM
runs. Any file that was removed from the transaction log more than the retention period ago is
eligible for deletion.

```
Retention Period Visualization:

         Retention Period (7 days default)
         |<──────────────────────────────>|
         |                                |
─────────+────────────────────────────────+──────────>
   Past                              Now       Time

Files removed BEFORE                Files removed AFTER
this point:                         this point:
  --> ELIGIBLE for VACUUM             --> PROTECTED from VACUUM
  --> Will be deleted                 --> Still needed for time travel
```

### Default Retention: 7 Days

The default retention period is 7 days (168 hours). This means:

- You can time travel to any version within the last 7 days
- Files older than 7 days that are not part of the current table version will be deleted
- This default is controlled by the table property `delta.deletedFileRetentionDuration`

```sql
-- Change default retention for a table
ALTER TABLE my_table SET TBLPROPERTIES (
    'delta.deletedFileRetentionDuration' = 'interval 30 days'
);
```

## VACUUM Safety Checks

Delta Lake has a built-in safety check that prevents you from running VACUUM with a retention
period shorter than the default (7 days). This protects against accidentally deleting files that
concurrent readers might still need.

```sql
-- This will FAIL with an error:
VACUUM my_table RETAIN 0 HOURS;
-- Error: RETAIN value must be >= delta.deletedFileRetentionDuration (168 hours)

-- To override the safety check (USE WITH EXTREME CAUTION):
SET spark.databricks.delta.retentionDurationCheck.enabled = false;
VACUUM my_table RETAIN 0 HOURS;
```

**Warning**: Disabling the retention duration check is dangerous in production environments. If you
vacuum with a retention of 0 hours while other queries are running, those queries might fail because
the files they need have been deleted.

```
Why the Safety Check Exists:

+-------------------------------------------+
|  Reader starts a long-running query       |
|  at version 5 (reads files A, B, C)       |
+-------------------------------------------+
        |
        |  Meanwhile...
        v
+-------------------------------------------+
|  Writer creates version 6                 |
|  (removes file A, adds file D)            |
+-------------------------------------------+
        |
        |  If VACUUM runs with 0 retention...
        v
+-------------------------------------------+
|  VACUUM deletes file A from disk          |
+-------------------------------------------+
        |
        v
+-------------------------------------------+
|  Reader tries to read file A              |
|  --> FILE NOT FOUND ERROR!                |
|  --> Query fails!                         |
+-------------------------------------------+
```

## VACUUM and Time Travel

VACUUM directly impacts time travel capabilities. Once files are vacuumed, you can no longer
access versions that depend on those files.

```sql
-- Before VACUUM: All versions accessible
SELECT * FROM my_table VERSION AS OF 1;   -- Works
SELECT * FROM my_table VERSION AS OF 5;   -- Works
SELECT * FROM my_table VERSION AS OF 10;  -- Works (current)

-- After VACUUM RETAIN 168 HOURS:
-- Versions older than 7 days that need vacuumed files:
SELECT * FROM my_table VERSION AS OF 1;   -- ERROR: files deleted
SELECT * FROM my_table VERSION AS OF 5;   -- May work (depends on timing)
SELECT * FROM my_table VERSION AS OF 10;  -- Works (current version)
```

**Important**: VACUUM deletes files, but it does NOT delete the transaction log entries. The log
entries still exist (governed by `delta.logRetentionDuration`), but the data files they reference
may no longer exist. So time travel will fail with a "file not found" error even though the version
is listed in DESCRIBE HISTORY.

## VACUUM vs Log Retention

These are two separate retention concepts that are often confused:

| Concept | Property | Default | What It Controls |
|---------|----------|---------|-----------------|
| **VACUUM retention** | `delta.deletedFileRetentionDuration` | 7 days | How long deleted data files are kept on disk |
| **Log retention** | `delta.logRetentionDuration` | 30 days | How long transaction log entries are kept |

```
Two Retention Periods:

                    Log Retention (30 days)
|<──────────────────────────────────────────────────────>|
|                                                        |
|          VACUUM Retention (7 days)                     |
|                              |<───────────────────────>|
|                              |                         |
──+────────────────────────────+─────────────────────────+──>
  |                            |                         |
  Log entries may              Data files are            Now
  be cleaned up                protected from
  after 30 days                VACUUM for 7 days
```

For time travel to work, you need BOTH:
1. The transaction log entry (controlled by log retention)
2. The data files referenced by that entry (controlled by VACUUM retention)

## DRY RUN

Always use DRY RUN first to see what VACUUM would delete before actually deleting:

```sql
-- See what files would be deleted
VACUUM my_table DRY RUN;

-- Output shows list of files that would be removed
-- and the total size that would be reclaimed
```

This is especially important when running VACUUM for the first time on a table that has
accumulated a lot of history.

## PySpark Usage

```python
from delta.tables import DeltaTable

# Load the Delta table
delta_table = DeltaTable.forName(spark, "my_table")

# VACUUM with default retention
delta_table.vacuum()

# VACUUM with custom retention (in hours)
delta_table.vacuum(168)  # 7 days
```

---

## CONCEPT GAP: VACUUM and External Tables

VACUUM behaves the same way for both managed and external tables -- it deletes obsolete data files
from the table's storage location. However, there's an important consideration for external tables:

- For **managed tables**: VACUUM cleans up files in the Databricks-managed storage location.
  If you DROP the table, all files are deleted anyway.
- For **external tables**: VACUUM cleans up files at the external location you specified.
  If you DROP the table, the data files remain but are no longer tracked. Running VACUUM before
  dropping ensures you're not leaving excessive obsolete files in your external storage.

Another important scenario: **orphaned files**. Sometimes files exist in the table directory but
are not referenced by any version of the transaction log (e.g., from a failed write that crashed
before committing). VACUUM will also clean up these orphaned files.

---

## KEY INTERVIEW QUESTIONS AND ANSWERS

### Q1: What is VACUUM in Delta Lake and why is it needed?
**A:** VACUUM is a maintenance command that permanently deletes obsolete data files from disk. It's needed because Delta Lake never modifies files in place -- operations like UPDATE, DELETE, MERGE, and OPTIMIZE create new files and mark old files as removed in the transaction log. Without VACUUM, these obsolete files accumulate and waste storage space.

### Q2: What is the default retention period for VACUUM?
**A:** The default retention period is 7 days (168 hours), controlled by the table property `delta.deletedFileRetentionDuration`. This means VACUUM will only delete files that were marked as removed more than 7 days ago. This default protects concurrent readers and preserves time travel for at least 7 days.

### Q3: How does VACUUM affect time travel?
**A:** Once VACUUM deletes obsolete files, you can no longer time travel to versions that depend on those files. The transaction log entries may still exist (governed by log retention), but the data files they reference are gone, so time travel queries will fail with "file not found" errors. Only versions within the VACUUM retention window and the current version remain accessible.

### Q4: What is the difference between VACUUM retention and log retention?
**A:** VACUUM retention (`delta.deletedFileRetentionDuration`, default 7 days) controls how long deleted data files are kept on disk. Log retention (`delta.logRetentionDuration`, default 30 days) controls how long transaction log entries are kept. For time travel to work, you need both the log entry and the data files it references.

### Q5: Why does Delta Lake prevent VACUUM with retention less than 7 days?
**A:** The safety check prevents accidentally deleting files that concurrent readers might still need. A long-running query that started reading files before VACUUM runs could fail with "file not found" errors if those files are deleted mid-query. You can disable this check with `spark.databricks.delta.retentionDurationCheck.enabled = false`, but this is dangerous in production.

### Q6: What is VACUUM DRY RUN?
**A:** DRY RUN shows which files VACUUM would delete and the total storage that would be reclaimed, without actually deleting anything. It's a safety practice to preview the impact of VACUUM before running it, especially important for tables with significant history or in production environments.

### Q7: Does VACUUM delete transaction log files?
**A:** No, VACUUM only deletes obsolete data files (Parquet files). Transaction log files are managed separately and cleaned up based on the `delta.logRetentionDuration` property (default 30 days). Delta Lake automatically creates checkpoint files and cleans up old log entries independently of VACUUM.

### Q8: How do orphaned files get created and how are they cleaned up?
**A:** Orphaned files are created when a write operation crashes before committing to the transaction log -- the data files are written to disk but never referenced by any commit. VACUUM cleans up these orphaned files because they are not referenced by any version of the table and are older than the retention period.

---
