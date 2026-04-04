# PySpark Implementation: End-to-End Medallion Architecture Pipeline

## Problem Statement

Build a complete **Bronze -> Silver -> Gold** medallion pipeline for an e-commerce dataset using Delta Lake. Each layer has a distinct responsibility:

1. **Bronze (Raw):** Ingest raw JSON order data using Auto Loader. Append metadata columns (source file path, ingestion timestamp). No transformations -- store data exactly as received.
2. **Silver (Cleaned):** Read from Bronze, cast to correct types, drop nulls and duplicates, enforce schema, apply data quality checks. Merge into a clean Silver Delta table.
3. **Gold (Business-Ready):** Aggregate Silver data into purpose-built tables -- `daily_revenue` and `customer_lifetime_value`. Use Delta MERGE for idempotent writes so the pipeline can be safely re-run.

Use Delta Lake at every layer with proper MERGE/upsert logic, schema enforcement, and metadata tracking.

### Sample Data

**Raw JSON orders (messy -- nulls, duplicates, bad types):**

```json
{"order_id": "1001", "customer_id": "C100", "product": "Laptop",    "amount": "999.99",  "quantity": "1", "order_date": "2024-03-01", "region": "US-East"}
{"order_id": "1002", "customer_id": "C101", "product": "Mouse",     "amount": "29.99",   "quantity": "2", "order_date": "2024-03-01", "region": "US-West"}
{"order_id": "1001", "customer_id": "C100", "product": "Laptop",    "amount": "999.99",  "quantity": "1", "order_date": "2024-03-01", "region": "US-East"}
{"order_id": "1003", "customer_id": null,   "product": "Keyboard",  "amount": "bad_val", "quantity": "1", "order_date": "2024-03-02", "region": null}
{"order_id": "1004", "customer_id": "C102", "product": "Monitor",   "amount": "349.50",  "quantity": "1", "order_date": "2024-03-02", "region": "US-East"}
{"order_id": null,   "customer_id": "C103", "product": "Headphones","amount": "79.00",   "quantity": "3", "order_date": "2024-03-02", "region": "EU-West"}
{"order_id": "1005", "customer_id": "C100", "product": "Charger",   "amount": "19.99",   "quantity": "2", "order_date": "2024-03-03", "region": "US-East"}
```

**Issues in the raw data:**
- Row 3 is a duplicate of row 1
- Row 4 has `null` customer_id, non-numeric amount (`"bad_val"`), and `null` region
- Row 6 has `null` order_id
- All numeric fields arrive as strings

### Expected Silver Output (after cleaning)

| order_id | customer_id | product   | amount | quantity | order_date | region  |
|----------|-------------|-----------|--------|----------|------------|---------|
| 1001     | C100        | Laptop    | 999.99 | 1        | 2024-03-01 | US-East |
| 1002     | C101        | Mouse     | 29.99  | 2        | 2024-03-01 | US-West |
| 1004     | C102        | Monitor   | 349.50 | 1        | 2024-03-02 | US-East |
| 1005     | C100        | Charger   | 19.99  | 2        | 2024-03-03 | US-East |

### Expected Gold Output

**daily_revenue:**

| order_date | region  | total_revenue | total_orders | total_units |
|------------|---------|---------------|--------------|-------------|
| 2024-03-01 | US-East | 999.99        | 1            | 1           |
| 2024-03-01 | US-West | 29.99         | 1            | 2           |
| 2024-03-02 | US-East | 349.50        | 1            | 1           |
| 2024-03-03 | US-East | 19.99         | 1            | 2           |

**customer_lifetime_value:**

| customer_id | total_spent | total_orders | avg_order_value | first_order | last_order |
|-------------|-------------|--------------|-----------------|-------------|------------|
| C100        | 1019.98     | 2            | 509.99          | 2024-03-01  | 2024-03-03 |
| C101        | 29.99       | 1            | 29.99           | 2024-03-01  | 2024-03-01 |
| C102        | 349.50      | 1            | 349.50          | 2024-03-02  | 2024-03-02 |

---

## Method 1: Bronze Layer -- Auto Loader Ingestion

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, lit, current_timestamp, input_file_name,
    to_date, sum as _sum, count, avg, min as _min, max as _max,
    when, round as _round
)
from pyspark.sql.types import (
    StructType, StructField, StringType, DoubleType, IntegerType, DateType
)
from delta.tables import DeltaTable

