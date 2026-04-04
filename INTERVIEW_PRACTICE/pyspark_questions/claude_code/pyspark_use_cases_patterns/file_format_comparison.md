# PySpark Implementation: File Format Comparison

## Problem Statement

Choosing the right file format is one of the most impactful decisions in data engineering. The format affects read/write performance, storage costs, schema evolution capabilities, and compatibility with downstream tools. In interviews, you're expected to know the trade-offs between CSV, JSON, Avro, Parquet, ORC, and Delta Lake, and when to use each.

**Real-world scenario**: A team is designing a new data lake. Raw data arrives as JSON from APIs and CSV from SFTP. The lakehouse needs to store this data efficiently for both batch analytics (SQL queries) and streaming consumers. You must recommend formats for each layer (bronze/silver/gold) and justify your choices.

---

## Approach 1: Read/Write Each Format with Benchmarks

### Sample Data

```python
data = [
    (i, f"user_{i % 1000}", f"dept_{i % 10}",
     float(i * 1.5), f"2024-{(i % 12) + 1:02d}-{(i % 28) + 1:02d}")
    for i in range(100000)
]
columns = ["id", "username", "department", "salary", "hire_date"]
```

### Expected Output

A comparison table showing file size, write time, and read time for each format.

### Full Working Code

```python
from pyspark.sql import SparkSession
from pyspark.sql.types import (StructType, StructField, IntegerType,
                                StringType, DoubleType)
import time
import os
import glob as pyglob

spark = SparkSession.builder \
    .appName("FileFormatComparison") \
    .master("local[*]") \
    .getOrCreate()

# ── 1. Create Sample Data ─────────────────────────────────────────
data = [
    (i, f"user_{i % 1000}", f"dept_{i % 10}",
     float(i * 1.5), f"2024-{(i % 12) + 1:02d}-{(i % 28) + 1:02d}")
    for i in range(100000)
]
schema = StructType([
    StructField("id", IntegerType()),
    StructField("username", StringType()),
    StructField("department", StringType()),
    StructField("salary", DoubleType()),
    StructField("hire_date", StringType()),
])
df = spark.createDataFrame(data, schema)
df.cache()
df.count()  # materialize the cache

base_path = "/tmp/format_comparison"

# ── 2. Helper Functions ───────────────────────────────────────────
def get_dir_size(path):
    total = 0
    for f in pyglob.glob(f"{path}/**/*", recursive=True):
        if os.path.isfile(f):
            total += os.path.getsize(f)
    return total

def benchmark_write(df, fmt, path, **options):
    start = time.time()
    writer = df.write.mode("overwrite")
    for k, v in options.items():
        writer = writer.option(k, v)
    writer.format(fmt).save(path)
    elapsed = time.time() - start
    size = get_dir_size(path)
    return elapsed, size

def benchmark_read(spark, fmt, path, **options):
    start = time.time()
    reader = spark.read.format(fmt)
    for k, v in options.items():
        reader = reader.option(k, v)
    count = reader.load(path).count()
    elapsed = time.time() - start
    return elapsed, count

results = []

# ── 3. CSV ─────────────────────────────────────────────────────────
path = f"{base_path}/csv"
w_time, w_size = benchmark_write(df, "csv", path, header="true")
r_time, _ = benchmark_read(spark, "csv", path, header="true", inferSchema="true")
results.append(("CSV", w_time, r_time, w_size))

# ── 4. JSON ────────────────────────────────────────────────────────
path = f"{base_path}/json"
w_time, w_size = benchmark_write(df, "json", path)
r_time, _ = benchmark_read(spark, "json", path)
results.append(("JSON", w_time, r_time, w_size))

# ── 5. Parquet (default snappy compression) ────────────────────────
path = f"{base_path}/parquet"
w_time, w_size = benchmark_write(df, "parquet", path)
r_time, _ = benchmark_read(spark, "parquet", path)
results.append(("Parquet", w_time, r_time, w_size))

# ── 6. ORC ─────────────────────────────────────────────────────────
path = f"{base_path}/orc"
w_time, w_size = benchmark_write(df, "orc", path)
r_time, _ = benchmark_read(spark, "orc", path)
results.append(("ORC", w_time, r_time, w_size))

# ── 7. Avro ────────────────────────────────────────────────────────
path = f"{base_path}/avro"
w_time, w_size = benchmark_write(df, "avro", path)
r_time, _ = benchmark_read(spark, "avro", path)
results.append(("Avro", w_time, r_time, w_size))

# ── 8. Print Results ──────────────────────────────────────────────
print(f"\n{'Format':<10} {'Write (s)':<12} {'Read (s)':<12} {'Size (MB)':<12}")
print("-" * 46)
for fmt, w, r, s in results:
    print(f"{fmt:<10} {w:<12.3f} {r:<12.3f} {s / (1024*1024):<12.2f}")

spark.stop()
```

