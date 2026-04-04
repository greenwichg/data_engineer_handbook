# PySpark Implementation: Z-Ordering and Data Skipping in Delta Lake

## Problem Statement

Partitioning works well when queries filter on one low-cardinality column (e.g., date). But what if queries frequently filter on multiple high-cardinality columns simultaneously (e.g., `WHERE customer_id = 12345 AND product_id = 678`)? Partitioning by both would create millions of tiny directories.

**Z-ordering** solves this by co-locating related data within files using a space-filling Z-curve. Combined with Delta Lake's **data skipping** (min/max statistics per file), Spark can skip entire files whose min/max ranges don't overlap with the query predicate.

**Real-world scenario**: An e-commerce analytics table has 10 billion rows. Analysts query by `customer_id`, `product_category`, and `order_date` in varying combinations. Z-ordering on these columns lets Delta skip 90%+ of files for any filter combination.

---

## Approach 1: Z-Ordering with Delta Lake OPTIMIZE

### Sample Data

```python
# 100K orders across customers, products, and dates
import random
data = [
    (i,
     random.randint(1, 10000),          # customer_id (high cardinality)
     random.choice(["Electronics", "Clothing", "Food", "Books", "Sports"]),
     f"2024-{random.randint(1,12):02d}-{random.randint(1,28):02d}",
     round(random.uniform(10, 5000), 2))
    for i in range(100000)
]
```

### Expected Output

After Z-ordering by `customer_id` and `product_category`, queries filtering on either or both columns should skip significantly more files than without Z-ordering.

### Full Working Code

```python
from pyspark.sql import SparkSession
from pyspark.sql.types import (StructType, StructField, IntegerType,
                                StringType, DoubleType)
import random

spark = SparkSession.builder \
    .appName("ZOrdering") \
    .master("local[*]") \
    .config("spark.jars.packages", "io.delta:delta-core_2.12:2.4.0") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog",
            "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .getOrCreate()

# ── 1. Create Sample Data ─────────────────────────────────────────
random.seed(42)
data = [
    (i,
     random.randint(1, 10000),
     random.choice(["Electronics", "Clothing", "Food", "Books", "Sports"]),
     f"2024-{random.randint(1,12):02d}-{random.randint(1,28):02d}",
     round(random.uniform(10, 5000), 2))
    for i in range(100000)
]

schema = StructType([
    StructField("order_id", IntegerType()),
    StructField("customer_id", IntegerType()),
    StructField("category", StringType()),
    StructField("order_date", StringType()),
    StructField("amount", DoubleType()),
])

df = spark.createDataFrame(data, schema)

# ── 2. Write as Delta WITHOUT Z-Ordering ──────────────────────────
no_zorder_path = "/tmp/delta_no_zorder"

df.repartition(20) \
    .write.format("delta") \
    .mode("overwrite") \
    .save(no_zorder_path)

# ── 3. Write as Delta WITH Z-Ordering ─────────────────────────────
zorder_path = "/tmp/delta_with_zorder"

df.write.format("delta").mode("overwrite").save(zorder_path)

# Run OPTIMIZE with ZORDER BY
spark.sql(f"""
    OPTIMIZE delta.`{zorder_path}`
    ZORDER BY (customer_id, category)
""")

# ── 4. Query Both and Compare ─────────────────────────────────────
# Read both tables
df_no_z = spark.read.format("delta").load(no_zorder_path)
df_z = spark.read.format("delta").load(zorder_path)

# Query: specific customer and category
query_filter = "customer_id = 5000 AND category = 'Electronics'"

print("=== WITHOUT Z-ORDER ===")
df_no_z.filter(query_filter).explain(True)
result_no_z = df_no_z.filter(query_filter)
print(f"Rows found: {result_no_z.count()}")

print("\n=== WITH Z-ORDER ===")
df_z.filter(query_filter).explain(True)
result_z = df_z.filter(query_filter)
print(f"Rows found: {result_z.count()}")

# In the Spark UI -> SQL tab, compare "files read" metrics:
# Without Z-order: Spark reads most/all files
# With Z-order: Spark skips files where customer_id min/max
#   doesn't include 5000 AND category min/max doesn't include 'Electronics'

spark.stop()
```

---

## Approach 2: Understanding Data Skipping Statistics

### Full Working Code

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, from_json, explode
import json

spark = SparkSession.builder \
    .appName("DataSkippingStats") \
    .master("local[*]") \
    .config("spark.jars.packages", "io.delta:delta-core_2.12:2.4.0") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog",
            "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .getOrCreate()

delta_path = "/tmp/delta_with_zorder"

# ── 1. Read Delta Log to See Per-File Stats ────────────────────────
# Delta stores min/max/nullCount stats for the first 32 columns
# in the transaction log JSON files