spark = SparkSession.builder \
    .appName("MedallionPipeline") \
    .config("spark.jars.packages", "io.delta:delta-spark_2.12:3.1.0") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog",
            "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .getOrCreate()

# === BRONZE LAYER ===
# Auto Loader (Databricks) -- cloudFiles reads new JSON files incrementally
# In production this runs as a Structured Streaming job

bronze_path = "/mnt/data/bronze/orders"
raw_json_path = "/mnt/landing/orders/"

# Auto Loader with cloudFiles format
bronze_stream = (
    spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "json")
    .option("cloudFiles.inferColumnTypes", "false")    # Keep everything as strings
    .option("cloudFiles.schemaLocation", "/mnt/checkpoints/bronze/orders/schema")
    .option("cloudFiles.schemaEvolutionMode", "addNewColumns")  # Handle new fields
    .load(raw_json_path)
    # Add metadata columns
    .withColumn("_source_file", input_file_name())
    .withColumn("_ingestion_timestamp", current_timestamp())
    .withColumn("_batch_id", lit("batch_2024_03"))
)

# Write to Bronze Delta table -- append-only, no transformations
(
    bronze_stream.writeStream
    .format("delta")
    .outputMode("append")
    .option("checkpointLocation", "/mnt/checkpoints/bronze/orders")
    .option("mergeSchema", "true")         # Allow new columns from schema evolution
    .trigger(availableNow=True)            # Process all available files, then stop
    .toTable("catalog.bronze.orders")
)
```

### Step-by-Step Explanation

**Auto Loader (`cloudFiles`) handles:**
- **File discovery:** Automatically tracks which files have been processed using a checkpoint directory. New files landing in the source path are picked up on the next trigger.
- **Schema inference:** Infers the JSON schema from the first batch. Subsequent batches evolve the schema if new columns appear.
- **`_rescued_data` column:** When `cloudFiles.rescuedDataColumn` is set, any fields that do not match the inferred schema are captured in a `_rescued_data` JSON string column instead of being silently dropped.

```python
# Enable rescued data column to capture schema mismatches
bronze_stream_with_rescue = (
    spark.readStream
    .format("cloudFiles")
    .option("cloudFiles.format", "json")
    .option("cloudFiles.rescuedDataColumn", "_rescued_data")
    .option("cloudFiles.schemaLocation", "/mnt/checkpoints/bronze/orders/schema")
    .load(raw_json_path)
    .withColumn("_source_file", input_file_name())
    .withColumn("_ingestion_timestamp", current_timestamp())
)
```

**Why append-only at Bronze?**
- Bronze is the raw audit layer. Never update or delete. Every record that arrives is preserved exactly as-is for lineage and reprocessing.

---

## Method 2: Silver Layer -- Clean, Validate, Deduplicate, Merge

```python
# === SILVER LAYER ===

# Define the clean schema we expect
silver_schema = StructType([
    StructField("order_id", StringType()),
    StructField("customer_id", StringType()),
    StructField("product", StringType()),
    StructField("amount", DoubleType()),
    StructField("quantity", IntegerType()),
    StructField("order_date", DateType()),
    StructField("region", StringType()),
])

# Read from Bronze
bronze_df = spark.read.format("delta").table("catalog.bronze.orders")

# Step 1: Cast types (strings -> proper types)
typed_df = (
    bronze_df
    .withColumn("amount", col("amount").cast(DoubleType()))
    .withColumn("quantity", col("quantity").cast(IntegerType()))
    .withColumn("order_date", to_date(col("order_date"), "yyyy-MM-dd"))
)

# Step 2: Separate good records from quarantined records
# Records with cast failures get NULL in the cast column
quarantine_condition = (
    col("order_id").isNull() |
    col("customer_id").isNull() |
    col("amount").isNull() |          # Catches "bad_val" -> NULL after cast
    col("quantity").isNull() |
    col("order_date").isNull()
)

quarantined_df = typed_df.filter(quarantine_condition)
clean_df = typed_df.filter(~quarantine_condition)

# Write quarantined records for investigation
quarantined_df.write.format("delta").mode("append").save(
    "/mnt/data/silver/orders_quarantine"
)

