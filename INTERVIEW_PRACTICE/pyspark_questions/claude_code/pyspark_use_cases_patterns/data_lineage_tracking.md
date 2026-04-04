# PySpark Implementation: Data Lineage Tracking

## Problem Statement

Data lineage tracks how data flows from source to destination — where it came from, what transformations were applied, and where it ended up. In production pipelines, lineage is essential for **debugging**, **compliance** (GDPR, SOX), **impact analysis**, and **data quality auditing**.

Interviewers test whether you can implement practical lineage tracking in PySpark pipelines.

---

## Sample Data

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, lit, current_timestamp, input_file_name,
    md5, concat_ws, monotonically_increasing_id
)

spark = SparkSession.builder.appName("DataLineage").getOrCreate()

# Source data
orders = spark.createDataFrame([
    (1, "C001", 100.0, "2024-01-01"),
    (2, "C002", 200.0, "2024-01-02"),
    (3, "C001", 150.0, "2024-01-03"),
], ["order_id", "customer_id", "amount", "order_date"])

customers = spark.createDataFrame([
    ("C001", "Alice", "alice@email.com"),
    ("C002", "Bob", "bob@email.com"),
], ["customer_id", "name", "email"])
```

---

## Method 1: Metadata Columns for Row-Level Lineage

```python
from datetime import datetime

batch_id = "batch_20240103_001"
pipeline_name = "orders_enrichment"
run_timestamp = datetime.now().isoformat()

# Add lineage columns to track source and processing metadata
enriched = orders.join(customers, "customer_id") \
    .withColumn("_batch_id", lit(batch_id)) \
    .withColumn("_pipeline_name", lit(pipeline_name)) \
    .withColumn("_load_timestamp", current_timestamp()) \
    .withColumn("_source_tables", lit("orders,customers")) \
    .withColumn("_row_hash", md5(concat_ws("||",
        col("order_id").cast("string"),
        col("customer_id"),
        col("amount").cast("string")
    )))

enriched.show(truncate=False)
# +----------+--------+------+----------+-----+---------------+-------------------+-------------------+-----------------+--------------------+
# |customer_id|order_id|amount|order_date| name|          email|         _batch_id |   _pipeline_name  | _load_timestamp |          _row_hash |
# +----------+--------+------+----------+-----+---------------+-------------------+-------------------+-----------------+--------------------+
# |      C001 |      1 | 100.0|2024-01-01|Alice|alice@email.com|batch_20240103_001 |orders_enrichment  |2024-01-03 10:...|a1b2c3...           |
```

---

## Method 2: Audit Log Table

```python
from pyspark.sql import Row

def log_pipeline_run(spark, audit_table_path, pipeline_name, source_tables,
                     target_table, input_count, output_count, status, batch_id):
    """Log pipeline execution metadata to an audit table."""
    audit_entry = spark.createDataFrame([Row(
        pipeline_name=pipeline_name,
        batch_id=batch_id,
        source_tables=source_tables,
        target_table=target_table,
        input_row_count=input_count,
        output_row_count=output_count,
        rows_dropped=input_count - output_count,
        status=status,
        run_timestamp=datetime.now().isoformat()
    )])
    
    audit_entry.write.format("delta").mode("append").save(audit_table_path)

# Usage in pipeline
input_count = orders.count()

enriched = orders.join(customers, "customer_id")
output_count = enriched.count()

# Write output
enriched.write.format("delta").mode("overwrite").save("/tmp/delta/enriched_orders")

# Log the run
log_pipeline_run(
    spark=spark,
    audit_table_path="/tmp/delta/audit_log",
    pipeline_name="orders_enrichment",
    source_tables="orders,customers",
    target_table="enriched_orders",
    input_count=input_count,
    output_count=output_count,
    status="SUCCESS",
    batch_id=batch_id
)
```

---

## Method 3: Source File Tracking with input_file_name()

```python
# When reading from files, track which file each row came from
df = spark.read.parquet("/data/orders/") \
    .withColumn("_source_file", input_file_name())

df.show(truncate=False)
# +--------+----------+------+----------+------------------------------------------+
# |order_id|customer_id|amount|order_date|                        _source_file      |
# +--------+----------+------+----------+------------------------------------------+
# |       1|      C001 | 100.0|2024-01-01|file:///data/orders/part-00000.parquet    |
# |       2|      C002 | 200.0|2024-01-02|file:///data/orders/part-00001.parquet    |
```

---

## Method 4: Query Plan Lineage

```python
# Extract column-level lineage from Spark's logical plan
enriched = orders.join(customers, "customer_id") \
    .select("order_id", "name", "amount")

# View the logical plan to understand column lineage
enriched.explain(True)

# The "Analyzed Logical Plan" shows which source columns map to output columns
# This is useful for automated lineage extraction tools
```

---

## Method 5: Before/After Reconciliation

```python
def reconcile(source_df, target_df, key_cols, compare_cols, table_name):
    """Compare source and target to validate data lineage."""
    source_count = source_df.count()
    target_count = target_df.count()
    
    # Check for missing records
    missing_in_target = source_df.join(target_df, key_cols, "left_anti")
    missing_count = missing_in_target.count()
    
    # Check for mismatched values
    joined = source_df.alias("s").join(target_df.alias("t"), key_cols)
    mismatches = joined
    for c in compare_cols:
        mismatches = mismatches.filter(col(f"s.{c}") != col(f"t.{c}"))
    mismatch_count = mismatches.count()
    
    print(f"--- Reconciliation Report: {table_name} ---")
    print(f"Source rows:       {source_count}")
    print(f"Target rows:       {target_count}")
    print(f"Missing in target: {missing_count}")
    print(f"Value mismatches:  {mismatch_count}")
    print(f"Status:            {'PASS' if missing_count == 0 and mismatch_count == 0 else 'FAIL'}")
    
    return missing_count == 0 and mismatch_count == 0

# Usage
reconcile(orders, enriched, ["order_id"], ["amount"], "enriched_orders")
```

---

## Key Takeaways

| Lineage Type | Technique | Granularity |
|-------------|-----------|-------------|
| Row-level | Metadata columns (_batch_id, _source_file, _row_hash) | Per row |
| Pipeline-level | Audit log table | Per pipeline run |
| File-level | `input_file_name()` | Per source file |
| Column-level | Query plan analysis | Per column transformation |
| Validation | Before/after reconciliation | Per table |

## Interview Tips

1. **Always add audit columns** — `_load_timestamp`, `_batch_id`, `_source_tables` are standard practice
2. **Row hashing** (md5/sha2) enables change detection and deduplication
3. **Audit log tables** should be append-only Delta tables for immutability
4. **input_file_name()** is the PySpark-native way to track source file lineage
5. **Reconciliation** (row counts, value checks) validates that lineage is correct end-to-end
