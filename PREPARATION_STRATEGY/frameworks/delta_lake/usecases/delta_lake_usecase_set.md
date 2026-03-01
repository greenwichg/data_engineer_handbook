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
11. Delta Lake vs Apache Iceberg vs Apache Hudi
12. Transaction Log Internals
13. Liquid Clustering (Delta Lake 3.0+)
14. Deletion Vectors
15. UniForm (Universal Format)
16. Clone Operations (SHALLOW / DEEP)
17. CHECK Constraints
18. Generated Columns & Identity Columns
19. Bloom Filter Index
20. Multi-Cluster Writes (S3/ADLS)
21. Column Mapping
22. Idempotent Writes (txnAppId / txnVersion)
23. Copy-on-Write vs Merge-on-Read
24. Medallion Architecture (Bronze / Silver / Gold)
25. Unity Catalog & Governance
26. Delta Live Tables (DLT)
27. Delta Sharing
28. Photon Engine
29. Cost Optimization Strategies
30. Monitoring & Observability
31. GDPR & Compliance Patterns
32. Disaster Recovery & High Availability
33. SCD Type 3 & Type 4 Patterns
34. Data Mesh with Delta Lake
35. Delta Lake with ML / Feature Stores

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

## **PART 11: Delta Lake vs Apache Iceberg vs Apache Hudi**

### **Head-to-Head Comparison**

```
┌─────────────────────────┬─────────────────────┬──────────────────────┬──────────────────────┐
│ Feature                 │ Delta Lake          │ Apache Iceberg       │ Apache Hudi          │
├─────────────────────────┼─────────────────────┼──────────────────────┼──────────────────────┤
│ Origin                  │ Databricks (2019)   │ Netflix (2017)       │ Uber (2016)          │
│ License                 │ Apache 2.0          │ Apache 2.0           │ Apache 2.0           │
│ Transaction Log         │ JSON + Parquet      │ Manifest files       │ Timeline metadata    │
│                         │ (_delta_log/)        │ (metadata/)          │ (.hoodie/)           │
├─────────────────────────┼─────────────────────┼──────────────────────┼──────────────────────┤
│ ACID Transactions       │ ✅ Yes              │ ✅ Yes               │ ✅ Yes               │
│ Time Travel             │ ✅ Yes              │ ✅ Yes (snapshots)   │ ✅ Yes (instants)    │
│ Schema Evolution        │ ✅ Yes              │ ✅ Yes (full)        │ ✅ Yes               │
│ Partition Evolution     │ ⚠️ Via Liquid Clust │ ✅ Hidden partitions │ ❌ Limited           │
│ Updates/Deletes         │ ✅ CoW              │ ✅ CoW + MoR         │ ✅ CoW + MoR         │
│ Streaming               │ ✅ Native           │ ⚠️ Limited           │ ✅ Native            │
├─────────────────────────┼─────────────────────┼──────────────────────┼──────────────────────┤
│ File Format             │ Parquet only        │ Parquet, ORC, Avro   │ Parquet, ORC         │
│ Catalog                 │ Unity Catalog       │ Hive, Nessie, REST   │ Hive Metastore       │
│ Engine Lock-in          │ Spark-first         │ Engine-agnostic      │ Spark-first          │
│                         │ (UniForm opens up)  │ (Trino, Flink, etc.) │                      │
├─────────────────────────┼─────────────────────┼──────────────────────┼──────────────────────┤
│ Small File Compaction   │ OPTIMIZE            │ Rewrite manifests    │ Compaction (inline)  │
│ Data Skipping           │ Z-ORDER, Liquid     │ Hidden partitioning  │ Record-level index   │
│ Clustering              │                     │ + sort orders        │                      │
│ Merge Performance       │ Good                │ Good                 │ Excellent (indexes)  │
│ Upsert Specialty        │ General-purpose     │ General-purpose      │ Built for upserts    │
├─────────────────────────┼─────────────────────┼──────────────────────┼──────────────────────┤
│ Best For                │ Databricks shops,   │ Multi-engine envs,   │ High-frequency       │
│                         │ Spark-centric,      │ engine-agnostic,     │ upserts, CDC-heavy,  │
│                         │ lakehouse arch      │ vendor-neutral       │ near-real-time       │
└─────────────────────────┴─────────────────────┴──────────────────────┴──────────────────────┘
```

### **Transaction Log Architecture Comparison**

```
Delta Lake:                    Iceberg:                       Hudi:
_delta_log/                    metadata/                      .hoodie/
├── 00000.json (add/remove)    ├── v1.metadata.json           ├── 20240208.commit (instant)
├── 00001.json                 ├── snap-123.avro (snapshot)    ├── 20240209.commit
├── 00002.json                 ├── m-456.avro (manifest list) │
├── ...                        ├── M-789.avro (manifest file) │
├── 00010.checkpoint.parquet   │                               │
│   (every 10 versions)        │                               │
│                              │                               │
│ Optimistic Concurrency:      │ Optimistic Concurrency:       │ Timeline-based:
│ File-level conflict detect   │ Snapshot isolation             │ MVCC with timeline
│ JSON atomic rename           │ Atomic pointer swap            │ Marker-based commits
│ Retry on conflict            │ Retry on conflict              │ Lock-based for COW

KEY DIFFERENCES:
  Delta:   Linear log → checkpoint every 10 → fast replay
  Iceberg: Tree structure → snapshot → manifest list → manifest → data files
  Hudi:    Timeline of instants → actions (commits, compactions, cleans)
```

### **When to Choose Each Format**

```python
"""
DECISION FRAMEWORK:

Choose DELTA LAKE when:
  ✅ Using Databricks as primary platform
  ✅ Spark-centric architecture
  ✅ Need tight Unity Catalog integration
  ✅ Want simplest setup (format + catalog in one)
  ✅ Streaming-first workloads with Structured Streaming
  ✅ Need Liquid Clustering for auto-optimization

Choose ICEBERG when:
  ✅ Multi-engine requirement (Spark + Trino + Flink + Dremio)
  ✅ Vendor-neutral / avoid Databricks lock-in
  ✅ Hidden partitioning is critical (users shouldn't know partition scheme)
  ✅ Need Partition Evolution (change partitioning without rewriting data)
  ✅ Large-scale metadata (millions of files) — tree-based catalog scales better
  ✅ AWS-centric (Athena, EMR, Glue have native Iceberg support)

Choose HUDI when:
  ✅ High-frequency upserts / CDC-heavy workloads
  ✅ Near-real-time ingestion (record-level indexing)
  ✅ Need Merge-on-Read for write-heavy workloads
  ✅ Uber/Lyft-style event processing pipelines
  ✅ Want built-in incremental processing (incremental queries)

INTERVIEW TIP:
  "All three provide ACID on data lakes. Delta is Databricks-native and
   simplest to adopt. Iceberg is engine-agnostic and excels at multi-engine
   queries. Hudi is optimized for high-frequency upserts and CDC."
"""
```

---

## **PART 12: Transaction Log Internals**

### **Delta Log File Structure**

```python
"""
Every Delta operation creates a JSON commit file in _delta_log/

ANATOMY OF A COMMIT FILE (e.g., 00005.json):

{
  "commitInfo": {
    "timestamp": 1707400000000,
    "operation": "MERGE",
    "operationParameters": {"predicate": "target.id = source.id"},
    "operationMetrics": {
      "numTargetRowsInserted": "1000",
      "numTargetRowsUpdated": "500",
      "numTargetRowsDeleted": "50",
      "numOutputRows": "10500"
    },
    "engineInfo": "Apache-Spark/3.5.0 Delta-Lake/3.0.0"
  }
}
{
  "add": {
    "path": "part-00000-abc123.snappy.parquet",
    "size": 134217728,
    "partitionValues": {"year": "2024", "month": "02"},
    "modificationTime": 1707400000000,
    "dataChange": true,
    "stats": "{\"numRecords\":50000,\"minValues\":{\"id\":1},\"maxValues\":{\"id\":50000}}"
  }
}
{
  "remove": {
    "path": "part-00000-old456.snappy.parquet",
    "deletionTimestamp": 1707400000000,
    "dataChange": true
  }
}

ACTIONS IN A COMMIT FILE:
  commitInfo  → Metadata about the operation
  add         → New Parquet file added to the table
  remove      → Old Parquet file marked for removal (not physically deleted)
  metaData    → Schema changes, partition changes, table properties
  protocol    → Reader/writer version requirements
  txn         → Application-level transaction ID (for idempotency)
"""

# ✅ PATTERN: Inspect raw transaction log
import json

# Read a specific commit file
log_path = "/delta/table/_delta_log/00005.json"
log_content = spark.sparkContext.textFile(log_path).collect()

for line in log_content:
    action = json.loads(line)
    print(json.dumps(action, indent=2))
```

### **Checkpoint Files**

```python
"""
CHECKPOINT MECHANISM:

Problem: Reading 10,000 JSON files to reconstruct table state is slow.
Solution: Checkpoint files consolidate state every N versions.

_delta_log/
├── 00000.json
├── 00001.json
├── ...
├── 00009.json
├── 00010.checkpoint.parquet    ← Snapshot of table state at version 10
├── 00010.json
├── 00011.json
├── ...
├── 00019.json
├── 00020.checkpoint.parquet    ← Snapshot at version 20
├── _last_checkpoint            ← Points to latest checkpoint

HOW IT WORKS:
  1. Every 10 commits (configurable), Delta writes a checkpoint
  2. Checkpoint = single Parquet file with ALL active add/remove actions
  3. To read table at version 25:
     - Read checkpoint at version 20 (one file)
     - Replay JSON logs 21-25 (five files)
     - Total: 6 files instead of 26

CONFIGURE CHECKPOINT INTERVAL:
  spark.conf.set("spark.databricks.delta.checkpointInterval", "10")  # default
"""

# ✅ PATTERN: Read _last_checkpoint
last_checkpoint = spark.read.json("/delta/table/_delta_log/_last_checkpoint")
last_checkpoint.show()
# version | size | parts
# 1000    | 5000 | null

# ✅ PATTERN: Force checkpoint
from delta.tables import DeltaTable
delta_table = DeltaTable.forPath(spark, "/delta/table")

# Checkpoint is automatic, but you can trigger via a dummy operation
# or use internal API (Databricks):
# delta_table._jdt.checkpoint()
```

### **Protocol Versioning**

```python
"""
READER/WRITER PROTOCOL:

The protocol action controls which features are enabled and
which minimum reader/writer versions are required.

┌─────────────────────┬──────────────────┬──────────────────┐
│ Feature             │ Min Reader Ver.  │ Min Writer Ver.  │
├─────────────────────┼──────────────────┼──────────────────┤
│ Basic Delta Lake    │ 1                │ 1                │
│ Column mapping      │ 2                │ 5                │
│ Change Data Feed    │ 1                │ 4                │
│ Generated columns   │ 1                │ 4                │
│ CHECK constraints   │ 1                │ 3                │
│ Identity columns    │ 1                │ 6                │
│ Deletion vectors    │ 3                │ 7                │
│ Liquid clustering   │ 3                │ 7                │
│ Row tracking        │ 3                │ 7                │
│ V2 checkpoints      │ 3                │ 7                │
└─────────────────────┴──────────────────┴──────────────────┘

IMPORTANT:
  - Upgrading protocol is IRREVERSIBLE
  - Once you enable writer version 7, older clients cannot write
  - Plan upgrades carefully in shared environments
"""

# ✅ PATTERN: Check current protocol
spark.sql("DESCRIBE DETAIL delta.`/delta/table`").select(
    "minReaderVersion", "minWriterVersion"
).show()

# ✅ PATTERN: Upgrade protocol
spark.sql("""
    ALTER TABLE delta.`/delta/table`
    SET TBLPROPERTIES (
        'delta.minReaderVersion' = '3',
        'delta.minWriterVersion' = '7'
    )
""")
```

### **Conflict Resolution Deep Dive**

```python
"""
OPTIMISTIC CONCURRENCY CONTROL (OCC):

Delta uses file-level conflict detection:

Writer A: Reads version 5, modifies files F1, F2
Writer B: Reads version 5, modifies files F3, F4

SCENARIO 1 — No conflict (different files):
  Writer A commits version 6 (touches F1, F2) ✅
  Writer B tries version 6, sees conflict, rebases to version 7
  Writer B checks: Do my changes conflict with version 6?
  F3, F4 don't overlap with F1, F2 → Auto-retry succeeds ✅

SCENARIO 2 — Conflict (same files):
  Writer A commits version 6 (touches F1, F2) ✅
  Writer B tries version 6, sees conflict, rebases
  Writer B also touches F1 → CONFLICT ❌
  Throws ConcurrentModificationException

CONFLICT RULES:
  ┌──────────────┬────────────┬────────────┬──────────┐
  │              │ APPEND     │ UPDATE     │ DELETE   │
  ├──────────────┼────────────┼────────────┼──────────┤
  │ APPEND       │ ✅ No conf │ ✅ No conf │ ✅ No    │
  │ UPDATE       │ ✅ No conf │ ❌ If same │ ❌ If    │
  │              │            │    files   │   same   │
  │ DELETE       │ ✅ No conf │ ❌ If same │ ❌ If    │
  │              │            │    files   │   same   │
  │ OPTIMIZE     │ ✅ No conf │ ❌ Always  │ ❌ Alw.  │
  └──────────────┴────────────┴────────────┴──────────┘

  Key insight: APPEND never conflicts with anything.
  This is why streaming appends + batch updates can coexist.
"""
```

---

## **PART 13: Liquid Clustering (Delta Lake 3.0+)**

### **Why Liquid Clustering Replaces Partitioning + Z-ORDER**

```
PROBLEM with traditional approach:

  Partitioning:
  ❌ Must choose partition columns upfront (irreversible)
  ❌ Over-partitioning → small files problem
  ❌ Under-partitioning → full table scans
  ❌ Changing partition scheme requires full rewrite

  Z-ORDER:
  ❌ Must run OPTIMIZE manually or on schedule
  ❌ Only works within partitions
  ❌ Effectiveness degrades as data is appended

SOLUTION — Liquid Clustering:
  ✅ Cluster by any column(s) — changeable at any time
  ✅ No partitioning needed (no small files problem)
  ✅ Incremental clustering (only new/modified data)
  ✅ Engine-optimized (Databricks Photon auto-clusters)
  ✅ Replaces PARTITIONED BY + ZORDER BY in one feature
```

### **Using Liquid Clustering**

```python
# ✅ PATTERN 1: Create table with Liquid Clustering
spark.sql("""
    CREATE TABLE events (
        event_id STRING,
        user_id STRING,
        event_type STRING,
        event_date DATE,
        properties MAP<STRING, STRING>
    )
    USING DELTA
    CLUSTER BY (user_id, event_date)
""")

# ✅ PATTERN 2: Enable on existing table
spark.sql("""
    ALTER TABLE events
    CLUSTER BY (user_id, event_date)
""")

# ✅ PATTERN 3: Change clustering columns (no data rewrite!)
# If query patterns change from user_id lookups to event_type lookups:
spark.sql("""
    ALTER TABLE events
    CLUSTER BY (event_type, event_date)
""")
# Only NEW data is clustered by the new columns
# Old data is incrementally re-clustered during OPTIMIZE

# ✅ PATTERN 4: Remove clustering
spark.sql("""
    ALTER TABLE events
    CLUSTER BY NONE
""")

# ✅ PATTERN 5: Trigger clustering (OPTIMIZE still works)
spark.sql("OPTIMIZE events")
# With Liquid Clustering enabled, OPTIMIZE clusters instead of just compacting
# No need for ZORDER BY — clustering is automatic

# ✅ PATTERN 6: Write data (clustering happens automatically on Databricks)
new_events.write \
    .format("delta") \
    .mode("append") \
    .saveAsTable("events")
# Photon engine auto-clusters during write if optimizeWrite is enabled
```

### **Liquid Clustering vs Partitioning vs Z-ORDER**