# Step 3: Deduplicate -- keep the latest ingestion per order_id
from pyspark.sql.window import Window

dedup_window = Window.partitionBy("order_id").orderBy(col("_ingestion_timestamp").desc())

deduped_df = (
    clean_df
    .withColumn("_row_num", row_number().over(dedup_window))
    .filter(col("_row_num") == 1)
    .drop("_row_num")
)

# Step 4: Select final Silver columns (drop Bronze metadata)
silver_df = deduped_df.select(
    "order_id", "customer_id", "product",
    "amount", "quantity", "order_date", "region"
)

# Step 5: Quality checks -- log metrics before writing
total_bronze = bronze_df.count()
total_quarantined = quarantined_df.count()
total_dupes = clean_df.count() - deduped_df.count()
total_silver = silver_df.count()

quality_metrics = {
    "bronze_count": total_bronze,
    "quarantined_count": total_quarantined,
    "duplicate_count": total_dupes,
    "silver_count": total_silver,
    "pass_rate": round(total_silver / total_bronze * 100, 2) if total_bronze > 0 else 0
}
print(f"Quality Metrics: {quality_metrics}")

# Step 6: MERGE into Silver Delta table (idempotent upsert)
silver_path = "/mnt/data/silver/orders"

# First run: create the table
if not DeltaTable.isDeltaTable(spark, silver_path):
    silver_df.write.format("delta").mode("overwrite").save(silver_path)
else:
    silver_table = DeltaTable.forPath(spark, silver_path)

    silver_table.alias("tgt").merge(
        silver_df.alias("src"),
        "tgt.order_id = src.order_id"
    ).whenMatchedUpdate(
        condition="""
            tgt.customer_id != src.customer_id OR
            tgt.product != src.product OR
            tgt.amount != src.amount OR
            tgt.quantity != src.quantity OR
            tgt.order_date != src.order_date OR
            tgt.region != src.region
        """,
        set={
            "customer_id": "src.customer_id",
            "product": "src.product",
            "amount": "src.amount",
            "quantity": "src.quantity",
            "order_date": "src.order_date",
            "region": "src.region"
        }
    ).whenNotMatchedInsertAll(
    ).execute()

silver_table.toDF().orderBy("order_id").show(truncate=False)
```

### Step-by-Step Explanation

**After Step 1 -- Type casting:**

| order_id | customer_id | product   | amount | quantity | order_date |
|----------|-------------|-----------|--------|----------|------------|
| 1001     | C100        | Laptop    | 999.99 | 1        | 2024-03-01 |
| 1003     | null        | Keyboard  | null   | 1        | 2024-03-02 |

`"bad_val"` becomes `null` after `.cast(DoubleType())`. This makes null-check filtering reliable.

**After Step 2 -- Quarantine:**

Rows with `order_id=null`, `customer_id=null`, or `amount=null` (from bad casts) are routed to a quarantine table. In production, alert on quarantine table growth.

**After Step 3 -- Deduplication:**

The duplicate `order_id=1001` row is removed. `row_number()` partitioned by `order_id` and ordered by `_ingestion_timestamp DESC` keeps the most recently ingested version.

**After Step 6 -- MERGE:**

The conditional `whenMatchedUpdate` avoids rewriting rows when nothing has changed. This reduces write amplification on Delta tables with large existing data.

### Schema Enforcement vs Schema Evolution

```python
# Schema enforcement: reject writes with wrong schema (default Delta behavior)
# This FAILS if silver_df has extra or mistyped columns
silver_df.write.format("delta").mode("append").save(silver_path)

# Schema evolution: allow new columns to be added automatically
silver_df.write.format("delta") \
    .mode("append") \
    .option("mergeSchema", "true") \
    .save(silver_path)

# In production: enforce at Silver, evolve at Bronze
# Bronze accepts anything (raw). Silver has a strict contract.
```

---

## Method 3: Gold Layer -- Business Aggregations with Idempotent Merge

```python
# === GOLD LAYER ===

# Read clean data from Silver
silver_df = spark.read.format("delta").load(silver_path)

# ---------- Gold Table 1: daily_revenue ----------

daily_revenue_df = (
    silver_df
    .groupBy("order_date", "region")
    .agg(
        _round(_sum(col("amount") * col("quantity")), 2).alias("total_revenue"),
        count("order_id").alias("total_orders"),
        _sum("quantity").alias("total_units")
    )
)

