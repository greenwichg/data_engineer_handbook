# Compaction - OPTIMIZE and ZORDER

## Introduction

Alright, let's talk about one of the most important performance optimization techniques in Delta
Lake -- compaction. If you've been working with Delta tables for a while, you've probably noticed
that tables can accumulate a lot of small files over time, especially with streaming workloads or
frequent small batch writes. These small files are a performance killer. Every time you run a query,
the engine has to open and read each file, and when you have thousands of tiny files instead of a
few large ones, that overhead adds up fast.

This is where OPTIMIZE comes in. OPTIMIZE is Delta Lake's compaction command -- it combines small
files into larger, more efficient files. And when you pair OPTIMIZE with ZORDER, you get data
co-location, which means related data gets stored together for faster query filtering. Let's break
it all down.

## The Small Files Problem

Before we dive into the solution, let's understand the problem clearly.

```
The Small Files Problem:

BEFORE OPTIMIZE:
+-----+ +-----+ +-----+ +-----+ +-----+ +-----+ +-----+ +-----+
| 2MB | | 5MB | | 1MB | | 3MB | | 800K| | 4MB | | 2MB | | 1MB |
+-----+ +-----+ +-----+ +-----+ +-----+ +-----+ +-----+ +-----+
+-----+ +-----+ +-----+ +-----+ +-----+ +-----+ +-----+ +-----+
| 6MB | | 500K| | 3MB | | 2MB | | 1MB | | 4MB | | 3MB | | 2MB |
+-----+ +-----+ +-----+ +-----+ +-----+ +-----+ +-----+ +-----+

Total: 16 files, ~40MB, lots of overhead per file

AFTER OPTIMIZE:
+============+ +============+
|   512 MB   | |   512 MB   |
+============+ +============+

Total: 2 files, ~40MB, minimal overhead
(Target file size is typically 1 GB in production)
```

Small files cause performance problems because:
- **File listing overhead**: The engine must list and open each file separately
- **Metadata overhead**: Each file has its own footer with schema and statistics
- **Poor compression**: Small files can't take advantage of columnar compression
- **Excessive I/O**: More network round trips to cloud storage

## OPTIMIZE Command

OPTIMIZE is the compaction command that solves the small files problem. It reads small files,
combines them into larger files, and updates the transaction log.

### Basic Syntax

```sql
-- Optimize an entire table
OPTIMIZE my_table;

-- Optimize a specific partition
OPTIMIZE my_table WHERE region = 'US';

-- Optimize with a date filter on a partitioned table
OPTIMIZE events WHERE event_date >= '2025-01-01';
```

### How OPTIMIZE Works

```
OPTIMIZE Execution Flow:

+-------------------------------------------+
|  1. Identify small files                  |
|     - Scan the table (or partition)       |
|     - Find files below target size        |
|     - Group files for compaction          |
+-------------------------------------------+
            |
            v
+-------------------------------------------+
|  2. Read and merge small files            |
|     - Read data from identified files     |
|     - Combine into larger DataFrames      |
+-------------------------------------------+
            |
            v
+-------------------------------------------+
|  3. Write new compacted files             |
|     - Write larger Parquet files          |
|     - Target size: ~1 GB per file         |
|     - Files are written with optimal      |
|       compression and statistics          |
+-------------------------------------------+
            |
            v
+-------------------------------------------+
|  4. Update transaction log                |
|     - Add new compacted files             |
|     - Remove old small files              |
|     - Single atomic commit                |
+-------------------------------------------+
            |
            v
+-------------------------------------------+
|  5. Old files remain on disk              |
|     - Available for time travel           |
|     - Removed by VACUUM later             |
+-------------------------------------------+
```

### OPTIMIZE Output

When you run OPTIMIZE, it returns metrics about what it did:

```sql
OPTIMIZE my_table;

-- Returns:
-- path                    | metrics
-- ----------------------- | -----------------------------------------------
-- dbfs:/user/.../my_table | {numFilesAdded: 5, numFilesRemoved: 150,
--                         |  numBatches: 1, totalConsideredFiles: 150,
--                         |  totalFilesSkipped: 0,
--                         |  preserveInsertionOrder: false, ...}
```

## ZORDER BY

