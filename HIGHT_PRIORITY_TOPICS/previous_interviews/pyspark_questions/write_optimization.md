# PySpark Implementation: Write Optimization (Partitioning, Bucketing, Compaction)

## Problem Statement 

You have a large DataFrame (1 billion rows) and need to write it efficiently to disk. Poorly written data leads to **too many small files** (thrashing the namenode), **skewed partition sizes** (slow reads), or **missing partition pruning** (full table scans). This guide covers the three key write optimization techniques: **partitioning**, **bucketing**, and **small file compaction**.

---

## Part 1: Partition-By Writing

### When to Partition

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_date, year, month

spark = SparkSession.builder.appName("WriteOptimization").getOrCreate()

# Sample data
data = [
    ("O001", "2025-01-05", "Electronics", 1200),
    ("O002", "2025-01-15", "Clothing", 300),
    ("O003", "2025-02-08", "Electronics", 800),
    ("O004", "2025-02-15", "Clothing", 950),
    ("O005", "2025-03-10", "Electronics", 400),
    ("O006", "2025-03-20", "Clothing", 600)
]
df = spark.createDataFrame(data, ["order_id", "order_date", "category", "amount"])
df = df.withColumn("order_date", to_date("order_date"))

# Basic partition by column
df.write.partitionBy("category").parquet("/tmp/output/by_category")
```

**Directory structure created:**
```
/tmp/output/by_category/
├── category=Electronics/
│   ├── part-00000.parquet
│   └── part-00001.parquet
└── category=Clothing/
    ├── part-00000.parquet
    └── part-00001.parquet
```

### Multi-Level Partitioning (Year/Month)

```python
# Add partition columns
df_partitioned = df.withColumn("year", year("order_date")) \
    .withColumn("month", month("order_date"))

# Write with hierarchical partitions
df_partitioned.write.partitionBy("year", "month").parquet("/tmp/output/by_date")
```

**Directory structure:**
```
/tmp/output/by_date/
├── year=2025/
│   ├── month=1/
│   │   └── part-00000.parquet
│   ├── month=2/
│   │   └── part-00000.parquet
│   └── month=3/
│       └── part-00000.parquet
```

### Partition Pruning — Why It Matters

```python
# Reading with filter — Spark ONLY reads the matching partition folder
# Skips all other partitions at the file system level (no data scan)
df_filtered = spark.read.parquet("/tmp/output/by_date") \
    .filter((col("year") == 2025) & (col("month") == 1))

# Check the physical plan — look for "PartitionFilters"
df_filtered.explain()
# PushedFilters: []
# PartitionFilters: [year = 2025, month = 1]  ← Only reads this folder
```

### Choosing the Right Partition Column

| Column | Cardinality | Partition? | Why |
|--------|------------|-----------|-----|
| `year/month` | 12/year | Yes | Sweet spot for time-series data |
| `country` | ~200 | Yes | Good if queries always filter by country |
| `status` | 3-5 values | Yes | Only if queries filter on status |
| `customer_id` | Millions | **No!** | Too many tiny partitions |
| `order_id` | Billions | **Never** | One file per ID — catastrophic |

**Rule of thumb:** Partition by columns with **low to medium cardinality** (< 1000 distinct values) that appear in **WHERE clauses** of most queries.

---

## Part 2: Controlling Number of Output Files

### Problem: Too Many Small Files

```python
# This creates one file per Spark partition (could be 200+ files)
df.write.parquet("/tmp/output/too_many_files")
```

### Solution: repartition() or coalesce() Before Writing

```python
# Exact control: write exactly N files total
df.repartition(4).write.parquet("/tmp/output/4_files")

# Write exactly 1 file per partition value
df.repartition("category").write.partitionBy("category") \
    .parquet("/tmp/output/one_file_per_partition")

# coalesce (no shuffle — merge existing partitions)
df.coalesce(2).write.parquet("/tmp/output/2_files")
```

### repartition vs coalesce for Writes

| | repartition(N) | coalesce(N) |
|--|--------------|------------|
| Shuffle | Yes (full shuffle) | No (merge adjacent partitions) |
| File sizes | Even | Uneven (depends on input distribution) |
| When to use | Need even file sizes | Reducing file count, already well-distributed |
| Typical use | `repartition(col).write.partitionBy(col)` | `coalesce(10).write.parquet(...)` |

### Target File Size

```python
# Aim for 128MB - 1GB per file (Parquet)
# Formula: num_files = total_size_gb / target_file_size_gb
# Example: 50GB total → 50-400 files

# For partitioned writes, control files per partition:
df.repartition(10, "category").write.partitionBy("category") \
    .parquet("/tmp/output/sized_files")
# This creates ~10 files per partition value
```

---

## Part 3: Bucketing

### What Bucketing Does

```python
# Bucketing sorts data into N fixed buckets based on hash(column)
# Unlike partitioning (folders), bucketing creates N files with data distributed by hash
df.write.bucketBy(8, "customer_id") \
    .sortBy("customer_id") \
    .saveAsTable("orders_bucketed")
```

### Bucket Join Optimization

```python
# If BOTH tables are bucketed by the same column with same bucket count,
# Spark can do a sort-merge join WITHOUT shuffle

orders = spark.table("orders_bucketed")       # bucketed by customer_id, 8 buckets
customers = spark.table("customers_bucketed")  # bucketed by customer_id, 8 buckets

