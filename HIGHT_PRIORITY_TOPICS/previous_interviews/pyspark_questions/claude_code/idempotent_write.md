# PySpark Implementation: Idempotent Partitioned Writes

## Problem Statement
Write daily ETL output to a partitioned table so that rerunning the pipeline for a specific date overwrites only that date's partition, leaving all other partitions untouched. This is the "idempotent write" pattern -- running the same job twice with the same input produces the same result without duplicating data or corrupting other partitions.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_date, lit, count

spark = SparkSession.builder \
    .appName("IdempotentWrite") \
    .config("spark.sql.sources.partitionOverwriteMode", "dynamic") \
    .getOrCreate()

# Simulated daily ETL output for multiple dates
data = [
    ("2024-01-15", "tx_001", "Alice", 100.00),
    ("2024-01-15", "tx_002", "Bob",   250.00),
    ("2024-01-15", "tx_003", "Charlie", 75.00),
    ("2024-01-16", "tx_004", "Diana", 300.00),
    ("2024-01-16", "tx_005", "Eve",   180.00),
    ("2024-01-17", "tx_006", "Frank", 420.00),
    ("2024-01-17", "tx_007", "Grace", 90.00),
    ("2024-01-17", "tx_008", "Hank",  315.00),
]

df = spark.createDataFrame(
    data, ["process_date", "tx_id", "customer", "amount"]
)
df = df.withColumn("process_date", to_date("process_date"))
df.show()
```

| process_date | tx_id  | customer | amount |
|--------------|--------|----------|--------|
| 2024-01-15   | tx_001 | Alice    | 100.00 |
| 2024-01-15   | tx_002 | Bob      | 250.00 |
| 2024-01-15   | tx_003 | Charlie  | 75.00  |
| 2024-01-16   | tx_004 | Diana    | 300.00 |
| 2024-01-16   | tx_005 | Eve      | 180.00 |
| 2024-01-17   | tx_006 | Frank    | 420.00 |
| 2024-01-17   | tx_007 | Grace    | 90.00  |
| 2024-01-17   | tx_008 | Hank     | 315.00 |

### Expected Behavior
- First run: creates partitions for 2024-01-15, 2024-01-16, 2024-01-17.
- Rerun for 2024-01-16 only: overwrites the 2024-01-16 partition; 2024-01-15 and 2024-01-17 remain untouched.
- No duplicate records after any number of reruns.

---

## Method 1: Dynamic Partition Overwrite Mode (Recommended)

```python
output_path = "/tmp/etl_output/transactions"

# Step 1: Set dynamic partition overwrite mode (can also be set at session level)
spark.conf.set("spark.sql.sources.partitionOverwriteMode", "dynamic")

# Step 2: Write all data partitioned by process_date
df.write \
    .format("parquet") \
    .mode("overwrite") \
    .partitionBy("process_date") \
    .save(output_path)

# Step 3: Verify the partitions exist
written = spark.read.parquet(output_path)
written.groupBy("process_date").count().orderBy("process_date").show()

# Step 4: Simulate a rerun for 2024-01-16 with corrected data
rerun_data = [
    ("2024-01-16", "tx_004", "Diana", 350.00),  # corrected amount
    ("2024-01-16", "tx_005", "Eve",   180.00),
    ("2024-01-16", "tx_009", "Ivy",   225.00),  # new transaction
]
rerun_df = spark.createDataFrame(
    rerun_data, ["process_date", "tx_id", "customer", "amount"]
)
rerun_df = rerun_df.withColumn("process_date", to_date("process_date"))

# Step 5: Write the rerun -- ONLY 2024-01-16 partition is overwritten
rerun_df.write \
    .format("parquet") \
    .mode("overwrite") \
    .partitionBy("process_date") \
    .save(output_path)

# Step 6: Verify other partitions are untouched
final = spark.read.parquet(output_path)
final.orderBy("process_date", "tx_id").show()
```

### Step-by-Step Explanation

**After Step 2 -- Initial write creates 3 partition directories:**
```
/tmp/etl_output/transactions/
  process_date=2024-01-15/   (3 records)
  process_date=2024-01-16/   (2 records)
  process_date=2024-01-17/   (3 records)