---

## Approach 2: Compression Options Comparison

### Full Working Code

```python
from pyspark.sql import SparkSession
import time
import os
import glob as pyglob

spark = SparkSession.builder \
    .appName("CompressionComparison") \
    .master("local[*]") \
    .getOrCreate()

# ── 1. Create Data ────────────────────────────────────────────────
data = [(i, f"user_{i % 500}", f"dept_{i % 20}", float(i * 2.5))
        for i in range(200000)]
df = spark.createDataFrame(data, ["id", "user", "dept", "salary"])
df.cache()
df.count()

base_path = "/tmp/compression_test"

def get_dir_size(path):
    return sum(os.path.getsize(f) for f in pyglob.glob(f"{path}/**/*", recursive=True)
               if os.path.isfile(f))

# ── 2. Parquet with Different Compressions ─────────────────────────
compressions = ["none", "snappy", "gzip", "zstd", "lz4"]

print(f"\n{'Compression':<15} {'Write (s)':<12} {'Read (s)':<12} {'Size (MB)':<12}")
print("-" * 51)

for comp in compressions:
    path = f"{base_path}/parquet_{comp}"

    start = time.time()
    df.write.mode("overwrite") \
        .option("compression", comp) \
        .parquet(path)
    w_time = time.time() - start

    start = time.time()
    spark.read.parquet(path).count()
    r_time = time.time() - start

    size = get_dir_size(path)
    print(f"{comp:<15} {w_time:<12.3f} {r_time:<12.3f} {size / (1024*1024):<12.2f}")

# ── 3. Typical Results (relative) ─────────────────────────────────
# Compression    Write Speed    Read Speed    Size      Ratio
# none           fastest        fastest       largest   1.0x
# snappy         fast           fast          good      ~0.4x    (DEFAULT)
# lz4            fast           fast          good      ~0.4x
# zstd           moderate       fast          smallest  ~0.3x
# gzip           slowest        moderate      small     ~0.35x

# ── 4. CSV Compression ────────────────────────────────────────────
for comp in ["none", "gzip", "bzip2"]:
    path = f"{base_path}/csv_{comp}"
    df.write.mode("overwrite") \
        .option("header", "true") \
        .option("compression", comp) \
        .csv(path)
    size = get_dir_size(path)
    print(f"CSV + {comp}: {size / (1024*1024):.2f} MB")

# NOTE: gzip CSV is NOT splittable! Spark must read the entire file
# in a single task. Use bzip2 for splittable compressed CSV (slower).

spark.stop()
```

---

## Approach 3: Schema Evolution Support by Format

### Full Working Code

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import lit

spark = SparkSession.builder \
    .appName("SchemaEvolution") \
    .master("local[*]") \
    .getOrCreate()

base_path = "/tmp/schema_evolution"

# ── 1. Write V1 Schema ────────────────────────────────────────────
v1_data = [(1, "Alice", 100.0), (2, "Bob", 200.0)]
v1_df = spark.createDataFrame(v1_data, ["id", "name", "salary"])

# ── 2. Parquet Schema Evolution ───────────────────────────────────
parquet_path = f"{base_path}/parquet_evo"

# Write v1
v1_df.write.mode("overwrite").parquet(parquet_path)

# Write v2 with a new column (append to same path)
v2_data = [(3, "Carol", 150.0, "Engineering")]
v2_df = spark.createDataFrame(v2_data, ["id", "name", "salary", "department"])
v2_df.write.mode("append").parquet(parquet_path)

# Read with mergeSchema
merged = spark.read.option("mergeSchema", "true").parquet(parquet_path)
print("=== Parquet: Merged Schema ===")
merged.printSchema()
merged.show()
# department is null for v1 rows, populated for v2 rows

# Without mergeSchema, Spark uses the schema of the first file
# and may miss the new column or throw an error.

# ── 3. Avro Schema Evolution ──────────────────────────────────────
avro_path = f"{base_path}/avro_evo"