daily_revenue_path = "/mnt/data/gold/daily_revenue"

if not DeltaTable.isDeltaTable(spark, daily_revenue_path):
    daily_revenue_df.write.format("delta").mode("overwrite").save(daily_revenue_path)
else:
    gold_daily = DeltaTable.forPath(spark, daily_revenue_path)

    # MERGE on composite key (order_date + region)
    # Fully replace the aggregate for that date-region when data refreshes
    gold_daily.alias("tgt").merge(
        daily_revenue_df.alias("src"),
        "tgt.order_date = src.order_date AND tgt.region = src.region"
    ).whenMatchedUpdate(
        set={
            "total_revenue": "src.total_revenue",
            "total_orders": "src.total_orders",
            "total_units": "src.total_units"
        }
    ).whenNotMatchedInsertAll(
    ).execute()

daily_revenue_df.orderBy("order_date", "region").show(truncate=False)

# ---------- Gold Table 2: customer_lifetime_value ----------

clv_df = (
    silver_df
    .groupBy("customer_id")
    .agg(
        _round(_sum(col("amount") * col("quantity")), 2).alias("total_spent"),
        count("order_id").alias("total_orders"),
        _round(avg(col("amount") * col("quantity")), 2).alias("avg_order_value"),
        _min("order_date").alias("first_order"),
        _max("order_date").alias("last_order")
    )
)

clv_path = "/mnt/data/gold/customer_lifetime_value"

if not DeltaTable.isDeltaTable(spark, clv_path):
    clv_df.write.format("delta").mode("overwrite").save(clv_path)
else:
    gold_clv = DeltaTable.forPath(spark, clv_path)

    # MERGE on customer_id -- re-aggregate replaces prior metrics
    gold_clv.alias("tgt").merge(
        clv_df.alias("src"),
        "tgt.customer_id = src.customer_id"
    ).whenMatchedUpdate(
        set={
            "total_spent": "src.total_spent",
            "total_orders": "src.total_orders",
            "avg_order_value": "src.avg_order_value",
            "first_order": "src.first_order",
            "last_order": "src.last_order"
        }
    ).whenNotMatchedInsertAll(
    ).execute()

clv_df.orderBy("customer_id").show(truncate=False)
```

### Step-by-Step Explanation

**Why MERGE at the Gold layer instead of overwrite?**

- **Idempotency:** Re-running the pipeline with the same Silver data produces the same Gold output. MERGE matches on the natural key and updates in place.
- **Partial refresh:** If only one day of Silver data is reprocessed, only that day's Gold rows are updated. Other days remain untouched.
- **Concurrent reads:** Downstream dashboards can read Gold tables while the MERGE is in progress -- Delta's ACID guarantees ensure they see a consistent snapshot.

### Change Data Feed (CDF) Between Layers

```python
# Enable CDF on the Silver table to track row-level changes
spark.sql("""
    ALTER TABLE delta.`/mnt/data/silver/orders`
    SET TBLPROPERTIES (delta.enableChangeDataFeed = true)
""")

# Read only the changes since the last Gold refresh
# _change_type: insert, update_preimage, update_postimage, delete
changes_df = (
    spark.read.format("delta")
    .option("readChangeFeed", "true")
    .option("startingVersion", 3)          # From version 3 onward
    .load(silver_path)
)

changes_df.show(truncate=False)

# Use table_changes() in SQL
spark.sql("""
    SELECT * FROM table_changes('catalog.silver.orders', 3)
    WHERE _change_type IN ('insert', 'update_postimage')
""").show(truncate=False)

# Feed only changed rows into Gold aggregations for efficiency
changed_silver = changes_df.filter(
    col("_change_type").isin("insert", "update_postimage")
).drop("_change_type", "_commit_version", "_commit_timestamp")
```

CDF avoids re-reading the entire Silver table on each Gold refresh. Only rows that changed since the last run are processed.

---

## Method 4: Orchestration -- Chaining Layers

```python
# === ORCHESTRATION ===

# Option A: Simple sequential execution (notebooks / scripts)

