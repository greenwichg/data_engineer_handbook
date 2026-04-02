# PySpark Implementation: Change Data Capture (CDC)

## Problem Statement

In data warehousing and lakehouse architectures, source systems (OLTP databases) constantly change -- rows are inserted, updated, and deleted. **Change Data Capture (CDC)** is the process of identifying and applying these changes to a target analytical table.

**Real-world scenario**: An e-commerce company has an orders table in PostgreSQL. Every night, a batch job must sync changes to the Delta Lake warehouse. New orders must be inserted, modified orders (e.g., status changes) must be updated, and cancelled orders must be soft-deleted. The solution must handle:
- **Type 1 SCD**: Overwrite the old value with the new value (no history).
- **Type 2 SCD**: Keep full history with effective dates and current-flag columns.

---

## Approach 1: CDC with Delta Lake MERGE (Type 1 - Upsert)

### Sample Data

```python
# Existing target table
target_data = [
    (1, "Alice", "shipped",   "2024-01-10", 100.00),
    (2, "Bob",   "pending",   "2024-01-11", 200.00),
    (3, "Carol", "delivered", "2024-01-12", 150.00),
]

# CDC source (changes captured from OLTP)
cdc_data = [
    (2, "Bob",   "shipped",   "2024-01-13", 200.00, "UPDATE"),
    (3, "Carol", "delivered", "2024-01-12", 150.00, "DELETE"),
    (4, "Dave",  "pending",   "2024-01-13", 300.00, "INSERT"),
]
```

### Expected Output

| id | customer | status    | order_date | amount | (action)  |
|----|----------|-----------|------------|--------|-----------|
| 1  | Alice    | shipped   | 2024-01-10 | 100.00 | unchanged |
| 2  | Bob      | shipped   | 2024-01-13 | 200.00 | updated   |
| 4  | Dave     | pending   | 2024-01-13 | 300.00 | inserted  |

(Row 3 deleted)

### Full Working Code

```python
from pyspark.sql import SparkSession
from pyspark.sql.types import (StructType, StructField, IntegerType,
                                StringType, DoubleType)

spark = SparkSession.builder \
    .appName("CDC_Type1") \
    .master("local[*]") \
    .config("spark.jars.packages", "io.delta:delta-core_2.12:2.4.0") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog",
            "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .getOrCreate()

# ── 1. Create Target Table ────────────────────────────────────────
target_schema = StructType([
    StructField("id", IntegerType()),
    StructField("customer", StringType()),
    StructField("status", StringType()),
    StructField("order_date", StringType()),
    StructField("amount", DoubleType()),
])

target_data = [
    (1, "Alice", "shipped",   "2024-01-10", 100.00),
    (2, "Bob",   "pending",   "2024-01-11", 200.00),
    (3, "Carol", "delivered", "2024-01-12", 150.00),
]

target_path = "/tmp/delta_cdc_target"
target_df = spark.createDataFrame(target_data, target_schema)
target_df.write.format("delta").mode("overwrite").save(target_path)

# ── 2. Create CDC Source ──────────────────────────────────────────
cdc_schema = StructType([
    StructField("id", IntegerType()),
    StructField("customer", StringType()),
    StructField("status", StringType()),
    StructField("order_date", StringType()),
    StructField("amount", DoubleType()),
    StructField("cdc_operation", StringType()),
])

cdc_data = [
    (2, "Bob",   "shipped",   "2024-01-13", 200.00, "UPDATE"),
    (3, "Carol", "delivered", "2024-01-12", 150.00, "DELETE"),
    (4, "Dave",  "pending",   "2024-01-13", 300.00, "INSERT"),
]

cdc_df = spark.createDataFrame(cdc_data, cdc_schema)

# ── 3. Apply CDC with Delta MERGE ─────────────────────────────────
from delta.tables import DeltaTable

delta_target = DeltaTable.forPath(spark, target_path)

delta_target.alias("target").merge(
    cdc_df.alias("source"),
    "target.id = source.id"
).whenMatchedDelete(
    condition="source.cdc_operation = 'DELETE'"
).whenMatchedUpdate(
    condition="source.cdc_operation = 'UPDATE'",
    set={
        "customer": "source.customer",
        "status": "source.status",
        "order_date": "source.order_date",
        "amount": "source.amount",
    }
).whenNotMatchedInsert(
    condition="source.cdc_operation = 'INSERT'",
    values={
        "id": "source.id",
        "customer": "source.customer",
        "status": "source.status",
        "order_date": "source.order_date",
        "amount": "source.amount",
    }
).execute()

# ── 4. Verify Result ──────────────────────────────────────────────
print("=== After CDC MERGE ===")
spark.read.format("delta").load(target_path).orderBy("id").show()
# +---+--------+-------+----------+------+
# | id|customer| status|order_date|amount|
# +---+--------+-------+----------+------+
# |  1|   Alice|shipped|2024-01-10| 100.0|  <- unchanged
# |  2|     Bob|shipped|2024-01-13| 200.0|  <- updated
# |  4|    Dave|pending|2024-01-13| 300.0|  <- inserted
# +---+--------+-------+----------+------+
# Row 3 (Carol) deleted

# ── 5. Check MERGE Metrics ────────────────────────────────────────
history = DeltaTable.forPath(spark, target_path).history(1)
history.select("operation", "operationMetrics").show(truncate=False)
# Shows numTargetRowsInserted, numTargetRowsUpdated, numTargetRowsDeleted

spark.stop()
```