```
┌────────────────────┬──────────────────┬──────────────┬────────────────────┐
│ Aspect             │ Partitioning     │ Z-ORDER      │ Liquid Clustering  │
├────────────────────┼──────────────────┼──────────────┼────────────────────┤
│ Column selection   │ At table creation│ At OPTIMIZE  │ Any time (ALTER)   │
│ Can change later?  │ ❌ No (rewrite)  │ ✅ Yes       │ ✅ Yes (instant)   │
│ Small files risk   │ ❌ High          │ N/A          │ ✅ None            │
│ Maintenance        │ None             │ Manual/sched │ Automatic          │
│ Data skipping      │ Partition pruning│ File-level   │ File-level         │
│ Incremental?       │ N/A              │ ❌ Full redo │ ✅ Incremental     │
│ Max cluster cols   │ 2-3 practical    │ ~4 practical │ Up to 4            │
│ Works with stream? │ ✅ Yes           │ ❌ Post-hoc  │ ✅ Yes (inline)    │
│ Requires protocol  │ Writer v1        │ Writer v1    │ Reader 3/Writer 7  │
└────────────────────┴──────────────────┴──────────────┴────────────────────┘

INTERVIEW ANSWER:
  "Liquid Clustering is the modern replacement for PARTITIONED BY + ZORDER BY.
   It allows changing clustering columns without rewriting data, avoids small
   files, and clusters incrementally. On Databricks, it's the recommended
   approach for all new tables."
```

---

## **PART 14: Deletion Vectors**

### **How Deletion Vectors Avoid Full File Rewrites**

```
PROBLEM — Traditional DELETE/UPDATE:

  Traditional (Copy-on-Write):
  1. Read entire Parquet file (e.g., 128 MB, 1M rows)
  2. Filter out 5 deleted rows
  3. Write NEW Parquet file with 999,995 rows
  4. Mark old file as removed in log
  → Write amplification: rewrote 128 MB to delete 5 rows!

  With Deletion Vectors:
  1. Create a small deletion vector bitmap (few KB)
  2. Store which row positions are deleted: {row 42, row 1089, row 50001, ...}
  3. Attach DV to the original file in the transaction log
  4. Original file is NOT rewritten
  → Write: only a few KB bitmap instead of 128 MB!

  READS with DVs:
  1. Read Parquet file normally
  2. Check deletion vector
  3. Skip rows marked as deleted
  → Slight read overhead, massive write savings

┌──────────────────────────────────────────────────────────────────┐
│ WITHOUT Deletion Vectors:                                        │
│                                                                  │
│ DELETE 5 rows from file with 1M rows:                            │
│   Read 128 MB → Remove 5 rows → Write 128 MB → Log remove+add  │
│   Cost: 256 MB I/O                                               │
│                                                                  │
│ WITH Deletion Vectors:                                            │
│                                                                  │
│ DELETE 5 rows from file with 1M rows:                            │
│   Write 1 KB bitmap → Log DV attachment                          │
│   Cost: 1 KB I/O                                                 │
│   (Original file untouched!)                                     │
└──────────────────────────────────────────────────────────────────┘
```

### **Using Deletion Vectors**

```python
# ✅ PATTERN 1: Enable deletion vectors
spark.sql("""
    ALTER TABLE events
    SET TBLPROPERTIES (
        'delta.enableDeletionVectors' = 'true'
    )
""")
# Requires: minReaderVersion=3, minWriterVersion=7

# ✅ PATTERN 2: Delete with DVs (automatic — no code change)
# Same syntax, but now uses DVs internally
spark.sql("DELETE FROM events WHERE user_id = 'user_123'")
# Instead of rewriting files, creates deletion vector bitmaps

# ✅ PATTERN 3: Update with DVs (automatic)
spark.sql("""
    UPDATE events
    SET event_type = 'converted'
    WHERE event_id = 'evt_456'
""")
# Old row marked in DV, new row written to new small file

# ✅ PATTERN 4: MERGE with DVs (automatic)
# Matched updates use DVs to mark old rows
delta_table.alias("t").merge(
    source.alias("s"), "t.id = s.id"
).whenMatchedUpdateAll() \
 .whenNotMatchedInsertAll() \
 .execute()

# ✅ PATTERN 5: Compact DVs (materialize deletions)
# Over time, DVs accumulate → run OPTIMIZE to physically remove deleted rows
spark.sql("OPTIMIZE events")
# OPTIMIZE rewrites files with accumulated DVs, resetting them

# ✅ PATTERN 6: Check DV status
spark.sql("DESCRIBE DETAIL events").select(
    "numFiles", "sizeInBytes"
).show()

# View files with DVs via table history
delta_table.history().select(
    "version", "operation", "operationMetrics"
).show(truncate=False)
```

### **Deletion Vectors Performance Impact**

```
┌──────────────────┬──────────────────────────┬────────────────────────┐
│ Operation        │ Without DVs (CoW)        │ With DVs               │
├──────────────────┼──────────────────────────┼────────────────────────┤
│ DELETE 100 rows  │ Rewrite all touched files│ Write 100-byte bitmap  │
│ from 10 GB table │ (potentially 10 GB I/O)  │ (<1 KB I/O)            │
│                  │ Time: minutes            │ Time: milliseconds     │
├──────────────────┼──────────────────────────┼────────────────────────┤
│ UPDATE 1K rows   │ Rewrite files + new file │ DV + small new file    │
│                  │ (GB-scale I/O)           │ (MB-scale I/O)         │
├──────────────────┼──────────────────────────┼────────────────────────┤
│ MERGE (1% match) │ Rewrite ~all target files│ DV for matched rows    │
│                  │ (full table rewrite)     │ + append new rows      │
├──────────────────┼──────────────────────────┼────────────────────────┤
│ READ (scan)      │ Normal speed             │ ~5% overhead (DV check)│
│ OPTIMIZE         │ Normal compaction        │ Also materializes DVs  │
└──────────────────┴──────────────────────────┴────────────────────────┘

BEST PRACTICE:
  - Enable DVs for tables with frequent DELETE/UPDATE/MERGE
  - Run OPTIMIZE periodically to compact DVs
  - Monitor DV accumulation — too many DVs slow reads
```

---

## **PART 15: UniForm (Universal Format)**

### **What UniForm Does**

```
PROBLEM:
  Team A uses Delta Lake (Databricks)
  Team B uses Iceberg (Trino/Athena)
  Team C uses Hudi (EMR)
  → Same data must be readable by all three formats!

TRADITIONAL SOLUTION:
  Maintain 3 copies of data → expensive, inconsistent

UNIFORM SOLUTION:
  Write once as Delta → UniForm auto-generates Iceberg + Hudi metadata
  All three engines read the SAME Parquet files with their native metadata

┌───────────────────────────────────────────────────────────┐
│                     SAME Parquet Files                     │
│                                                           │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │ _delta_log/  │  │ metadata/    │  │ .hoodie/        │  │
│  │ (Delta meta) │  │ (Iceberg     │  │ (Hudi metadata) │  │
│  │              │  │  metadata)   │  │                 │  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬──────────┘  │
│         │                 │                  │             │
│    Databricks        Trino/Athena       EMR/Hudi          │
│    Spark SQL         Presto             Spark             │
└───────────────────────────────────────────────────────────┘

UniForm automatically keeps all metadata layers in sync
when writing via Delta Lake.
```

### **Using UniForm**

```python
# ✅ PATTERN 1: Enable UniForm (Iceberg compatibility)
spark.sql("""
    CREATE TABLE sales (
        sale_id BIGINT,
        product STRING,
        amount DECIMAL(10,2),
        sale_date DATE
    )
    USING DELTA
    TBLPROPERTIES (
        'delta.universalFormat.enabledFormats' = 'iceberg'
    )
""")

# ✅ PATTERN 2: Enable UniForm on existing table
spark.sql("""
    ALTER TABLE sales
    SET TBLPROPERTIES (
        'delta.universalFormat.enabledFormats' = 'iceberg'
    )
""")
# Requires: delta.columnMapping.mode = 'name'
#           minReaderVersion = 3, minWriterVersion = 7

# ✅ PATTERN 3: Enable both Iceberg AND Hudi
spark.sql("""
    ALTER TABLE sales
    SET TBLPROPERTIES (
        'delta.universalFormat.enabledFormats' = 'iceberg,hudi'
    )
""")

# ✅ PATTERN 4: Read as Iceberg from another engine
# From Trino/Presto:
# SELECT * FROM iceberg.schema.sales WHERE sale_date = '2024-02-08'
#
# From Athena:
# SELECT * FROM sales  (via Glue catalog with Iceberg metadata)
#
# From Spark with Iceberg catalog:
# spark.read.format("iceberg").load("catalog.schema.sales")

# ✅ PATTERN 5: Verify UniForm is working
spark.sql("DESCRIBE DETAIL sales").select(
    "format", "properties"
).show(truncate=False)
# properties should include universalFormat.enabledFormats = iceberg
```

---

## **PART 16: Clone Operations**

### **SHALLOW CLONE vs DEEP CLONE**

```
SHALLOW CLONE:
  - Copies only metadata (transaction log)
  - Does NOT copy Parquet data files
  - Points to original data files
  - Zero-copy — instant, no storage cost
  - Changes to clone don't affect source
  - If source files are VACUUM'd, clone breaks!

  Source Table:                Clone Table:
  ┌──────────────┐            ┌──────────────┐
  │ _delta_log/  │            │ _delta_log/  │ (new, independent)
  │ data/        │◄───────────│ (references) │ (points to source files)
  │  file1.parq  │            └──────────────┘
  │  file2.parq  │
  └──────────────┘

DEEP CLONE:
  - Copies metadata AND all Parquet data files
  - Fully independent copy
  - Takes time and storage proportional to table size
  - Safe — source changes don't affect clone

  Source Table:                Clone Table:
  ┌──────────────┐            ┌──────────────┐
  │ _delta_log/  │            │ _delta_log/  │ (new copy)
  │ data/        │            │ data/        │ (full copy)
  │  file1.parq  │            │  file1.parq  │
  │  file2.parq  │            │  file2.parq  │
  └──────────────┘            └──────────────┘
```

### **Clone Patterns**

```python
# ✅ PATTERN 1: SHALLOW CLONE (instant copy for testing)
spark.sql("""
    CREATE TABLE events_dev
    SHALLOW CLONE events
""")
# Instant — no data copied

# ✅ PATTERN 2: DEEP CLONE (full independent copy)
spark.sql("""
    CREATE TABLE events_backup
    DEEP CLONE events
""")
# Takes time — copies all data files

# ✅ PATTERN 3: Clone to specific path
spark.sql("""
    CREATE TABLE events_staging
    SHALLOW CLONE events
    LOCATION '/delta/staging/events'
""")

# ✅ PATTERN 4: Clone specific version (time travel + clone)
spark.sql("""
    CREATE TABLE events_snapshot
    DEEP CLONE events VERSION AS OF 100
""")

# ✅ PATTERN 5: Clone for A/B testing
# Create test environment from production
spark.sql("CREATE TABLE customers_test SHALLOW CLONE customers")

# Modify test copy freely — source is untouched
spark.sql("""
    UPDATE customers_test
    SET discount_tier = 'premium'
    WHERE total_purchases > 10000
""")

# Run tests against customers_test
# If test passes → apply same update to production
# If test fails → drop customers_test (no cost)

# ✅ PATTERN 6: Clone for schema migration
# Clone current table
spark.sql("CREATE TABLE users_v2 DEEP CLONE users")

# Apply schema changes to clone
spark.sql("ALTER TABLE users_v2 ADD COLUMNS (phone STRING)")
spark.sql("ALTER TABLE users_v2 DROP COLUMN legacy_field")

# Validate
validation = spark.table("users_v2")
assert validation.count() == spark.table("users").count()

# Swap (rename)
spark.sql("ALTER TABLE users RENAME TO users_v1_backup")
spark.sql("ALTER TABLE users_v2 RENAME TO users")

# ✅ PATTERN 7: Incremental DEEP CLONE (sync changes)
# After initial deep clone, sync only new changes:
spark.sql("""
    CREATE OR REPLACE TABLE events_backup
    DEEP CLONE events
""")
# Only copies files that changed since last clone
```

### **Clone Use Cases Summary**

```
┌────────────────────────┬────────────────┬──────────────────────────────┐
│ Use Case               │ Clone Type     │ Why                          │
├────────────────────────┼────────────────┼──────────────────────────────┤
│ Dev/test environment   │ SHALLOW        │ Instant, no storage cost     │
│ Disaster recovery      │ DEEP           │ Full independent backup      │
│ Schema migration       │ DEEP           │ Safe to modify independently │
│ A/B testing            │ SHALLOW        │ Fast setup, easy cleanup     │
│ Cross-region replica   │ DEEP           │ Independent in each region   │
│ Audit snapshot         │ DEEP + VERSION │ Point-in-time backup         │
│ Table archival         │ DEEP           │ Archive before VACUUM        │
└────────────────────────┴────────────────┴──────────────────────────────┘
```

---

## **PART 17: CHECK Constraints**

### **Table-Level Data Quality Enforcement**

```python
# ✅ PATTERN 1: Add CHECK constraint
spark.sql("""
    ALTER TABLE orders
    ADD CONSTRAINT valid_amount CHECK (amount > 0)
""")

# Now any write with amount <= 0 will FAIL:
# spark.sql("INSERT INTO orders VALUES (1, 'prod', -5.00, '2024-02-08')")
# Error: CHECK constraint valid_amount (amount > 0) violated

# ✅ PATTERN 2: Multiple constraints
spark.sql("""
    ALTER TABLE customers
    ADD CONSTRAINT valid_email CHECK (email LIKE '%@%.%')
""")

spark.sql("""
    ALTER TABLE customers
    ADD CONSTRAINT valid_age CHECK (age >= 0 AND age <= 150)
""")

spark.sql("""
    ALTER TABLE customers
    ADD CONSTRAINT valid_status CHECK (status IN ('active', 'inactive', 'suspended'))
""")

# ✅ PATTERN 3: Date range constraints
spark.sql("""
    ALTER TABLE events
    ADD CONSTRAINT valid_date CHECK (event_date >= '2020-01-01')
""")

spark.sql("""
    ALTER TABLE events
    ADD CONSTRAINT future_check CHECK (event_date <= current_date())
""")

# ✅ PATTERN 4: Cross-column constraints
spark.sql("""
    ALTER TABLE orders
    ADD CONSTRAINT valid_dates CHECK (ship_date >= order_date)
""")

spark.sql("""
    ALTER TABLE discounts
    ADD CONSTRAINT valid_discount CHECK (
        discount_pct >= 0 AND discount_pct <= 100
        AND (discount_pct < 50 OR approval_status = 'manager_approved')
    )
""")

# ✅ PATTERN 5: View existing constraints
spark.sql("DESCRIBE DETAIL orders").select("properties").show(truncate=False)
# Or:
spark.sql("SHOW TBLPROPERTIES orders").show(truncate=False)

# ✅ PATTERN 6: Drop a constraint
spark.sql("""
    ALTER TABLE orders
    DROP CONSTRAINT valid_amount
""")

# ✅ PATTERN 7: NOT NULL constraints (also a form of CHECK)
spark.sql("""
    ALTER TABLE customers
    ALTER COLUMN customer_id SET NOT NULL
""")

spark.sql("""
    ALTER TABLE customers
    ALTER COLUMN email SET NOT NULL
""")
```

### **CHECK Constraints vs Application-Level Validation**