def run_bronze():
    """Ingest raw data to Bronze."""
    raw_df = (
        spark.readStream
        .format("cloudFiles")
        .option("cloudFiles.format", "json")
        .option("cloudFiles.schemaLocation", "/mnt/checkpoints/bronze/orders/schema")
        .load("/mnt/landing/orders/")
        .withColumn("_source_file", input_file_name())
        .withColumn("_ingestion_timestamp", current_timestamp())
    )
    (
        raw_df.writeStream
        .format("delta")
        .outputMode("append")
        .option("checkpointLocation", "/mnt/checkpoints/bronze/orders")
        .trigger(availableNow=True)
        .toTable("catalog.bronze.orders")
    )
    print("Bronze complete.")

def run_silver():
    """Clean and merge into Silver."""
    bronze_df = spark.read.format("delta").table("catalog.bronze.orders")

    typed_df = (
        bronze_df
        .withColumn("amount", col("amount").cast(DoubleType()))
        .withColumn("quantity", col("quantity").cast(IntegerType()))
        .withColumn("order_date", to_date(col("order_date"), "yyyy-MM-dd"))
    )

    clean_df = typed_df.filter(
        col("order_id").isNotNull() &
        col("customer_id").isNotNull() &
        col("amount").isNotNull()
    )

    dedup_window = Window.partitionBy("order_id").orderBy(
        col("_ingestion_timestamp").desc()
    )
    silver_df = (
        clean_df
        .withColumn("_rn", row_number().over(dedup_window))
        .filter(col("_rn") == 1)
        .drop("_rn", "_source_file", "_ingestion_timestamp", "_batch_id")
    )

    silver_path = "/mnt/data/silver/orders"
    if not DeltaTable.isDeltaTable(spark, silver_path):
        silver_df.write.format("delta").mode("overwrite").save(silver_path)
    else:
        DeltaTable.forPath(spark, silver_path).alias("tgt").merge(
            silver_df.alias("src"), "tgt.order_id = src.order_id"
        ).whenMatchedUpdateAll().whenNotMatchedInsertAll().execute()

    print("Silver complete.")

def run_gold():
    """Aggregate into Gold tables."""
    silver_df = spark.read.format("delta").load("/mnt/data/silver/orders")

    # daily_revenue
    daily_rev = silver_df.groupBy("order_date", "region").agg(
        _round(_sum(col("amount") * col("quantity")), 2).alias("total_revenue"),
        count("order_id").alias("total_orders"),
        _sum("quantity").alias("total_units")
    )
    _merge_or_create(daily_rev, "/mnt/data/gold/daily_revenue",
                     "tgt.order_date = src.order_date AND tgt.region = src.region")

    # customer_lifetime_value
    clv = silver_df.groupBy("customer_id").agg(
        _round(_sum(col("amount") * col("quantity")), 2).alias("total_spent"),
        count("order_id").alias("total_orders"),
        _round(avg(col("amount") * col("quantity")), 2).alias("avg_order_value"),
        _min("order_date").alias("first_order"),
        _max("order_date").alias("last_order")
    )
    _merge_or_create(clv, "/mnt/data/gold/customer_lifetime_value",
                     "tgt.customer_id = src.customer_id")

    print("Gold complete.")

def _merge_or_create(df, path, condition):
    """Helper: create Delta table on first run, MERGE on subsequent runs."""
    if not DeltaTable.isDeltaTable(spark, path):
        df.write.format("delta").mode("overwrite").save(path)
    else:
        DeltaTable.forPath(spark, path).alias("tgt").merge(
            df.alias("src"), condition
        ).whenMatchedUpdateAll().whenNotMatchedInsertAll().execute()

# Run the full pipeline
from pyspark.sql.functions import row_number

