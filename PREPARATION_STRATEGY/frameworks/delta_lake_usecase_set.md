Excellent! Let me give you a **comprehensive deep dive into Delta Lake patterns** - this is critical for modern data engineering interviews, especially at companies using Databricks or building lakehouse architectures.

---

# **Delta Lake Patterns Deep Dive**

## **Table of Contents**
1. Delta Lake Fundamentals
2. ACID Transactions & Concurrency
3. Time Travel & Versioning
4. Merge/Upsert Patterns (CDC)
5. Schema Evolution
6. Optimization (OPTIMIZE, Z-ORDER, VACUUM)
7. Delete & Update Patterns
8. Streaming with Delta Lake
9. Common Interview Problems
10. Production Best Practices

---

## **PART 1: Delta Lake Fundamentals**

### **What is Delta Lake?**

```
Traditional Data Lake:
┌─────────────────────────────────────────┐
│ Parquet Files (Immutable)               │
│ ├── part-00000.parquet                  │
│ ├── part-00001.parquet                  │
│ └── part-00002.parquet                  │
│                                         │
│ Problems:                               │
│ ❌ No ACID transactions                 │
│ ❌ No schema enforcement                │
│ ❌ Difficult to update/delete           │
│ ❌ No time travel                       │
│ ❌ Slow metadata operations             │
└─────────────────────────────────────────┘

Delta Lake = Parquet + Transaction Log:
┌─────────────────────────────────────────┐
│ Delta Table                             │
│ ├── _delta_log/                         │
│ │   ├── 00000.json  ← Transaction log  │
│ │   ├── 00001.json                      │
│ │   └── 00002.json                      │
│ ├── part-00000.parquet                  │
│ ├── part-00001.parquet                  │
│ └── part-00002.parquet                  │
│                                         │
│ Benefits:                               │
│ ✓ ACID transactions                     │
│ ✓ Schema enforcement & evolution        │
│ ✓ Updates, deletes, merges              │
│ ✓ Time travel                           │
│ ✓ Fast metadata operations              │
└─────────────────────────────────────────┘
```

### **Creating Delta Tables**

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, current_timestamp
from delta import *

# Initialize Spark with Delta Lake
spark = SparkSession.builder \
    .appName("DeltaLakePatterns") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .getOrCreate()

# ✅ PATTERN 1: Create Delta table from DataFrame
df = spark.read.parquet("source_data.parquet")

df.write \
    .format("delta") \
    .mode("overwrite") \
    .save("/delta/table_path")

# ✅ PATTERN 2: Create with partitioning
df.write \
    .format("delta") \
    .partitionBy("year", "month") \
    .mode("overwrite") \
    .save("/delta/partitioned_table")

# ✅ PATTERN 3: Create managed table (Databricks/Unity Catalog)
df.write \
    .format("delta") \
    .mode("overwrite") \
    .saveAsTable("database.table_name")

# ✅ PATTERN 4: Create with SQL
spark.sql("""
    CREATE TABLE users (
        user_id BIGINT,
        name STRING,
        email STRING,
        created_at TIMESTAMP,
        country STRING
    )
    USING DELTA
    PARTITIONED BY (country)
    LOCATION '/delta/users'
""")

# ✅ PATTERN 5: Create from existing Parquet (CONVERT TO DELTA)
# One-time conversion
spark.sql("""
    CONVERT TO DELTA parquet.`/path/to/parquet`
    PARTITIONED BY (year INT, month INT)
""")
```

### **Reading Delta Tables**

```python
# ✅ PATTERN 1: Read as DataFrame
df = spark.read.format("delta").load("/delta/table_path")

# ✅ PATTERN 2: Read managed table
df = spark.table("database.table_name")

# ✅ PATTERN 3: Read with SQL
df = spark.sql("SELECT * FROM delta.`/delta/table_path`")

# ✅ PATTERN 4: Read specific version (time travel)
df = spark.read \
    .format("delta") \
    .option("versionAsOf", 5) \
    .load("/delta/table_path")

# ✅ PATTERN 5: Read as of timestamp
df = spark.read \
    .format("delta") \
    .option("timestampAsOf", "2024-01-01 00:00:00") \
    .load("/delta/table_path")
```

---

## **PART 2: ACID Transactions & Concurrency**

### **Understanding ACID in Delta Lake**

```python
"""
ACID Properties:

A - Atomicity: All or nothing writes
    ✓ Either entire batch succeeds or fails
    ✓ No partial writes visible to readers

C - Consistency: Schema enforcement
    ✓ Schema validation on write
    ✓ Data type enforcement

I - Isolation: Concurrent operations don't interfere
    ✓ Readers always see consistent snapshot
    ✓ Writers don't block readers

D - Durability: Committed changes are permanent
    ✓ Transaction log ensures durability
    ✓ Can recover from failures
"""

# ✅ PATTERN: Atomic batch write
from pyspark.sql.utils import AnalysisException

try:
    # This either fully succeeds or fully fails
    df.write \
        .format("delta") \
        .mode("append") \
        .save("/delta/table")
    print("Write succeeded atomically")
except AnalysisException as e:
    print(f"Write failed - no partial data written: {e}")
```

### **Concurrency Control**

```python
# ✅ PATTERN: Optimistic concurrency control

# Writer 1: Updates version 0 → 1
df1.write.format("delta").mode("append").save("/delta/table")

# Writer 2: Also tries to update version 0 → 1
# Delta Lake detects conflict and retries automatically
df2.write.format("delta").mode("append").save("/delta/table")

# Result: Writer 2 automatically retries on version 1 → 2

# ✅ PATTERN: Handle concurrent writes explicitly
from delta.tables import DeltaTable
from pyspark.sql.utils import AnalysisException

max_retries = 3
for attempt in range(max_retries):
    try:
        df.write \
            .format("delta") \
            .mode("append") \
            .save("/delta/table")
        break  # Success
    except AnalysisException as e:
        if "ConcurrentAppendException" in str(e) and attempt < max_retries - 1:
            print(f"Concurrent write detected, retrying... (attempt {attempt + 1})")
            time.sleep(2 ** attempt)  # Exponential backoff
        else:
            raise
```

### **Isolation Levels**

```python
# Delta Lake provides Snapshot Isolation by default

# Reader: Reads version 5
reader_df = spark.read.format("delta").load("/delta/table")
# Snapshot at version 5 is isolated

# Writer: Writes version 6 (concurrent with reader)
writer_df.write.format("delta").mode("append").save("/delta/table")

# Reader still sees version 5 (not version 6)
# No dirty reads, no non-repeatable reads

# ✅ PATTERN: Ensure readers see consistent snapshot
# Start long-running analytics job
snapshot_df = spark.read.format("delta").load("/delta/table")
snapshot_df.cache()  # Cache the snapshot