```
┌──────────────────────┬──────────────────────────┬─────────────────────────┐
│ Aspect               │ CHECK Constraints        │ App-Level Validation    │
├──────────────────────┼──────────────────────────┼─────────────────────────┤
│ Enforcement point    │ Storage layer (Delta)    │ Application code        │
│ Can be bypassed?     │ ❌ No (all writes)       │ ⚠️ Yes (if skipped)     │
│ Multiple writers     │ ✅ All writers checked   │ ❌ Each must implement  │
│ Error handling       │ Write fails immediately  │ Custom error handling   │
│ Flexibility          │ SQL expressions only     │ Any logic               │
│ Performance          │ Slight write overhead    │ Pre-write overhead      │
│ Best for             │ Hard invariants          │ Soft/complex rules      │
└──────────────────────┴──────────────────────────┴─────────────────────────┘

BEST PRACTICE: Use BOTH
  - CHECK constraints for hard invariants (amount > 0, valid status codes)
  - App-level validation for complex business rules (cross-table checks)
```

---

## **PART 18: Generated Columns & Identity Columns**

### **Generated Columns (Auto-Computed)**

```python
# Generated columns are automatically computed from other columns
# Useful for: partition columns, derived fields, denormalization

# ✅ PATTERN 1: Generate date from timestamp (for partitioning)
spark.sql("""
    CREATE TABLE events (
        event_id STRING,
        event_timestamp TIMESTAMP,
        event_date DATE GENERATED ALWAYS AS (CAST(event_timestamp AS DATE)),
        user_id STRING,
        event_type STRING
    )
    USING DELTA
    PARTITIONED BY (event_date)
""")
# Writers only provide event_timestamp
# event_date is auto-computed → partitioning is automatic!

# ✅ PATTERN 2: Generate year/month for partitioning
spark.sql("""
    CREATE TABLE sales (
        sale_id BIGINT,
        sale_timestamp TIMESTAMP,
        year INT GENERATED ALWAYS AS (YEAR(sale_timestamp)),
        month INT GENERATED ALWAYS AS (MONTH(sale_timestamp)),
        amount DECIMAL(10,2)
    )
    USING DELTA
    PARTITIONED BY (year, month)
""")

# ✅ PATTERN 3: Generate hash for bucketing
spark.sql("""
    CREATE TABLE users (
        user_id STRING,
        user_bucket INT GENERATED ALWAYS AS (ABS(HASH(user_id)) % 256),
        name STRING,
        email STRING
    )
    USING DELTA
""")

# ✅ PATTERN 4: Generate uppercase key for case-insensitive lookups
spark.sql("""
    CREATE TABLE products (
        product_code STRING,
        product_code_upper STRING GENERATED ALWAYS AS (UPPER(product_code)),
        name STRING,
        price DECIMAL(10,2)
    )
    USING DELTA
""")

# Writing: Just provide the source columns
spark.sql("""
    INSERT INTO events (event_id, event_timestamp, user_id, event_type)
    VALUES ('evt1', '2024-02-08 14:30:00', 'user1', 'click')
""")
# event_date is auto-populated as '2024-02-08'

# QUERY OPTIMIZATION:
# This query on event_timestamp auto-uses partition pruning on event_date:
spark.sql("""
    SELECT * FROM events
    WHERE event_timestamp >= '2024-02-01' AND event_timestamp < '2024-03-01'
""")
# Delta infers: event_date >= '2024-02-01' AND event_date < '2024-03-01'
# → Only scans February partition!
```

### **Identity Columns (Auto-Increment)**

```python
# Identity columns generate unique, auto-incrementing values
# Useful for: surrogate keys, monotonically increasing IDs

# ✅ PATTERN 1: Basic identity column
spark.sql("""
    CREATE TABLE customers (
        customer_sk BIGINT GENERATED ALWAYS AS IDENTITY,
        customer_id STRING,
        name STRING,
        email STRING
    )
    USING DELTA
""")
# customer_sk: 1, 2, 3, 4, ... (auto-generated, unique)

# ✅ PATTERN 2: Identity with custom start and step
spark.sql("""
    CREATE TABLE orders (
        order_sk BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 1000 INCREMENT BY 1),
        order_id STRING,
        customer_id STRING,
        amount DECIMAL(10,2)
    )
    USING DELTA
""")
# order_sk: 1000, 1001, 1002, ...

# ✅ PATTERN 3: Identity as default (can be overridden)
spark.sql("""
    CREATE TABLE products (
        product_sk BIGINT GENERATED BY DEFAULT AS IDENTITY,
        product_id STRING,
        name STRING
    )
    USING DELTA
""")
# GENERATED BY DEFAULT → can provide explicit value during INSERT
# GENERATED ALWAYS → cannot override, always auto-generated

# Writing: Omit the identity column
spark.sql("""
    INSERT INTO customers (customer_id, name, email)
    VALUES ('cust_001', 'Alice', 'alice@example.com')
""")
# customer_sk is auto-assigned

"""
IDENTITY COLUMN CAVEATS:
  - Values are UNIQUE but NOT NECESSARILY CONTIGUOUS
    (gaps can occur due to failed transactions, parallelism)
  - NOT a replacement for natural keys
  - Requires minWriterVersion = 6
  - Cannot be used with GENERATED ALWAYS AS (expression)
"""
```

---

## **PART 19: Bloom Filter Index**

### **Point Lookup Optimization**

```
PROBLEM: Finding a specific record in a large table

  Without Bloom Filter:
  Query: SELECT * FROM events WHERE event_id = 'evt_abc123'
  → Must check min/max stats for every file
  → If event_id is random (UUID), min/max is useless
  → Full table scan!

  With Bloom Filter:
  → Each file has a Bloom filter for event_id
  → Bloom filter says "definitely NOT in this file" or "MAYBE in this file"
  → Skip 99% of files → read only 1-2 files!

  HOW IT WORKS:
  ┌──────────────────────────────────────────────────┐
  │ File 1: Bloom filter for event_id                │
  │   "evt_abc123" → hash → check bits → NOT HERE    │ ← Skip!
  │                                                   │
  │ File 2: Bloom filter for event_id                │
  │   "evt_abc123" → hash → check bits → NOT HERE    │ ← Skip!
  │                                                   │
  │ File 3: Bloom filter for event_id                │
  │   "evt_abc123" → hash → check bits → MAYBE HERE  │ ← Read!
  │   (Actually found: row 42,501)                    │
  └──────────────────────────────────────────────────┘

  False positive rate: ~1% (configurable)
  False negative rate: 0% (NEVER misses a match)
```

### **Using Bloom Filters**

```python
# ✅ PATTERN 1: Create Bloom filter index
spark.sql("""
    CREATE BLOOMFILTER INDEX ON TABLE events
    FOR COLUMNS (event_id OPTIONS (fpp=0.01, numItems=10000000))
""")
# fpp = false positive probability (default 0.01 = 1%)
# numItems = expected distinct values

# ✅ PATTERN 2: Via table properties
spark.sql("""
    ALTER TABLE events
    SET TBLPROPERTIES (
        'delta.dataSkippingNumIndexedCols' = '32',
        'delta.bloomFilter.columns' = 'event_id,user_id',
        'delta.bloomFilter.event_id.fpp' = '0.01',
        'delta.bloomFilter.event_id.numItems' = '10000000',
        'delta.bloomFilter.user_id.fpp' = '0.01',
        'delta.bloomFilter.user_id.numItems' = '1000000'
    )
""")

# ✅ PATTERN 3: Query benefits (automatic — no syntax change)
# These queries automatically use Bloom filter:
spark.sql("SELECT * FROM events WHERE event_id = 'evt_abc123'")
spark.sql("SELECT * FROM events WHERE user_id IN ('user_1', 'user_2', 'user_3')")

# ✅ PATTERN 4: Drop Bloom filter
spark.sql("DROP BLOOMFILTER INDEX ON TABLE events FOR COLUMNS (event_id)")

# ✅ PATTERN 5: Rebuild index after major changes
# After OPTIMIZE or large data load, rebuild for accuracy:
spark.sql("""
    CREATE BLOOMFILTER INDEX ON TABLE events
    FOR COLUMNS (event_id OPTIONS (fpp=0.01, numItems=50000000))
""")
```

### **When to Use Bloom Filters**

```
GOOD candidates for Bloom filter:
  ✅ High-cardinality columns (UUIDs, event IDs, user IDs)
  ✅ Point lookups (WHERE id = 'value')
  ✅ IN queries with few values
  ✅ Columns with random/non-sequential values (hashes, UUIDs)

BAD candidates for Bloom filter:
  ❌ Low-cardinality columns (status, country) — min/max stats work fine
  ❌ Range queries (WHERE date BETWEEN ...) — Bloom only works for equality
  ❌ Already partitioned columns — partition pruning is better
  ❌ Columns rarely used in WHERE clauses — wasted storage

OVERHEAD:
  Storage: ~10 bytes per distinct value per file (small)
  Write:   ~5% slower (building Bloom filter during write)
  Read:    Faster for point lookups, no impact on scans
```

---

## **PART 20: Multi-Cluster Writes (S3/ADLS)**

### **The S3 Consistency Problem**

```
PROBLEM: S3 doesn't support atomic rename

  Delta Lake uses atomic file rename for commits:
    Write 00005.json.tmp → Rename to 00005.json (atomic on HDFS/DBFS)

  On S3:
    ❌ Rename is NOT atomic (it's copy + delete)
    ❌ Two writers could both "win" the same version
    ❌ Corrupted transaction log!

SOLUTION: S3DynamoDBLogStore

  ┌──────────┐     ┌──────────────┐     ┌──────────┐
  │ Writer A │────►│ DynamoDB     │◄────│ Writer B │
  │ (EMR)    │     │ (Lock Table) │     │ (Glue)   │
  └──────┬───┘     └──────────────┘     └──────┬───┘
         │                                      │
         ▼                                      ▼
  ┌──────────────────────────────────────────────────┐
  │                    S3 Bucket                      │
  │  _delta_log/00005.json                           │
  │  data/part-xxxxx.parquet                         │
  └──────────────────────────────────────────────────┘

  DynamoDB acts as a distributed lock:
  1. Writer A: "I want to write version 5" → acquires lock
  2. Writer B: "I want to write version 5" → blocked (lock held)
  3. Writer A: Writes 00005.json to S3 → releases lock
  4. Writer B: Retries as version 6
```

### **Configuring Multi-Cluster Writes**

```python
# ✅ PATTERN 1: Configure S3DynamoDBLogStore
spark = SparkSession.builder \
    .appName("MultiClusterDelta") \
    .config("spark.delta.logStore.class",
            "io.delta.storage.S3DynamoDBLogStore") \
    .config("spark.io.delta.storage.S3DynamoDBLogStore.ddb.tableName",
            "delta_log_lock_table") \
    .config("spark.io.delta.storage.S3DynamoDBLogStore.ddb.region",
            "us-east-1") \
    .config("spark.hadoop.fs.s3a.access.key", "...") \
    .config("spark.hadoop.fs.s3a.secret.key", "...") \
    .getOrCreate()

# ✅ PATTERN 2: Create DynamoDB lock table (one-time setup)
# AWS CLI:
# aws dynamodb create-table \
#   --table-name delta_log_lock_table \
#   --attribute-definitions \
#     AttributeName=tablePath,AttributeType=S \
#     AttributeName=fileName,AttributeType=S \
#   --key-schema \
#     AttributeName=tablePath,KeyType=HASH \
#     AttributeName=fileName,KeyType=RANGE \
#   --billing-mode PAY_PER_REQUEST \
#   --region us-east-1

# ✅ PATTERN 3: EMR configuration (emr-config.json)
"""
{
  "Classification": "spark-defaults",
  "Properties": {
    "spark.delta.logStore.class": "io.delta.storage.S3DynamoDBLogStore",
    "spark.io.delta.storage.S3DynamoDBLogStore.ddb.tableName": "delta_log",
    "spark.io.delta.storage.S3DynamoDBLogStore.ddb.region": "us-east-1"
  }
}
"""

# ✅ PATTERN 4: ADLS (Azure) — built-in atomicity
# Azure Data Lake Storage Gen2 supports atomic rename natively
# No additional log store needed!
spark = SparkSession.builder \
    .config("spark.delta.logStore.class",
            "io.delta.storage.AzureLogStore") \
    .getOrCreate()

# ✅ PATTERN 5: GCS — uses Cloud Storage lock
spark = SparkSession.builder \
    .config("spark.delta.logStore.class",
            "io.delta.storage.GCSLogStore") \
    .getOrCreate()
```

### **Multi-Cluster Architecture Patterns**

```
PATTERN A: Shared table, multiple writers (same data)
  ┌────────────┐
  │ EMR Job A  │──write──┐
  └────────────┘         ▼
                    ┌──────────┐     ┌─────────────┐
                    │ DynamoDB │────►│ Delta Table  │
                    │ (Lock)   │     │ (S3)         │
  ┌────────────┐   └──────────┘     └─────────────┘
  │ EMR Job B  │──write──┘
  └────────────┘
  Use case: Multiple ingest jobs writing to same table
  Risk: Conflicts on UPDATE/MERGE (appends are safe)

PATTERN B: Partition-isolated writers (recommended)
  ┌────────────┐
  │ Job A      │──write──► partition: region=US
  └────────────┘
  ┌────────────┐
  │ Job B      │──write──► partition: region=EU
  └────────────┘
  ┌────────────┐
  │ Job C      │──write──► partition: region=APAC
  └────────────┘
  All write to same Delta table, but different partitions
  → Zero conflict, no locking needed!

BEST PRACTICE:
  1. Use APPEND mode when possible (no conflicts)
  2. Partition-isolate concurrent writers
  3. If MERGE is unavoidable, use DynamoDB LogStore
  4. Monitor DynamoDB for throttling (enable auto-scaling)
```

---

## **PART 21: Column Mapping**

### **Name Mode vs ID Mode**

```
PROBLEM: Parquet files reference columns by POSITION (ordinal index)
  Column 0 = "id", Column 1 = "name", Column 2 = "email"

  Renaming "email" to "email_address" is IMPOSSIBLE without rewriting
  all Parquet files (since position is embedded in file metadata).

SOLUTION: Column Mapping
  Adds a logical ID layer between column names and physical positions.

  ┌────────────────────────────────────────────────────────┐
  │ POSITION MODE (default, legacy):                       │
  │   Logical: id(0), name(1), email(2)                    │
  │   Physical: column_0, column_1, column_2               │
  │   → Rename requires full rewrite                       │
  │                                                        │
  │ NAME MODE (delta.columnMapping.mode = 'name'):         │
  │   Logical: id → col-abc, name → col-def, email → col-ghi│
  │   Physical: col-abc, col-def, col-ghi (random IDs)    │
  │   → Rename just updates mapping in metadata!           │
  │   → Drop column just removes mapping — no file rewrite │
  └────────────────────────────────────────────────────────┘
```

### **Using Column Mapping**

```python
# ✅ PATTERN 1: Enable column mapping
spark.sql("""
    ALTER TABLE customers
    SET TBLPROPERTIES (
        'delta.columnMapping.mode' = 'name',
        'delta.minReaderVersion' = '2',
        'delta.minWriterVersion' = '5'
    )
""")

# ✅ PATTERN 2: Rename column (only works with column mapping!)
spark.sql("""
    ALTER TABLE customers
    RENAME COLUMN email TO email_address
""")
# Instant — no data rewrite, just updates metadata mapping

# ✅ PATTERN 3: Drop column (only works with column mapping!)
spark.sql("""
    ALTER TABLE customers
    DROP COLUMN legacy_field
""")
# Instant — just removes from metadata
# Physical data remains in Parquet files until VACUUM + OPTIMIZE

# ✅ PATTERN 4: Rename nested struct fields
spark.sql("""
    ALTER TABLE events
    RENAME COLUMN properties.user_agent TO properties.browser
""")

# ✅ PATTERN 5: Create table with column mapping from the start
spark.sql("""
    CREATE TABLE new_table (
        id BIGINT,
        name STRING,
        data STRUCT<field1: STRING, field2: INT>
    )
    USING DELTA
    TBLPROPERTIES (
        'delta.columnMapping.mode' = 'name'
    )
""")
```

### **Column Mapping Caveats**

