# PySpark Implementation: Delta Lake Table Maintenance (VACUUM, OPTIMIZE)

## Problem Statement

Delta Lake tables accumulate old files over time from updates, deletes, and overwrites. Without regular maintenance, storage costs grow and query performance degrades. **VACUUM** removes old files, **OPTIMIZE** compacts small files, and **ZORDER** improves query performance through data co-location.

This is a critical topic for production data engineering roles and frequently asked in interviews about Delta Lake operations.

---

## Setup

```python
from pyspark.sql import SparkSession
from delta.tables import DeltaTable

spark = SparkSession.builder \
    .appName("DeltaMaintenance") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .getOrCreate()

# Create sample Delta table
data = [
    (1, "Alice", "Engineering", "2024-01-01"),
    (2, "Bob", "Sales", "2024-01-01"),
    (3, "Charlie", "HR", "2024-01-02"),
    (4, "Diana", "Engineering", "2024-01-02"),
    (5, "Eve", "Sales", "2024-01-03"),
]
df = spark.createDataFrame(data, ["id", "name", "department", "date"])
df.write.format("delta").mode("overwrite").save("/tmp/delta/employees")
```

---

## Method 1: OPTIMIZE (File Compaction)

```python
# OPTIMIZE compacts small files into larger files (target ~1 GB each)

# Using SQL
spark.sql("OPTIMIZE delta.`/tmp/delta/employees`")

# With ZORDER for query optimization
spark.sql("OPTIMIZE delta.`/tmp/delta/employees` ZORDER BY (department)")

# Using DeltaTable API
delta_table = DeltaTable.forPath(spark, "/tmp/delta/employees")
delta_table.optimize().executeCompaction()

# OPTIMIZE with ZORDER via API
delta_table.optimize().executeZOrderBy("department")

# OPTIMIZE a specific partition only
spark.sql("""
    OPTIMIZE delta.`/tmp/delta/employees`
    WHERE date = '2024-01-01'
    ZORDER BY (department)
""")
```

### When to OPTIMIZE

```
- After batch writes that create many small files
- After streaming jobs with frequent micro-batches
- When query performance degrades
- Typically run daily or after major ETL jobs
```

---

## Method 2: VACUUM (Remove Old Files)

```python
# VACUUM removes files no longer referenced by the Delta log
# Default retention: 7 days (168 hours)

# Using SQL
spark.sql("VACUUM delta.`/tmp/delta/employees`")

# With custom retention (30 days)
spark.sql("VACUUM delta.`/tmp/delta/employees` RETAIN 720 HOURS")

# Using DeltaTable API
delta_table = DeltaTable.forPath(spark, "/tmp/delta/employees")
delta_table.vacuum(168)  # hours

# DRY RUN first — see what files would be deleted
spark.sql("VACUUM delta.`/tmp/delta/employees` RETAIN 168 HOURS DRY RUN")

# WARNING: Setting retention < 7 days requires disabling safety check
spark.conf.set("spark.databricks.delta.retentionDurationCheck.enabled", "false")
spark.sql("VACUUM delta.`/tmp/delta/employees` RETAIN 0 HOURS")
# ⚠️ DANGEROUS: Breaks time travel for all versions
```

### VACUUM Safety

```
IMPORTANT:
- Never VACUUM with 0 hours retention in production
- Time travel WILL NOT WORK for versions older than retention period
- Running concurrent queries during VACUUM can fail if they reference old files
- Always do a DRY RUN first to see what will be deleted
```

---

## Method 3: DESCRIBE HISTORY (Audit Trail)