# Run multiple queries on same snapshot
count = snapshot_df.count()
stats = snapshot_df.groupBy("category").count()
# Both see same version, even if table is being updated
```

---

## **PART 3: Time Travel & Versioning**

### **Understanding Delta Versions**

```python
from delta.tables import DeltaTable

# ✅ PATTERN: View table history
delta_table = DeltaTable.forPath(spark, "/delta/table")
history_df = delta_table.history()

history_df.select("version", "timestamp", "operation", "operationMetrics").show()

"""
+-------+--------------------+---------+--------------------+
|version|timestamp           |operation|operationMetrics    |
+-------+--------------------+---------+--------------------+
|5      |2024-02-08 14:30:00 |MERGE    |{numTargetRows: 1M} |
|4      |2024-02-08 12:00:00 |OPTIMIZE |{numFiles: 100}     |
|3      |2024-02-08 10:00:00 |UPDATE   |{numUpdated: 5000}  |
|2      |2024-02-07 20:00:00 |DELETE   |{numDeleted: 1000}  |
|1      |2024-02-07 18:00:00 |WRITE    |{numFiles: 50}      |
|0      |2024-02-07 15:00:00 |CREATE   |{}                  |
+-------+--------------------+---------+--------------------+
"""

# ✅ PATTERN: Read specific version
version_3 = spark.read \
    .format("delta") \
    .option("versionAsOf", 3) \
    .load("/delta/table")

# ✅ PATTERN: Read as of timestamp
jan_1_data = spark.read \
    .format("delta") \
    .option("timestampAsOf", "2024-01-01") \
    .load("/delta/table")

# ✅ PATTERN: SQL time travel
spark.sql("""
    SELECT * 
    FROM delta.`/delta/table` 
    VERSION AS OF 3
""")

spark.sql("""
    SELECT * 
    FROM delta.`/delta/table` 
    TIMESTAMP AS OF '2024-01-01'
""")
```

### **Practical Time Travel Use Cases**

```python
# USE CASE 1: Audit and compliance
# ✅ PATTERN: Compare current vs historical data
current_data = spark.read.format("delta").load("/delta/sales")
yesterday_data = spark.read \
    .format("delta") \
    .option("timestampAsOf", "2024-02-07") \
    .load("/delta/sales")

# Find what changed
changes = current_data.subtract(yesterday_data)
print(f"Records changed: {changes.count()}")

# USE CASE 2: Rollback bad data
# ✅ PATTERN: Restore to previous version
from delta.tables import DeltaTable

delta_table = DeltaTable.forPath(spark, "/delta/table")

# Rollback to version 5 (before bad write at version 6)
delta_table.restoreToVersion(5)

# Or rollback to timestamp
delta_table.restoreToTimestamp("2024-02-07 12:00:00")

# USE CASE 3: Reproduce past reports
# ✅ PATTERN: Regenerate report from historical data
report_date = "2024-01-31"
historical_df = spark.read \
    .format("delta") \
    .option("timestampAsOf", report_date) \
    .load("/delta/sales")

monthly_report = historical_df.groupBy("region") \
    .agg(sum("amount").alias("total_sales"))

# USE CASE 4: A/B testing analysis
# ✅ PATTERN: Compare feature impact
before_feature = spark.read \
    .format("delta") \
    .option("versionAsOf", 10) \
    .load("/delta/user_metrics")

after_feature = spark.read \
    .format("delta") \
    .option("versionAsOf", 15) \
    .load("/delta/user_metrics")

# Analyze difference
impact = after_feature.join(before_feature, "user_id", "inner") \
    .withColumn("engagement_change", 
                col("after.engagement") - col("before.engagement"))
```

---

## **PART 4: Merge/Upsert Patterns (CDC)**

### **The MERGE Command - The Most Important Pattern**

```python
from delta.tables import DeltaTable
from pyspark.sql.functions import col, current_timestamp, lit

# Sample scenario: CDC (Change Data Capture) updates
# Target table (existing data in Delta)
target_path = "/delta/customers"

# Source data (new updates from CDC)
updates_df = spark.read.parquet("/source/customer_updates.parquet")
# Schema: customer_id, name, email, city, updated_at

# ✅ PATTERN 1: Basic UPSERT (Insert + Update)
delta_table = DeltaTable.forPath(spark, target_path)

delta_table.alias("target").merge(
    updates_df.alias("source"),
    "target.customer_id = source.customer_id"  # Merge condition
).whenMatchedUpdateAll() \
 .whenNotMatchedInsertAll() \
 .execute()

"""
What happens:
1. If customer_id exists → UPDATE all columns
2. If customer_id doesn't exist → INSERT new row
"""

# ✅ PATTERN 2: Selective column updates
delta_table.alias("target").merge(
    updates_df.alias("source"),
    "target.customer_id = source.customer_id"
).whenMatchedUpdate(set={
    "name": col("source.name"),
    "email": col("source.email"),
    "city": col("source.city"),
    "updated_at": current_timestamp()
}).whenNotMatchedInsert(values={
    "customer_id": col("source.customer_id"),
    "name": col("source.name"),
    "email": col("source.email"),
    "city": col("source.city"),
    "created_at": current_timestamp(),
    "updated_at": current_timestamp()
}).execute()

# ✅ PATTERN 3: Conditional merge (only update if newer)
delta_table.alias("target").merge(
    updates_df.alias("source"),
    "target.customer_id = source.customer_id"
).whenMatchedUpdate(
    condition="source.updated_at > target.updated_at",  # Only if newer
    set={
        "name": col("source.name"),
        "email": col("source.email"),
        "updated_at": col("source.updated_at")
    }
).whenNotMatchedInsertAll() \
 .execute()

# ✅ PATTERN 4: Merge with DELETE
# CDC with operation type (INSERT, UPDATE, DELETE)
delta_table.alias("target").merge(
    updates_df.alias("source"),
    "target.customer_id = source.customer_id"
).whenMatchedUpdate(
    condition="source.operation = 'UPDATE'",
    set={"name": col("source.name"), "email": col("source.email")}
).whenMatchedDelete(
    condition="source.operation = 'DELETE'"
).whenNotMatchedInsert(
    condition="source.operation = 'INSERT'",
    values={
        "customer_id": col("source.customer_id"),
        "name": col("source.name"),
        "email": col("source.email")
    }
).execute()
```

### **Advanced Merge Patterns**

```python
# ✅ PATTERN 5: SCD Type 2 (Slowly Changing Dimension)
# Track full history of changes

from pyspark.sql.functions import when, lit, current_timestamp