```
IMPORTANT CONSIDERATIONS:

1. IRREVERSIBLE: Once enabled, cannot switch back to position mode

2. PROTOCOL UPGRADE: Requires minReaderVersion=2, minWriterVersion=5
   → Older Delta clients cannot read the table

3. STREAMING IMPACT: Existing streaming queries must be restarted
   after enabling column mapping

4. REQUIRED FOR:
   - Column rename (ALTER TABLE RENAME COLUMN)
   - Column drop (ALTER TABLE DROP COLUMN)
   - UniForm (requires name mode)
   - Liquid Clustering (requires name mode)

5. BEST PRACTICE: Enable on ALL new tables — there's no downside
   and it unlocks critical features
```

---

## **PART 22: Idempotent Writes (txnAppId / txnVersion)**

### **Exactly-Once Batch Writes**

```
PROBLEM: Job fails after writing some data, then retries
  Run 1: Writes 1000 rows → FAILS at commit → partial data? No (ACID)
  Run 2: Writes 1000 rows → SUCCEEDS → but did Run 1 partially succeed?

  With idempotent writes:
  Run 1: txnAppId="job_daily_load", txnVersion=1 → FAILS
  Run 2: txnAppId="job_daily_load", txnVersion=1 → SUCCEEDS
  Run 3: txnAppId="job_daily_load", txnVersion=1 → SKIPPED (already done!)
```

### **Using Idempotent Writes**

```python
# ✅ PATTERN 1: Idempotent write with txn options
df.write \
    .format("delta") \
    .mode("append") \
    .option("txnAppId", "daily_sales_etl") \
    .option("txnVersion", "20240208") \
    .save("/delta/sales")

# If this write is retried (same txnAppId + txnVersion):
# Delta checks: "daily_sales_etl version 20240208 already committed"
# → Write is SKIPPED silently (no error, no duplicate data)

# ✅ PATTERN 2: Idempotent writes in orchestrated pipelines
def idempotent_load(df, target_path, job_name, run_date):
    """
    Load data exactly once, even if retried.

    Args:
        df: Source DataFrame
        target_path: Delta table path
        job_name: Unique job identifier
        run_date: Run date as version identifier
    """
    txn_version = run_date.strftime("%Y%m%d%H%M%S")

    df.write \
        .format("delta") \
        .mode("append") \
        .option("txnAppId", job_name) \
        .option("txnVersion", txn_version) \
        .save(target_path)

    print(f"Write completed: {job_name} v{txn_version}")

# Usage in Airflow DAG:
from datetime import datetime

idempotent_load(
    df=daily_sales_df,
    target_path="/delta/sales",
    job_name="daily_sales_etl",
    run_date=datetime(2024, 2, 8)
)
# Safe to retry — duplicate runs are automatically deduplicated

# ✅ PATTERN 3: Idempotent streaming with foreachBatch
def idempotent_upsert(batch_df, batch_id):
    """Idempotent upsert for streaming."""
    delta_table = DeltaTable.forPath(spark, "/delta/customers")

    delta_table.alias("t").merge(
        batch_df.alias("s"),
        "t.customer_id = s.customer_id"
    ).whenMatchedUpdateAll() \
     .whenNotMatchedInsertAll() \
     .execute()

# foreachBatch + checkpointing already provides exactly-once
# txnAppId adds extra safety for manual restarts:
streaming_df.writeStream \
    .foreachBatch(idempotent_upsert) \
    .option("checkpointLocation", "/delta/checkpoints/customers") \
    .start()

# ✅ PATTERN 4: Check transaction history
delta_table = DeltaTable.forPath(spark, "/delta/sales")
history = delta_table.history()
history.select("version", "operation", "operationParameters").show(truncate=False)
# Look for txnAppId in operationParameters
```

---

## **PART 23: Copy-on-Write vs Merge-on-Read**

### **Two Strategies for Handling Updates**

```
COPY-ON-WRITE (CoW) — Delta Lake's default:
═══════════════════════════════════════════

  UPDATE: "Change user_123's email"

  1. Find file containing user_123 (e.g., file_A.parquet, 128 MB, 1M rows)
  2. Read entire file_A.parquet into memory
  3. Apply change to user_123's row
  4. Write NEW file_A_v2.parquet (128 MB, 1M rows)
  5. Log: remove file_A, add file_A_v2

  ┌────────────────┐     ┌────────────────┐
  │ file_A.parquet │     │file_A_v2.parquet│
  │ (1M rows)      │ ──► │ (1M rows)       │
  │ user_123: old  │     │ user_123: NEW   │
  │ 999,999 others │     │ 999,999 same    │
  └────────────────┘     └────────────────┘
       REMOVED                ADDED

  Pros: ✅ Fast reads (no merge needed at query time)
  Cons: ❌ Slow writes (full file rewrite for 1 row change)
        ❌ Write amplification (128 MB to change 1 row)


MERGE-ON-READ (MoR) — Used by Hudi, Iceberg; Delta via Deletion Vectors:
════════════════════════════════════════════════════════════════════════

  UPDATE: "Change user_123's email"

  1. Write small delta file with ONLY the changed row (< 1 KB)
  2. Mark old row position in deletion vector
  3. At READ time: merge base file + delta file

  ┌────────────────┐     ┌──────────────┐
  │ file_A.parquet │  +  │ delta_file   │
  │ (1M rows)      │     │ (1 row)      │
  │ user_123: old  │     │ user_123: NEW│
  └────────────────┘     └──────────────┘
    NOT MODIFIED           SMALL NEW FILE

  At read time:
  file_A rows (skip deleted) + delta_file rows = merged result

  Pros: ✅ Fast writes (only write changed rows)
        ✅ Low write amplification
  Cons: ❌ Slower reads (must merge at query time)
        ❌ Requires periodic compaction
```

### **Comparison Table**

```
┌─────────────────────┬─────────────────────┬────────────────────────┐
│ Aspect              │ Copy-on-Write (CoW) │ Merge-on-Read (MoR)    │
├─────────────────────┼─────────────────────┼────────────────────────┤
│ Write speed         │ ❌ Slow             │ ✅ Fast                │
│ Read speed          │ ✅ Fast             │ ❌ Slower (merge cost) │
│ Write amplification │ ❌ High (full file) │ ✅ Low (delta only)    │
│ Storage efficiency  │ ❌ Duplicated data  │ ✅ Minimal extra       │
│ Complexity          │ ✅ Simple           │ ❌ Complex (compaction)│
├─────────────────────┼─────────────────────┼────────────────────────┤
│ Best for            │ Read-heavy workloads│ Write-heavy workloads  │
│                     │ Infrequent updates  │ Frequent updates/CDC   │
│                     │ Analytics/BI        │ OLTP-like patterns     │
├─────────────────────┼─────────────────────┼────────────────────────┤
│ Delta Lake          │ ✅ Default mode     │ ⚠️ Via Deletion Vectors│
│ Apache Iceberg      │ ✅ Supported        │ ✅ Supported (v2)      │
│ Apache Hudi         │ ✅ COW table type   │ ✅ MOR table type      │
└─────────────────────┴─────────────────────┴────────────────────────┘

DELTA LAKE EVOLUTION:
  v1.0: Copy-on-Write only
  v2.0: Still CoW, but with Change Data Feed
  v3.0: Deletion Vectors = partial MoR behavior
        (marks deletes without rewriting, but inserts still CoW)

  Delta's approach: CoW + Deletion Vectors = hybrid
    - Deletes/updates: MoR-like (deletion vector, no file rewrite)
    - New inserts: CoW (new Parquet files)
    - OPTIMIZE: Materializes all changes (compacts DVs)

INTERVIEW ANSWER:
  "Delta Lake uses Copy-on-Write by default, which optimizes for read-heavy
   analytics workloads. With Deletion Vectors (v3.0+), it adds MoR-like
   behavior for deletes and updates without full file rewrites. Hudi offers
   both CoW and MoR as explicit table types. Iceberg v2 also supports both.
   The tradeoff is always write performance vs read performance."
```

---

## **PART 24: Medallion Architecture (Bronze / Silver / Gold)**

### **The Three-Layer Lakehouse Pattern**

```
┌──────────────────────────────────────────────────────────────────────┐
│                     MEDALLION ARCHITECTURE                           │
│                                                                      │
│  RAW SOURCES         BRONZE            SILVER            GOLD        │
│  ┌─────────┐     ┌───────────┐     ┌───────────┐     ┌───────────┐  │
│  │ Kafka   │────►│ Raw       │────►│ Cleaned   │────►│ Business  │  │
│  │ S3 files│     │ Ingestion │     │ Conformed │     │ Aggregates│  │
│  │ APIs    │     │ Append-   │     │ Deduplied │     │ Curated   │  │
│  │ DBs     │     │ only      │     │ Validated │     │ KPI-ready │  │
│  └─────────┘     └───────────┘     └───────────┘     └───────────┘  │
│                                                                      │
│  Principle:  Raw ingest  →  Clean & conform  →  Business logic       │
│  Schema:     Source schema   Canonical schema   Star schema / agg    │
│  Quality:    No validation   Data quality rules  Business rules      │
│  Consumers:  Data engineers  Data engineers      Analysts / BI / ML  │
│  Retention:  Long (audit)    Medium              Short (re-derivable)│
│  Writes:     Append-only     MERGE (dedupe)      Overwrite / MERGE   │
└──────────────────────────────────────────────────────────────────────┘
```

### **Implementing Medallion with Delta Lake**

```python
# ═══════════════════════════════════════════════════
# BRONZE LAYER — Raw ingestion, append-only
# ═══════════════════════════════════════════════════

# Bronze: Ingest raw Kafka events (preserve everything)
raw_events = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", "broker:9092") \
    .option("subscribe", "user_events") \
    .load()

bronze_df = raw_events.select(
    col("key").cast("string").alias("event_key"),
    col("value").cast("string").alias("raw_payload"),
    col("topic"),
    col("partition"),
    col("offset"),
    col("timestamp").alias("kafka_timestamp"),
    current_timestamp().alias("ingested_at")
)

bronze_df.writeStream \
    .format("delta") \
    .outputMode("append") \
    .option("checkpointLocation", "/checkpoints/bronze/user_events") \
    .trigger(processingTime="30 seconds") \
    .start("/delta/bronze/user_events")

# Bronze table properties
spark.sql("""
    ALTER TABLE bronze.user_events SET TBLPROPERTIES (
        'delta.enableChangeDataFeed' = 'true',
        'delta.logRetentionDuration' = 'interval 90 days',
        'delta.deletedFileRetentionDuration' = 'interval 90 days'
    )
""")

# ═══════════════════════════════════════════════════
# SILVER LAYER — Cleaned, conformed, deduplicated
# ═══════════════════════════════════════════════════

from pyspark.sql.functions import from_json, col, sha2, concat

# Silver: Parse, validate, deduplicate
event_schema = StructType([
    StructField("event_id", StringType()),
    StructField("user_id", StringType()),
    StructField("event_type", StringType()),
    StructField("properties", MapType(StringType(), StringType())),
    StructField("event_timestamp", TimestampType())
])

def bronze_to_silver(batch_df, batch_id):
    # Step 1: Parse JSON
    parsed = batch_df.select(
        from_json(col("raw_payload"), event_schema).alias("data"),
        col("kafka_timestamp"),
        col("ingested_at")
    ).select("data.*", "kafka_timestamp", "ingested_at")

    # Step 2: Data quality filters
    clean = parsed.filter(
        col("event_id").isNotNull() &
        col("user_id").isNotNull() &
        col("event_type").isin("click", "view", "purchase", "signup")
    )

    # Step 3: Add derived columns
    enriched = clean.withColumn(
        "event_date", col("event_timestamp").cast("date")
    ).withColumn(
        "row_hash", sha2(concat(col("event_id"), col("event_timestamp")), 256)
    )

    # Step 4: MERGE to deduplicate
    silver_table = DeltaTable.forPath(spark, "/delta/silver/user_events")
    silver_table.alias("t").merge(
        enriched.alias("s"),
        "t.event_id = s.event_id"
    ).whenNotMatchedInsertAll().execute()
    # Only inserts truly new events — deduplication built in

spark.readStream.format("delta") \
    .option("readChangeFeed", "true") \
    .option("startingVersion", "latest") \
    .load("/delta/bronze/user_events") \
    .writeStream \
    .foreachBatch(bronze_to_silver) \
    .option("checkpointLocation", "/checkpoints/silver/user_events") \
    .trigger(processingTime="1 minute") \
    .start()

# Silver table with quality constraints
spark.sql("""
    CREATE TABLE IF NOT EXISTS silver.user_events (
        event_id        STRING NOT NULL,
        user_id         STRING NOT NULL,
        event_type      STRING,
        properties      MAP<STRING, STRING>,
        event_timestamp TIMESTAMP,
        event_date      DATE GENERATED ALWAYS AS (CAST(event_timestamp AS DATE)),
        kafka_timestamp TIMESTAMP,
        ingested_at     TIMESTAMP,
        row_hash        STRING
    ) USING DELTA
    CLUSTER BY (user_id, event_date)
    TBLPROPERTIES (
        'delta.enableChangeDataFeed' = 'true',
        'delta.enableDeletionVectors' = 'true',
        'delta.columnMapping.mode' = 'name'
    )
""")
spark.sql("""
    ALTER TABLE silver.user_events
    ADD CONSTRAINT valid_event_type
    CHECK (event_type IN ('click', 'view', 'purchase', 'signup'))
""")

# ═══════════════════════════════════════════════════
# GOLD LAYER — Business aggregates, KPI-ready
# ═══════════════════════════════════════════════════

# Gold: Daily user activity summary
spark.sql("""
    CREATE OR REPLACE TABLE gold.daily_user_activity AS
    SELECT
        event_date,
        user_id,
        COUNT(*) AS total_events,
        COUNT(DISTINCT event_type) AS unique_event_types,
        SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS purchases,
        SUM(CASE WHEN event_type = 'click' THEN 1 ELSE 0 END) AS clicks,
        MIN(event_timestamp) AS first_event,
        MAX(event_timestamp) AS last_event
    FROM silver.user_events
    GROUP BY event_date, user_id
""")

# Gold: Incremental refresh with MERGE
def refresh_gold_daily(target_date):
    daily_agg = spark.sql(f"""
        SELECT
            event_date, user_id,
            COUNT(*) AS total_events,
            SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS purchases
        FROM silver.user_events
        WHERE event_date = '{target_date}'
        GROUP BY event_date, user_id
    """)

    gold_table = DeltaTable.forName(spark, "gold.daily_user_activity")
    gold_table.alias("t").merge(
        daily_agg.alias("s"),
        "t.event_date = s.event_date AND t.user_id = s.user_id"
    ).whenMatchedUpdateAll() \
     .whenNotMatchedInsertAll() \
     .execute()
```

### **Medallion Best Practices**

```
┌─────────────┬───────────────────────────┬────────────────────────────┐
│ Layer       │ Do                        │ Don't                      │
├─────────────┼───────────────────────────┼────────────────────────────┤
│ Bronze      │ Append-only               │ Transform or filter        │
│             │ Preserve raw payload      │ Drop fields                │
│             │ Add ingestion metadata    │ Apply business logic       │
│             │ Long retention (audit)    │ Short retention            │
├─────────────┼───────────────────────────┼────────────────────────────┤
│ Silver      │ Deduplicate               │ Aggregate                  │
│             │ Validate & clean          │ Apply business definitions │
│             │ Conform to canonical model│ Join unrelated domains     │
│             │ CHECK constraints         │ Over-normalize             │
├─────────────┼───────────────────────────┼────────────────────────────┤
│ Gold        │ Aggregate for use case    │ Store raw data             │
│             │ Star schema / wide tables │ Complex joins at query time│
│             │ Optimize for query pattern│ Store intermediate results │
│             │ Short retention (re-derive)│ Duplicate silver logic    │
└─────────────┴───────────────────────────┴────────────────────────────┘
```

---

## **PART 25: Unity Catalog & Governance**

### **Three-Level Namespace**

