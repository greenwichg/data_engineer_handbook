# PySpark Implementation: Dynamic Partition Overwrite

## Problem Statement

In ETL pipelines, you often need to overwrite only specific partitions of a table while leaving other partitions untouched. For example, you reprocess January 2024 data due to a bug, and you want to overwrite only the `date=2024-01-*` partitions without destroying February or March data.

Spark offers two modes for partitioned writes with `mode("overwrite")`:

- **Static mode** (default): Deletes ALL existing data in the target path, then writes new data. This is dangerous -- it wipes partitions you didn't intend to touch.
- **Dynamic mode**: Only overwrites partitions that exist in the new DataFrame. Other partitions remain untouched.

This is one of the most common ETL pitfalls. Getting it wrong means data loss.

---

## Approach 1: Demonstrating the Problem with Static Overwrite

### Sample Data

```python
# Existing data in the table
existing_data = [
    ("2024-01-15", "US", 1000),
    ("2024-01-15", "EU", 800),
    ("2024-02-10", "US", 1200),
    ("2024-02-10", "EU", 950),
    ("2024-03-05", "US", 1100),
]

# New/corrected data for January only
new_jan_data = [
    ("2024-01-15", "US", 1050),  # corrected amount
    ("2024-01-15", "EU", 820),   # corrected amount
]
```

### Expected Output

After overwrite, February and March data should still exist. Only January data should be replaced.

### Full Working Code

```python
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, IntegerType

spark = SparkSession.builder \
    .appName("StaticOverwriteProblem") \
    .master("local[*]") \
    .getOrCreate()

schema = StructType([
    StructField("sale_date", StringType()),
    StructField("region", StringType()),
    StructField("amount", IntegerType()),
])

# ── 1. Write Initial Data (partitioned by sale_date) ──────────────
existing_data = [
    ("2024-01-15", "US", 1000),
    ("2024-01-15", "EU", 800),
    ("2024-02-10", "US", 1200),
    ("2024-02-10", "EU", 950),
    ("2024-03-05", "US", 1100),
]

output_path = "/tmp/static_overwrite_demo"
existing_df = spark.createDataFrame(existing_data, schema)
existing_df.write.partitionBy("sale_date").mode("overwrite").parquet(output_path)

print("=== BEFORE Overwrite ===")
spark.read.parquet(output_path).orderBy("sale_date", "region").show()
# +----------+------+------+
# | sale_date|region|amount|
# +----------+------+------+
# |2024-01-15|    EU|   800|
# |2024-01-15|    US|  1000|
# |2024-02-10|    EU|   950|
# |2024-02-10|    US|  1200|
# |2024-03-05|    US|  1100|
# +----------+------+------+

# ── 2. Static Overwrite (DEFAULT BEHAVIOR - DANGEROUS!) ───────────
new_jan_data = [
    ("2024-01-15", "US", 1050),
    ("2024-01-15", "EU", 820),
]
new_df = spark.createDataFrame(new_jan_data, schema)

# This is the DEFAULT mode: static partition overwrite
# It deletes ALL data in output_path and writes only the new data!
new_df.write.partitionBy("sale_date").mode("overwrite").parquet(output_path)

print("=== AFTER Static Overwrite (DATA LOSS!) ===")
spark.read.parquet(output_path).orderBy("sale_date", "region").show()
# +----------+------+------+
# | sale_date|region|amount|
# +----------+------+------+
# |2024-01-15|    EU|   820|
# |2024-01-15|    US|  1050|
# +----------+------+------+
# February and March data is GONE!

spark.stop()
```

---

## Approach 2: Dynamic Partition Overwrite (The Correct Way)

### Full Working Code

```python
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, IntegerType

spark = SparkSession.builder \
    .appName("DynamicPartitionOverwrite") \
    .master("local[*]") \
    .config("spark.sql.sources.partitionOverwriteMode", "dynamic") \
    .getOrCreate()

schema = StructType([
    StructField("sale_date", StringType()),
    StructField("region", StringType()),
    StructField("amount", IntegerType()),
])

# ── 1. Write Initial Data ─────────────────────────────────────────
existing_data = [
    ("2024-01-15", "US", 1000),
    ("2024-01-15", "EU", 800),
    ("2024-02-10", "US", 1200),
    ("2024-02-10", "EU", 950),
    ("2024-03-05", "US", 1100),
]

output_path = "/tmp/dynamic_overwrite_demo"
existing_df = spark.createDataFrame(existing_data, schema)
existing_df.write.partitionBy("sale_date").mode("overwrite").parquet(output_path)

print("=== BEFORE Overwrite ===")
spark.read.parquet(output_path).orderBy("sale_date", "region").show()

# ── 2. Dynamic Overwrite (SAFE) ───────────────────────────────────
# Config is already set at SparkSession level, but can also be set here:
# spark.conf.set("spark.sql.sources.partitionOverwriteMode", "dynamic")

new_jan_data = [
    ("2024-01-15", "US", 1050),
    ("2024-01-15", "EU", 820),
]
new_df = spark.createDataFrame(new_jan_data, schema)

# With dynamic mode, ONLY the sale_date=2024-01-15 partition is overwritten
new_df.write.partitionBy("sale_date").mode("overwrite").parquet(output_path)

print("=== AFTER Dynamic Overwrite (Feb & Mar preserved!) ===")
spark.read.parquet(output_path).orderBy("sale_date", "region").show()
# +----------+------+------+
# | sale_date|region|amount|
# +----------+------+------+
# |2024-01-15|    EU|   820|  <- updated
# |2024-01-15|    US|  1050|  <- updated
# |2024-02-10|    EU|   950|  <- preserved
# |2024-02-10|    US|  1200|  <- preserved
# |2024-03-05|    US|  1100|  <- preserved
# +----------+------+------+

spark.stop()
```