# Prepare source with change detection
source_with_change = updates_df.alias("source").join(
    delta_table.toDF().alias("target"),
    col("source.customer_id") == col("target.customer_id"),
    "left_outer"
).select(
    col("source.*"),
    when(col("target.customer_id").isNull(), lit("INSERT"))
    .when(
        (col("source.name") != col("target.name")) |
        (col("source.email") != col("target.email")),
        lit("UPDATE")
    )
    .otherwise(lit("NO_CHANGE"))
    .alias("change_type")
).filter(col("change_type") != "NO_CHANGE")

# Step 1: Close old records (mark as inactive)
delta_table.alias("target").merge(
    source_with_change.filter(col("change_type") == "UPDATE").alias("source"),
    "target.customer_id = source.customer_id AND target.is_current = true"
).whenMatchedUpdate(set={
    "is_current": lit(False),
    "end_date": current_timestamp()
}).execute()

# Step 2: Insert new versions
new_records = source_with_change.select(
    col("customer_id"),
    col("name"),
    col("email"),
    current_timestamp().alias("start_date"),
    lit(None).cast("timestamp").alias("end_date"),
    lit(True).alias("is_current")
)

new_records.write.format("delta").mode("append").save(target_path)

# ✅ PATTERN 6: Deduplication during merge
from pyspark.sql.window import Window
from pyspark.sql.functions import row_number, desc

# Remove duplicates from source before merge
window = Window.partitionBy("customer_id").orderBy(desc("updated_at"))

deduplicated_source = updates_df.withColumn("rn", row_number().over(window)) \
    .filter(col("rn") == 1) \
    .drop("rn")

delta_table.alias("target").merge(
    deduplicated_source.alias("source"),
    "target.customer_id = source.customer_id"
).whenMatchedUpdateAll() \
 .whenNotMatchedInsertAll() \
 .execute()

# ✅ PATTERN 7: Incremental processing with checkpointing
# Track what's been processed
checkpoint_path = "/delta/checkpoints/customer_cdc"

# Read checkpoint
try:
    last_processed = spark.read.format("delta").load(checkpoint_path)
    max_timestamp = last_processed.agg(max("processed_timestamp")).collect()[0][0]
except:
    max_timestamp = None

# Process only new records
if max_timestamp:
    new_updates = updates_df.filter(col("updated_at") > max_timestamp)
else:
    new_updates = updates_df

# Merge new updates
delta_table.alias("target").merge(
    new_updates.alias("source"),
    "target.customer_id = source.customer_id"
).whenMatchedUpdateAll() \
 .whenNotMatchedInsertAll() \
 .execute()

# Update checkpoint
checkpoint_df = spark.createDataFrame(
    [(current_timestamp(),)],
    ["processed_timestamp"]
)
checkpoint_df.write.format("delta").mode("overwrite").save(checkpoint_path)
```

### **Merge Performance Optimization**

```python
# ✅ PATTERN 8: Partition pruning in merge
# Partition source to match target partitions
delta_table.alias("target").merge(
    updates_df.alias("source"),
    "target.customer_id = source.customer_id AND target.country = source.country"
).whenMatchedUpdateAll() \
 .whenNotMatchedInsertAll() \
 .execute()

# ✅ PATTERN 9: Pre-aggregate before merge
# If merging aggregated data
aggregated_source = updates_df.groupBy("customer_id").agg(
    sum("amount").alias("total_amount"),
    count("*").alias("transaction_count"),
    max("updated_at").alias("last_transaction")
)

delta_table.alias("target").merge(
    aggregated_source.alias("source"),
    "target.customer_id = source.customer_id"
).whenMatchedUpdate(set={
    "total_amount": col("target.total_amount") + col("source.total_amount"),
    "transaction_count": col("target.transaction_count") + col("source.transaction_count"),
    "last_transaction": col("source.last_transaction")
}).whenNotMatchedInsertAll() \
 .execute()

# ✅ PATTERN 10: Broadcast small source
from pyspark.sql.functions import broadcast

# If source is small, broadcast it
delta_table.alias("target").merge(
    broadcast(updates_df.alias("source")),
    "target.customer_id = source.customer_id"
).whenMatchedUpdateAll() \
 .whenNotMatchedInsertAll() \
 .execute()
```

---

## **PART 5: Schema Evolution**

### **Schema Evolution Patterns**

```python
# Current schema
"""
customers:
- customer_id (long)
- name (string)
- email (string)
"""

# New data with additional column
new_data_schema = """
- customer_id (long)
- name (string)
- email (string)
- phone (string)  ← NEW COLUMN
"""

# ❌ WITHOUT schema evolution (fails)
new_df.write.format("delta").mode("append").save("/delta/customers")
# Error: Schema mismatch

# ✅ PATTERN 1: Enable schema evolution (add new columns)
new_df.write \
    .format("delta") \
    .mode("append") \
    .option("mergeSchema", "true") \
    .save("/delta/customers")

# Result: phone column added, existing rows have NULL for phone

# ✅ PATTERN 2: Schema evolution with merge
delta_table.alias("target").merge(
    new_df.alias("source"),
    "target.customer_id = source.customer_id"
).whenMatchedUpdateAll() \
 .whenNotMatchedInsertAll() \
 .execute()

# Enable schema evolution globally
spark.conf.set("spark.databricks.delta.schema.autoMerge.enabled", "true")

# ✅ PATTERN 3: Overwrite schema (replace)
new_df.write \
    .format("delta") \
    .mode("overwrite") \
    .option("overwriteSchema", "true") \
    .save("/delta/customers")
# Warning: Changes schema completely!

# ✅ PATTERN 4: Controlled schema evolution
from delta.tables import DeltaTable

delta_table = DeltaTable.forPath(spark, "/delta/customers")

# Check current schema
current_schema = delta_table.toDF().schema
print("Current schema:", current_schema)

# Add column explicitly with ALTER TABLE
spark.sql("""
    ALTER TABLE delta.`/delta/customers`
    ADD COLUMNS (phone STRING, address STRING)
""")

# ✅ PATTERN 5: Column renaming (copy + drop)
spark.sql("""
    ALTER TABLE delta.`/delta/customers`
    RENAME COLUMN email TO email_address
""")

# ✅ PATTERN 6: Change column comment
spark.sql("""
    ALTER TABLE delta.`/delta/customers`
    ALTER COLUMN phone COMMENT 'Customer phone number with country code'
""")

# ✅ PATTERN 7: Reorder columns
spark.sql("""
    ALTER TABLE delta.`/delta/customers`
    ALTER COLUMN phone FIRST
""")

# or
spark.sql("""
    ALTER TABLE delta.`/delta/customers`
    ALTER COLUMN phone AFTER customer_id
""")
```

### **Schema Enforcement & Validation**

```python
# ✅ PATTERN: Schema enforcement (reject incompatible writes)
from pyspark.sql.types import StructType, StructField, StringType, LongType