```
┌──────────────────────────────────────────────────────────────────┐
│                    UNITY CATALOG HIERARCHY                        │
│                                                                  │
│  Metastore (top-level, one per Databricks account region)        │
│  └── Catalog (logical grouping, e.g., "production", "staging")   │
│      └── Schema (database, e.g., "analytics", "raw")             │
│          └── Table / View / Function / Model                     │
│                                                                  │
│  Full reference: catalog.schema.table                            │
│  Example:        production.analytics.daily_revenue              │
│                                                                  │
│  BEFORE Unity Catalog:   hive_metastore.default.my_table         │
│  WITH Unity Catalog:     prod.analytics.daily_revenue            │
│                                                                  │
│  KEY BENEFITS:                                                   │
│  ✅ Centralized access control (GRANT/REVOKE)                    │
│  ✅ Data lineage (automatic, column-level)                       │
│  ✅ Data discovery (search, tags, comments)                      │
│  ✅ Audit logging (who accessed what, when)                      │
│  ✅ Cross-workspace governance (share across workspaces)         │
│  ✅ Works with Delta, Iceberg, Parquet, CSV, JSON                │
└──────────────────────────────────────────────────────────────────┘
```

### **Unity Catalog Access Control**

```python
# ✅ PATTERN 1: Create catalog and schema
spark.sql("CREATE CATALOG IF NOT EXISTS production")
spark.sql("CREATE SCHEMA IF NOT EXISTS production.analytics")

# ✅ PATTERN 2: Grant permissions
spark.sql("GRANT USAGE ON CATALOG production TO `data_engineers`")
spark.sql("GRANT USAGE ON SCHEMA production.analytics TO `data_engineers`")
spark.sql("GRANT SELECT ON TABLE production.analytics.revenue TO `analysts`")
spark.sql("GRANT MODIFY ON TABLE production.analytics.revenue TO `data_engineers`")
spark.sql("GRANT CREATE TABLE ON SCHEMA production.analytics TO `data_engineers`")

# ✅ PATTERN 3: Fine-grained permissions
spark.sql("GRANT SELECT ON TABLE production.analytics.customers TO `marketing`")
# marketing can READ but not WRITE

# ✅ PATTERN 4: Row-level security with row filters
spark.sql("""
    ALTER TABLE production.analytics.orders
    SET ROW FILTER region_filter ON (region)
""")
# region_filter is a SQL UDF that returns TRUE for allowed rows

# ✅ PATTERN 5: Column-level security with column masks
spark.sql("""
    ALTER TABLE production.analytics.customers
    ALTER COLUMN email SET MASK mask_email
""")
# mask_email returns masked value for unauthorized users:
# "user@example.com" → "u***@example.com"

# ✅ PATTERN 6: Create row filter function
spark.sql("""
    CREATE FUNCTION production.analytics.region_filter(region STRING)
    RETURNS BOOLEAN
    RETURN IF(IS_MEMBER('global_admins'), true, region = current_user_region())
""")

# ✅ PATTERN 7: Create column mask function
spark.sql("""
    CREATE FUNCTION production.analytics.mask_email(email STRING)
    RETURNS STRING
    RETURN IF(IS_MEMBER('pii_authorized'), email,
              CONCAT(LEFT(email, 1), '***@', SPLIT(email, '@')[1]))
""")

# ✅ PATTERN 8: Data lineage (automatic in Unity Catalog)
# Lineage is tracked automatically when you:
#   - CREATE TABLE AS SELECT (tracks source → target)
#   - INSERT INTO ... SELECT (tracks flow)
#   - MERGE INTO (tracks source → target)
# View in Databricks UI: Catalog Explorer → Table → Lineage tab

# ✅ PATTERN 9: Tags for data classification
spark.sql("""
    ALTER TABLE production.analytics.customers
    SET TAGS ('pii' = 'true', 'sensitivity' = 'high', 'owner' = 'privacy_team')
""")
spark.sql("""
    ALTER TABLE production.analytics.customers
    ALTER COLUMN ssn SET TAGS ('pii_type' = 'ssn', 'mask_required' = 'true')
""")

# ✅ PATTERN 10: View permissions
spark.sql("SHOW GRANTS ON TABLE production.analytics.revenue")
spark.sql("SHOW GRANTS TO `data_engineers`")
```

### **Unity Catalog vs Legacy Hive Metastore**

```
┌────────────────────────┬───────────────────────┬────────────────────────┐
│ Feature                │ Hive Metastore        │ Unity Catalog          │
├────────────────────────┼───────────────────────┼────────────────────────┤
│ Namespace              │ database.table        │ catalog.schema.table   │
│ Access control         │ Table ACLs (limited)  │ GRANT/REVOKE (full)    │
│ Row/column security    │ ❌ None               │ ✅ Filters & Masks     │
│ Data lineage           │ ❌ None               │ ✅ Automatic           │
│ Cross-workspace        │ ❌ No                 │ ✅ Yes                 │
│ External tables        │ ✅ Yes                │ ✅ Yes (managed locs)  │
│ Formats supported      │ Delta, Parquet, etc.  │ Delta, Iceberg, +more  │
│ Audit logging          │ ❌ Limited            │ ✅ Full audit trail     │
│ Data discovery         │ ❌ None               │ ✅ Search, tags, docs   │
└────────────────────────┴───────────────────────┴────────────────────────┘
```

---

## **PART 26: Delta Live Tables (DLT)**

### **Declarative ETL Pipelines**

```
WHAT IS DLT?
  Delta Live Tables is a DECLARATIVE framework for building ETL pipelines.

  Traditional ETL:              DLT:
  ─────────────────             ────────────────
  You manage:                   You declare:
  - Read source                 - "This table should contain..."
  - Transform                   - "Quality expectations..."
  - Write target                - DLT handles orchestration,
  - Handle failures               retries, dependencies, and
  - Manage dependencies            data quality automatically
  - Schedule jobs

  DLT automatically:
  ✅ Resolves dependencies between tables
  ✅ Manages incremental processing
  ✅ Enforces data quality expectations
  ✅ Handles retries and recovery
  ✅ Optimizes execution
```

### **DLT Syntax and Patterns**

```python
import dlt
from pyspark.sql.functions import *

# ═══════════════════════════════════════════════════
# BRONZE — Raw ingestion with Auto Loader
# ═══════════════════════════════════════════════════

@dlt.table(
    name="bronze_events",
    comment="Raw events ingested from cloud storage",
    table_properties={"quality": "bronze"}
)
def bronze_events():
    return (
        spark.readStream
            .format("cloudFiles")
            .option("cloudFiles.format", "json")
            .option("cloudFiles.inferColumnTypes", "true")
            .load("/data/raw/events/")
    )

# ═══════════════════════════════════════════════════
# SILVER — Cleaned with quality expectations
# ═══════════════════════════════════════════════════

@dlt.table(
    name="silver_events",
    comment="Cleaned and validated events"
)
@dlt.expect("valid_event_id", "event_id IS NOT NULL")
@dlt.expect("valid_timestamp", "event_timestamp IS NOT NULL")
@dlt.expect_or_drop("valid_event_type",
                     "event_type IN ('click', 'view', 'purchase')")
@dlt.expect_or_fail("valid_user_id", "user_id IS NOT NULL")
def silver_events():
    return (
        dlt.read_stream("bronze_events")
            .select(
                col("event_id"),
                col("user_id"),
                col("event_type"),
                col("event_timestamp").cast("timestamp"),
                col("event_timestamp").cast("date").alias("event_date")
            )
    )

# ═══════════════════════════════════════════════════
# GOLD — Business aggregation
# ═══════════════════════════════════════════════════

@dlt.table(
    name="gold_daily_summary",
    comment="Daily event summary per user"
)
def gold_daily_summary():
    return (
        dlt.read("silver_events")
            .groupBy("event_date", "user_id")
            .agg(
                count("*").alias("total_events"),
                countDistinct("event_type").alias("unique_types"),
                sum(when(col("event_type") == "purchase", 1).otherwise(0))
                    .alias("purchases")
            )
    )

"""
DLT EXPECTATION ACTIONS:
  @dlt.expect("name", "condition")
    → Logs violations, keeps bad rows (warn)
  @dlt.expect_or_drop("name", "condition")
    → Drops bad rows silently
  @dlt.expect_or_fail("name", "condition")
    → Fails entire pipeline on violation

MATERIALIZATION TYPES:
  @dlt.table      → Materialized table (stored as Delta)
  @dlt.view       → Computed view (not stored, for intermediate steps)

STREAMING vs BATCH:
  dlt.read_stream("table")  → Incremental (streaming)
  dlt.read("table")         → Full recompute (batch)
"""
```

### **DLT vs Manual ETL**

```
┌───────────────────────┬──────────────────────────┬──────────────────────┐
│ Aspect                │ Manual ETL (Notebooks)   │ Delta Live Tables    │
├───────────────────────┼──────────────────────────┼──────────────────────┤
│ Dependency management │ Manual (job orchestrator) │ Automatic (DAG)     │
│ Incremental processing│ You implement            │ Built-in             │
│ Data quality          │ Custom validation code   │ Declarative expects  │
│ Error handling        │ Try/catch, manual retry  │ Automatic retry      │
│ Schema evolution      │ Manual                   │ Automatic            │
│ Monitoring            │ Custom dashboards        │ Built-in event log   │
│ Code complexity       │ Higher                   │ Lower (declarative)  │
│ Flexibility           │ Maximum                  │ Framework-constrained│
│ Testing               │ Unit tests needed        │ Expectations = tests │
└───────────────────────┴──────────────────────────┴──────────────────────┘
```

---

## **PART 27: Delta Sharing**

### **Cross-Organization Data Sharing**

```
PROBLEM:
  Company A wants to share a Delta table with Company B
  Traditional: Export CSV/Parquet → upload to B's storage → B imports
  → Stale data, duplication, no access control, no audit trail

DELTA SHARING:
  Company A shares a LIVE Delta table with Company B
  Company B reads directly — no data copying!

  ┌───────────────┐                    ┌───────────────┐
  │ PROVIDER      │                    │ RECIPIENT     │
  │ (Company A)   │                    │ (Company B)   │
  │               │   Delta Sharing    │               │
  │ Delta Table ──┼───── Protocol ─────┼──► Read-only  │
  │               │   (open protocol)  │    access     │
  │ Access control│                    │               │
  │ Audit logging │                    │ Any client:   │
  └───────────────┘                    │ Spark, Pandas,│
                                       │ Trino, Power BI│
                                       └───────────────┘

  KEY FEATURES:
  ✅ Open protocol (not Databricks-only)
  ✅ No data copying — recipients read from provider's storage
  ✅ Fine-grained access control (table, partition, column level)
  ✅ Audit trail (who accessed what, when)
  ✅ Recipients don't need Databricks — any client works
  ✅ Supports sharing tables, views, notebooks, AI models
```

### **Delta Sharing Patterns**

```python
# ═══════════════════════════════════════════════════
# PROVIDER SIDE — Share data
# ═══════════════════════════════════════════════════

# ✅ PATTERN 1: Create a share
spark.sql("CREATE SHARE IF NOT EXISTS customer_analytics")

# ✅ PATTERN 2: Add tables to share
spark.sql("""
    ALTER SHARE customer_analytics
    ADD TABLE production.analytics.daily_revenue
""")

# ✅ PATTERN 3: Share with partition filter (limit what's visible)
spark.sql("""
    ALTER SHARE customer_analytics
    ADD TABLE production.analytics.orders
    PARTITION (region = 'US')
""")
# Recipient only sees US orders

# ✅ PATTERN 4: Grant recipient access
spark.sql("""
    GRANT SELECT ON SHARE customer_analytics
    TO RECIPIENT partner_company
""")

# ✅ PATTERN 5: Create recipient
spark.sql("""
    CREATE RECIPIENT partner_company
    COMMENT 'Partner Company B for analytics sharing'
""")
# Returns an activation link for the recipient

# ═══════════════════════════════════════════════════
# RECIPIENT SIDE — Consume shared data
# ═══════════════════════════════════════════════════

# ✅ PATTERN 6: Create catalog from share (Databricks)
spark.sql("""
    CREATE CATALOG IF NOT EXISTS shared_data
    USING SHARE provider_org.customer_analytics
""")
# Now query: SELECT * FROM shared_data.analytics.daily_revenue

# ✅ PATTERN 7: Read with open-source connector (non-Databricks)
import delta_sharing

# Using the profile file from activation link
profile = "/path/to/share_profile.json"
shares = delta_sharing.SharingClient(profile).list_shares()

# Read as Pandas
df = delta_sharing.load_as_pandas(f"{profile}#share_name.schema.table")

# Read as Spark
df = delta_sharing.load_as_spark(f"{profile}#share_name.schema.table")

# ✅ PATTERN 8: Manage shares
spark.sql("SHOW SHARES")
spark.sql("DESCRIBE SHARE customer_analytics")
spark.sql("SHOW RECIPIENTS")
spark.sql("SHOW GRANTS ON SHARE customer_analytics")
```

---

## **PART 28: Photon Engine**

### **Vectorized Query Execution**

```
WHAT IS PHOTON?
  Photon is Databricks' C++-based vectorized query engine that
  replaces parts of the Spark JVM execution engine.

  Traditional Spark:                Photon:
  ┌──────────────────┐              ┌──────────────────┐
  │ Spark SQL         │              │ Spark SQL         │
  │ Catalyst Optimizer│              │ Catalyst Optimizer│
  │ ↓                 │              │ ↓                 │
  │ JVM Execution     │              │ Photon (C++ native)│
  │ Row-at-a-time     │              │ Vectorized (batch) │
  │ Garbage collection│              │ No GC overhead     │
  │ Interpreted       │              │ SIMD-optimized     │
  └──────────────────┘              └──────────────────┘

  PERFORMANCE GAINS (typical):
  ┌────────────────────────┬──────────┬─────────┬───────────┐
  │ Operation              │ JVM Spark│ Photon  │ Speedup   │
  ├────────────────────────┼──────────┼─────────┼───────────┤
  │ Full table scan        │ 100s     │ 30s     │ ~3x       │
  │ Aggregation            │ 60s      │ 15s     │ ~4x       │
  │ JOIN (large tables)    │ 120s     │ 40s     │ ~3x       │
  │ String operations      │ 80s      │ 10s     │ ~8x       │
  │ Parquet I/O            │ 50s      │ 15s     │ ~3x       │
  │ MERGE / DML            │ 90s      │ 25s     │ ~3.5x     │
  └────────────────────────┴──────────┴─────────┴───────────┘

WHEN PHOTON HELPS MOST:
  ✅ Scan-heavy workloads (large table scans, aggregations)
  ✅ String-heavy processing (parsing, regex, string functions)
  ✅ JOIN-heavy queries (hash joins, broadcast joins)
  ✅ DML operations (MERGE, UPDATE, DELETE on Delta)
  ✅ ETL / ELT pipelines

WHEN PHOTON DOESN'T HELP:
  ❌ UDF-heavy workloads (Python UDFs still run in JVM/Python)
  ❌ ML training (Photon is for SQL/DataFrame, not MLlib)
  ❌ Very small datasets (overhead not worth it)
  ❌ Workloads already bottlenecked on I/O, not compute

HOW TO ENABLE:
  - Select "Photon" runtime when creating a cluster
  - Or set: spark.databricks.photon.enabled = true
  - No code changes needed — Photon is transparent
```

---

## **PART 29: Cost Optimization Strategies**

### **Storage Cost Optimization**