---

## Approach 3: Dynamic Overwrite with Multiple Partition Columns

### Full Working Code

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("MultiColumnDynOverwrite") \
    .master("local[*]") \
    .config("spark.sql.sources.partitionOverwriteMode", "dynamic") \
    .getOrCreate()

# ── 1. Write with Two Partition Columns ────────────────────────────
data = [
    (1, "2024-01", "US", 100),
    (2, "2024-01", "EU", 200),
    (3, "2024-02", "US", 300),
    (4, "2024-02", "EU", 400),
    (5, "2024-03", "US", 500),
    (6, "2024-03", "EU", 600),
]
df = spark.createDataFrame(data, ["id", "month", "region", "amount"])

path = "/tmp/multi_partition_overwrite"
df.write.partitionBy("month", "region").mode("overwrite").parquet(path)

print("=== Original Data ===")
spark.read.parquet(path).orderBy("month", "region").show()

# ── 2. Overwrite Only month=2024-01/region=US ─────────────────────
correction = [(7, "2024-01", "US", 150)]  # corrected record
correction_df = spark.createDataFrame(correction, ["id", "month", "region", "amount"])

correction_df.write.partitionBy("month", "region").mode("overwrite").parquet(path)

print("=== After Dynamic Overwrite (only 2024-01/US changed) ===")
spark.read.parquet(path).orderBy("month", "region").show()
# +---+-------+------+------+
# | id|  month|region|amount|
# +---+-------+------+------+
# |  7|2024-01|    US|   150|  <- overwritten (was id=1, amount=100)
# |  2|2024-01|    EU|   200|  <- untouched
# |  3|2024-02|    US|   300|  <- untouched
# |  4|2024-02|    EU|   400|  <- untouched
# |  5|2024-03|    US|   500|  <- untouched
# |  6|2024-03|    EU|   600|  <- untouched
# +---+-------+------+------+

spark.stop()
```

---

## Approach 4: InsertInto with Hive Tables (Alternative)

### Full Working Code

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("InsertOverwrite") \
    .master("local[*]") \
    .config("spark.sql.sources.partitionOverwriteMode", "dynamic") \
    .config("spark.sql.warehouse.dir", "/tmp/spark-warehouse") \
    .enableHiveSupport() \
    .getOrCreate()

# ── 1. Create Hive Table ──────────────────────────────────────────
spark.sql("DROP TABLE IF EXISTS sales_table")
spark.sql("""
    CREATE TABLE sales_table (
        id INT,
        amount INT
    )
    PARTITIONED BY (sale_month STRING)
    STORED AS PARQUET
""")

# ── 2. Insert Initial Data ────────────────────────────────────────
spark.sql("""
    INSERT INTO sales_table PARTITION(sale_month='2024-01')
    VALUES (1, 100), (2, 200)
""")
spark.sql("""
    INSERT INTO sales_table PARTITION(sale_month='2024-02')
    VALUES (3, 300), (4, 400)
""")

print("=== Before ===")
spark.sql("SELECT * FROM sales_table ORDER BY sale_month, id").show()

# ── 3. INSERT OVERWRITE with Dynamic Partition ─────────────────────
# This only overwrites the partition present in the SELECT result
spark.sql("""
    INSERT OVERWRITE TABLE sales_table PARTITION(sale_month)
    SELECT 1 as id, 150 as amount, '2024-01' as sale_month
    UNION ALL
    SELECT 2 as id, 250 as amount, '2024-01' as sale_month
""")

print("=== After INSERT OVERWRITE (only 2024-01 changed) ===")
spark.sql("SELECT * FROM sales_table ORDER BY sale_month, id").show()
# +---+------+----------+
# | id|amount|sale_month|
# +---+------+----------+
# |  1|   150|   2024-01|  <- overwritten
# |  2|   250|   2024-01|  <- overwritten
# |  3|   300|   2024-02|  <- untouched
# |  4|   400|   2024-02|  <- untouched
# +---+------+----------+

# ── 4. DataFrame API equivalent ───────────────────────────────────
correction = spark.createDataFrame([(5, 350, "2024-02")], ["id", "amount", "sale_month"])
correction.write.mode("overwrite").insertInto("sales_table")
# With dynamic mode, only the 2024-02 partition is overwritten

print("=== After insertInto (only 2024-02 changed) ===")
spark.sql("SELECT * FROM sales_table ORDER BY sale_month, id").show()

spark.stop()
```