# Define schema strictly
schema = StructType([
    StructField("customer_id", LongType(), nullable=False),
    StructField("name", StringType(), nullable=False),
    StructField("email", StringType(), nullable=True)
])

# Create table with schema
spark.createDataFrame([], schema).write \
    .format("delta") \
    .save("/delta/customers")

# Try to write incompatible data
bad_data = spark.createDataFrame([
    ("123", "Alice", "alice@email.com")  # customer_id is string, not long!
], ["customer_id", "name", "email"])

bad_data.write.format("delta").mode("append").save("/delta/customers")
# Error: Schema enforcement prevents this

# ✅ PATTERN: NOT NULL enforcement
spark.sql("""
    ALTER TABLE delta.`/delta/customers`
    ALTER COLUMN email SET NOT NULL
""")

# Now writes with NULL email will fail
```

---

## **PART 6: Optimization (OPTIMIZE, Z-ORDER, VACUUM)**

### **Small Files Problem**

```
PROBLEM: Many small files hurt performance

Before OPTIMIZE:
/delta/table/
├── part-00000.parquet (10 MB)
├── part-00001.parquet (5 MB)
├── part-00002.parquet (8 MB)
├── part-00003.parquet (12 MB)
... (1000 files, each 5-15 MB)

Issues:
❌ Slow reads (file open overhead)
❌ High memory for file metadata
❌ Inefficient query planning

After OPTIMIZE:
/delta/table/
├── part-00000.parquet (128 MB)
├── part-00001.parquet (128 MB)
├── part-00002.parquet (128 MB)
... (10 files, each 128 MB)

Benefits:
✓ Faster reads
✓ Lower metadata overhead
✓ Better compression
```

### **OPTIMIZE Command**

```python
from delta.tables import DeltaTable

# ✅ PATTERN 1: Basic OPTIMIZE (compact small files)
delta_table = DeltaTable.forPath(spark, "/delta/table")
delta_table.optimize().executeCompaction()

# SQL version
spark.sql("OPTIMIZE delta.`/delta/table`")

# ✅ PATTERN 2: OPTIMIZE specific partition
delta_table.optimize().where("country = 'USA'").executeCompaction()

# SQL version
spark.sql("""
    OPTIMIZE delta.`/delta/table`
    WHERE country = 'USA'
""")

# ✅ PATTERN 3: Z-ORDER by columns (data skipping)
delta_table.optimize().executeZOrderBy("user_id", "event_date")

# SQL version
spark.sql("""
    OPTIMIZE delta.`/delta/table`
    ZORDER BY (user_id, event_date)
""")

"""
Z-ORDER arranges data so related values are co-located:

Without Z-ORDER:
File 1: users 1, 5, 9, dates 2024-01-01, 2024-02-05, 2024-03-10
File 2: users 2, 6, 10, dates 2024-01-15, 2024-02-20, 2024-03-25
Query: user_id = 5 AND date = '2024-02-05'
→ Must scan BOTH files

With Z-ORDER by (user_id, date):
File 1: users 1-5, dates 2024-01-01 to 2024-02-10
File 2: users 6-10, dates 2024-02-11 to 2024-03-31
Query: user_id = 5 AND date = '2024-02-05'
→ Only scan File 1 (data skipping!)
"""

# ✅ PATTERN 4: Auto OPTIMIZE (Databricks)
spark.sql("""
    ALTER TABLE delta.`/delta/table`
    SET TBLPROPERTIES (
        delta.autoOptimize.optimizeWrite = true,
        delta.autoOptimize.autoCompact = true
    )
""")

# ✅ PATTERN 5: Schedule regular OPTIMIZE
def optimize_table(table_path, partition_filter=None):
    """Optimize Delta table with optional partition filtering."""
    delta_table = DeltaTable.forPath(spark, table_path)
    
    if partition_filter:
        # Optimize specific partitions
        delta_table.optimize() \
            .where(partition_filter) \
            .executeCompaction()
    else:
        # Optimize entire table
        delta_table.optimize().executeCompaction()
    
    # Get metrics
    history = delta_table.history(1)
    metrics = history.select("operationMetrics").collect()[0][0]
    
    print(f"Files compacted: {metrics.get('numFilesRemoved', 0)}")
    print(f"New files: {metrics.get('numFilesAdded', 0)}")
    print(f"Rows compacted: {metrics.get('numTargetRowsCopied', 0)}")

# Run daily
optimize_table("/delta/events", "event_date >= current_date() - 7")
```

### **VACUUM Command - Delete Old Files**

```python
# ✅ PATTERN 1: VACUUM to remove old files
from delta.tables import DeltaTable

delta_table = DeltaTable.forPath(spark, "/delta/table")

# Remove files older than 7 days (default retention)
delta_table.vacuum()

# SQL version
spark.sql("VACUUM delta.`/delta/table`")

# ✅ PATTERN 2: Custom retention period
# Remove files older than 30 days
delta_table.vacuum(168)  # hours (30 days = 720 hours)

spark.sql("""
    VACUUM delta.`/delta/table`
    RETAIN 720 HOURS
""")

# ✅ PATTERN 3: Dry run (see what would be deleted)
files_to_delete = delta_table.vacuum(168, dryRun=True)
files_to_delete.show()

# ✅ PATTERN 4: Override safety check (dangerous!)
# Delta prevents VACUUM < 7 days to protect time travel
spark.conf.set("spark.databricks.delta.retentionDurationCheck.enabled", "false")
delta_table.vacuum(24)  # Delete files older than 1 day
spark.conf.set("spark.databricks.delta.retentionDurationCheck.enabled", "true")

"""
IMPORTANT: VACUUM Trade-offs

✓ Benefits:
  - Reduces storage costs
  - Removes obsolete files

❌ Risks:
  - Breaks time travel beyond retention period
  - Concurrent readers might fail if reading old versions
  - Cannot restore to vacuumed versions

Best Practice:
- Default 7 days is safe
- Extend to 30 days for production
- Never vacuum if you need long-term time travel
"""

# ✅ PATTERN 5: Safe VACUUM workflow
def safe_vacuum(table_path, retention_hours=720):
    """Safely vacuum with checks."""
    delta_table = DeltaTable.forPath(spark, table_path)
    
    # 1. Check current version
    current_version = delta_table.history(1).select("version").collect()[0][0]
    
    # 2. Dry run to see impact
    files_to_delete = delta_table.vacuum(retention_hours, dryRun=True)
    num_files = files_to_delete.count()
    
    print(f"Current version: {current_version}")
    print(f"Files to delete: {num_files}")
    
    # 3. Confirm before actual vacuum
    if num_files > 0:
        response = input(f"Delete {num_files} files? (yes/no): ")
        if response.lower() == "yes":
            delta_table.vacuum(retention_hours)
            print("Vacuum completed")
        else:
            print("Vacuum cancelled")
    else:
        print("No files to vacuum")