# This join is shuffle-free! Bucket 1 joins with bucket 1, etc.
result = orders.join(customers, on="customer_id")
result.explain()
# SortMergeJoin (no Exchange/Shuffle nodes)
```

### Partitioning vs Bucketing

| | Partitioning | Bucketing |
|--|-------------|-----------|
| Storage | Separate folders | Separate files within folder |
| Cardinality | Low (< 1000) | High (millions) |
| Optimizes | Filter/WHERE queries | JOIN operations |
| Mechanism | Folder pruning | Shuffle elimination |
| Syntax | `partitionBy("col")` | `bucketBy(N, "col")` |

---

## Part 4: Small File Compaction

### Problem: Thousands of Tiny Files from Streaming or Frequent Appends

```python
# Common in streaming: each micro-batch writes 1-2 small files
# After 24 hours: thousands of 1KB files per partition

# Compact: read all, repartition, overwrite
small_files_path = "/tmp/output/many_small_files"
df_compact = spark.read.parquet(small_files_path)

# Calculate target file count (~1M rows per file)
total_rows = df_compact.count()
target_files = max(1, total_rows // 1000000)

df_compact.repartition(target_files) \
    .write.mode("overwrite") \
    .parquet(small_files_path)
```

### Delta Lake Auto-Compaction (Production)

```python
# Delta Lake handles compaction natively
df.write.format("delta").partitionBy("year", "month") \
    .save("/tmp/output/delta_table")

# Compact small files
spark.sql("OPTIMIZE delta.`/tmp/output/delta_table`")

# With Z-ordering (co-locate related data for faster filters)
spark.sql("""
    OPTIMIZE delta.`/tmp/output/delta_table`
    ZORDER BY (customer_id)
""")
```

---

## Part 5: Write Modes

```python
# Overwrite: replace all data
df.write.mode("overwrite").parquet("/tmp/output/data")

# Append: add to existing data (can create duplicates!)
df.write.mode("append").parquet("/tmp/output/data")

# Ignore: skip if path exists
df.write.mode("ignore").parquet("/tmp/output/data")

# Error (default): fail if path exists
df.write.mode("error").parquet("/tmp/output/data")

# Dynamic partition overwrite — only overwrite partitions present in DataFrame
spark.conf.set("spark.sql.sources.partitionOverwriteMode", "dynamic")
df.write.mode("overwrite").partitionBy("year", "month") \
    .parquet("/tmp/output/data")
# Only partitions in df are overwritten; other partitions untouched
```

---

## Part 6: File Format Comparison

| Format | Type | Compression | Schema Evolution | ACID | Best For |
|--------|------|-------------|-----------------|------|----------|
| Parquet | Columnar | Excellent | Limited | No | Analytics queries |
| ORC | Columnar | Excellent | Limited | No | Hive ecosystem |
| Delta | Columnar | Excellent | Yes | Yes | Data lakes |
| CSV | Row | None | No | No | Data exchange |
| Avro | Row | Good | Yes | No | Streaming |

```python
# Compression options for Parquet
df.write.option("compression", "snappy").parquet("/tmp/snappy")   # Default, fastest
df.write.option("compression", "zstd").parquet("/tmp/zstd")       # Best balance
df.write.option("compression", "gzip").parquet("/tmp/gzip")       # Smallest, slowest
```

| Codec | Ratio | Write Speed | Read Speed | Best For |
|-------|-------|-------------|------------|----------|
| Snappy | Medium | Fastest | Fastest | Default / hot data |
| Zstd | High | Fast | Fast | Cold data / cost savings |
| Gzip | High | Slow | Medium | Maximum compression |

---

## Complete Production Write Pattern

```python
(
    df
    .withColumn("year", year("order_date"))
    .withColumn("month", month("order_date"))
    .repartition("year", "month")           # Even distribution
    .sortWithinPartitions("order_date")      # Sort within each file
    .write
    .mode("overwrite")
    .partitionBy("year", "month")            # Folder structure for pruning
    .option("compression", "zstd")           # Good compression
    .option("maxRecordsPerFile", 1000000)    # Cap file size
    .parquet("/tmp/output/production_data")
)
```

---

## Key Interview Talking Points

1. **Partition by low-cardinality filter columns:** `partitionBy("year", "month")` creates folder structure for partition pruning. Never partition by high-cardinality columns (customer_id) — creates millions of tiny folders.

2. **Bucket by high-cardinality join columns:** `bucketBy(N, "customer_id")` pre-sorts data for shuffle-free joins. Both tables must be bucketed on the same column with same bucket count.

3. **Control file count:** Use `repartition(N)` before `.write` to control output file count. Target 128MB-1GB per file. Too many small files kills read performance.

4. **repartition vs coalesce:** `repartition(N)` does a full shuffle (even sizes). `coalesce(N)` merges without shuffle (uneven but faster). Use `repartition` for final writes, `coalesce` for quick reduction.

5. **Dynamic partition overwrite:** Set `partitionOverwriteMode=dynamic` to overwrite only partitions present in the DataFrame, not the entire table. Critical for incremental loads.

6. **sortWithinPartitions:** Sorting data within each file improves Parquet's internal statistics (min/max per row group), enabling better predicate pushdown at read time.
