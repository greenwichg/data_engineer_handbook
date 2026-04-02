# PySpark Implementation: The Small Files Problem

## Problem Statement

In distributed data lakes (HDFS, S3, ADLS), having too many small files is one of the most common and damaging performance problems. Each file requires metadata overhead in the NameNode (HDFS) or object store listing calls (S3). When Spark reads thousands of tiny files, it creates one task per file, leading to excessive task scheduling overhead, poor parallelism utilization, and slow reads.

**Real-world scenario**: A streaming job writes micro-batches every 10 seconds into a Hive partition. After a day, a single partition contains 8,640 tiny files (each a few KB). A downstream batch job reading this partition spends more time on task scheduling and file opening than on actual data processing.

---

## Approach 1: Detecting the Small Files Problem

### Sample Data

```python
# Simulate writing many small files by repartitioning to a high number
data = [(i, f"user_{i % 100}", i * 1.5) for i in range(10000)]
```

### Expected Output

A diagnostic showing file count, average file size, and whether the partition has a small files issue.

### Full Working Code

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit, input_file_name, count, avg
import os
import glob as pyglob

spark = SparkSession.builder \
    .appName("SmallFilesDetection") \
    .master("local[*]") \
    .getOrCreate()

# ── 1. Create the Small Files Problem ─────────────────────────────
data = [(i, f"user_{i % 100}", i * 1.5) for i in range(10000)]
df = spark.createDataFrame(data, ["id", "user", "amount"])

# Write with 200 partitions -> 200 small files
output_path = "/tmp/small_files_demo"
df.repartition(200).write.mode("overwrite").parquet(output_path)

# ── 2. Detect Small Files ─────────────────────────────────────────
# Method A: Use OS-level inspection
files = pyglob.glob(f"{output_path}/**/*.parquet", recursive=True)
file_sizes = [os.path.getsize(f) for f in files]

print(f"File count:       {len(files)}")
print(f"Total size:       {sum(file_sizes) / 1024:.1f} KB")
print(f"Avg file size:    {sum(file_sizes) / len(files) / 1024:.1f} KB")
print(f"Min file size:    {min(file_sizes) / 1024:.1f} KB")
print(f"Max file size:    {max(file_sizes) / 1024:.1f} KB")

# Rule of thumb: files under 128 MB are "small" for HDFS/S3
SMALL_THRESHOLD_BYTES = 128 * 1024 * 1024  # 128 MB
small_count = sum(1 for s in file_sizes if s < SMALL_THRESHOLD_BYTES)
print(f"Small files:      {small_count}/{len(files)}")

# Method B: Use Spark's input_file_name to see file distribution
read_df = spark.read.parquet(output_path)
file_dist = read_df.withColumn("file", input_file_name()) \
    .groupBy("file").count() \
    .agg(
        count("*").alias("num_files"),
        avg("count").alias("avg_rows_per_file")
    )
file_dist.show(truncate=False)

spark.stop()
```

---

## Approach 2: Fix with coalesce() and repartition()

### Sample Data

Same 200-file dataset from above.

### Expected Output

Compacted output with a target of ~4 well-sized files.

### Full Working Code

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("SmallFilesCoalesce") \
    .master("local[*]") \
    .getOrCreate()

# ── 1. Read the Small Files ───────────────────────────────────────
input_path = "/tmp/small_files_demo"
df = spark.read.parquet(input_path)

print(f"Number of partitions (tasks) on read: {df.rdd.getNumPartitions()}")
# This will be ~200, one per small file

# ── 2. Fix with coalesce (narrow transformation, no shuffle) ──────
compacted_path_coalesce = "/tmp/compacted_coalesce"

df.coalesce(4) \
    .write.mode("overwrite") \
    .parquet(compacted_path_coalesce)

# Verify: should have exactly 4 files now
import glob as pyglob, os
files = pyglob.glob(f"{compacted_path_coalesce}/*.parquet")
print(f"Files after coalesce(4): {len(files)}")
for f in files:
    print(f"  {os.path.basename(f)}: {os.path.getsize(f) / 1024:.1f} KB")

# ── 3. Fix with repartition (full shuffle, better data distribution)
compacted_path_repartition = "/tmp/compacted_repartition"

df.repartition(4) \
    .write.mode("overwrite") \
    .parquet(compacted_path_repartition)

files = pyglob.glob(f"{compacted_path_repartition}/*.parquet")
print(f"\nFiles after repartition(4): {len(files)}")
for f in files:
    print(f"  {os.path.basename(f)}: {os.path.getsize(f) / 1024:.1f} KB")

# ── 4. coalesce vs repartition ────────────────────────────────────
# coalesce(N):
#   - Reduces partitions WITHOUT a shuffle (narrow dependency)
#   - Faster, but can create uneven file sizes if upstream partitions vary
#   - Use when going from MANY partitions to FEWER
#
# repartition(N):
#   - Full shuffle -> even data distribution across N partitions
#   - More expensive but produces evenly sized files
#   - Use when you need balanced output files or are INCREASING partitions

spark.stop()
```