safe_vacuum("/delta/table", retention_hours=720)
```

### **File Statistics & Data Skipping**

```python
# ✅ PATTERN: View table details
spark.sql("DESCRIBE DETAIL delta.`/delta/table`").show(truncate=False)

"""
Shows:
- Number of files
- Size on disk
- Number of rows
- Partitions
- Min/max values per file (for data skipping)
"""

# ✅ PATTERN: View file-level statistics
spark.sql("""
    SELECT * FROM delta.`/delta/table` TABLESAMPLE (1 FILES)
""").explain()

# Look for "PushedFilters" and "DataFilters" in plan
# Shows which files were skipped

# ✅ PATTERN: Check Z-ORDER effectiveness
# Before Z-ORDER
query1 = spark.sql("""
    SELECT * FROM delta.`/delta/table`
    WHERE user_id = 12345 AND event_date = '2024-02-08'
""")
query1.explain()  # Note: "files read"

# After Z-ORDER by (user_id, event_date)
delta_table.optimize().executeZOrderBy("user_id", "event_date")

query2 = spark.sql("""
    SELECT * FROM delta.`/delta/table`
    WHERE user_id = 12345 AND event_date = '2024-02-08'
""")
query2.explain()  # Should show fewer files read
```

---

## **PART 7: Delete & Update Patterns**

### **DELETE Operations**

```python
from delta.tables import DeltaTable

delta_table = DeltaTable.forPath(spark, "/delta/table")

# ✅ PATTERN 1: Simple DELETE
delta_table.delete("customer_id = 12345")

# SQL version
spark.sql("""
    DELETE FROM delta.`/delta/table`
    WHERE customer_id = 12345
""")

# ✅ PATTERN 2: Conditional DELETE
delta_table.delete(
    (col("status") == "inactive") & 
    (col("last_login") < "2023-01-01")
)

# ✅ PATTERN 3: DELETE with subquery
spark.sql("""
    DELETE FROM delta.`/delta/customers` c
    WHERE EXISTS (
        SELECT 1 FROM delta.`/delta/deleted_users` d
        WHERE d.user_id = c.customer_id
    )
""")

# ✅ PATTERN 4: Partition-level DELETE (faster)
# Instead of row-by-row delete
delta_table.delete("year = 2020 AND month = 1")
# Removes entire partition files

# ✅ PATTERN 5: Soft delete (recommended for audit)
# Don't actually delete, just mark as deleted
delta_table.update(
    condition="customer_id = 12345",
    set={"is_deleted": lit(True), "deleted_at": current_timestamp()}
)

# Queries filter out deleted records
active_customers = spark.read.format("delta").load("/delta/customers") \
    .filter(col("is_deleted") == False)
```

### **UPDATE Operations**

```python
# ✅ PATTERN 1: Simple UPDATE
delta_table.update(
    condition="status = 'pending'",
    set={"status": lit("active"), "updated_at": current_timestamp()}
)

# SQL version
spark.sql("""
    UPDATE delta.`/delta/table`
    SET status = 'active', updated_at = current_timestamp()
    WHERE status = 'pending'
""")

# ✅ PATTERN 2: Conditional UPDATE
delta_table.update(
    condition="order_total > 1000",
    set={
        "discount": col("order_total") * 0.1,
        "tier": lit("premium")
    }
)

# ✅ PATTERN 3: UPDATE from another table (use MERGE)
# Don't do separate UPDATE, use MERGE instead
delta_table.alias("target").merge(
    price_updates.alias("source"),
    "target.product_id = source.product_id"
).whenMatchedUpdate(set={
    "price": col("source.new_price"),
    "updated_at": current_timestamp()
}).execute()

# ✅ PATTERN 4: Incremental updates with checkpoint
def incremental_update(table_path, updates_df, checkpoint_col="processed_id"):
    """Update only new records since last run."""
    delta_table = DeltaTable.forPath(spark, table_path)
    
    # Get last processed ID
    last_processed = spark.read.format("delta").load(table_path) \
        .agg(max(checkpoint_col)).collect()[0][0] or 0
    
    # Filter to new updates
    new_updates = updates_df.filter(col(checkpoint_col) > last_processed)
    
    if new_updates.count() == 0:
        print("No new updates")
        return
    
    # Merge updates
    delta_table.alias("target").merge(
        new_updates.alias("source"),
        "target.id = source.id"
    ).whenMatchedUpdateAll() \
     .whenNotMatchedInsertAll() \
     .execute()
    
    print(f"Processed {new_updates.count()} updates")

incremental_update("/delta/products", new_prices_df)
```

---

## **PART 8: Streaming with Delta Lake**

### **Structured Streaming + Delta**

```python
from pyspark.sql.functions import col, window, count

# ✅ PATTERN 1: Stream to Delta (append mode)
streaming_df = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "localhost:9092") \
    .option("subscribe", "events") \
    .load()

# Parse and write to Delta
parsed_stream = streaming_df.select(
    col("key").cast("string"),
    col("value").cast("string"),
    col("timestamp")
)

query = parsed_stream.writeStream \
    .format("delta") \
    .outputMode("append") \
    .option("checkpointLocation", "/delta/checkpoints/events") \
    .start("/delta/events")

# ✅ PATTERN 2: Stream from Delta
# Read Delta table as streaming source
delta_stream = spark.readStream \
    .format("delta") \
    .load("/delta/events")

# Process stream
aggregated = delta_stream.groupBy(
    window(col("timestamp"), "1 hour"),
    col("event_type")
).agg(count("*").alias("count"))

# ✅ PATTERN 3: Exactly-once processing
query = parsed_stream.writeStream \
    .format("delta") \
    .outputMode("append") \
    .option("checkpointLocation", "/delta/checkpoints/events") \
    .option("queryName", "events_ingestion") \
    .start("/delta/events")

# Checkpoints ensure exactly-once semantics
# If job fails and restarts, it continues from checkpoint

# ✅ PATTERN 4: Stream-stream MERGE (streaming upserts)
from delta.tables import DeltaTable

def upsert_to_delta(microBatchDF, batchId):
    """Upsert function for foreachBatch."""
    delta_table = DeltaTable.forPath(spark, "/delta/customers")
    
    delta_table.alias("target").merge(
        microBatchDF.alias("source"),
        "target.customer_id = source.customer_id"
    ).whenMatchedUpdateAll() \
     .whenNotMatchedInsertAll() \
     .execute()

streaming_df.writeStream \
    .format("delta") \
    .foreachBatch(upsert_to_delta) \
    .option("checkpointLocation", "/delta/checkpoints/customer_upsert") \
    .start()