run_bronze()
run_silver()
run_gold()
```

### Databricks Workflows (Option B)

```python
# In Databricks, use Workflows (formerly Jobs) to orchestrate:
#
# Task 1: bronze_ingest   (notebook: /pipelines/bronze_orders)
# Task 2: silver_clean     (notebook: /pipelines/silver_orders, depends_on: bronze_ingest)
# Task 3: gold_aggregate   (notebook: /pipelines/gold_orders,  depends_on: silver_clean)
#
# Workflow configuration (JSON):
# {
#   "name": "orders_medallion_pipeline",
#   "tasks": [
#     {"task_key": "bronze_ingest",  "notebook_task": {"notebook_path": "/pipelines/bronze_orders"}},
#     {"task_key": "silver_clean",   "notebook_task": {"notebook_path": "/pipelines/silver_orders"},
#      "depends_on": [{"task_key": "bronze_ingest"}]},
#     {"task_key": "gold_aggregate", "notebook_task": {"notebook_path": "/pipelines/gold_orders"},
#      "depends_on": [{"task_key": "silver_clean"}]}
#   ],
#   "schedule": {"quartz_cron_expression": "0 0 */2 * * ?", "timezone_id": "UTC"}
# }
#
# Delta Live Tables (DLT) alternative:
# DLT declaratively defines expectations and dependencies between tables.
# It handles orchestration, retries, and data quality automatically.
```

---

## Quality Metrics Logging

```python
# Log data quality metrics to a Delta table for monitoring

from datetime import datetime

def log_quality_metrics(layer, metrics):
    """Persist quality metrics after each layer completes."""
    metrics_data = [(
        layer,
        datetime.now().isoformat(),
        metrics.get("input_count", 0),
        metrics.get("output_count", 0),
        metrics.get("quarantined_count", 0),
        metrics.get("duplicate_count", 0),
        metrics.get("pass_rate", 0.0)
    )]

    metrics_df = spark.createDataFrame(
        metrics_data,
        ["layer", "run_timestamp", "input_count", "output_count",
         "quarantined_count", "duplicate_count", "pass_rate"]
    )

    metrics_df.write.format("delta").mode("append").save(
        "/mnt/data/monitoring/quality_metrics"
    )

# Usage after Silver layer
log_quality_metrics("silver", {
    "input_count": total_bronze,
    "output_count": total_silver,
    "quarantined_count": total_quarantined,
    "duplicate_count": total_dupes,
    "pass_rate": round(total_silver / total_bronze * 100, 2)
})
```

---

## Key Interview Talking Points

1. **"Walk me through your medallion pipeline."** Bronze is raw/append-only (the data lake's audit log). Silver enforces quality -- type casting, deduplication, null handling, schema enforcement. Gold is business-oriented aggregations optimized for consumption. Each layer has a single responsibility and can be reprocessed independently.

2. **"Why not just load directly to Gold?"** Separating layers provides reprocessability (rerun Silver without re-ingesting), debugging (compare Bronze vs Silver to find data quality issues), decoupling (Gold schema changes do not require re-ingestion), and different SLAs (Bronze can be near-real-time while Gold refreshes hourly).

3. **"How do you handle late-arriving data across layers?"** Bronze captures everything with an ingestion timestamp. Silver uses MERGE so late records are upserted by their natural key (`order_id`). Gold uses MERGE on composite keys (`order_date + region`), so re-aggregation after late data naturally corrects the metrics. CDF (Change Data Feed) on Silver lets Gold process only the changed rows instead of re-reading the full table.

4. **"How do you make each layer idempotent?"** Bronze uses Auto Loader checkpoints -- restarting the stream does not re-read processed files. Silver uses Delta MERGE on `order_id` -- re-running with the same data is a no-op (conditional update skips unchanged rows). Gold uses MERGE on aggregate keys -- re-computing and merging the same aggregates produces identical results.

5. **Schema enforcement vs evolution:** Bronze uses `mergeSchema=true` and Auto Loader's `schemaEvolutionMode=addNewColumns` to accept anything. Silver enforces a strict schema -- new or unexpected columns are rejected (or routed to `_rescued_data`). This protects downstream consumers from surprise schema changes.

6. **`_rescued_data` column:** Auto Loader's rescue column captures JSON fields that do not fit the inferred schema. This prevents silent data loss and gives engineers visibility into upstream schema changes. Always monitor the rescue column for non-null values as an early warning.

7. **MERGE performance at scale:** Partition Gold tables by date. Z-order Silver tables on the merge key (`order_id`). Broadcast small source DataFrames. Use conditional updates to skip unchanged rows. Run `OPTIMIZE` periodically to compact small files created by frequent merges.

8. **Delta advantages over plain Parquet:** ACID transactions (MERGE is atomic), time travel (rollback bad writes), schema enforcement (reject malformed data), CDF (track row-level changes), OPTIMIZE + Z-ORDER (query performance), and VACUUM (storage management).
