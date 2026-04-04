# PySpark Implementation: Data Lake vs Data Lakehouse

## Problem Statement

Understanding the evolution from **data lakes** to **data lakehouses** is a fundamental architecture question in data engineering interviews. A data lake stores raw data cheaply but lacks reliability; a lakehouse adds **ACID transactions, schema enforcement, and time travel** on top of a data lake using technologies like **Delta Lake**.

---

## Data Lake: Traditional Approach

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, current_timestamp

spark = SparkSession.builder.appName("DataLakeVsLakehouse").getOrCreate()

# Sample data
data = [
    (1, "Alice", "Engineering", 95000, "2024-01-01"),
    (2, "Bob", "Sales", 82000, "2024-01-01"),
    (3, "Charlie", "HR", 72000, "2024-01-02"),
]
df = spark.createDataFrame(data, ["id", "name", "dept", "salary", "date"])
```

### Data Lake Write (Parquet)

```python
# Simple write — no ACID, no schema enforcement
df.write.mode("overwrite").partitionBy("date").parquet("/datalake/employees")

# Problems with pure data lake:
# 1. No ACID — partial writes can corrupt data
# 2. No schema enforcement — bad data can sneak in
# 3. No updates/deletes — can only append or overwrite entire partitions
# 4. No time travel — once overwritten, old data is gone
# 5. Small file problem — streaming creates many tiny files
# 6. No audit trail — no history of changes
```

### Data Lake Read

```python
employees = spark.read.parquet("/datalake/employees")
employees.show()
# Works fine for reads, but what if a write failed halfway?
# You might read partial/corrupted data
```

---

## Data Lakehouse: Delta Lake Approach

```python
# Write as Delta — gets ACID, schema enforcement, time travel
df.write.format("delta").mode("overwrite").partitionBy("date") \
    .save("/lakehouse/employees")
```

### Advantage 1: ACID Transactions

```python
from delta.tables import DeltaTable

# Concurrent reads and writes are safe — ACID guarantees
# Failed writes are automatically rolled back (atomic)

# MERGE (upsert) — impossible in plain data lake
delta_table = DeltaTable.forPath(spark, "/lakehouse/employees")

new_data = spark.createDataFrame([
    (2, "Bob", "Sales", 90000, "2024-01-03"),    # Update salary
    (4, "Diana", "Engineering", 88000, "2024-01-03"),  # New employee
], ["id", "name", "dept", "salary", "date"])

delta_table.alias("target").merge(
    new_data.alias("source"),
    "target.id = source.id"
).whenMatchedUpdateAll() \
 .whenNotMatchedInsertAll() \
 .execute()
```

### Advantage 2: Schema Enforcement & Evolution

```python
# Schema enforcement — rejects data that doesn't match schema
bad_data = spark.createDataFrame([
    (5, "Eve", "Marketing", "not_a_number", "2024-01-03"),  # salary is string
], ["id", "name", "dept", "salary", "date"])

# This would FAIL with Delta (schema mismatch) — protects data quality
# bad_data.write.format("delta").mode("append").save("/lakehouse/employees")

# Schema evolution — safely add new columns
spark.conf.set("spark.databricks.delta.schema.autoMerge.enabled", "true")
evolved_data = spark.createDataFrame([
    (5, "Eve", "Marketing", 78000, "2024-01-03", "Senior"),
], ["id", "name", "dept", "salary", "date", "level"])

evolved_data.write.format("delta").mode("append") \
    .option("mergeSchema", "true") \
    .save("/lakehouse/employees")
```

### Advantage 3: Time Travel

```python
# Read previous versions — impossible in plain data lake
df_v0 = spark.read.format("delta").option("versionAsOf", 0) \
    .load("/lakehouse/employees")

# Read by timestamp
df_yesterday = spark.read.format("delta") \
    .option("timestampAsOf", "2024-01-01") \
    .load("/lakehouse/employees")

# View all versions
spark.sql("DESCRIBE HISTORY delta.`/lakehouse/employees`").show()

# Restore to previous version (undo mistakes)
delta_table.restoreToVersion(0)
```

### Advantage 4: UPDATE and DELETE

```python
# UPDATE — not possible in plain Parquet data lake
delta_table.update(
    condition=col("name") == "Alice",
    set={"salary": lit(100000)}
)

# DELETE — not possible in plain Parquet data lake
delta_table.delete(condition=col("dept") == "HR")
```

### Advantage 5: Table Maintenance

```python
# OPTIMIZE — compact small files
spark.sql("OPTIMIZE delta.`/lakehouse/employees` ZORDER BY (dept)")

# VACUUM — remove old files
spark.sql("VACUUM delta.`/lakehouse/employees` RETAIN 168 HOURS")
```

---

## Architecture Comparison

```
┌──────────────────────────────────────────────────────┐
│                    DATA LAKE                          │
│                                                      │
│  Storage: S3/ADLS/GCS (cheap object storage)         │
│  Format:  Parquet/ORC/CSV/JSON                       │
│  Engine:  Spark, Presto, Hive                        │
│                                                      │
│  ✓ Cheap storage    ✓ Schema-on-read                 │
│  ✗ No ACID          ✗ No updates/deletes             │
│  ✗ Data corruption  ✗ No time travel                 │
│  ✗ No enforcement   ✗ Small file problem             │
└──────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────┐
│                  DATA LAKEHOUSE                       │
│                                                      │
│  Storage: Same S3/ADLS/GCS (still cheap)             │
│  Format:  Delta Lake / Apache Iceberg / Apache Hudi  │
│  Engine:  Spark, Presto, Trino, Flink                │
│                                                      │
│  ✓ ACID transactions   ✓ Schema enforcement          │
│  ✓ Time travel         ✓ UPDATE/DELETE/MERGE         │
│  ✓ Audit history       ✓ File compaction             │
│  ✓ Streaming + Batch   ✓ Data versioning             │
└──────────────────────────────────────────────────────┘
```

---

## Key Takeaways

| Feature | Data Lake (Parquet) | Lakehouse (Delta Lake) |
|---------|-------------------|----------------------|
| ACID transactions | No | Yes |
| Schema enforcement | No (schema-on-read) | Yes (schema-on-write) |
| UPDATE/DELETE | No (overwrite only) | Yes |
| MERGE (upsert) | No | Yes |
| Time travel | No | Yes |
| Audit history | No | Yes (DESCRIBE HISTORY) |
| File compaction | Manual | OPTIMIZE command |
| Streaming support | Append only | Full CRUD |
| Cost | Low (object storage) | Same low storage cost |

## Interview Tips

1. **Lakehouse = Data Lake + Data Warehouse reliability** — best of both worlds
2. **Delta Lake, Iceberg, Hudi** are the three main lakehouse formats — know the differences
3. **Key selling point**: ACID on cheap object storage (no need for expensive data warehouse)
4. **Medallion architecture** (Bronze → Silver → Gold) is the standard lakehouse pattern
5. **Schema enforcement prevents bad data** from entering the lake — huge improvement over raw data lakes
6. **Time travel** enables easy debugging, auditing, and rollbacks