```

**After Step 3 -- Partition counts:**

| process_date | count |
|--------------|-------|
| 2024-01-15   | 3     |
| 2024-01-16   | 2     |
| 2024-01-17   | 3     |

**Key: Dynamic vs Static Partition Overwrite:**
- `dynamic` mode: only partitions present in the DataFrame being written are overwritten. Other partitions remain intact.
- `static` mode (default): ALL partitions at the output path are deleted, then the new data is written. This destroys data for dates not in the current batch.

**After Step 5 -- Only 2024-01-16 is replaced:**

| process_date | tx_id  | customer | amount |
|--------------|--------|----------|--------|
| 2024-01-15   | tx_001 | Alice    | 100.00 |
| 2024-01-15   | tx_002 | Bob      | 250.00 |
| 2024-01-15   | tx_003 | Charlie  | 75.00  |
| 2024-01-16   | tx_004 | Diana    | 350.00 |
| 2024-01-16   | tx_005 | Eve      | 180.00 |
| 2024-01-16   | tx_009 | Ivy      | 225.00 |
| 2024-01-17   | tx_006 | Frank    | 420.00 |
| 2024-01-17   | tx_007 | Grace    | 90.00  |
| 2024-01-17   | tx_008 | Hank     | 315.00 |

The 2024-01-15 and 2024-01-17 partitions are completely unchanged. The 2024-01-16 partition now has the corrected data.

---

## Method 2: Delta Lake replaceWhere

```python
output_path_delta = "/tmp/etl_output/transactions_delta"

# Initial write as Delta
df.write.format("delta").mode("overwrite").partitionBy("process_date") \
    .save(output_path_delta)

# Rerun: overwrite only the specific partition using replaceWhere
rerun_df.write.format("delta") \
    .mode("overwrite") \
    .option("replaceWhere", "process_date = '2024-01-16'") \
    .save(output_path_delta)

# Verify
spark.read.format("delta").load(output_path_delta) \
    .orderBy("process_date", "tx_id").show()
```

`replaceWhere` is explicit about which partition to overwrite. It provides a safety guarantee: if the new data contains records outside the specified predicate, the write fails. This prevents accidental overwrites of the wrong partition.

---

## Method 3: Deduplication Guard for Append Mode

```python
output_path_dedup = "/tmp/etl_output/transactions_dedup"

# Write initial data in append mode
df.write.format("parquet").mode("append").partitionBy("process_date") \
    .save(output_path_dedup)

# Read existing data to check for duplicates before appending
existing = spark.read.parquet(output_path_dedup)

# Deduplicate: only insert records whose tx_id does not already exist
new_records_only = rerun_df.alias("new").join(
    existing.alias("old"),
    col("new.tx_id") == col("old.tx_id"),
    "left_anti"
)

# Append only genuinely new records
new_records_only.write.format("parquet").mode("append") \
    .partitionBy("process_date").save(output_path_dedup)

# Verify no duplicates
result = spark.read.parquet(output_path_dedup)
result.groupBy("tx_id").agg(count("*").alias("cnt")) \
    .filter(col("cnt") > 1).show()  # Should be empty
```

This approach is useful when you must use append mode (e.g., streaming sinks) and cannot overwrite partitions. The left_anti join acts as a deduplication gate.

---

## Key Interview Talking Points

1. **`partitionOverwriteMode=dynamic` is the single most important setting** for idempotent batch writes. Without it, `mode("overwrite")` with `partitionBy` deletes the entire table first. Many production data loss incidents stem from forgetting this setting.

2. **Set the config at the SparkSession level** -- `spark.conf.set("spark.sql.sources.partitionOverwriteMode", "dynamic")` ensures all writes in the application behave correctly. Alternatively, set it in `spark-defaults.conf` for cluster-wide safety.

3. **Delta Lake `replaceWhere` is safer** -- it validates that the new data matches the predicate. If you accidentally include records for 2024-01-17 in a `replaceWhere` targeting 2024-01-16, the write fails with an error rather than silently corrupting data.

4. **Idempotency requires overwrite semantics** -- append mode is inherently non-idempotent because rerunning produces duplicates. If you must use append, implement deduplication either before writing (left_anti join) or after reading (dedup view).

5. **Partition pruning depends on the column** -- `partitionBy("process_date")` creates physical directory structure. Queries filtering on `process_date` skip irrelevant directories entirely. Choose partition columns with moderate cardinality (daily dates are ideal; timestamps are too granular).

6. **File count management** -- each write to a partition creates new files. After many reruns, run `OPTIMIZE` (Delta) or repartition before writing to control file counts. Too many small files degrades read performance.

7. **Checkpointing for streaming** -- in Structured Streaming, Spark uses checkpoint directories to track which data has been processed. This is the streaming equivalent of the watermark pattern and provides exactly-once write guarantees when combined with idempotent sinks.

8. **Testing idempotency** -- a reliable test is: run the pipeline, record row counts per partition, run it again with the same input, verify counts are identical. Any increase indicates duplicates; any decrease indicates data loss.