```python
"""
DELTA LAKE STORAGE COST BREAKDOWN:

  ┌─────────────────────────────────────────────────────────┐
  │ Cost Component         │ Typical %  │ Optimization       │
  ├────────────────────────┼────────────┼────────────────────┤
  │ Active data files      │ 40-60%     │ Compaction, codec   │
  │ Old file versions      │ 20-40%     │ VACUUM              │
  │ Transaction log        │ 1-5%       │ Log retention       │
  │ Bloom filter indexes   │ 1-3%       │ Only on needed cols │
  │ Deletion vectors       │ <1%        │ OPTIMIZE compacts   │
  └────────────────────────┴────────────┴────────────────────┘
"""

# ✅ PATTERN 1: Right-size VACUUM retention
# Aggressive retention = less storage cost
spark.sql("""
    ALTER TABLE events SET TBLPROPERTIES (
        'delta.deletedFileRetentionDuration' = 'interval 7 days',
        'delta.logRetentionDuration' = 'interval 30 days'
    )
""")
# 7-day file retention is minimum safe value
# Reduces storage of old versions by up to 80%

# ✅ PATTERN 2: Regular OPTIMIZE + VACUUM workflow
spark.sql("OPTIMIZE events")           # Compact small files → fewer large files
spark.sql("VACUUM events RETAIN 168 HOURS")  # Remove old files

# ✅ PATTERN 3: Avoid over-partitioning (biggest cost mistake)
# ❌ BAD: Millions of partitions → millions of tiny files
# df.write.partitionBy("user_id").save(...)  # 10M users = 10M directories!

# ✅ GOOD: Use Liquid Clustering instead
spark.sql("ALTER TABLE events CLUSTER BY (user_id, event_date)")

# ✅ PATTERN 4: Compression codec optimization
spark.conf.set("spark.sql.parquet.compression.codec", "zstd")
# zstd: Best compression ratio with good speed
# snappy: Fastest but less compression (default)
# lz4: Fast decompression, moderate compression

# ✅ PATTERN 5: Drop unused Bloom filter indexes
spark.sql("DROP BLOOMFILTER INDEX ON TABLE events FOR COLUMNS (rarely_queried_col)")

# ✅ PATTERN 6: Monitor table size
spark.sql("DESCRIBE DETAIL events").select(
    "name", "numFiles", "sizeInBytes"
).show()
# Check: sizeInBytes / numFiles ≈ 128MB–1GB is optimal
# If much smaller → need OPTIMIZE
# If much larger → may need repartitioning
```

### **Compute Cost Optimization**

```python
"""
COMPUTE COST STRATEGIES:

1. DATA SKIPPING — Read less data
   - Partition pruning: only scan relevant directories
   - Z-ORDER / Liquid Clustering: skip irrelevant files
   - Bloom filter: skip files for point lookups
   - Column pruning: SELECT only needed columns

2. WRITE EFFICIENCY — Write less data
   - Deletion Vectors: avoid full file rewrites
   - Idempotent writes: avoid duplicate processing
   - optimizeWrite: avoid small file writes

3. PROCESSING EFFICIENCY — Use compute wisely
   - Photon: 2-8x faster on supported operations
   - Auto-scaling clusters: scale down during idle
   - Trigger(availableNow=True): batch-style streaming (no idle clusters)

4. CACHING — Avoid redundant reads
   - Delta cache: automatically caches hot data on SSD
   - Result cache: caches query results
"""

# ✅ PATTERN 7: Use availableNow trigger (no idle streaming cluster)
stream.writeStream \
    .trigger(availableNow=True) \
    .format("delta") \
    .option("checkpointLocation", checkpoint) \
    .start(target)
# Processes all available data then STOPS — no idle compute cost
# Schedule this as a job every N minutes instead of continuous streaming

# ✅ PATTERN 8: Column pruning (read only what you need)
# ❌ EXPENSIVE: SELECT * FROM huge_table WHERE ...
# ✅ CHEAP:    SELECT col1, col2 FROM huge_table WHERE ...

# ✅ PATTERN 9: Predicate pushdown (filter early)
# ❌ EXPENSIVE: Read all, then filter in application
# ✅ CHEAP:    Push filter to Delta scan
spark.sql("""
    SELECT user_id, event_type
    FROM events
    WHERE event_date = '2024-02-08'  -- partition pruning
      AND user_id = 'user_123'       -- data skipping (Liquid Cluster)
""")
```

### **Cost Optimization Checklist**

```
┌──────────────────────────────────────────────────────────────┐
│              DELTA LAKE COST OPTIMIZATION CHECKLIST           │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│ STORAGE:                                                     │
│ □ VACUUM running regularly (7-30 day retention)              │
│ □ OPTIMIZE running regularly (compact small files)           │
│ □ No over-partitioning (use Liquid Clustering)               │
│ □ zstd compression codec enabled                             │
│ □ Bloom filters only on frequently queried high-card cols    │
│ □ Log retention set appropriately (30 days default)          │
│                                                              │
│ COMPUTE:                                                     │
│ □ Partition pruning in WHERE clauses                         │
│ □ Column pruning (no SELECT *)                               │
│ □ Liquid Clustering / Z-ORDER on filter columns              │
│ □ Deletion Vectors enabled (avoid write amplification)       │
│ □ Photon runtime enabled                                     │
│ □ availableNow trigger for batch-style streaming             │
│ □ Auto-scaling clusters configured                           │
│ □ Idempotent writes to prevent reprocessing                  │
│                                                              │
│ MONITORING:                                                  │
│ □ Track numFiles and sizeInBytes trends                      │
│ □ Alert on small file accumulation                           │
│ □ Review OPTIMIZE/VACUUM job history                         │
│ □ Monitor query scan metrics (files scanned vs skipped)      │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## **PART 30: Monitoring & Observability**

### **Table Health Monitoring**

```python
# ✅ PATTERN 1: Table detail metrics
detail = spark.sql("DESCRIBE DETAIL events")
detail.select(
    "name", "format", "numFiles", "sizeInBytes",
    "minReaderVersion", "minWriterVersion",
    "properties"
).show(truncate=False)

# Key metrics to watch:
# - numFiles: should not grow unboundedly (need OPTIMIZE)
# - sizeInBytes / numFiles: should be 128MB-1GB per file
# - properties: verify expected table properties are set

# ✅ PATTERN 2: Table history analysis
from delta.tables import DeltaTable

delta_table = DeltaTable.forPath(spark, "/delta/events")
history = delta_table.history(100)  # last 100 operations

# Analyze operation frequency
history.groupBy("operation").count().orderBy(col("count").desc()).show()

# Analyze operation metrics
history.select(
    "version", "timestamp", "operation",
    "operationMetrics.numOutputRows",
    "operationMetrics.numAddedFiles",
    "operationMetrics.numRemovedFiles"
).show(truncate=False)

# ✅ PATTERN 3: Small file detection
file_stats = spark.sql("""
    DESCRIBE DETAIL events
""").select("numFiles", "sizeInBytes").collect()[0]

avg_file_size_mb = (file_stats["sizeInBytes"] / file_stats["numFiles"]) / (1024 * 1024)
print(f"Average file size: {avg_file_size_mb:.1f} MB")
print(f"Total files: {file_stats['numFiles']}")

if avg_file_size_mb < 32:
    print("WARNING: Small files detected! Run OPTIMIZE.")
elif avg_file_size_mb > 2048:
    print("WARNING: Files too large! Consider repartitioning.")
else:
    print("OK: File sizes within healthy range.")

# ✅ PATTERN 4: Operation metrics dashboard
def table_health_report(table_name):
    """Generate comprehensive health report for a Delta table."""
    detail = spark.sql(f"DESCRIBE DETAIL {table_name}").collect()[0]
    history = DeltaTable.forName(spark, table_name).history(50)

    report = {
        "table": table_name,
        "num_files": detail["numFiles"],
        "size_gb": round(detail["sizeInBytes"] / (1024**3), 2),
        "avg_file_mb": round(
            detail["sizeInBytes"] / detail["numFiles"] / (1024**2), 1
        ) if detail["numFiles"] > 0 else 0,
        "total_versions": history.count(),
        "last_optimize": history.filter("operation = 'OPTIMIZE'")
            .select("timestamp").first(),
        "last_vacuum": history.filter("operation = 'VACUUM END'")
            .select("timestamp").first(),
        "operations_24h": history.filter(
            "timestamp > current_timestamp() - INTERVAL 24 HOURS"
        ).groupBy("operation").count().collect()
    }
    return report

report = table_health_report("production.analytics.events")
print(f"Table: {report['table']}")
print(f"Size: {report['size_gb']} GB across {report['num_files']} files")
print(f"Avg file size: {report['avg_file_mb']} MB")
print(f"Last OPTIMIZE: {report['last_optimize']}")
print(f"Last VACUUM: {report['last_vacuum']}")

# ✅ PATTERN 5: Query performance metrics
# After running a query, check Spark UI metrics:
# - "files pruned" vs "files scanned" (data skipping effectiveness)
# - "bytes read" (should be much less than total table size)
# - "time in scan" vs "time in processing"

# Programmatic check:
spark.sql("""
    SELECT * FROM events
    WHERE event_date = '2024-02-08' AND user_id = 'user_123'
""")
# Check: spark.sql("EXPLAIN EXTENDED SELECT ...") for partition pruning
```

### **Alerting Patterns**

```python
# ✅ PATTERN 6: Automated health checks (run as scheduled job)
def check_table_health(table_name, max_files=10000, min_avg_mb=32):
    """Alert if table health degrades."""
    detail = spark.sql(f"DESCRIBE DETAIL {table_name}").collect()[0]
    num_files = detail["numFiles"]
    size_bytes = detail["sizeInBytes"]
    avg_mb = (size_bytes / num_files / (1024**2)) if num_files > 0 else 0

    alerts = []
    if num_files > max_files:
        alerts.append(f"ALERT: {table_name} has {num_files} files (max: {max_files})")
    if avg_mb < min_avg_mb and num_files > 0:
        alerts.append(f"ALERT: {table_name} avg file {avg_mb:.0f}MB (min: {min_avg_mb}MB)")

    return alerts

# Check all critical tables
for table in ["events", "customers", "orders"]:
    alerts = check_table_health(f"production.analytics.{table}")
    for alert in alerts:
        print(alert)
        # Send to Slack/PagerDuty/email
```

---

## **PART 31: GDPR & Compliance Patterns**

### **Right to Be Forgotten (GDPR Article 17)**

```python
"""
GDPR REQUIREMENT: Delete all data for a specific user upon request.

CHALLENGE with data lakes:
  - Data is spread across many tables and partitions
  - Parquet files are immutable (can't delete individual rows easily)
  - Need to prove deletion happened (audit trail)

DELTA LAKE SOLUTION:
  - DELETE command removes user data from all tables
  - Deletion Vectors make this fast (no full file rewrite)
  - Time Travel + VACUUM ensures data is physically removed
  - Transaction log provides audit trail
"""

# ✅ PATTERN 1: GDPR deletion workflow
def gdpr_delete_user(user_id, tables, vacuum_after=False):
    """
    Delete all data for a user across all tables.
    Returns audit record.
    """
    audit = []

    for table in tables:
        # Count rows before
        before = spark.sql(f"""
            SELECT COUNT(*) as cnt FROM {table} WHERE user_id = '{user_id}'
        """).collect()[0]["cnt"]

        # Delete
        spark.sql(f"DELETE FROM {table} WHERE user_id = '{user_id}'")

        # Count rows after (should be 0)
        after = spark.sql(f"""
            SELECT COUNT(*) as cnt FROM {table} WHERE user_id = '{user_id}'
        """).collect()[0]["cnt"]

        audit.append({
            "table": table,
            "user_id": user_id,
            "rows_deleted": before - after,
            "rows_remaining": after,
            "timestamp": datetime.now().isoformat()
        })

    if vacuum_after:
        for table in tables:
            spark.sql(f"VACUUM {table} RETAIN 0 HOURS")
            # WARNING: Only use 0 hours in GDPR context with no active readers

    return audit

# Execute GDPR deletion
tables = [
    "production.analytics.events",
    "production.analytics.orders",
    "production.analytics.profiles"
]
audit = gdpr_delete_user("user_to_forget", tables)

# Store audit record
audit_df = spark.createDataFrame(audit)
audit_df.write.format("delta").mode("append").save("/delta/gdpr_audit_log")

# ✅ PATTERN 2: Pseudonymization (alternative to deletion)
from pyspark.sql.functions import sha2, concat, lit

def pseudonymize_user(user_id, tables, salt="gdpr_salt_2024"):
    """Replace PII with hashed values instead of deleting."""
    pseudo_id = sha2(concat(lit(user_id), lit(salt)), 256)

    for table in tables:
        spark.sql(f"""
            UPDATE {table}
            SET
                user_id = '{pseudo_id}',
                email = NULL,
                name = NULL,
                phone = NULL
            WHERE user_id = '{user_id}'
        """)

# ✅ PATTERN 3: Ensure physical deletion (VACUUM after DELETE)
# After logical DELETE, data still exists in old Parquet files
# VACUUM physically removes old files

spark.sql("DELETE FROM events WHERE user_id = 'user_to_forget'")

# Wait for all concurrent readers to finish, then:
spark.conf.set(
    "spark.databricks.delta.retentionDurationCheck.enabled", "false"
)
spark.sql("VACUUM events RETAIN 0 HOURS")  # Physically remove files
spark.conf.set(
    "spark.databricks.delta.retentionDurationCheck.enabled", "true"
)
# Now old files are gone — data is unrecoverable

# ✅ PATTERN 4: Verify deletion (compliance proof)
# Check that no data remains via time travel
try:
    spark.read.format("delta") \
        .option("versionAsOf", 0) \
        .load("/delta/events") \
        .filter(f"user_id = 'user_to_forget'") \
        .count()
    print("WARNING: Old versions still contain user data!")
    print("Run VACUUM to physically remove.")
except Exception:
    print("VERIFIED: Old versions vacuumed. Data is physically removed.")
```

### **Data Retention Policies**

```python
# ✅ PATTERN 5: Automated retention enforcement
def enforce_retention(table, retention_days, date_column="event_date"):
    """Delete data older than retention period."""
    cutoff = (datetime.now() - timedelta(days=retention_days)).strftime("%Y-%m-%d")

    deleted = spark.sql(f"""
        DELETE FROM {table}
        WHERE {date_column} < '{cutoff}'
    """)

    spark.sql(f"OPTIMIZE {table}")
    spark.sql(f"VACUUM {table} RETAIN 168 HOURS")

    return f"Deleted data before {cutoff} from {table}"

# Monthly retention job
enforce_retention("bronze.raw_events", retention_days=90)
enforce_retention("silver.processed_events", retention_days=365)
# Gold tables: keep indefinitely (re-derivable from silver)
```

---

## **PART 32: Disaster Recovery & High Availability**

### **Backup Strategies**

```
DISASTER RECOVERY TIERS:

  Tier 1: Transaction Log Protection (basic)
  ────────────────────────────────────────────
  - Delta log is the source of truth
  - S3/ADLS versioning protects against accidental deletion
  - RESTORE command undoes bad operations
  - Cost: Zero (built-in)

  Tier 2: DEEP CLONE to Same Region (standard)
  ────────────────────────────────────────────
  - Scheduled DEEP CLONE to backup location
  - Same-region — protects against table corruption
  - Cost: 1x storage
  - RPO: depends on clone frequency

  Tier 3: Cross-Region Replication (enterprise)
  ────────────────────────────────────────────
  - DEEP CLONE to different AWS region / Azure region
  - Protects against regional outages
  - Cost: 1x storage + cross-region transfer
  - RPO: depends on replication frequency

  ┌─────────────────┬─────────────┬──────────┬─────────┬──────────┐
  │ Strategy        │ RTO         │ RPO      │ Cost    │ Protects │
  ├─────────────────┼─────────────┼──────────┼─────────┼──────────┤
  │ RESTORE command │ Minutes     │ 0 (ACID) │ Free    │ Bad write│
  │ DEEP CLONE same │ Minutes     │ Hours    │ 1x      │ Corrupt  │
  │ Cross-region    │ Hours       │ Hours    │ 2x+     │ Region   │
  │ S3 versioning   │ Hours       │ 0        │ ~0.3x   │ Delete   │
  └─────────────────┴─────────────┴──────────┴─────────┴──────────┘