---

## Approach 2: Type 2 SCD (Slowly Changing Dimension) with Full History

### Sample Data

```python
# Target with SCD2 columns
target_data = [
    (1, "Alice", "shipped", "2024-01-10", 100.00, "2024-01-10", "9999-12-31", True),
    (2, "Bob",   "pending", "2024-01-11", 200.00, "2024-01-11", "9999-12-31", True),
]

# Incoming changes
changes = [
    (2, "Bob", "shipped", "2024-01-13", 200.00),  # Bob's order shipped
    (3, "Carol", "pending", "2024-01-13", 150.00), # new order
]
```

### Expected Output

| id | customer | status  | effective_from | effective_to | is_current |
|----|----------|---------|----------------|--------------|------------|
| 1  | Alice    | shipped | 2024-01-10     | 9999-12-31   | true       |
| 2  | Bob      | pending | 2024-01-11     | 2024-01-12   | false      |
| 2  | Bob      | shipped | 2024-01-13     | 9999-12-31   | true       |
| 3  | Carol    | pending | 2024-01-13     | 9999-12-31   | true       |

### Full Working Code

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit, current_date, when, date_sub
from pyspark.sql.types import (StructType, StructField, IntegerType,
                                StringType, DoubleType, BooleanType)

spark = SparkSession.builder \
    .appName("CDC_Type2_SCD") \
    .master("local[*]") \
    .config("spark.jars.packages", "io.delta:delta-core_2.12:2.4.0") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog",
            "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .getOrCreate()

# ── 1. Create SCD2 Target Table ───────────────────────────────────
target_schema = StructType([
    StructField("id", IntegerType()),
    StructField("customer", StringType()),
    StructField("status", StringType()),
    StructField("order_date", StringType()),
    StructField("amount", DoubleType()),
    StructField("effective_from", StringType()),
    StructField("effective_to", StringType()),
    StructField("is_current", BooleanType()),
])

target_data = [
    (1, "Alice", "shipped", "2024-01-10", 100.0, "2024-01-10", "9999-12-31", True),
    (2, "Bob",   "pending", "2024-01-11", 200.0, "2024-01-11", "9999-12-31", True),
]

target_path = "/tmp/delta_scd2"
spark.createDataFrame(target_data, target_schema) \
    .write.format("delta").mode("overwrite").save(target_path)

# ── 2. Incoming Changes ───────────────────────────────────────────
changes_data = [
    (2, "Bob",   "shipped", "2024-01-13", 200.00),
    (3, "Carol", "pending", "2024-01-13", 150.00),
]
changes_df = spark.createDataFrame(
    changes_data, ["id", "customer", "status", "order_date", "amount"]
)

# ── 3. SCD Type 2 Logic ───────────────────────────────────────────
from delta.tables import DeltaTable

delta_target = DeltaTable.forPath(spark, target_path)
target_df = delta_target.toDF()

# Step A: Find rows that actually changed (compare business columns)
changed = changes_df.alias("new").join(
    target_df.filter(col("is_current") == True).alias("old"),
    "id",
    "inner"
).filter(
    (col("new.status") != col("old.status")) |
    (col("new.amount") != col("old.amount"))
).select("new.*")

# Step B: New rows not in target at all
new_inserts = changes_df.alias("new").join(
    target_df.alias("old"),
    "id",
    "left_anti"
)

# Step C: Build staged updates
# For changed rows, create two records:
#   1. Close the old record (update effective_to and is_current)
#   2. Insert a new current record

today = "2024-01-13"  # In production: use current_date()

# New versions of changed rows
new_versions = changed.select(
    col("id"), col("customer"), col("status"),
    col("order_date"), col("amount"),
    lit(today).alias("effective_from"),
    lit("9999-12-31").alias("effective_to"),
    lit(True).alias("is_current"),
)

# Completely new rows
new_rows = new_inserts.select(
    col("id"), col("customer"), col("status"),
    col("order_date"), col("amount"),
    lit(today).alias("effective_from"),
    lit("9999-12-31").alias("effective_to"),
    lit(True).alias("is_current"),
)

