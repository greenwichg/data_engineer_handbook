# PySpark Implementation: Union and Merge Multiple Sources

## Problem Statement

Merge DataFrames from multiple sources that have different schemas -- different column names, different column orders, missing columns, and different data types. Use `unionByName` with `allowMissingColumns` and other strategies to combine heterogeneous datasets into a single unified DataFrame. This is a common interview question for data engineering roles dealing with data lake ingestion, multi-source ETL, and schema evolution scenarios.

### Sample Data

**Source A (Web Events):**

| event_id | user_id | event_type | timestamp           | page_url       |
|----------|---------|------------|---------------------|----------------|
| 1        | U001    | click      | 2024-01-15 10:00:00 | /home          |
| 2        | U002    | view       | 2024-01-15 10:05:00 | /products      |

**Source B (Mobile Events):**

| event_id | user_id | event_type | timestamp           | app_version | device_type |
|----------|---------|------------|---------------------|-------------|-------------|
| 101      | U003    | tap        | 2024-01-15 11:00:00 | 3.2.1       | iOS         |
| 102      | U001    | swipe      | 2024-01-15 11:30:00 | 3.2.0       | Android     |

**Source C (API Events):**

| event_id | event_type | api_endpoint | status_code | timestamp           |
|----------|------------|--------------|-------------|---------------------|
| 201      | request    | /api/users   | 200         | 2024-01-15 12:00:00 |
| 202      | request    | /api/orders  | 500         | 2024-01-15 12:05:00 |

### Expected Output (Unified)

| event_id | user_id | event_type | timestamp           | page_url  | app_version | device_type | api_endpoint | status_code | source  |
|----------|---------|------------|---------------------|-----------|-------------|-------------|--------------|-------------|---------|
| 1        | U001    | click      | 2024-01-15 10:00:00 | /home     | null        | null        | null         | null        | web     |
| 2        | U002    | view       | 2024-01-15 10:05:00 | /products | null        | null        | null         | null        | web     |
| 101      | U003    | tap        | 2024-01-15 11:00:00 | null      | 3.2.1       | iOS         | null         | null        | mobile  |
| 102      | U001    | swipe      | 2024-01-15 11:30:00 | null      | 3.2.0       | Android     | null         | null        | mobile  |
| 201      | null    | request    | 2024-01-15 12:00:00 | null      | null        | null        | /api/users   | 200         | api     |
| 202      | null    | request    | 2024-01-15 12:05:00 | null      | null        | null        | /api/orders  | 500         | api     |

---

## Method 1: unionByName with allowMissingColumns

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

# Initialize Spark
spark = SparkSession.builder \
    .appName("Union Merge Multiple Sources") \
    .master("local[*]") \
    .getOrCreate()

# --- Source A: Web Events ---
web_data = [
    (1, "U001", "click", "2024-01-15 10:00:00", "/home"),
    (2, "U002", "view", "2024-01-15 10:05:00", "/products"),
    (3, "U001", "view", "2024-01-15 10:15:00", "/checkout"),
]
web_df = spark.createDataFrame(
    web_data, ["event_id", "user_id", "event_type", "timestamp", "page_url"]
).withColumn("source", F.lit("web"))

# --- Source B: Mobile Events ---
mobile_data = [
    (101, "U003", "tap", "2024-01-15 11:00:00", "3.2.1", "iOS"),
    (102, "U001", "swipe", "2024-01-15 11:30:00", "3.2.0", "Android"),
]
mobile_df = spark.createDataFrame(
    mobile_data, ["event_id", "user_id", "event_type", "timestamp", "app_version", "device_type"]
).withColumn("source", F.lit("mobile"))

# --- Source C: API Events ---
api_data = [
    (201, "request", "/api/users", 200, "2024-01-15 12:00:00"),
    (202, "request", "/api/orders", 500, "2024-01-15 12:05:00"),
]
api_df = spark.createDataFrame(
    api_data, ["event_id", "event_type", "api_endpoint", "status_code", "timestamp"]
).withColumn("source", F.lit("api"))

print("=== Web Schema ===")
web_df.printSchema()
print("=== Mobile Schema ===")
mobile_df.printSchema()
print("=== API Schema ===")
api_df.printSchema()

# --- Union all sources using unionByName with allowMissingColumns ---
unified_df = web_df \
    .unionByName(mobile_df, allowMissingColumns=True) \
    .unionByName(api_df, allowMissingColumns=True)

print("=== Unified Events (unionByName) ===")
unified_df.show(truncate=False)

# --- Verify schema ---
print("=== Unified Schema ===")
unified_df.printSchema()