v1_df.write.mode("overwrite").format("avro").save(avro_path)
v2_df.write.mode("append").format("avro").save(avro_path)

# Avro supports schema evolution natively with reader/writer schemas
avro_merged = spark.read.format("avro").load(avro_path)
print("=== Avro: Schema Evolution ===")
avro_merged.printSchema()
avro_merged.show()

# ── 4. JSON Schema Evolution ──────────────────────────────────────
json_path = f"{base_path}/json_evo"

v1_df.write.mode("overwrite").json(json_path)
v2_df.write.mode("append").json(json_path)

# JSON is schema-on-read, so it handles evolution naturally
json_merged = spark.read.json(json_path)
print("=== JSON: Schema Evolution ===")
json_merged.printSchema()
json_merged.show()

# ── 5. CSV Schema Evolution (POOR support) ────────────────────────
csv_path = f"{base_path}/csv_evo"

v1_df.write.mode("overwrite").option("header", "true").csv(csv_path)
v2_df.write.mode("append").option("header", "true").csv(csv_path)

# CSV reads with the header from the first file.
# New columns in v2 files are silently dropped or misaligned.
csv_read = spark.read.option("header", "true").csv(csv_path)
print("=== CSV: Schema Evolution (broken) ===")
csv_read.printSchema()
csv_read.show()
# The 'department' column may not appear or data may be corrupted

spark.stop()
```

---

## Approach 4: Column Pruning and Predicate Pushdown

### Full Working Code

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("ColumnPruningPushdown") \
    .master("local[*]") \
    .getOrCreate()

data = [(i, f"user_{i}", f"dept_{i % 10}", float(i * 1.5))
        for i in range(100000)]
df = spark.createDataFrame(data, ["id", "username", "department", "salary"])

base = "/tmp/column_pruning_test"

# Write in all formats
df.write.mode("overwrite").parquet(f"{base}/parquet")
df.write.mode("overwrite").orc(f"{base}/orc")
df.write.mode("overwrite").json(f"{base}/json")
df.write.mode("overwrite").option("header", "true").csv(f"{base}/csv")

# ── 1. Column Pruning ─────────────────────────────────────────────
# Parquet and ORC are COLUMNAR -> only read requested columns from disk
# JSON and CSV are ROW-BASED -> must read entire row to get one column

# Select only 2 of 4 columns from Parquet
parquet_pruned = spark.read.parquet(f"{base}/parquet") \
    .select("id", "salary")
parquet_pruned.explain(True)
# ReadSchema shows only id and salary -> 50% less I/O

# Same query on CSV reads ALL columns from disk
csv_pruned = spark.read.option("header", "true").csv(f"{base}/csv") \
    .select("id", "salary")
csv_pruned.explain(True)
# Must read entire row, then project -> no I/O savings

# ── 2. Predicate Pushdown ─────────────────────────────────────────
# Parquet stores min/max stats per row group per column.
# Spark pushes filter predicates into the Parquet reader to skip
# row groups where the predicate cannot match.

filtered = spark.read.parquet(f"{base}/parquet") \
    .filter("salary > 100000")
filtered.explain(True)
# PushedFilters: [IsNotNull(salary), GreaterThan(salary, 100000.0)]

# ORC has even more advanced pushdown with bloom filters and indexes
orc_filtered = spark.read.orc(f"{base}/orc") \
    .filter("salary > 100000")
orc_filtered.explain(True)

# JSON/CSV: no predicate pushdown. Must read everything, then filter.
json_filtered = spark.read.json(f"{base}/json") \
    .filter("salary > 100000")
json_filtered.explain(True)
# PushedFilters: [] (empty)

spark.stop()
```

---

## Approach 5: Format Selection Decision Guide

### Full Working Code

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("FormatDecisionGuide") \
    .master("local[*]") \
    .getOrCreate()

# ── Complete Format Comparison Matrix ──────────────────────────────