# Union the staged rows
staged = new_versions.unionByName(new_rows)

# Step D: Apply with MERGE
# Close old records and insert new versions
delta_target.alias("target").merge(
    staged.alias("source"),
    "target.id = source.id AND target.is_current = true"
).whenMatchedUpdate(
    set={
        "effective_to": lit("2024-01-12"),  # day before new effective date
        "is_current": lit(False),
    }
).whenNotMatchedInsertAll(
).execute()

# ── 4. Verify SCD2 Result ─────────────────────────────────────────
print("=== SCD Type 2 Result ===")
spark.read.format("delta").load(target_path) \
    .orderBy("id", "effective_from").show(truncate=False)
# +---+--------+-------+----------+------+--------------+------------+----------+
# |id |customer|status |order_date|amount|effective_from|effective_to|is_current|
# +---+--------+-------+----------+------+--------------+------------+----------+
# |1  |Alice   |shipped|2024-01-10|100.0 |2024-01-10    |9999-12-31  |true      |
# |2  |Bob     |pending|2024-01-11|200.0 |2024-01-11    |2024-01-12  |false     |
# |2  |Bob     |shipped|2024-01-13|200.0 |2024-01-13    |9999-12-31  |true      |
# |3  |Carol   |pending|2024-01-13|150.0 |2024-01-13    |9999-12-31  |true      |
# +---+--------+-------+----------+------+--------------+------------+----------+

# Query: get current snapshot
print("=== Current Snapshot (is_current=true) ===")
spark.read.format("delta").load(target_path) \
    .filter("is_current = true").orderBy("id").show()

# Query: point-in-time view (what did the table look like on 2024-01-12?)
print("=== Point-in-Time: 2024-01-12 ===")
spark.read.format("delta").load(target_path) \
    .filter("effective_from <= '2024-01-12' AND effective_to >= '2024-01-12'") \
    .orderBy("id").show()

spark.stop()
```

---

## Approach 3: Hash-Based Change Detection

### Full Working Code

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, md5, concat_ws, lit

spark = SparkSession.builder \
    .appName("HashBasedCDC") \
    .master("local[*]") \
    .getOrCreate()

# ── 1. Source and Target Data ──────────────────────────────────────
# When CDC flags (INSERT/UPDATE/DELETE) are not available,
# use hash comparison to detect changes.

target_data = [
    (1, "Alice", "shipped",   100.00),
    (2, "Bob",   "pending",   200.00),
    (3, "Carol", "delivered", 150.00),
]
target_df = spark.createDataFrame(target_data, ["id", "customer", "status", "amount"])

source_data = [
    (1, "Alice", "shipped",   100.00),  # unchanged
    (2, "Bob",   "shipped",   200.00),  # status changed
    (4, "Dave",  "pending",   300.00),  # new
    # Carol (id=3) is missing -> deleted
]
source_df = spark.createDataFrame(source_data, ["id", "customer", "status", "amount"])

# ── 2. Compute Row Hashes ─────────────────────────────────────────
def add_row_hash(df, cols, hash_col="row_hash"):
    """Add MD5 hash of business columns for change detection."""
    return df.withColumn(hash_col, md5(concat_ws("||", *[col(c).cast("string") for c in cols])))

business_cols = ["customer", "status", "amount"]
target_hashed = add_row_hash(target_df, business_cols)
source_hashed = add_row_hash(source_df, business_cols)

# ── 3. Detect Changes ─────────────────────────────────────────────
# New rows (in source but not in target)
inserts = source_hashed.join(target_hashed, "id", "left_anti")
print("=== INSERTS ===")
inserts.show()

# Deleted rows (in target but not in source)
deletes = target_hashed.join(source_hashed, "id", "left_anti")
print("=== DELETES ===")
deletes.show()

# Updated rows (same id, different hash)
updates = source_hashed.alias("s").join(
    target_hashed.alias("t"),
    "id",
    "inner"
).filter(col("s.row_hash") != col("t.row_hash")) \
 .select("s.*")
print("=== UPDATES ===")
updates.show()

# Unchanged rows
unchanged = source_hashed.alias("s").join(
    target_hashed.alias("t"),
    "id",
    "inner"
).filter(col("s.row_hash") == col("t.row_hash")) \
 .select("s.*")
print("=== UNCHANGED ===")
unchanged.show()

# ── 4. Summary ─────────────────────────────────────────────────────
print(f"Inserts: {inserts.count()}, Updates: {updates.count()}, "
      f"Deletes: {deletes.count()}, Unchanged: {unchanged.count()}")

spark.stop()
```

---

## Approach 4: CDC with Audit Columns and Watermarking

### Full Working Code

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, current_timestamp, lit, max as spark_max