# ✅ PATTERN 5: Change Data Feed (Delta 2.0+)
# Enable CDC on table
spark.sql("""
    ALTER TABLE delta.`/delta/customers`
    SET TBLPROPERTIES (delta.enableChangeDataFeed = true)
""")

# Read changes as stream
changes_df = spark.readStream \
    .format("delta") \
    .option("readChangeDataFeed", "true") \
    .option("startingVersion", 10) \
    .load("/delta/customers")

changes_df.writeStream \
    .format("console") \
    .start()

"""
Output includes:
- All columns from table
- _change_type: insert, update_preimage, update_postimage, delete
- _commit_version: Version where change occurred
- _commit_timestamp: When change was committed
"""

# ✅ PATTERN 6: Stream deduplication
from pyspark.sql.functions import expr

# Deduplicate within stream using watermark
deduplicated_stream = streaming_df \
    .withWatermark("timestamp", "10 minutes") \
    .dropDuplicates(["event_id", "timestamp"])

deduplicated_stream.writeStream \
    .format("delta") \
    .outputMode("append") \
    .option("checkpointLocation", "/delta/checkpoints/dedupe") \
    .start("/delta/events")
```

### **Streaming Best Practices**

```python
# ✅ PATTERN 7: Trigger intervals
# Continuous processing (low latency)
query = streaming_df.writeStream \
    .format("delta") \
    .trigger(continuous="1 second") \
    .start("/delta/events")

# Micro-batch (default, balanced)
query = streaming_df.writeStream \
    .format("delta") \
    .trigger(processingTime="10 seconds") \
    .start("/delta/events")

# Once trigger (for scheduled jobs)
query = streaming_df.writeStream \
    .format("delta") \
    .trigger(once=True) \
    .start("/delta/events")

# ✅ PATTERN 8: Monitor streaming queries
# Get active streams
active_streams = spark.streams.active
for stream in active_streams:
    print(f"Stream: {stream.name}")
    print(f"Status: {stream.status}")
    print(f"Recent progress: {stream.recentProgress}")

# ✅ PATTERN 9: Graceful shutdown
import signal
import sys

def signal_handler(sig, frame):
    """Handle shutdown signal."""
    print("Stopping streaming queries...")
    for stream in spark.streams.active:
        stream.stop()
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

# ✅ PATTERN 10: Checkpoint management
# Location is critical for recovery
checkpoint_path = "/delta/checkpoints/app_name"

# Monitor checkpoint size
checkpoint_files = spark.sparkContext.binaryFiles(checkpoint_path)
total_size = checkpoint_files.map(lambda x: len(x[1])).sum()
print(f"Checkpoint size: {total_size / 1024 / 1024:.2f} MB")
```

---

## **PART 9: Common Interview Problems**

### **Problem 1: Incremental Data Load**

```python
"""
Load only new data since last run, avoiding duplicates
"""

from delta.tables import DeltaTable
from pyspark.sql.functions import col, max as spark_max

def incremental_load(source_path, target_path, key_column, timestamp_column):
    """
    Incrementally load data from source to Delta table.
    
    Args:
        source_path: Path to source data (Parquet, CSV, etc.)
        target_path: Path to Delta table
        key_column: Unique identifier column
        timestamp_column: Column to track latest data
    """
    # Read source data
    source_df = spark.read.parquet(source_path)
    
    # Check if target exists
    try:
        target_df = spark.read.format("delta").load(target_path)
        
        # Get last processed timestamp
        last_timestamp = target_df.agg(
            spark_max(timestamp_column)
        ).collect()[0][0]
        
        # Filter to new records
        new_records = source_df.filter(col(timestamp_column) > last_timestamp)
        
        if new_records.count() == 0:
            print("No new records to load")
            return
        
        # Merge new records
        delta_table = DeltaTable.forPath(spark, target_path)
        delta_table.alias("target").merge(
            new_records.alias("source"),
            f"target.{key_column} = source.{key_column}"
        ).whenMatchedUpdateAll() \
         .whenNotMatchedInsertAll() \
         .execute()
        
        print(f"Loaded {new_records.count()} new records")
        
    except:
        # Target doesn't exist, initial load
        source_df.write \
            .format("delta") \
            .mode("overwrite") \
            .save(target_path)
        print(f"Initial load: {source_df.count()} records")

# Usage
incremental_load(
    source_path="/data/events.parquet",
    target_path="/delta/events",
    key_column="event_id",
    timestamp_column="event_timestamp"
)
```

### **Problem 2: Late Arriving Data**

```python
"""
Handle data that arrives out of order
"""

from pyspark.sql.functions import col, current_timestamp, datediff

def handle_late_data(late_df, target_path, key_column, event_date_column, grace_period_days=7):
    """
    Handle late arriving data with grace period.
    
    Args:
        late_df: DataFrame with potentially late data
        target_path: Path to Delta table
        key_column: Unique identifier
        event_date_column: Event date column
        grace_period_days: Days to accept late data
    """
    delta_table = DeltaTable.forPath(spark, target_path)
    
    # Add metadata
    late_df_with_meta = late_df.withColumn(
        "ingestion_time", current_timestamp()
    ).withColumn(
        "days_late",
        datediff(current_timestamp(), col(event_date_column))
    )
    
    # Separate on-time and late data
    on_time = late_df_with_meta.filter(
        col("days_late") <= grace_period_days
    )
    
    too_late = late_df_with_meta.filter(
        col("days_late") > grace_period_days
    )
    
    # Process on-time data
    if on_time.count() > 0:
        delta_table.alias("target").merge(
            on_time.alias("source"),
            f"target.{key_column} = source.{key_column}"
        ).whenMatchedUpdateAll() \
         .whenNotMatchedInsertAll() \
         .execute()
        
        print(f"Processed {on_time.count()} on-time records")
    
    # Quarantine too-late data
    if too_late.count() > 0:
        too_late.write \
            .format("delta") \
            .mode("append") \
            .save("/delta/quarantine/late_arrivals")
        
        print(f"Quarantined {too_late.count()} late records")

# Usage
handle_late_data(
    late_df=new_events_df,
    target_path="/delta/events",
    key_column="event_id",
    event_date_column="event_date",
    grace_period_days=7
)
```

### **Problem 3: Multi-Table Transaction**

```python
"""
Update multiple Delta tables atomically (best effort)
"""