comparison = """
+----------+----------+----------+---------+----------+----------+----------+
| Feature  |   CSV    |   JSON   |  Avro   | Parquet  |   ORC    |  Delta   |
+----------+----------+----------+---------+----------+----------+----------+
| Type     |   Row    |   Row    |   Row   | Columnar | Columnar | Columnar |
| Compress | External | External |  Built  |  Built   |  Built   |  Built   |
| Schema   |  None    | Inferred | Embedded| Embedded | Embedded | Enforced |
| Evolution|  Poor    | Moderate |  Good   |  Good    |  Good    | Excellent|
| Split    | Yes*     | Yes*     |   Yes   |   Yes    |   Yes    |   Yes    |
| Col Prune|   No     |   No     |   No    |   Yes    |   Yes    |   Yes    |
| Pushdown |   No     |   No     |   No    |   Yes    |   Yes    |   Yes    |
| Human    |  Yes     |   Yes    |   No    |   No     |   No     |   No     |
| ACID     |   No     |   No     |   No    |   No     |   No     |   Yes    |
| Streaming|   Yes    |   Yes    |   Yes   |   Yes    |   Yes    |   Yes    |
| Best For | Ingress  | APIs/Log | Kafka/  | Analytics| Hive/    | Lakehouse|
|          | Export   | Landing  | Stream  | OLAP     | Legacy   | All Use  |
+----------+----------+----------+---------+----------+----------+----------+

* CSV/JSON splittability depends on compression:
  - Uncompressed or bzip2: splittable
  - gzip, snappy: NOT splittable (single task reads whole file)
"""
print(comparison)

# ── When to Use Each Format ────────────────────────────────────────

guide = """
FORMAT SELECTION GUIDE:

CSV:
  - Ingesting data from external systems (SFTP, legacy)
  - Exporting data for non-technical users (Excel)
  - NEVER for internal storage or analytics

JSON:
  - Landing zone for API responses
  - Semi-structured data with nested schemas
  - NEVER for large-scale analytics (no column pruning)

Avro:
  - Kafka message serialization (compact, schema registry)
  - Row-level operations (frequent full-row reads)
  - Schema evolution across producers/consumers

Parquet:
  - Default for analytics workloads
  - Columnar queries (SELECT few columns from wide tables)
  - Silver/Gold layers of data lakehouse

ORC:
  - Hive-centric ecosystems
  - Similar to Parquet with better Hive integration
  - Legacy Hadoop environments

Delta Lake:
  - Production lakehouse (ACID, time-travel, MERGE)
  - Any table that needs updates/deletes
  - All layers if using Databricks/Delta ecosystem
"""
print(guide)

# ── Lakehouse Layer Recommendations ────────────────────────────────

layers = """
LAKEHOUSE ARCHITECTURE:

Bronze (Raw):
  - Keep original format (JSON, CSV, Avro) OR convert to Delta
  - Delta gives ACID + schema enforcement even at raw layer
  - Retain raw data for reprocessing

Silver (Cleaned):
  - Delta Lake or Parquet
  - Deduplicated, typed, validated data
  - Partitioned by date

Gold (Aggregated):
  - Delta Lake or Parquet
  - Aggregated, business-ready tables
  - Optimized with Z-ordering for query patterns
"""
print(layers)

spark.stop()
```

---

## Key Takeaways

| Format | Strength | Weakness | Best For |
|---|---|---|---|
| **CSV** | Human-readable, universal | No schema, no pushdown, slow | Import/export |
| **JSON** | Semi-structured, human-readable | Large, no column pruning | API landing zone |
| **Avro** | Compact row format, great schema evolution | No column pruning | Kafka, streaming |
| **Parquet** | Columnar, compressed, pushdown | No ACID, no updates | Analytics queries |
| **ORC** | Columnar, Hive-optimized | Less ecosystem support than Parquet | Hive workloads |
| **Delta** | ACID, time-travel, MERGE, schema enforcement | Requires Delta runtime | Production lakehouse |

## Interview Tips

- **Always recommend Parquet or Delta** for analytics. If someone says they store analytics data in JSON, that's a red flag.
- **Know the splittability rules**: gzip-compressed CSV/JSON cannot be split across tasks, creating a single-task bottleneck. This is a classic interview question.
- **Column pruning is the key differentiator** between row-based (CSV, JSON, Avro) and columnar (Parquet, ORC) formats. On a 100-column table where you SELECT 3 columns, Parquet reads ~3% of the data. CSV reads 100%.
- **Delta Lake = Parquet + transaction log**. Delta files are Parquet files on disk with a `_delta_log` directory. This is important to understand -- Delta is not a separate file format; it's a storage layer on top of Parquet.
- **Compression defaults**: Parquet defaults to snappy (fast, reasonable compression). For cold storage/archival, recommend zstd (better ratio, still fast reads). For CSV export, gzip is common but not splittable.
- When asked "how would you design a data lake?", mention the Bronze/Silver/Gold pattern with format choices at each layer. This shows architectural thinking.