from delta.tables import DeltaTable
dt = DeltaTable.forPath(spark, delta_path)

# Get the file-level details
detail = dt.detail()
detail.show(truncate=False)

# ── 2. Read the Transaction Log Directly ───────────────────────────
log_df = spark.read.json(f"{delta_path}/_delta_log/*.json")

# The 'add' column contains file-level statistics
adds = log_df.filter(col("add").isNotNull()).select("add.*")
adds.select("path", "size", "stats").show(truncate=80)

# ── 3. Parse Statistics to See Min/Max Per File ───────────────────
# Stats look like:
# {
#   "numRecords": 5000,
#   "minValues": {"customer_id": 1, "category": "Books", ...},
#   "maxValues": {"customer_id": 9999, "category": "Sports", ...},
#   "nullCount": {"customer_id": 0, ...}
# }

# Without Z-ordering: each file has customer_id range ~1-10000 (wide)
# With Z-ordering: each file has a narrow customer_id range (e.g., 1-500)

# ── 4. Demonstrate How Data Skipping Works ─────────────────────────
# When you query WHERE customer_id = 5000:
#   - Spark reads stats from the Delta log
#   - For each file, checks: min(customer_id) <= 5000 <= max(customer_id)
#   - Skips files where 5000 is outside the [min, max] range
#
# With Z-ordering, customer_id values are clustered, so each file
# covers a narrow range -> more files can be skipped.
#
# Example:
#   File A: customer_id [1, 500]     -> SKIP (5000 not in range)
#   File B: customer_id [4800, 5200] -> READ (5000 is in range)
#   File C: customer_id [5500, 6000] -> SKIP

# ── 5. DESCRIBE HISTORY for Optimization Metrics ──────────────────
history = dt.history()
history.select("version", "operation", "operationMetrics").show(truncate=False)
# The OPTIMIZE operation shows:
#   numFilesAdded, numFilesRemoved, numBatches

spark.stop()
```

---

## Approach 3: Z-Ordering vs Partitioning Decision Framework

### Full Working Code

```python
from pyspark.sql import SparkSession
import random

spark = SparkSession.builder \
    .appName("ZOrderVsPartition") \
    .master("local[*]") \
    .config("spark.jars.packages", "io.delta:delta-core_2.12:2.4.0") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog",
            "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .getOrCreate()

# ── 1. Generate Realistic Data ─────────────────────────────────────
random.seed(42)
regions = ["US", "EU", "APAC"]
categories = ["Electronics", "Clothing", "Food", "Books", "Sports"]

data = [
    (i,
     random.choice(regions),
     random.randint(1, 50000),        # customer_id
     random.choice(categories),
     f"2024-{random.randint(1,12):02d}-{random.randint(1,28):02d}",
     round(random.uniform(5, 3000), 2))
    for i in range(200000)
]
df = spark.createDataFrame(data, ["id", "region", "customer_id",
                                   "category", "order_date", "amount"])

# ── Strategy A: Partition by region, Z-Order by customer_id ────────
path_a = "/tmp/strategy_a"
df.write.format("delta") \
    .partitionBy("region") \
    .mode("overwrite") \
    .save(path_a)

spark.sql(f"""
    OPTIMIZE delta.`{path_a}`
    ZORDER BY (customer_id, category)
""")

# ── Strategy B: No partition, Z-Order by region + customer_id ──────
path_b = "/tmp/strategy_b"
df.write.format("delta") \
    .mode("overwrite") \
    .save(path_b)

spark.sql(f"""
    OPTIMIZE delta.`{path_b}`
    ZORDER BY (region, customer_id, category)
""")

# ── 2. Compare Queries ────────────────────────────────────────────

# Query 1: Filter on region only (partition wins)
q1 = "region = 'US'"
print("Query 1: region = 'US'")
print("Strategy A (partitioned):")
spark.read.format("delta").load(path_a).filter(q1).explain()
print("Strategy B (z-ordered only):")
spark.read.format("delta").load(path_b).filter(q1).explain()

# Query 2: Filter on customer_id only (z-order helps both)
q2 = "customer_id = 12345"
print("\nQuery 2: customer_id = 12345")
spark.read.format("delta").load(path_a).filter(q2).explain()
spark.read.format("delta").load(path_b).filter(q2).explain()

# Query 3: Filter on region + customer_id (both help)
q3 = "region = 'EU' AND customer_id = 12345"
print("\nQuery 3: region = 'EU' AND customer_id = 12345")
spark.read.format("delta").load(path_a).filter(q3).explain()
spark.read.format("delta").load(path_b).filter(q3).explain()