def multi_table_update(order_id, new_status):
    """
    Update order status across multiple tables.
    Demonstrates best-effort multi-table consistency.
    """
    try:
        # Table 1: Update orders
        orders_table = DeltaTable.forPath(spark, "/delta/orders")
        orders_table.update(
            condition=f"order_id = {order_id}",
            set={
                "status": lit(new_status),
                "updated_at": current_timestamp()
            }
        )
        
        # Table 2: Update order_history
        history_record = spark.createDataFrame([
            (order_id, new_status, current_timestamp())
        ], ["order_id", "status", "change_timestamp"])
        
        history_record.write \
            .format("delta") \
            .mode("append") \
            .save("/delta/order_history")
        
        # Table 3: Update customer summary
        if new_status == "completed":
            customer_table = DeltaTable.forPath(spark, "/delta/customers")
            
            # Get order amount
            order_amount = spark.read.format("delta").load("/delta/orders") \
                .filter(col("order_id") == order_id) \
                .select("customer_id", "amount") \
                .first()
            
            customer_table.update(
                condition=f"customer_id = {order_amount.customer_id}",
                set={
                    "total_purchases": col("total_purchases") + order_amount.amount,
                    "last_purchase": current_timestamp()
                }
            )
        
        print(f"Successfully updated order {order_id} to {new_status}")
        
    except Exception as e:
        print(f"Error updating order {order_id}: {e}")
        # Note: Delta doesn't support cross-table transactions
        # Consider using compensating transactions or eventual consistency
        raise

multi_table_update(order_id=12345, new_status="completed")
```

### **Problem 4: Data Quality Validation**

```python
"""
Validate data quality before committing to Delta table
"""

from pyspark.sql.functions import col, sum as spark_sum, when, count

def validate_and_write(df, target_path, validation_rules):
    """
    Validate data before writing to Delta.
    
    Args:
        df: Source DataFrame
        target_path: Delta table path
        validation_rules: Dict of validation rules
    """
    # Run validations
    validation_results = df.agg(
        count("*").alias("total_rows"),
        
        # Null checks
        spark_sum(when(col("customer_id").isNull(), 1).otherwise(0))
            .alias("null_customer_ids"),
        
        # Range checks
        spark_sum(when(col("amount") < 0, 1).otherwise(0))
            .alias("negative_amounts"),
        
        # Referential integrity (example)
        spark_sum(when(~col("country_code").isin(["US", "UK", "CA"]), 1).otherwise(0))
            .alias("invalid_countries")
    ).collect()[0]
    
    # Check thresholds
    total_rows = validation_results["total_rows"]
    error_rate = (
        validation_results["null_customer_ids"] +
        validation_results["negative_amounts"] +
        validation_results["invalid_countries"]
    ) / total_rows
    
    print(f"Validation results:")
    print(f"  Total rows: {total_rows:,}")
    print(f"  Null customer IDs: {validation_results['null_customer_ids']:,}")
    print(f"  Negative amounts: {validation_results['negative_amounts']:,}")
    print(f"  Invalid countries: {validation_results['invalid_countries']:,}")
    print(f"  Error rate: {error_rate:.2%}")
    
    # Apply threshold
    max_error_rate = validation_rules.get("max_error_rate", 0.01)  # 1% default
    
    if error_rate > max_error_rate:
        # Reject batch
        print(f"❌ Validation failed: Error rate {error_rate:.2%} > {max_error_rate:.2%}")
        
        # Write to quarantine
        df.write.format("delta") \
            .mode("append") \
            .save("/delta/quarantine/failed_validation")
        
        raise ValueError("Data quality validation failed")
    else:
        # Accept batch
        print(f"✅ Validation passed: Error rate {error_rate:.2%} <= {max_error_rate:.2%}")
        
        df.write.format("delta") \
            .mode("append") \
            .save(target_path)
        
        print(f"Successfully wrote {total_rows:,} rows to {target_path}")

# Usage
validation_rules = {
    "max_error_rate": 0.005  # 0.5% max errors
}

validate_and_write(
    df=new_transactions_df,
    target_path="/delta/transactions",
    validation_rules=validation_rules
)
```

---

## **PART 10: Production Best Practices**

### **Table Properties Configuration**

```python
# ✅ PATTERN: Set optimal table properties
spark.sql("""
    CREATE TABLE events (
        event_id STRING,
        user_id STRING,
        event_type STRING,
        timestamp TIMESTAMP,
        properties MAP<STRING, STRING>
    )
    USING DELTA
    PARTITIONED BY (DATE(timestamp))
    TBLPROPERTIES (
        -- Data retention
        'delta.logRetentionDuration' = '30 days',
        'delta.deletedFileRetentionDuration' = '7 days',
        
        -- Auto optimization
        'delta.autoOptimize.optimizeWrite' = 'true',
        'delta.autoOptimize.autoCompact' = 'true',
        
        -- File size tuning
        'delta.targetFileSize' = '128mb',
        
        -- Change data feed
        'delta.enableChangeDataFeed' = 'true',
        
        -- Schema enforcement
        'delta.columnMapping.mode' = 'name',
        'delta.minReaderVersion' = '2',
        'delta.minWriterVersion' = '5'
    )
""")
```

### **Monitoring & Observability**

```python
# ✅ PATTERN: Monitor table health
def monitor_delta_table(table_path):
    """Monitor Delta table health metrics."""
    delta_table = DeltaTable.forPath(spark, table_path)
    
    # Get table details
    details = spark.sql(f"DESCRIBE DETAIL delta.`{table_path}`").collect()[0]
    
    print(f"=== Table Health Report ===")
    print(f"Location: {details.location}")
    print(f"Format: {details.format}")
    print(f"Num files: {details.numFiles:,}")
    print(f"Size bytes: {details.sizeInBytes:,} ({details.sizeInBytes/1024/1024/1024:.2f} GB)")
    
    # Check if OPTIMIZE needed
    if details.numFiles > details.sizeInBytes / (128 * 1024 * 1024):  # Target 128MB files
        print(f"⚠️  Too many small files. Consider running OPTIMIZE")
    
    # Check last operation
    history = delta_table.history(1).collect()[0]
    print(f"\nLast operation: {history.operation}")
    print(f"Last modified: {history.timestamp}")
    
    # Check partition count
    if "partitionColumns" in details:
        partitions = spark.sql(f"SHOW PARTITIONS delta.`{table_path}`").count()
        print(f"Partitions: {partitions:,}")
        if partitions > 10000:
            print(f"⚠️  Too many partitions. Consider different partitioning strategy")

monitor_delta_table("/delta/events")
```

### **Error Handling & Retry Logic**

```python
import time
from pyspark.sql.utils import AnalysisException

def write_with_retry(df, target_path, max_retries=3, mode="append"):
    """Write to Delta with retry logic for concurrent operations."""
    
    for attempt in range(max_retries):
        try:
            df.write \
                .format("delta") \
                .mode(mode) \
                .save(target_path)
            
            print(f"Write succeeded on attempt {attempt + 1}")
            return
            
        except AnalysisException as e:
            error_msg = str(e)
            
            if "ConcurrentAppendException" in error_msg:
                if attempt < max_retries - 1:
                    wait_time = 2 ** attempt  # Exponential backoff
                    print(f"Concurrent write detected. Retrying in {wait_time}s...")
                    time.sleep(wait_time)
                else:
                    print(f"Failed after {max_retries} attempts")
                    raise
            else:
                # Different error, don't retry
                print(f"Non-retryable error: {error_msg}")
                raise

