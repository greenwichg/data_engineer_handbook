# PySpark Implementation: Surrogate Key Generation

## Problem Statement

Surrogate keys are synthetic, system-generated identifiers used in data warehouses to uniquely identify dimension records independently of the natural business key. In PySpark, there are several approaches to generate surrogate keys: `monotonically_increasing_id`, `row_number` window function, and hash-based keys. Each approach has trade-offs around uniqueness, determinism, and performance. This is a common interview topic for data engineering roles involving dimensional modeling.

### Sample Data

```
product_id | product_name | category    | effective_date
P001       | Widget A     | Electronics | 2024-01-01
P002       | Gadget B     | Home        | 2024-01-15
P003       | Tool C       | Hardware    | 2024-02-01
P001       | Widget A+    | Electronics | 2024-02-10
```

### Expected Output

| surrogate_key | product_id | product_name | category    | effective_date |
|---------------|------------|--------------|-------------|----------------|
| 1             | P001       | Widget A     | Electronics | 2024-01-01     |
| 2             | P002       | Gadget B     | Home        | 2024-01-15     |
| 3             | P003       | Tool C       | Hardware    | 2024-02-01     |
| 4             | P001       | Widget A+    | Electronics | 2024-02-10     |

---

## Method 1: monotonically_increasing_id

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import monotonically_increasing_id

# Initialize SparkSession
spark = SparkSession.builder \
    .appName("SurrogateKey_MonotonicallyIncreasingId") \
    .master("local[*]") \
    .getOrCreate()

# Create sample data
data = [
    ("P001", "Widget A",  "Electronics", "2024-01-01"),
    ("P002", "Gadget B",  "Home",        "2024-01-15"),
    ("P003", "Tool C",    "Hardware",    "2024-02-01"),
    ("P001", "Widget A+", "Electronics", "2024-02-10"),
]

df = spark.createDataFrame(
    data,
    ["product_id", "product_name", "category", "effective_date"]
)

# Add surrogate key using monotonically_increasing_id
# NOTE: Values are unique and monotonically increasing, but NOT consecutive
# The values depend on partition structure (partition_id << 33 + row_index_within_partition)
df_with_sk = df.withColumn("surrogate_key", monotonically_increasing_id())

print("=== monotonically_increasing_id (not consecutive) ===")
df_with_sk.show(truncate=False)

spark.stop()
```

## Method 2: row_number Window Function (Consecutive Keys)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import row_number, col
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("SurrogateKey_RowNumber") \
    .master("local[*]") \
    .getOrCreate()

data = [
    ("P001", "Widget A",  "Electronics", "2024-01-01"),
    ("P002", "Gadget B",  "Home",        "2024-01-15"),
    ("P003", "Tool C",    "Hardware",    "2024-02-01"),
    ("P001", "Widget A+", "Electronics", "2024-02-10"),
]

df = spark.createDataFrame(
    data,
    ["product_id", "product_name", "category", "effective_date"]
)

# Use row_number with a deterministic ordering to get consecutive keys
window_spec = Window.orderBy("effective_date", "product_id")

df_with_sk = df.withColumn(
    "surrogate_key",
    row_number().over(window_spec)
)

print("=== row_number (consecutive, deterministic) ===")
df_with_sk.show(truncate=False)

# With offset: continue from existing max key
existing_max_key = 1000  # e.g., fetched from target table
df_with_sk_offset = df.withColumn(
    "surrogate_key",
    row_number().over(window_spec) + existing_max_key
)

print("=== row_number with offset (starting from 1001) ===")
df_with_sk_offset.show(truncate=False)

spark.stop()
```

## Method 3: Hash-Based Surrogate Keys

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    md5, sha2, concat_ws, col, abs as spark_abs,
    hash as spark_hash, xxhash64
)

spark = SparkSession.builder \
    .appName("SurrogateKey_Hashing") \
    .master("local[*]") \
    .getOrCreate()

data = [
    ("P001", "Widget A",  "Electronics", "2024-01-01"),
    ("P002", "Gadget B",  "Home",        "2024-01-15"),
    ("P003", "Tool C",    "Hardware",    "2024-02-01"),
    ("P001", "Widget A+", "Electronics", "2024-02-10"),
]