# ── 3. Decision Framework ─────────────────────────────────────────
decision_guide = """
WHEN TO USE PARTITIONING:
  - Column has LOW cardinality (< 1000 distinct values)
  - Almost every query filters on this column
  - Example: date, region, country

WHEN TO USE Z-ORDERING:
  - Column has HIGH cardinality (thousands/millions of distinct values)
  - Queries filter on multiple columns in different combinations
  - Example: customer_id, product_id, zip_code

BEST PRACTICE: COMBINE BOTH
  - Partition by low-cardinality date/region
  - Z-order by high-cardinality customer_id, product_id
  - Example:
      .partitionBy("date")        -- partition pruning
      ZORDER BY (customer_id)     -- data skipping within partitions

Z-ORDER LIMITS:
  - Z-ordering on more than 3-4 columns diminishes returns
  - Each OPTIMIZE rewrites all data files (expensive)
  - Benefits compound with larger tables (>1 GB)
"""
print(decision_guide)

spark.stop()
```

---

## Approach 4: Measuring Data Skipping Effectiveness

### Full Working Code

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, min as spark_min, max as spark_max
import random

spark = SparkSession.builder \
    .appName("MeasureSkipping") \
    .master("local[*]") \
    .config("spark.jars.packages", "io.delta:delta-core_2.12:2.4.0") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog",
            "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .getOrCreate()

# ── 1. Create and Z-Order a Table ─────────────────────────────────
random.seed(42)
data = [(i, random.randint(1, 100000), round(random.uniform(1, 1000), 2))
        for i in range(500000)]
df = spark.createDataFrame(data, ["id", "customer_id", "amount"])

path = "/tmp/measure_zorder"
df.write.format("delta").mode("overwrite").save(path)

# Z-order
spark.sql(f"OPTIMIZE delta.`{path}` ZORDER BY (customer_id)")

# ── 2. Check File-Level Statistics ─────────────────────────────────
from delta.tables import DeltaTable
import json

# Read the latest checkpoint or log files
log_files = spark.read.json(f"{path}/_delta_log/*.json")
file_stats = log_files.filter(col("add").isNotNull()) \
    .select("add.path", "add.stats")

# Parse stats to see min/max customer_id per file
file_stats.show(truncate=100)

# ── 3. Measure Skipping with Spark Metrics ─────────────────────────
# Enable metrics collection
spark.conf.set("spark.sql.files.maxPartitionBytes", "128m")

# Read and filter
delta_df = spark.read.format("delta").load(path)

# This query should skip most files after Z-ordering
filtered = delta_df.filter("customer_id BETWEEN 50000 AND 50100")

# Check physical plan for FileScan details
filtered.explain(True)

# Count to trigger execution
print(f"Matching rows: {filtered.count()}")

# ── 4. Compare: Random Sort vs Z-Order ────────────────────────────
# The key insight: without Z-ordering, customer_id values are randomly
# distributed across files, so every file's [min, max] range spans
# nearly the full domain [1, 100000]. Data skipping cannot help.
#
# After Z-ordering, each file covers a narrow range (e.g., [1, 1000]),
# so a query for customer_id=50000 only needs files covering that range.
#
# Metric to watch in Spark UI:
#   "number of files read" vs "number of files pruned by data skipping"

spark.stop()
```

---

## Key Takeaways

| Concept | Detail |
|---|---|
| **Z-ordering** | Reorganizes data within files using a Z-curve so that values co-located in multi-dimensional space end up in the same files. |
| **Data skipping** | Delta Lake stores min/max stats per column per file. Queries skip files whose ranges don't match the predicate. |
| **Z-order vs partition** | Partition for low-cardinality + always-filtered columns. Z-order for high-cardinality or multi-column filter patterns. |
| **Column limit** | Z-ordering effectiveness decreases after 3-4 columns. Prioritize the most queried columns. |
| **Cost** | OPTIMIZE ZORDER rewrites all files. Run during off-peak hours. Incremental OPTIMIZE only processes new files. |
| **Stats columns** | Delta collects stats for the first 32 columns by default. Configure `delta.dataSkippingNumIndexedCols`. |

## Interview Tips

- Z-ordering is a **Delta Lake** feature, not vanilla Spark. Make sure to clarify this distinction.
- Explain the difference between **partition pruning** (directory-level, coarse) and **data skipping** (file-level, fine-grained). Z-ordering improves data skipping.
- When asked "how would you optimize a slow query on a large table?", a strong answer is: "First check if it's partitioned on the filter columns. If the filter columns are high-cardinality, Z-order instead. Verify with DESCRIBE DETAIL and check the query's file-read metrics."
- Know that **Liquid Clustering** (Databricks) is the successor to Z-ordering -- it incrementally clusters data without full rewrites. Mention it as the future direction.
- A Z-curve interleaves bits of multiple column values to create a single sort key that preserves locality in all dimensions simultaneously. You don't need to explain the math, but understanding the concept shows depth.