write_with_retry(new_data_df, "/delta/events")
```

### **Access Control & Security**

```python
# ✅ PATTERN: Column-level security (Databricks)
spark.sql("""
    ALTER TABLE customers
    ADD COLUMN social_security_number STRING
    MASK sha2(social_security_number, 256)
""")

# ✅ PATTERN: Row-level security with views
spark.sql("""
    CREATE OR REPLACE VIEW customer_regional_view AS
    SELECT * FROM customers
    WHERE country = current_user_region()
""")

# ✅ PATTERN: Audit logging
def audit_write(df, table_path, user_id, operation):
    """Write with audit logging."""
    # Add audit columns
    df_with_audit = df.withColumn("modified_by", lit(user_id)) \
                      .withColumn("modified_at", current_timestamp()) \
                      .withColumn("operation", lit(operation))
    
    # Write to Delta
    df_with_audit.write.format("delta").mode("append").save(table_path)
    
    # Log to audit table
    audit_record = spark.createDataFrame([
        (table_path, user_id, operation, current_timestamp())
    ], ["table_path", "user_id", "operation", "timestamp"])
    
    audit_record.write.format("delta").mode("append").save("/delta/audit_log")

audit_write(updates_df, "/delta/customers", user_id="john.doe", operation="UPDATE")
```

---

## **QUICK REFERENCE CARD**

```
┌────────────────────────────────────────────────────────────┐
│            DELTA LAKE COMMAND QUICK REFERENCE              │
├────────────────────────────────────────────────────────────┤
│                                                            │
│ CREATE:                                                    │
│ df.write.format("delta").save(path)                        │
│ CREATE TABLE name USING DELTA                             │
│                                                            │
│ READ:                                                      │
│ spark.read.format("delta").load(path)                      │
│ spark.read.format("delta").option("versionAsOf", N)       │
│                                                            │
│ UPDATE:                                                    │
│ delta_table.update(condition, set={...})                   │
│                                                            │
│ DELETE:                                                    │
│ delta_table.delete(condition)                              │
│                                                            │
│ MERGE (UPSERT):                                            │
│ delta_table.merge(source, condition)                       │
│   .whenMatchedUpdate(...)                                  │
│   .whenNotMatchedInsert(...)                               │
│   .execute()                                               │
│                                                            │
│ OPTIMIZE:                                                  │
│ delta_table.optimize().executeCompaction()                 │
│ delta_table.optimize().executeZOrderBy("col1", "col2")     │
│                                                            │
│ VACUUM:                                                    │
│ delta_table.vacuum(retentionHours)                         │
│                                                            │
│ TIME TRAVEL:                                               │
│ delta_table.history()                                      │
│ delta_table.restoreToVersion(N)                            │
│                                                            │
│ SCHEMA:                                                    │
│ .option("mergeSchema", "true")                             │
│ .option("overwriteSchema", "true")                         │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## **Interview Questions & Answers**

### **Q1: What's the difference between Delta Lake and Parquet?**

**Answer:**
```
Parquet:
- Storage format (columnar compression)
- Immutable files
- No transactions or ACID guarantees
- No schema enforcement
- No updates/deletes (must rewrite entire file)

Delta Lake:
- Table format built ON TOP of Parquet
- Transaction log provides ACID guarantees
- Schema enforcement and evolution
- Supports updates/deletes/merges
- Time travel capabilities
- Optimizations (Z-ORDER, data skipping)

Analogy: Parquet is like a filing cabinet.
Delta Lake is like a database built using filing cabinets.
```

### **Q2: How does Delta Lake achieve ACID transactions?**

**Answer:**
```
Transaction Log (_delta_log):
1. Every operation writes a JSON file to _delta_log/
2. Files are numbered sequentially (00000.json, 00001.json, ...)
3. Atomic file creation ensures all-or-nothing commits
4. Readers read log to determine which Parquet files are current
5. Optimistic concurrency control handles conflicts

Example:
Version 0: Write initial data → 00000.json
Version 1: Update rows → 00001.json (references new Parquet files)
Version 2: Delete rows → 00002.json (marks files as removed)

Readers always see consistent snapshot by reading log up to a version.
```

### **Q3: When should you use OPTIMIZE vs VACUUM?**

**Answer:**
```
OPTIMIZE:
- Purpose: Compact small files into larger ones
- When: After many small writes (streaming, frequent updates)
- Frequency: Daily/weekly depending on write volume
- Side effect: Creates new files, marks old ones for deletion

VACUUM:
- Purpose: Delete old/unused files to save storage
- When: After OPTIMIZE or to clean up old versions
- Frequency: Weekly/monthly
- Side effect: Breaks time travel for deleted versions

Typical workflow:
1. Daily writes create small files
2. Run OPTIMIZE weekly → compacts files
3. Run VACUUM monthly → deletes old files (keep 30 days)
```

### **Q4: How do you handle late-arriving data in Delta Lake?**

**Answer:**
```python
Strategies:

1. Grace Period:
   - Accept data up to N days late
   - Use MERGE with timestamp condition
   - Quarantine data that's too late

2. Reprocessing:
   - Reprocess affected partitions
   - Use partition-level overwrites

3. Time Travel:
   - Query historical state
   - Identify what changed
   - Apply corrections

4. Streaming:
   - Use watermarks in Structured Streaming
   - Automatically handle late data within watermark

Best practice: Combine 1 & 4
```

### **Q5: What's the difference between mergeSchema and overwriteSchema?**

**Answer:**
```
mergeSchema (safe):
- Adds new columns from source
- Keeps existing columns
- Fills new columns with NULL for old rows
- Use case: Schema evolution (adding fields)

Example:
Old: {id, name}
New: {id, name, email}
Result: {id, name, email} (email=NULL for old rows)

overwriteSchema (dangerous):
- Replaces entire schema
- Can drop columns
- Destructive operation
- Use case: Complete schema redesign

Example:
Old: {id, name, email}
New: {id, first_name, last_name}
Result: {id, first_name, last_name} (email column lost!)
```

---

Would you like me to:
1. **Cover Delta Lake with Unity Catalog** (governance, lineage)?
2. **Deep dive into Change Data Feed** (CDC streaming)?
3. **Show multi-cluster writes** (Delta Lake on S3)?
4. **Cover Delta sharing** (cross-platform data sharing)?
5. **Build complete ETL pipeline examples** with Delta Lake?

**Master these Delta Lake patterns and you'll be ready for any lakehouse interview!** 🚀