df = spark.createDataFrame(
    data,
    ["product_id", "product_name", "category", "effective_date"]
)

# Method 3a: MD5 hash of business key columns
df_md5 = df.withColumn(
    "surrogate_key_md5",
    md5(concat_ws("||", col("product_id"), col("effective_date")))
)

print("=== MD5 hash-based key ===")
df_md5.show(truncate=False)

# Method 3b: SHA-256 for lower collision probability
df_sha = df.withColumn(
    "surrogate_key_sha256",
    sha2(concat_ws("||", col("product_id"), col("effective_date")), 256)
)

print("=== SHA-256 hash-based key ===")
df_sha.show(truncate=False)

# Method 3c: xxhash64 for integer key (faster, good for joins)
df_xxhash = df.withColumn(
    "surrogate_key_xxhash",
    xxhash64(col("product_id"), col("effective_date"))
)

print("=== xxhash64 integer key ===")
df_xxhash.show(truncate=False)

# Method 3d: Built-in hash (32-bit, more collisions)
df_hash = df.withColumn(
    "surrogate_key_hash",
    spark_abs(spark_hash(col("product_id"), col("effective_date")))
)

print("=== Spark hash (32-bit) ===")
df_hash.show(truncate=False)

spark.stop()
```

## Method 4: Combining with Existing Max Key from Target Table

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import row_number, col, coalesce, lit, max as spark_max
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("SurrogateKey_WithExistingMax") \
    .master("local[*]") \
    .getOrCreate()

# Simulate existing dimension table
existing_dim = spark.createDataFrame([
    (1, "P001", "Widget A",  "Electronics", "2024-01-01"),
    (2, "P002", "Gadget B",  "Home",        "2024-01-15"),
], ["surrogate_key", "product_id", "product_name", "category", "effective_date"])

# New records to be added
new_records = spark.createDataFrame([
    ("P003", "Tool C",    "Hardware",    "2024-02-01"),
    ("P001", "Widget A+", "Electronics", "2024-02-10"),
], ["product_id", "product_name", "category", "effective_date"])

# Get current max surrogate key
max_key = existing_dim.select(
    coalesce(spark_max("surrogate_key"), lit(0))
).collect()[0][0]

print(f"Current max surrogate key: {max_key}")

# Generate keys for new records starting after max
window_spec = Window.orderBy("effective_date", "product_id")

new_with_keys = new_records.withColumn(
    "surrogate_key",
    row_number().over(window_spec) + max_key
)

print("=== New records with surrogate keys ===")
new_with_keys.show(truncate=False)

# Union with existing dimension
updated_dim = existing_dim.unionByName(new_with_keys)

print("=== Complete dimension table ===")
updated_dim.orderBy("surrogate_key").show(truncate=False)

spark.stop()
```

## Key Concepts

- **monotonically_increasing_id()**: Generates unique, monotonically increasing 64-bit integers. Values are NOT consecutive since they encode partition ID in the upper bits. Not deterministic across runs.
- **row_number()**: Produces consecutive integers (1, 2, 3, ...) within a window. Requires `orderBy` which must be deterministic to get reproducible results. Requires a single partition shuffle for global ordering, which can be expensive on large datasets.
- **Hash-based keys**: Deterministic (same input always produces same key). Excellent for idempotent loads. MD5/SHA produce string keys; `xxhash64` produces integers. Risk of hash collisions, especially with 32-bit `hash()`.
- **Best practices**:
  - Use `row_number` + offset for traditional sequential integer keys in small-to-medium dimensions.
  - Use hash-based keys for large-scale, distributed systems where global ordering is expensive.
  - Use `monotonically_increasing_id` only for temporary unique identifiers within a single pipeline run.
- **Interview Tip**: Discuss why natural keys are insufficient (they can change, be reused, or be composite) and why surrogate keys provide a stable reference. Also mention that Delta Lake's `MERGE` operation benefits from hash-based keys for idempotent upserts.