---

## Approach 3: Adaptive Query Execution (AQE) Auto-Coalescing

### Full Working Code

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("AQECoalescing") \
    .master("local[*]") \
    .config("spark.sql.adaptive.enabled", "true") \
    .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
    .config("spark.sql.adaptive.coalescePartitions.minPartitionSize", "1MB") \
    .config("spark.sql.adaptive.advisoryPartitionSizeInBytes", "128MB") \
    .getOrCreate()

# AQE automatically coalesces shuffle partitions at runtime.
# After a shuffle stage completes, Spark checks the actual data sizes
# and merges small partitions together to meet the advisory size.

# ── 1. Create sample data ─────────────────────────────────────────
data = [(i, f"dept_{i % 5}", i * 10.0) for i in range(100000)]
df = spark.createDataFrame(data, ["id", "dept", "salary"])

# ── 2. Trigger a shuffle (groupBy) ────────────────────────────────
# Default shuffle partitions = 200, but AQE will coalesce them
spark.conf.set("spark.sql.shuffle.partitions", "200")

agg_df = df.groupBy("dept").sum("salary")

# Check plan -> AQE will show CustomShuffleReader or 
# AQEShuffleRead with coalesced partitions
agg_df.explain(True)

result = agg_df.collect()  # triggers execution
print(f"Result partitions: {agg_df.rdd.getNumPartitions()}")

# Without AQE: 200 shuffle partitions (most nearly empty for 5 depts)
# With AQE: Spark coalesces to ~5 partitions automatically

# ── 3. Write the AQE-optimized result ─────────────────────────────
output_path = "/tmp/aqe_output"
agg_df.write.mode("overwrite").parquet(output_path)

import glob as pyglob
files = pyglob.glob(f"{output_path}/*.parquet")
print(f"Output files with AQE: {len(files)}")

spark.stop()
```

---

## Approach 4: Delta Lake OPTIMIZE / Compaction

### Full Working Code

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("DeltaCompaction") \
    .master("local[*]") \
    .config("spark.jars.packages", "io.delta:delta-core_2.12:2.4.0") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog",
            "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .getOrCreate()

# ── 1. Create Many Small Delta Files ──────────────────────────────
delta_path = "/tmp/delta_small_files"

# Simulate multiple small appends (like a streaming job)
for batch in range(20):
    data = [(batch * 100 + i, f"user_{i}", batch) for i in range(50)]
    batch_df = spark.createDataFrame(data, ["id", "user", "batch_num"])
    batch_df.write.format("delta").mode("append").save(delta_path)

# Check file count before compaction
import glob as pyglob
files = pyglob.glob(f"{delta_path}/*.parquet")
print(f"Files BEFORE OPTIMIZE: {len(files)}")

# ── 2. Run OPTIMIZE (bin-packing compaction) ──────────────────────
from delta.tables import DeltaTable

delta_table = DeltaTable.forPath(spark, delta_path)

# SQL approach:
# spark.sql(f"OPTIMIZE delta.`{delta_path}`")

# Python approach:
delta_table.optimize().executeCompaction()

# After OPTIMIZE, Delta rewrites small files into larger ones
# Old files are retained for time-travel but new reads use compacted files
files_after = pyglob.glob(f"{delta_path}/*.parquet")
print(f"Files AFTER OPTIMIZE: {len(files_after)}")
# Note: old files still exist but Delta's transaction log points
# to the new compacted files. VACUUM removes old files.

# ── 3. VACUUM to Clean Up Old Files ───────────────────────────────
# Remove files older than 0 hours (for demo; use 168 hours = 7 days in prod)
spark.conf.set("spark.databricks.delta.retentionDurationCheck.enabled", "false")
delta_table.vacuum(0)

files_final = pyglob.glob(f"{delta_path}/*.parquet")
print(f"Files AFTER VACUUM: {len(files_final)}")

# ── 4. Auto-Compaction (Databricks / Delta 2.0+) ──────────────────
# In Databricks, enable auto-compaction on the table:
# spark.conf.set("spark.databricks.delta.autoCompact.enabled", "true")
# This automatically runs OPTIMIZE after each write if needed.

spark.stop()
```