---

## Approach 5: Common ETL Pitfalls and Best Practices

### Full Working Code

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit

spark = SparkSession.builder \
    .appName("OverwritePitfalls") \
    .master("local[*]") \
    .config("spark.sql.sources.partitionOverwriteMode", "dynamic") \
    .getOrCreate()

# ── PITFALL 1: Forgetting to set dynamic mode ─────────────────────
# The default is "static". If you forget to configure it, you lose data.
# Always set it explicitly in your SparkSession builder or job config.
print("Current mode:", spark.conf.get("spark.sql.sources.partitionOverwriteMode"))

# ── PITFALL 2: Empty DataFrame overwrites to nothing ──────────────
path = "/tmp/pitfall_demo"
data = [(1, "A", 100), (2, "B", 200)]
spark.createDataFrame(data, ["id", "part", "val"]) \
    .write.partitionBy("part").mode("overwrite").parquet(path)

# If your transformation produces an empty DataFrame for partition "A",
# dynamic overwrite will delete partition "A" entirely!
empty_df = spark.createDataFrame([], "id INT, part STRING, val INT")
# This writes nothing but in static mode would delete everything.
# In dynamic mode, no partitions exist in the empty DF, so nothing changes.
# BUT if the DF has partition column values with 0 rows, behavior varies.

# Safe pattern: always check if DataFrame is empty before writing
df_to_write = empty_df  # simulated
if df_to_write.head(1):
    df_to_write.write.partitionBy("part").mode("overwrite").parquet(path)
else:
    print("WARNING: Empty DataFrame. Skipping write to prevent data loss.")

# ── PITFALL 3: Dynamic mode with non-partitioned writes ────────────
# Dynamic partition overwrite ONLY applies when using partitionBy().
# Without partitionBy(), mode("overwrite") always replaces everything.
# This catches people off guard!

# ── PITFALL 4: Column ordering with insertInto ────────────────────
# insertInto matches by POSITION, not by name! This is a common bug.
# If your DataFrame has columns in a different order than the table,
# data ends up in wrong columns silently.

# ── PITFALL 5: Mixed partition values in same batch ────────────────
# If your correction DataFrame accidentally includes rows for other
# partitions, those partitions get overwritten too.
# Always filter your DataFrame to only the target partitions:
target_month = "2024-01"
correction_df = spark.createDataFrame(
    [(1, "2024-01", 100), (2, "2024-01", 200), (3, "2024-02", 999)],
    ["id", "month", "amount"]
)

# BAD: writes both months, overwriting 2024-02 unintentionally
# correction_df.write.partitionBy("month").mode("overwrite").parquet(path)

# GOOD: filter to only the partition you intend to overwrite
safe_df = correction_df.filter(col("month") == target_month)
safe_df.write.partitionBy("month").mode("overwrite").parquet(path)

# ── BEST PRACTICE: Use Delta Lake REPLACE WHERE ───────────────────
# Delta Lake provides an even safer mechanism:
# df.write.format("delta") \
#     .option("replaceWhere", "sale_date >= '2024-01-01' AND sale_date < '2024-02-01'") \
#     .mode("overwrite") \
#     .save(delta_path)
#
# This explicitly declares which partitions will be overwritten.
# If the DataFrame contains data outside this range, it FAILS instead
# of silently overwriting other partitions. This is the safest approach.

spark.stop()
```

---

## Key Takeaways

| Concept | Detail |
|---|---|
| **Default mode** | `static` -- deletes ALL data, then writes. Dangerous for incremental ETL. |
| **Dynamic mode** | Only overwrites partitions present in the DataFrame. Set `spark.sql.sources.partitionOverwriteMode=dynamic`. |
| **Config scope** | Set at SparkSession level or per-write. Always set it explicitly. |
| **Delta replaceWhere** | Safest approach -- explicitly declares target partitions and fails if data violates the constraint. |
| **insertInto** | Matches columns by position, not name. Ensure column order matches the table. |
| **Empty DF trap** | An empty DataFrame in dynamic mode won't delete anything, but validate before writing. |

## Interview Tips

- This is a **very common interview question** for data engineering roles. Interviewers want to see that you understand the data loss risk.
- Always start by explaining the **default behavior** (static) and why it's dangerous, then present the dynamic alternative.
- Mention `replaceWhere` in Delta Lake as the production-grade solution -- it shows you think about safety.
- If asked "how would you backfill a specific partition?", the answer is dynamic partition overwrite or Delta MERGE/replaceWhere.
- Know that `insertInto` matches by position, not name -- this is a gotcha that shows real-world experience.
- In Databricks, the default has been changed to `dynamic` for Delta tables, but not for Parquet/other formats. Know your platform's defaults.