ZORDER is a data co-location technique used with OPTIMIZE. When you ZORDER by a column, Delta Lake
rearranges the data so that rows with similar values in the ZORDER column are stored together in the
same files. This dramatically improves query performance when filtering on that column because the
engine can skip entire files that don't contain relevant values.

### Basic Syntax

```sql
-- OPTIMIZE with ZORDER on a single column
OPTIMIZE my_table ZORDER BY (customer_id);

-- OPTIMIZE with ZORDER on multiple columns
OPTIMIZE my_table ZORDER BY (customer_id, product_category);

-- OPTIMIZE a specific partition with ZORDER
OPTIMIZE my_table WHERE region = 'US' ZORDER BY (order_date);
```

### How ZORDER Works

```
Without ZORDER (data scattered across files):

File 1: customer_id = [1, 50, 23, 99, 5, 72, 34, 88]
File 2: customer_id = [45, 12, 67, 3, 91, 28, 55, 76]
File 3: customer_id = [19, 84, 41, 7, 63, 36, 92, 15]

Query: SELECT * FROM table WHERE customer_id = 23
--> Must scan ALL files (no file can be skipped)

With ZORDER BY (customer_id):

File 1: customer_id = [1, 3, 5, 7, 12, 15, 19, 23]    min=1,  max=23
File 2: customer_id = [28, 34, 36, 41, 45, 50, 55, 63] min=28, max=63
File 3: customer_id = [67, 72, 76, 84, 88, 91, 92, 99] min=67, max=99

Query: SELECT * FROM table WHERE customer_id = 23
--> Only reads File 1 (files 2 and 3 are SKIPPED via data skipping)
```

### Data Skipping with ZORDER

ZORDER works hand-in-hand with Delta Lake's **data skipping** feature. Delta Lake stores min/max
statistics for each column in each file. When you run a query with a filter, the engine checks
these statistics and skips files that can't possibly contain matching rows.

Without ZORDER, values are randomly distributed across files, so min/max ranges overlap heavily
and few files can be skipped. With ZORDER, values are co-located, creating tight min/max ranges
that enable maximum file skipping.

```
Data Skipping with ZORDER:

+------------------------------------------------------+
|  Transaction Log Statistics (per file)               |
+------------------------------------------------------+
|  File 1: customer_id  min=1,    max=23               |
|  File 2: customer_id  min=28,   max=63               |
|  File 3: customer_id  min=67,   max=99               |
+------------------------------------------------------+

Query: WHERE customer_id BETWEEN 30 AND 50

File 1: max=23  < 30   --> SKIP (no matching rows possible)
File 2: min=28, max=63 --> READ (range overlaps)
File 3: min=67  > 50   --> SKIP (no matching rows possible)

Result: Only 1 out of 3 files read = 66% data skipped
```

## ZORDER Best Practices

### Choosing ZORDER Columns

| Good ZORDER Candidates | Poor ZORDER Candidates |
|----------------------|----------------------|
| High cardinality columns | Low cardinality columns (< 100 values) |
| Frequently used in WHERE clauses | Rarely filtered on |
| Not already a partition column | Already used for partitioning |
| Join keys | Columns used only in SELECT |

**Important**: Don't ZORDER by a column you're already partitioning on. Partitioning already
physically separates data by that column, so ZORDER on the same column is redundant.

### Number of ZORDER Columns

You can ZORDER by multiple columns, but the effectiveness decreases with each additional column.
The first column gets the strongest co-location, the second gets less, and so on.

**Recommendation**: ZORDER by 1-3 columns maximum. If you need to optimize for more columns,
consider Liquid Clustering instead (covered in the next lesson).

## OPTIMIZE Scheduling