---

## Approach 5: Target File Size Calculation

### Full Working Code

```python
from pyspark.sql import SparkSession
import os
import glob as pyglob

spark = SparkSession.builder \
    .appName("TargetFileSize") \
    .master("local[*]") \
    .getOrCreate()

# ── Helper: Calculate Optimal Number of Output Files ───────────────
def calculate_target_files(input_path, target_file_size_mb=128):
    """
    Given an input path, calculate how many output files to write
    so each is approximately target_file_size_mb.
    """
    files = pyglob.glob(f"{input_path}/**/*.parquet", recursive=True)
    total_bytes = sum(os.path.getsize(f) for f in files)
    total_mb = total_bytes / (1024 * 1024)

    target_files = max(1, int(total_mb / target_file_size_mb))

    print(f"Total data size: {total_mb:.2f} MB")
    print(f"Target file size: {target_file_size_mb} MB")
    print(f"Recommended output files: {target_files}")
    return target_files

# ── Usage ──────────────────────────────────────────────────────────
input_path = "/tmp/small_files_demo"
num_files = calculate_target_files(input_path, target_file_size_mb=128)

df = spark.read.parquet(input_path)
df.coalesce(num_files).write.mode("overwrite").parquet("/tmp/right_sized_output")

# ── maxRecordsPerFile option ───────────────────────────────────────
# Spark also supports limiting rows per file:
df.write \
    .option("maxRecordsPerFile", 100000) \
    .mode("overwrite") \
    .parquet("/tmp/max_records_output")

spark.stop()
```

---

## Key Takeaways

| Problem | Symptom | Solution |
|---|---|---|
| Too many small files | Slow reads, high task count, NameNode pressure | coalesce/repartition before write |
| Streaming micro-batches | Thousands of files per partition per day | Delta OPTIMIZE, trigger-based compaction |
| Post-shuffle fragmentation | 200 shuffle partitions for 5 groups | AQE coalescing, reduce `shuffle.partitions` |
| Uneven file sizes | Some files 1 KB, others 1 GB | repartition (with shuffle) for even distribution |
| Legacy data lake cleanup | Years of accumulated small files | Periodic compaction job |

## Interview Tips

- **Target file size**: The sweet spot is 128 MB to 1 GB per file for HDFS/S3. Mention this number explicitly.
- **coalesce vs repartition**: `coalesce(N)` is a narrow transformation (no shuffle, fast, but uneven). `repartition(N)` is a wide transformation (shuffle, slower, but even). Always explain the trade-off.
- **AQE is the modern answer**: In Spark 3.x, AQE auto-coalesces shuffle partitions. Mention that you'd enable it (`spark.sql.adaptive.enabled=true`) as a first step.
- **Delta Lake OPTIMIZE**: This is the gold standard for lakehouse architectures. It rewrites small files into larger ones without affecting concurrent readers (MVCC).
- **Root cause**: Don't just fix symptoms. Identify why small files are being created (too many shuffle partitions, frequent appends, over-partitioning) and fix the source.
- **S3 vs HDFS**: On S3, the small files problem is even worse because each file requires a separate HTTP request. S3's list operations are also slow (1,000 keys per request). This makes compaction even more critical.