spark.stop()
```

## Method 2: Programmatic Schema Alignment

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import StringType, IntegerType
from functools import reduce

spark = SparkSession.builder \
    .appName("Union - Schema Alignment") \
    .master("local[*]") \
    .getOrCreate()

# --- Sample sources with different schemas ---
web_df = spark.createDataFrame(
    [(1, "U001", "click", "/home")],
    ["event_id", "user_id", "event_type", "page_url"]
)

mobile_df = spark.createDataFrame(
    [(101, "U003", "tap", "iOS")],
    ["event_id", "user_id", "event_type", "device_type"]
)

api_df = spark.createDataFrame(
    [(201, "request", "/api/users", 200)],
    ["event_id", "event_type", "api_endpoint", "status_code"]
)

dataframes = [web_df, mobile_df, api_df]

# --- Step 1: Find the superset of all columns ---
all_columns = set()
for df in dataframes:
    all_columns.update(df.columns)

all_columns = sorted(all_columns)
print(f"Superset of columns: {all_columns}")

# --- Step 2: Add missing columns as null to each DataFrame ---
def align_schema(df, target_columns):
    """Add missing columns as null and reorder to match target."""
    for col_name in target_columns:
        if col_name not in df.columns:
            df = df.withColumn(col_name, F.lit(None).cast(StringType()))
    return df.select(*target_columns)

aligned_dfs = [align_schema(df, all_columns) for df in dataframes]

# --- Step 3: Union aligned DataFrames ---
unified = reduce(lambda a, b: a.union(b), aligned_dfs)

print("=== Unified with Manual Schema Alignment ===")
unified.show(truncate=False)

# --- Step 4: Handle type conflicts ---
# When sources have different types for the same column, cast to a common type
source_a = spark.createDataFrame([(1, "100")], ["id", "value"])   # value is string
source_b = spark.createDataFrame([(2, 200)], ["id", "value"])     # value is int

print("Source A schema:")
source_a.printSchema()
print("Source B schema:")
source_b.printSchema()

# Cast to common type before union
source_b_casted = source_b.withColumn("value", F.col("value").cast(StringType()))
merged = source_a.unionByName(source_b_casted)

print("=== After Type Casting ===")
merged.show()
merged.printSchema()

spark.stop()
```

## Method 3: Dynamic Multi-Source Ingestion with Metadata

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from functools import reduce

spark = SparkSession.builder \
    .appName("Union - Dynamic Ingestion") \
    .master("local[*]") \
    .getOrCreate()

# --- Simulate reading from multiple sources with metadata ---
def create_source(data, columns, source_name, source_timestamp):
    """Create a source DataFrame with standard metadata columns."""
    df = spark.createDataFrame(data, columns)
    df = df.withColumn("_source", F.lit(source_name)) \
           .withColumn("_ingested_at", F.lit(source_timestamp).cast("timestamp")) \
           .withColumn("_row_hash", F.sha2(F.concat_ws("|", *[F.coalesce(F.col(c).cast("string"), F.lit("")) for c in columns]), 256))
    return df

source_a = create_source(
    [(1, "Alice", "alice@a.com"), (2, "Bob", "bob@a.com")],
    ["id", "name", "email"],
    "crm_system", "2024-01-15 10:00:00"
)

source_b = create_source(
    [(3, "Carol", "555-1234"), (4, "Dave", "555-5678")],
    ["id", "name", "phone"],
    "legacy_db", "2024-01-15 11:00:00"
)

source_c = create_source(
    [(5, "Eve", "eve@c.com", "555-9012")],
    ["id", "name", "email", "phone"],
    "api_import", "2024-01-15 12:00:00"
)

# --- Union all sources ---
all_sources = [source_a, source_b, source_c]
unified = reduce(
    lambda a, b: a.unionByName(b, allowMissingColumns=True),
    all_sources
)

print("=== Unified with Metadata ===")
unified.show(truncate=False)

# --- Deduplication after union (prefer most recent source) ---
from pyspark.sql.window import Window

w = Window.partitionBy("id").orderBy(F.desc("_ingested_at"))

deduped = unified \
    .withColumn("rn", F.row_number().over(w)) \
    .filter(F.col("rn") == 1) \
    .drop("rn")

print("=== Deduplicated (most recent source wins) ===")
deduped.show(truncate=False)

# --- Coalesce columns from multiple sources ---
# Combine non-null values from different sources for the same entity
coalesced = unified.groupBy("id").agg(
    F.first("name", ignorenulls=True).alias("name"),
    F.first("email", ignorenulls=True).alias("email"),
    F.first("phone", ignorenulls=True).alias("phone"),
    F.collect_set("_source").alias("sources"),
    F.max("_ingested_at").alias("last_updated"),
)

print("=== Coalesced from Multiple Sources ===")
coalesced.show(truncate=False)

spark.stop()
```

## Key Concepts

- **unionByName**: Unions DataFrames by column name rather than position. Safer than `union()` which relies on column order.
- **allowMissingColumns=True**: (Spark 3.1+) Automatically adds null columns for any column that exists in one DataFrame but not the other.
- **union() vs unionByName()**: `union()` matches by position and requires identical column counts. `unionByName()` matches by name and is schema-aware.
- **Schema Alignment**: For Spark < 3.1 or finer control, manually add missing columns with `lit(None)` before unioning.
- **Type Conflicts**: If the same column has different types across sources, cast to a common type (usually StringType or the wider numeric type).

## Interview Tips

- Always prefer `unionByName` over `union` in production -- position-based matching is fragile when schemas evolve.
- Mention **schema evolution** in Delta Lake: `mergeSchema` option handles new columns automatically during writes.
- After unioning, consider **deduplication** if the same records appear in multiple sources.
- Add **metadata columns** (_source, _ingested_at) to track data lineage through the union.
- For very many sources (100+), use `reduce(lambda a, b: a.unionByName(b, allowMissingColumns=True), dfs)` to chain unions programmatically.
- Discuss the **performance impact**: each union adds a stage. For many small DataFrames, it may be more efficient to align schemas first and use a single `union`.