```python
# View table history — all operations performed on the table
spark.sql("DESCRIBE HISTORY delta.`/tmp/delta/employees`").show(truncate=False)

# Using API
delta_table = DeltaTable.forPath(spark, "/tmp/delta/employees")
history_df = delta_table.history()
history_df.select("version", "timestamp", "operation", "operationParameters").show()

# Output:
# +-------+--------------------+---------+---------------------+
# |version|           timestamp|operation|operationParameters  |
# +-------+--------------------+---------+---------------------+
# |      2|2024-01-03 10:30:00| OPTIMIZE|{predicate -> [], ..}|
# |      1|2024-01-02 09:00:00|    MERGE|{predicate -> ...}   |
# |      0|2024-01-01 08:00:00|    WRITE|{mode -> Overwrite}  |
# +-------+--------------------+---------+---------------------+

# Time travel — query a specific version
df_v0 = spark.read.format("delta").option("versionAsOf", 0).load("/tmp/delta/employees")
df_v0.show()

# Time travel by timestamp
df_old = spark.read.format("delta") \
    .option("timestampAsOf", "2024-01-01") \
    .load("/tmp/delta/employees")
```

---

## Method 4: DESCRIBE DETAIL (Table Metadata)

```python
# Check table size, file count, partition info
spark.sql("DESCRIBE DETAIL delta.`/tmp/delta/employees`").show(truncate=False)

# Key columns returned:
# - numFiles: current number of files
# - sizeInBytes: total size of the table
# - partitionColumns: partition scheme
# - minReaderVersion / minWriterVersion: protocol versions
```

---

## Method 5: Automated Maintenance Schedule

```python
from datetime import datetime

def run_delta_maintenance(table_path, zorder_cols=None, vacuum_hours=168):
    """Run standard maintenance on a Delta table."""
    delta_table = DeltaTable.forPath(spark, table_path)
    
    print(f"[{datetime.now()}] Starting maintenance for {table_path}")
    
    # Step 1: OPTIMIZE (compact small files)
    print("  Running OPTIMIZE...")
    if zorder_cols:
        delta_table.optimize().executeZOrderBy(*zorder_cols)
    else:
        delta_table.optimize().executeCompaction()
    
    # Step 2: VACUUM (remove old files)
    print(f"  Running VACUUM with {vacuum_hours}h retention...")
    delta_table.vacuum(vacuum_hours)
    
    # Step 3: Log results
    detail = spark.sql(f"DESCRIBE DETAIL delta.`{table_path}`").collect()[0]
    print(f"  Files: {detail['numFiles']}, Size: {detail['sizeInBytes'] / 1e6:.1f} MB")
    print(f"[{datetime.now()}] Maintenance complete")

# Run maintenance
run_delta_maintenance(
    table_path="/tmp/delta/employees",
    zorder_cols=["department"],
    vacuum_hours=168
)
```

---

## Method 6: Delta Table Properties

```python
# Set table properties for automatic optimization
spark.sql("""
    ALTER TABLE delta.`/tmp/delta/employees`
    SET TBLPROPERTIES (
        'delta.autoOptimize.optimizeWrite' = 'true',
        'delta.autoOptimize.autoCompact' = 'true',
        'delta.logRetentionDuration' = 'interval 30 days',
        'delta.deletedFileRetentionDuration' = 'interval 7 days'
    )
""")

# autoOptimize.optimizeWrite: Coalesces small writes into optimal file sizes
# autoOptimize.autoCompact: Automatically runs OPTIMIZE after writes
# logRetentionDuration: How long to keep transaction log entries
# deletedFileRetentionDuration: How long VACUUM retains deleted files
```

---

## Key Takeaways

| Operation | Purpose | Frequency | Default Retention |
|-----------|---------|-----------|-------------------|
| OPTIMIZE | Compact small files into ~1GB files | Daily or after large writes | N/A |
| ZORDER | Co-locate data for faster queries | With OPTIMIZE, on filter columns | N/A |
| VACUUM | Delete unreferenced old files | Weekly | 7 days (168 hours) |
| DESCRIBE HISTORY | Audit trail of all operations | Ad-hoc debugging | 30 days log retention |

## Interview Tips

1. **OPTIMIZE before VACUUM** — optimize first to compact, then vacuum to clean up
2. **VACUUM breaks time travel** — you cannot time-travel to versions older than the retention period
3. **Never VACUUM with 0 hours in production** — concurrent readers may fail
4. **ZORDER is different from partitioning** — partitioning splits directories, ZORDER organizes data within files
5. **autoOptimize** is the production answer for avoiding small files proactively
6. **Know the DRY RUN** option for VACUUM — always preview before deleting