```

### **DR Implementation Patterns**

```python
# ✅ PATTERN 1: Scheduled backup with DEEP CLONE
def backup_table(source, backup_path, version=None):
    """Create or update backup via DEEP CLONE."""
    if version:
        spark.sql(f"""
            CREATE OR REPLACE TABLE delta.`{backup_path}`
            DEEP CLONE {source} VERSION AS OF {version}
        """)
    else:
        spark.sql(f"""
            CREATE OR REPLACE TABLE delta.`{backup_path}`
            DEEP CLONE {source}
        """)
    # CREATE OR REPLACE with DEEP CLONE only copies changed files

# Daily backup job
critical_tables = {
    "production.analytics.customers": "/backup/customers",
    "production.analytics.orders": "/backup/orders",
    "production.analytics.revenue": "/backup/revenue"
}
for source, backup in critical_tables.items():
    backup_table(source, backup)

# ✅ PATTERN 2: Cross-region backup
# Same as above, but backup_path is in a different region:
# /backup-us-west-2/customers (if primary is us-east-1)

# ✅ PATTERN 3: Point-in-time recovery
def recover_table(source, target, point_in_time):
    """Recover table to specific point in time."""
    spark.sql(f"""
        CREATE OR REPLACE TABLE {target}
        DEEP CLONE {source} TIMESTAMP AS OF '{point_in_time}'
    """)

# Recover to yesterday's state
recover_table(
    "production.analytics.orders",
    "production.analytics.orders_recovered",
    "2024-02-07T23:59:59"
)

# ✅ PATTERN 4: Validate backup integrity
def validate_backup(source, backup):
    """Verify backup matches source."""
    source_count = spark.table(source).count()
    backup_count = spark.read.format("delta").load(backup).count()

    source_schema = spark.table(source).schema
    backup_schema = spark.read.format("delta").load(backup).schema

    assert source_count == backup_count, \
        f"Count mismatch: {source_count} vs {backup_count}"
    assert source_schema == backup_schema, \
        "Schema mismatch!"

    return f"Backup validated: {source_count} rows, schema matches"
```

---

## **PART 33: SCD Type 3 & Type 4 Patterns**

### **SCD Type 3 — Previous Value Column**

```python
"""
SCD TYPE 3: Keep current + one previous value in the same row.

  Before update:
  | customer_id | city      | prev_city | city_changed_at |
  | C001        | New York  | NULL      | 2023-01-15      |

  After update (customer moves to Boston):
  | customer_id | city      | prev_city | city_changed_at |
  | C001        | Boston    | New York  | 2024-02-08      |

  Only tracks ONE historical value — lightweight but limited.
"""

# ✅ PATTERN: SCD Type 3 MERGE
delta_table = DeltaTable.forName(spark, "dim_customer")

delta_table.alias("t").merge(
    updates_df.alias("s"),
    "t.customer_id = s.customer_id"
).whenMatchedUpdate(
    condition="t.city != s.city",  # Only when value actually changed
    set={
        "prev_city": "t.city",             # Save current as previous
        "city": "s.city",                   # Update to new value
        "city_changed_at": "current_date()" # Track when it changed
    }
).whenMatchedUpdate(
    condition="t.city = s.city",  # No change — update other fields only
    set={
        "name": "s.name",
        "email": "s.email"
    }
).whenNotMatchedInsert(values={
    "customer_id": "s.customer_id",
    "name": "s.name",
    "email": "s.email",
    "city": "s.city",
    "prev_city": "NULL",
    "city_changed_at": "current_date()"
}).execute()
```

### **SCD Type 4 — History Table**

```python
"""
SCD TYPE 4: Current values in main table + full history in separate table.

  Main table (dim_customer):
  | customer_id | name  | city    | tier     | updated_at |
  | C001        | Alice | Boston  | Gold     | 2024-02-08 |

  History table (dim_customer_history):
  | customer_id | name  | city      | tier   | valid_from | valid_to   |
  | C001        | Alice | New York  | Silver | 2023-01-15 | 2023-08-01 |
  | C001        | Alice | New York  | Gold   | 2023-08-01 | 2024-02-08 |
  | C001        | Alice | Boston    | Gold   | 2024-02-08 | 9999-12-31 |

  Best of both worlds:
  ✅ Fast lookups on current table (no is_current filter needed)
  ✅ Full history available in separate table
  ✅ History table can have different retention/optimization
"""

# ✅ PATTERN: SCD Type 4 — Dual table update
def scd_type4_merge(updates_df, current_table, history_table, key_col):
    """
    Update current table + append to history table.
    """
    current_dt = DeltaTable.forName(spark, current_table)
    current_df = current_dt.toDF()

    # Find changed rows
    changed = updates_df.alias("s").join(
        current_df.alias("t"), key_col
    ).where("""
        s.name != t.name OR s.city != t.city OR s.tier != t.tier
    """).select("t.*")

    # Close old records in history
    if changed.count() > 0:
        history_dt = DeltaTable.forName(spark, history_table)
        history_dt.alias("h").merge(
            changed.alias("c"),
            f"h.{key_col} = c.{key_col} AND h.valid_to = '9999-12-31'"
        ).whenMatchedUpdate(set={
            "valid_to": "current_timestamp()"
        }).execute()

    # Insert new records to history
    new_history = updates_df.withColumn(
        "valid_from", current_timestamp()
    ).withColumn(
        "valid_to", lit("9999-12-31").cast("timestamp")
    )
    new_history.write.format("delta").mode("append").saveAsTable(history_table)

    # Upsert current table
    current_dt.alias("t").merge(
        updates_df.alias("s"), f"t.{key_col} = s.{key_col}"
    ).whenMatchedUpdateAll() \
     .whenNotMatchedInsertAll() \
     .execute()

scd_type4_merge(updates_df, "dim_customer", "dim_customer_history", "customer_id")
```

### **SCD Type Comparison**

```
┌──────────┬──────────────────┬──────────────┬──────────────┬───────────┐
│ SCD Type │ Strategy         │ History Kept │ Complexity   │ Use When  │
├──────────┼──────────────────┼──────────────┼──────────────┼───────────┤
│ Type 0   │ Never update     │ None         │ Trivial      │ Static    │
│          │                  │              │              │ dimensions│
│ Type 1   │ Overwrite        │ None         │ Simple       │ No history│
│          │ (MERGE update)   │              │ (basic MERGE)│ needed    │
│ Type 2   │ New row + close  │ Full history │ Complex      │ Full audit│
│          │ old (is_current) │ (all changes)│ (versioned)  │ trail     │
│ Type 3   │ Previous value   │ Last change  │ Medium       │ Track one │
│          │ column           │ only         │              │ prior val │
│ Type 4   │ Separate history │ Full history │ Medium-High  │ Fast      │
│          │ table            │ (own table)  │ (two tables) │ current + │
│          │                  │              │              │ full hist │
│ Type 6   │ Type 1+2+3 combo │ Full + prev  │ Highest      │ Maximum  │
│          │ (hybrid)         │              │              │ flexibility│
└──────────┴──────────────────┴──────────────┴──────────────┴───────────┘
```

---

## **PART 34: Data Mesh with Delta Lake**

### **Data Mesh Principles Applied to Lakehouse**

```
DATA MESH CORE PRINCIPLES:

  1. DOMAIN OWNERSHIP
     Each business domain owns its data (not central data team)

  2. DATA AS A PRODUCT
     Each domain publishes data products with SLAs

  3. SELF-SERVE DATA PLATFORM
     Platform team provides tooling, domains operate independently

  4. FEDERATED COMPUTATIONAL GOVERNANCE
     Global standards, local implementation

HOW DELTA LAKE + UNITY CATALOG ENABLES DATA MESH:

  ┌─────────────────────────────────────────────────────────────┐
  │                     UNITY CATALOG (Governance)              │
  │  ┌────────────────┐ ┌────────────────┐ ┌────────────────┐  │
  │  │  SALES DOMAIN  │ │ MARKETING      │ │ FINANCE        │  │
  │  │  Catalog: sales│ │ Catalog: mktg  │ │ Catalog: fin   │  │
  │  │                │ │                │ │                │  │
  │  │  Bronze tables │ │  Bronze tables │ │  Bronze tables │  │
  │  │  Silver tables │ │  Silver tables │ │  Silver tables │  │
  │  │  Gold (product)│ │  Gold (product)│ │  Gold (product)│  │
  │  │                │ │                │ │                │  │
  │  │  Delta Sharing │ │  Delta Sharing │ │  Delta Sharing │  │
  │  │  (published)   │ │  (published)   │ │  (published)   │  │
  │  └────────────────┘ └────────────────┘ └────────────────┘  │
  │                                                             │
  │  Cross-domain access via:                                   │
  │  - Delta Sharing (external consumers)                       │
  │  - Unity Catalog GRANT (internal consumers)                 │
  │  - Federated governance (tags, lineage, audit)              │
  └─────────────────────────────────────────────────────────────┘
```

### **Implementing Data Mesh with Delta**

```python
# ✅ PATTERN 1: Domain catalog per team
spark.sql("CREATE CATALOG IF NOT EXISTS sales")
spark.sql("CREATE CATALOG IF NOT EXISTS marketing")
spark.sql("CREATE CATALOG IF NOT EXISTS finance")

# Each domain manages their own schemas
spark.sql("CREATE SCHEMA IF NOT EXISTS sales.raw")
spark.sql("CREATE SCHEMA IF NOT EXISTS sales.curated")
spark.sql("CREATE SCHEMA IF NOT EXISTS sales.products")  # published data products

# ✅ PATTERN 2: Data product with SLA metadata
spark.sql("""
    CREATE TABLE sales.products.daily_revenue (
        sale_date DATE,
        region STRING,
        product_category STRING,
        revenue DECIMAL(15,2),
        order_count BIGINT
    ) USING DELTA
    CLUSTER BY (region, sale_date)
    TBLPROPERTIES (
        'data_product.owner' = 'sales_team',
        'data_product.sla' = 'daily_by_6am_utc',
        'data_product.freshness' = '24h',
        'data_product.quality_score' = '99.5',
        'data_product.documentation' = 'https://wiki/sales/daily_revenue',
        'delta.enableChangeDataFeed' = 'true',
        'delta.columnMapping.mode' = 'name'
    )
""")

# ✅ PATTERN 3: Cross-domain access via grants
# Marketing team can READ sales data product
spark.sql("""
    GRANT SELECT ON TABLE sales.products.daily_revenue
    TO `marketing_analysts`
""")

# ✅ PATTERN 4: Data product quality gate
spark.sql("""
    ALTER TABLE sales.products.daily_revenue
    ADD CONSTRAINT positive_revenue CHECK (revenue >= 0)
""")
spark.sql("""
    ALTER TABLE sales.products.daily_revenue
    ADD CONSTRAINT valid_date CHECK (sale_date <= current_date())
""")

# ✅ PATTERN 5: External sharing via Delta Sharing
spark.sql("""
    CREATE SHARE IF NOT EXISTS sales_analytics_share
""")
spark.sql("""
    ALTER SHARE sales_analytics_share
    ADD TABLE sales.products.daily_revenue
""")
```

---

## **PART 35: Delta Lake with ML / Feature Stores**

### **Feature Store Pattern with Delta Lake**

```python
"""
WHY DELTA LAKE FOR FEATURE STORES?

  ML features need:
  ✅ Point-in-time correctness (no data leakage)
  ✅ Versioning (reproduce training data)
  ✅ Low-latency lookups (serving)
  ✅ Batch + streaming updates
  ✅ Schema evolution (new features)

  Delta Lake provides ALL of these natively.
"""

# ✅ PATTERN 1: Feature table with time travel
spark.sql("""
    CREATE TABLE ml.features.user_features (
        user_id         STRING NOT NULL,
        feature_date    DATE NOT NULL,
        purchase_count_7d    INT,
        purchase_count_30d   INT,
        avg_order_value_30d  DECIMAL(10,2),
        days_since_last_purchase INT,
        total_lifetime_value DECIMAL(15,2),
        user_segment         STRING,
        updated_at           TIMESTAMP
    ) USING DELTA
    CLUSTER BY (user_id, feature_date)
    TBLPROPERTIES (
        'delta.enableChangeDataFeed' = 'true',
        'delta.columnMapping.mode' = 'name'
    )
""")

# ✅ PATTERN 2: Point-in-time feature retrieval (no data leakage)
def get_features_as_of(entity_df, feature_table, join_keys, as_of_column):
    """
    Join features with point-in-time correctness.
    Prevents future data from leaking into training set.
    """
    features = spark.table(feature_table)

    # For each entity row, get the latest feature BEFORE the event timestamp
    from pyspark.sql.window import Window
    from pyspark.sql.functions import row_number

    joined = entity_df.alias("e").join(
        features.alias("f"),
        [entity_df[k] == features[k] for k in join_keys] +
        [features["feature_date"] <= entity_df[as_of_column]],
        "left"
    )

    window = Window.partitionBy(
        *[f"e.{k}" for k in join_keys], f"e.{as_of_column}"
    ).orderBy(col("f.feature_date").desc())

    result = joined.withColumn("_rn", row_number().over(window)) \
        .filter("_rn = 1").drop("_rn")

    return result

# Training set with point-in-time features
training_events = spark.sql("""
    SELECT user_id, event_date, label
    FROM ml.training.purchase_labels
""")

training_data = get_features_as_of(
    training_events,
    "ml.features.user_features",
    join_keys=["user_id"],
    as_of_column="event_date"
)

# ✅ PATTERN 3: Feature versioning with time travel
# Reproduce exact training data from 2 weeks ago
features_2_weeks_ago = spark.read.format("delta") \
    .option("timestampAsOf", "2024-01-25") \
    .table("ml.features.user_features")

# ✅ PATTERN 4: Incremental feature updates
def update_user_features(as_of_date):
    """Compute and upsert features for a specific date."""
    new_features = spark.sql(f"""
        SELECT
            user_id,
            DATE('{as_of_date}') as feature_date,
            COUNT(*) FILTER (WHERE order_date >= DATE_SUB('{as_of_date}', 7))
                as purchase_count_7d,
            COUNT(*) FILTER (WHERE order_date >= DATE_SUB('{as_of_date}', 30))
                as purchase_count_30d,
            AVG(amount) FILTER (WHERE order_date >= DATE_SUB('{as_of_date}', 30))
                as avg_order_value_30d,
            DATEDIFF('{as_of_date}', MAX(order_date))
                as days_since_last_purchase,
            SUM(amount) as total_lifetime_value,
            current_timestamp() as updated_at
        FROM production.analytics.orders
        WHERE order_date <= '{as_of_date}'
        GROUP BY user_id
    """)

    feature_table = DeltaTable.forName(spark, "ml.features.user_features")
    feature_table.alias("t").merge(
        new_features.alias("s"),
        "t.user_id = s.user_id AND t.feature_date = s.feature_date"
    ).whenMatchedUpdateAll() \
     .whenNotMatchedInsertAll() \
     .execute()