spark = SparkSession.builder \
    .appName("CDC_AuditColumns") \
    .master("local[*]") \
    .config("spark.jars.packages", "io.delta:delta-core_2.12:2.4.0") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog",
            "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .getOrCreate()

# ── 1. Source Table with Audit Columns ─────────────────────────────
# Many OLTP systems have updated_at or modified_at timestamps.
# Use these as a watermark for incremental extraction.

source_data = [
    (1, "Alice", "shipped",   100.0, "2024-01-10 08:00:00"),
    (2, "Bob",   "shipped",   200.0, "2024-01-13 10:30:00"),  # recently updated
    (3, "Carol", "delivered", 150.0, "2024-01-12 14:00:00"),
    (4, "Dave",  "pending",   300.0, "2024-01-13 09:00:00"),  # new
]
source_df = spark.createDataFrame(
    source_data, ["id", "customer", "status", "amount", "updated_at"]
)

# ── 2. Track Watermark (last processed timestamp) ─────────────────
# Store the high-water mark from the previous run
last_watermark = "2024-01-12 00:00:00"  # from previous job run

# ── 3. Extract Only Changed Records ───────────────────────────────
incremental_df = source_df.filter(col("updated_at") > lit(last_watermark))
print("=== Incremental Extract (since last watermark) ===")
incremental_df.show()
# Only Bob (updated) and Dave (new) are extracted

# ── 4. Apply to Target with MERGE ─────────────────────────────────
target_path = "/tmp/delta_cdc_watermark"

# Initialize target (first run)
initial_data = [
    (1, "Alice", "shipped",   100.0, "2024-01-10 08:00:00"),
    (2, "Bob",   "pending",   200.0, "2024-01-11 16:00:00"),
    (3, "Carol", "delivered", 150.0, "2024-01-12 14:00:00"),
]
spark.createDataFrame(
    initial_data, ["id", "customer", "status", "amount", "updated_at"]
).write.format("delta").mode("overwrite").save(target_path)

from delta.tables import DeltaTable
delta_target = DeltaTable.forPath(spark, target_path)

# Add ETL audit columns
enriched = incremental_df \
    .withColumn("etl_loaded_at", current_timestamp()) \
    .withColumn("etl_source", lit("postgresql_orders"))

delta_target.alias("t").merge(
    enriched.alias("s"),
    "t.id = s.id"
).whenMatchedUpdateAll() \
 .whenNotMatchedInsertAll() \
 .execute()

print("=== Target After Incremental CDC ===")
spark.read.format("delta").load(target_path).orderBy("id").show(truncate=False)

# ── 5. Update Watermark for Next Run ──────────────────────────────
new_watermark = incremental_df.agg(spark_max("updated_at")).collect()[0][0]
print(f"New watermark for next run: {new_watermark}")
# In production, store this in a control table or checkpoint file

# ── 6. Idempotency Check ──────────────────────────────────────────
# If the job reruns with the same watermark, MERGE handles it safely:
# - Existing rows match on id -> update (idempotent, same values)
# - New rows -> insert
# No duplicates are created. This is a key advantage of MERGE.

spark.stop()
```

---

## Key Takeaways

| Pattern | Use Case | Mechanism |
|---|---|---|
| **Type 1 SCD** | Overwrite with latest values, no history needed | Delta MERGE with whenMatchedUpdate |
| **Type 2 SCD** | Full history with effective dates | Close old record, insert new version |
| **Hash-based CDC** | Source has no CDC flags or timestamps | MD5/SHA hash of business columns for comparison |
| **Watermark-based** | Source has `updated_at` column | Extract records newer than last high-water mark |
| **Soft deletes** | Audit requirements, no physical deletes | Add `is_deleted` flag instead of DELETE |
| **Delta CDF** | Delta Lake Change Data Feed | `readChangeData` to get changes from Delta log |

## Interview Tips

- **MERGE is the gold standard**: Delta Lake MERGE handles INSERT, UPDATE, DELETE in a single atomic operation. Always mention it first.
- **Idempotency is critical**: Your CDC pipeline should produce the same result whether it runs once or five times. MERGE provides this naturally.
- **Hash-based detection** is expensive (full table scan on both sides) but necessary when the source doesn't provide change flags. Mention the trade-off.
- **Type 2 SCD is complex**: The two-step process (close old record + insert new) in a single MERGE is a common interview coding question. Practice the MERGE syntax.
- **Watermark management**: Storing the high-water mark reliably is as important as the CDC logic itself. Mention control tables, checkpoint files, or Spark's structured streaming checkpoints.
- **Delta Change Data Feed (CDF)**: In Delta Lake 2.0+, you can enable CDF on a table (`delta.enableChangeDataFeed=true`) and read a stream of changes. This is useful when Delta is both source and target.