OPTIMIZE is not automatic by default (unless you've enabled auto-compaction via table properties).
In production, you typically schedule OPTIMIZE to run at regular intervals.

```sql
-- Common pattern: Run OPTIMIZE on recent partitions after batch loads
OPTIMIZE events WHERE event_date >= current_date() - INTERVAL 7 DAYS
ZORDER BY (user_id, event_type);
```

### Auto-Optimization

You can enable automatic optimization through table properties:

```sql
ALTER TABLE my_table SET TBLPROPERTIES (
    'delta.autoOptimize.optimizeWrite' = 'true',   -- Coalesce during writes
    'delta.autoOptimize.autoCompact' = 'true'       -- Auto-compact after writes
);
```

- **optimizeWrite**: Coalesces small files during the write itself (prevents small files)
- **autoCompact**: Runs a lightweight compaction after writes (fixes small files)

Note: Auto-compaction runs a lighter version of OPTIMIZE and may not achieve the same level of
compaction as a manual OPTIMIZE with ZORDER.

---

## CONCEPT GAP: Predictive Optimization

Databricks offers **Predictive Optimization**, an intelligent system that automatically runs
OPTIMIZE and VACUUM on your Delta tables based on usage patterns. Instead of manually scheduling
these maintenance operations, Predictive Optimization monitors your tables and runs maintenance
when it determines it would be beneficial.

```sql
-- Enable Predictive Optimization at the catalog or schema level
ALTER CATALOG my_catalog ENABLE PREDICTIVE OPTIMIZATION;
ALTER SCHEMA my_schema ENABLE PREDICTIVE OPTIMIZATION;
```

Key benefits:
- Automatically identifies tables that need optimization
- Runs OPTIMIZE and VACUUM at optimal times
- Reduces manual maintenance overhead
- Available in Databricks Unity Catalog managed tables

This is a Databricks-specific feature (not part of open-source Delta Lake).

---

## KEY INTERVIEW QUESTIONS AND ANSWERS

### Q1: What is the small files problem and why does it matter?
**A:** The small files problem occurs when a Delta table accumulates many tiny files instead of fewer, larger files. This degrades query performance due to excessive file listing overhead, metadata processing, poor compression, and increased I/O round trips. It commonly happens with streaming workloads, frequent small batch writes, or over-partitioned tables.

### Q2: What does OPTIMIZE do in Delta Lake?
**A:** OPTIMIZE is a compaction command that combines small files into larger, more efficient files (targeting ~1 GB per file). It reads small files, merges them into larger Parquet files, writes the compacted files, and updates the transaction log in a single atomic commit. Old files remain on disk for time travel until VACUUM removes them.

### Q3: What is ZORDER and how does it improve query performance?
**A:** ZORDER is a data co-location technique used with OPTIMIZE that rearranges data so rows with similar values in the ZORDER columns are stored in the same files. This creates tight min/max statistics per file, enabling Delta Lake's data skipping feature to skip entire files that don't contain relevant values, dramatically reducing the amount of data scanned.

### Q4: How does data skipping work with ZORDER?
**A:** Delta Lake stores min/max statistics for each column in each file's metadata. When a query filters on a ZORDER column, the engine checks these statistics and skips files where the filter value falls outside the file's min/max range. ZORDER maximizes skipping effectiveness by ensuring values are tightly clustered within files, creating non-overlapping ranges.

### Q5: What columns should you choose for ZORDER?
**A:** Choose columns that have high cardinality, are frequently used in WHERE clauses or JOIN conditions, and are NOT already partition columns. Avoid low-cardinality columns (where partitioning is better) and columns rarely used for filtering. Limit ZORDER to 1-3 columns as effectiveness decreases with each additional column.

### Q6: What is the difference between optimizeWrite and autoCompact?
**A:** optimizeWrite coalesces small files during the write operation itself, preventing small files from being created. autoCompact runs a lightweight compaction after writes complete, fixing small files that were created. Both are enabled via table properties and help manage the small files problem automatically, though manual OPTIMIZE with ZORDER may still be needed periodically for optimal performance.

### Q7: Can you run OPTIMIZE on specific partitions only?
**A:** Yes, you can use a WHERE clause to limit OPTIMIZE to specific partitions: `OPTIMIZE my_table WHERE date_column >= '2025-01-01'`. This is a common production pattern -- you only optimize recent partitions where new data has been written, rather than optimizing the entire table each time.

### Q8: What is the relationship between OPTIMIZE and VACUUM?
**A:** OPTIMIZE creates new compacted files and logically removes old small files in the transaction log. VACUUM physically deletes the old files from disk after the retention period. They serve complementary purposes: OPTIMIZE improves performance by reducing file count, while VACUUM reclaims storage space by deleting obsolete files.

---