```

---

## **QUICK REFERENCE CARD**

```
┌──────────────────────────────────────────────────────────────────────┐
│              DELTA LAKE COMMAND QUICK REFERENCE (Complete)            │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│ CREATE:                                                              │
│ df.write.format("delta").save(path)                                  │
│ CREATE TABLE name USING DELTA                                       │
│                                                                      │
│ READ:                                                                │
│ spark.read.format("delta").load(path)                                │
│ spark.read.format("delta").option("versionAsOf", N)                 │
│                                                                      │
│ UPDATE:                                                              │
│ delta_table.update(condition, set={...})                             │
│                                                                      │
│ DELETE:                                                              │
│ delta_table.delete(condition)                                        │
│                                                                      │
│ MERGE (UPSERT):                                                      │
│ delta_table.merge(source, condition)                                 │
│   .whenMatchedUpdate(...)                                            │
│   .whenNotMatchedInsert(...)                                         │
│   .execute()                                                         │
│                                                                      │
│ OPTIMIZE:                                                            │
│ delta_table.optimize().executeCompaction()                           │
│ delta_table.optimize().executeZOrderBy("col1", "col2")               │
│                                                                      │
│ VACUUM:                                                              │
│ delta_table.vacuum(retentionHours)                                   │
│                                                                      │
│ TIME TRAVEL:                                                         │
│ delta_table.history()                                                │
│ delta_table.restoreToVersion(N)                                      │
│                                                                      │
│ SCHEMA:                                                              │
│ .option("mergeSchema", "true")                                       │
│ .option("overwriteSchema", "true")                                   │
│                                                                      │
│ LIQUID CLUSTERING (replaces PARTITIONED BY + ZORDER):                │
│ CREATE TABLE t (...) USING DELTA CLUSTER BY (col1, col2)             │
│ ALTER TABLE t CLUSTER BY (col3, col4)    -- change anytime           │
│ ALTER TABLE t CLUSTER BY NONE            -- disable                  │
│                                                                      │
│ DELETION VECTORS:                                                    │
│ SET TBLPROPERTIES ('delta.enableDeletionVectors' = 'true')           │
│ -- DELETE/UPDATE/MERGE then use DVs automatically                    │
│                                                                      │
│ UNIFORM (cross-format):                                              │
│ SET TBLPROPERTIES ('delta.universalFormat.enabledFormats'='iceberg') │
│                                                                      │
│ CLONE:                                                               │
│ CREATE TABLE clone SHALLOW CLONE source                              │
│ CREATE TABLE backup DEEP CLONE source VERSION AS OF N                │
│                                                                      │
│ CHECK CONSTRAINTS:                                                   │
│ ALTER TABLE t ADD CONSTRAINT ck CHECK (amount > 0)                   │
│ ALTER TABLE t DROP CONSTRAINT ck                                     │
│                                                                      │
│ GENERATED COLUMNS:                                                   │
│ col_name TYPE GENERATED ALWAYS AS (expression)                       │
│                                                                      │
│ IDENTITY COLUMNS:                                                    │
│ col_name BIGINT GENERATED ALWAYS AS IDENTITY                         │
│                                                                      │
│ BLOOM FILTER:                                                        │
│ CREATE BLOOMFILTER INDEX ON TABLE t FOR COLUMNS (col)                │
│                                                                      │
│ COLUMN MAPPING:                                                      │
│ SET TBLPROPERTIES ('delta.columnMapping.mode' = 'name')              │
│ ALTER TABLE t RENAME COLUMN old_name TO new_name                     │
│ ALTER TABLE t DROP COLUMN col_name                                   │
│                                                                      │
│ IDEMPOTENT WRITES:                                                   │
│ .option("txnAppId", "job_name").option("txnVersion", "run_id")      │
│                                                                      │
│ UNITY CATALOG:                                                       │
│ CREATE CATALOG name / CREATE SCHEMA catalog.schema                   │
│ GRANT SELECT ON TABLE catalog.schema.table TO `group`                │
│ ALTER TABLE t SET ROW FILTER func ON (col)                           │
│ ALTER TABLE t ALTER COLUMN c SET MASK mask_func                      │
│                                                                      │
│ DELTA LIVE TABLES:                                                   │
│ @dlt.table / @dlt.view                                               │
│ @dlt.expect("name", "condition")                                     │
│ @dlt.expect_or_drop("name", "condition")                             │
│ @dlt.expect_or_fail("name", "condition")                             │
│                                                                      │
│ DELTA SHARING:                                                       │
│ CREATE SHARE name / ALTER SHARE name ADD TABLE t                     │
│ CREATE RECIPIENT name / GRANT SELECT ON SHARE TO RECIPIENT           │
│                                                                      │
│ GDPR:                                                                │
│ DELETE FROM t WHERE user_id = 'x' (then VACUUM to physically remove) │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
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

### **Q6: What is Liquid Clustering and why does it replace partitioning + Z-ORDER?**

**Answer:**
```
Traditional approach requires TWO mechanisms:
  PARTITIONED BY (date)     → physical directory layout (irreversible)
  ZORDER BY (user_id)       → file-level data colocating (manual OPTIMIZE)

Problems:
  - Partition columns locked at table creation
  - Over-partitioning → small files; under-partitioning → full scans
  - Z-ORDER must be run manually and rewrites ALL data

Liquid Clustering (Delta 3.0+):
  CLUSTER BY (user_id, date) → single mechanism, changeable anytime
  - ALTER TABLE t CLUSTER BY (new_col) → instant, no rewrite
  - Incremental: only clusters new/modified data
  - No small files problem (no directory-per-partition)
  - Auto-clusters during optimizeWrite

When to use:
  - All NEW tables (no reason to use old approach)
  - Existing tables where partition scheme is suboptimal
  - Tables where query patterns evolve over time
```

### **Q7: What are Deletion Vectors and how do they improve performance?**

**Answer:**
```
Without DVs (Copy-on-Write):
  DELETE 5 rows from 128 MB file (1M rows)
  → Read 128 MB, remove 5 rows, write 128 MB
  → 256 MB I/O for 5 rows!

With DVs:
  DELETE 5 rows from 128 MB file
  → Write 1 KB bitmap marking positions {42, 1089, 50001, ...}
  → Original file untouched!
  → 1 KB I/O instead of 256 MB

Trade-off:
  Reads must check DV bitmap → ~5% read overhead
  Periodically run OPTIMIZE to materialize deletions

Enable: SET TBLPROPERTIES ('delta.enableDeletionVectors' = 'true')
Requires: minReaderVersion=3, minWriterVersion=7
```

### **Q8: Delta Lake vs Iceberg vs Hudi — when to choose which?**

**Answer:**
```
Delta Lake: Best for Databricks-centric architectures
  - Tightest Spark integration
  - Unity Catalog for governance
  - Liquid Clustering, Photon engine
  - UniForm bridges to Iceberg/Hudi

Iceberg: Best for multi-engine, vendor-neutral architectures
  - Works natively with Spark, Trino, Flink, Dremio, Athena
  - Hidden partitioning (users don't need to know partition scheme)
  - Partition Evolution (change partitioning without rewriting)
  - Strongest open-source community momentum

Hudi: Best for high-frequency upsert / CDC workloads
  - Built-in record-level indexing (fastest point lookups)
  - Native MoR table type (write-optimized)
  - Inline compaction (no separate job)
  - Best for near-real-time CDC pipelines

All three provide ACID, time travel, and schema evolution.
The differentiator is ecosystem fit and workload pattern.
```

### **Q9: How does Delta Lake handle concurrent writes on S3?**

**Answer:**
```
Problem: S3 doesn't support atomic rename (needed for commits)

Solution: S3DynamoDBLogStore
  - DynamoDB acts as distributed lock for commit coordination
  - Writer acquires lock → writes commit JSON → releases lock
  - Competing writers wait or retry

Configuration:
  spark.delta.logStore.class = io.delta.storage.S3DynamoDBLogStore
  + DynamoDB table with (tablePath HASH, fileName RANGE)

ADLS (Azure): Atomic rename is native → no extra config needed
GCS: Uses GCSLogStore for consistency

Best practice: Partition-isolate concurrent writers when possible
(appends to different partitions never conflict)
```

### **Q10: What is UniForm and when would you use it?**

**Answer:**
```
UniForm = Universal Format
  Write as Delta Lake → auto-generates Iceberg (and/or Hudi) metadata
  Same Parquet files readable by all three table formats

Use case:
  Team A (Databricks) writes Delta tables
  Team B (Trino/Athena) reads as Iceberg
  Team C (EMR Hudi) reads as Hudi
  → ONE copy of data, THREE metadata layers

Enable:
  SET TBLPROPERTIES ('delta.universalFormat.enabledFormats' = 'iceberg')

Requires: column mapping mode = 'name'

Key: Delta is the primary writer; Iceberg/Hudi metadata is read-only
```

### **Q11: Explain Copy-on-Write vs Merge-on-Read in the context of table formats.**

**Answer:**
```
Copy-on-Write (CoW):
  UPDATE 1 row in 128 MB file → rewrite entire 128 MB file
  ✅ Fast reads (no merge at query time)
  ❌ Slow writes (full file rewrite)
  Used by: Delta Lake (default), Iceberg (default), Hudi (COW table)

Merge-on-Read (MoR):
  UPDATE 1 row → write tiny delta file (1 KB) + deletion marker
  ✅ Fast writes (only write changes)
  ❌ Slower reads (must merge base + delta at query time)
  Used by: Hudi (MOR table), Iceberg v2

Delta Lake's approach (v3.0+):
  Hybrid — CoW + Deletion Vectors
  Deletes/updates: DV bitmap (MoR-like, no file rewrite)
  Inserts: new Parquet files (CoW)
  OPTIMIZE: materializes all DVs (compacts back to pure CoW)
```

### **Q12: What is Column Mapping and why is it required for modern Delta features?**

**Answer:**
```
Problem: Parquet references columns by position (ordinal index)
  → Renaming or dropping columns requires rewriting ALL files

Column Mapping (delta.columnMapping.mode = 'name'):
  → Adds logical ID layer between names and physical positions
  → Rename = metadata-only change (instant)
  → Drop = metadata-only change (instant)

Required for:
  - ALTER TABLE RENAME COLUMN
  - ALTER TABLE DROP COLUMN
  - UniForm
  - Liquid Clustering

Enable: SET TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
Protocol: minReaderVersion=2, minWriterVersion=5
Warning: Irreversible — cannot switch back to position mode

Best practice: Enable on ALL new tables (no downside)
```

### **Q13: Explain the Medallion Architecture and how Delta Lake enables it.**

**Answer:**
```
Medallion = Bronze → Silver → Gold layered data architecture.

Bronze (Raw):
  - Append-only ingestion from sources (Kafka, S3, APIs)
  - Preserve raw payload + ingestion metadata
  - No transformation, no filtering
  - Long retention for audit/replay

Silver (Cleaned):
  - Parsed, validated, deduplicated
  - Canonical schema (consistent types, naming)
  - CHECK constraints for data quality
  - MERGE for deduplication
  - Medium retention

Gold (Business):
  - Aggregated, business-logic applied
  - Star schema or wide tables
  - Optimized for query patterns (BI, ML)
  - Short retention (re-derivable from Silver)

Delta Lake enables this with:
  - ACID writes at each layer (no partial state)
  - Change Data Feed to propagate changes layer-to-layer
  - Schema evolution as sources change
  - Time travel for debugging between layers
  - Streaming between layers (readStream → writeStream)
```

### **Q14: What is Unity Catalog and how does it differ from Hive Metastore?**

**Answer:**
```
Unity Catalog = Databricks' unified governance solution.

Key differences from Hive Metastore:
  Namespace:      database.table → catalog.schema.table (3-level)
  Access control: Limited table ACLs → full GRANT/REVOKE + row/column security
  Lineage:        None → automatic column-level lineage
  Audit:          Limited → full audit trail
  Cross-workspace: No → Yes (share across Databricks workspaces)
  Data discovery:  None → search, tags, comments

Row-level security: ALTER TABLE t SET ROW FILTER func ON (col)
Column masking:     ALTER TABLE t ALTER COLUMN c SET MASK mask_func

Unity Catalog is the foundation for governance, compliance, and
data mesh architectures on Databricks.
```

### **Q15: What is Delta Live Tables (DLT)?**

**Answer:**
```
DLT = Declarative ETL framework built on Delta Lake.

Instead of writing imperative ETL (read → transform → write),
you DECLARE what the table should contain:

  @dlt.table
  @dlt.expect_or_drop("valid_id", "id IS NOT NULL")
  def silver_events():
      return dlt.read_stream("bronze_events").select(...)

DLT automatically handles:
  - Dependency resolution (DAG of tables)
  - Incremental processing (only new data)
  - Data quality (expectations = declarative checks)
  - Error recovery and retries
  - Schema management

Three expectation levels:
  @dlt.expect           → warn (log bad rows, keep them)
  @dlt.expect_or_drop   → drop bad rows silently
  @dlt.expect_or_fail   → fail pipeline on violation

Best for: Production ETL pipelines where reliability matters
          more than maximum flexibility.
```

### **Q16: How do you handle GDPR "Right to Be Forgotten" with Delta Lake?**

**Answer:**
```
Challenge: Delete all data for a user across all tables,
           AND prove the data is physically removed.

Step 1 — Logical delete:
  DELETE FROM events WHERE user_id = 'user_to_forget'
  DELETE FROM orders WHERE user_id = 'user_to_forget'
  (repeat for all tables containing user data)

Step 2 — Physical removal:
  VACUUM events RETAIN 0 HOURS
  (removes old Parquet files containing the deleted user's data)
  WARNING: This breaks time travel for all data, not just the user!

Step 3 — Verification:
  Attempt time travel to old versions → should fail (files vacuumed)
  Query current version → user data should return 0 rows

Step 4 — Audit trail:
  Store deletion records in a GDPR audit log table
  (table, user_id, rows_deleted, timestamp)

Alternative: Pseudonymization (replace PII with hashed values)
  — Preserves analytics value while removing identifiability

Key: Deletion Vectors make Step 1 fast (no full file rewrite).
     VACUUM in Step 2 handles physical removal.
```

### **Q17: What is Delta Sharing and when would you use it?**

**Answer:**
```
Delta Sharing = Open protocol for sharing live Delta tables
across organizations without copying data.

How it works:
  Provider creates a SHARE → adds tables to it
  Recipient gets activation link → reads tables directly
  Data stays in provider's storage — no copying!

Key features:
  - Open protocol (works with Spark, Pandas, Trino, Power BI)
  - Recipient doesn't need Databricks
  - Fine-grained access (table, partition, column level)
  - Full audit trail

Use cases:
  - Share data with partners/vendors
  - B2B data marketplace
  - Cross-department data products (Data Mesh)
  - Compliance reporting to regulators

vs. traditional sharing (export CSV/Parquet):
  ✅ Always fresh (live data, not stale exports)
  ✅ No data duplication (saves storage cost)
  ✅ Access control and audit (revoke anytime)
  ✅ Schema evolution handled automatically
```

### **Q18: How would you optimize Delta Lake costs in production?**

**Answer:**
```
Storage costs:
  1. Regular VACUUM (remove old file versions)
  2. OPTIMIZE (compact small files → fewer, larger files)
  3. Use Liquid Clustering (avoid over-partitioning)
  4. zstd compression (better ratio than snappy)
  5. Drop unused Bloom filter indexes

Compute costs:
  1. Partition pruning (filter on partition columns)
  2. Column pruning (SELECT only needed cols, never SELECT *)
  3. Data skipping (Liquid Clustering / Z-ORDER on filter cols)
  4. Bloom filters (for UUID/high-cardinality point lookups)
  5. Deletion Vectors (avoid write amplification on UPDATE/DELETE)
  6. Photon engine (2-8x faster, no code changes)
  7. availableNow trigger (batch-style streaming, no idle cluster)
  8. Idempotent writes (prevent duplicate processing)

Monitoring:
  - Track numFiles and avgFileSize trends
  - Alert on small file accumulation
  - Monitor files scanned vs skipped per query
  - Review OPTIMIZE/VACUUM job history
```

### **Q19: Compare SCD Types 1, 2, 3, and 4 with Delta Lake.**

**Answer:**
```
SCD Type 1 — Overwrite (no history):
  MERGE ... WHEN MATCHED UPDATE SET *
  Simple, fast, but history is lost.

SCD Type 2 — Versioned rows (full history):
  MERGE: close old row (is_current=false, end_date=now)
       + insert new row (is_current=true, end_date=9999-12-31)
  Full audit trail, but table grows unboundedly.
  Query current: WHERE is_current = true

SCD Type 3 — Previous value column (one change):
  MERGE: SET prev_city = t.city, city = s.city
  Only tracks ONE prior value. Lightweight but limited.

SCD Type 4 — Separate history table:
  Main table: always current (fast lookups)
  History table: all changes (full audit)
  Best of both: fast current reads + full history.
  More complex: must maintain two tables in sync.

Type 2 is most common in interviews.
Type 4 is recommended for large-scale production systems.
```
