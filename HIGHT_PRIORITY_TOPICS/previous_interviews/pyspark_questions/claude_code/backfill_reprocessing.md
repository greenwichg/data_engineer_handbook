# PySpark Implementation: Backfill and Historical Reprocessing

## Problem Statement
Your daily ETL pipeline failed for 3 days (Jan 10-12). You need to reprocess those dates without duplicating data, without affecting current-day processing, and without full table rebuilds. Demonstrate idempotent backfill patterns that can safely re-run for any date range.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, lit, to_date, current_timestamp, date_add, date_sub,
    max as _max, min as _min, count, sequence, explode, expr
)
from datetime import date, timedelta
from delta.tables import DeltaTable

spark = SparkSession.builder \
    .appName("BackfillReprocessing") \
    .config("spark.jars.packages", "io.delta:delta-spark_2.12:3.1.0") \
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension") \
    .config("spark.sql.catalog.spark_catalog",
            "org.apache.spark.sql.delta.catalog.DeltaCatalog") \
    .config("spark.sql.sources.partitionOverwriteMode", "dynamic") \
    .getOrCreate()

# Daily orders table — some dates are missing due to pipeline failure
existing_data = [
    ("2024-01-08", "ord_001", "Alice",   120.00, "completed"),
    ("2024-01-08", "ord_002", "Bob",     85.50,  "completed"),
    ("2024-01-09", "ord_003", "Charlie", 200.00, "completed"),
    ("2024-01-09", "ord_004", "Diana",   310.00, "completed"),
    # Jan 10-12 MISSING — pipeline failed these 3 days
    ("2024-01-13", "ord_010", "Ivy",     175.00, "completed"),
    ("2024-01-13", "ord_011", "Jack",    90.00,  "completed"),
    ("2024-01-14", "ord_012", "Karen",   260.00, "completed"),
]

existing_df = spark.createDataFrame(
    existing_data, ["order_date", "order_id", "customer", "amount", "status"]
)
existing_df = existing_df.withColumn("order_date", to_date("order_date"))

# Raw source data for the failed dates (available in Bronze/raw layer)
backfill_source = [
    ("2024-01-10", "ord_005", "Eve",     145.00, "completed"),
    ("2024-01-10", "ord_006", "Frank",   430.00, "completed"),
    ("2024-01-11", "ord_007", "Grace",   78.00,  "completed"),
    ("2024-01-11", "ord_008", "Hank",    225.00, "completed"),
    ("2024-01-12", "ord_009", "Ivy",     310.00, "completed"),
]

backfill_df = spark.createDataFrame(
    backfill_source, ["order_date", "order_id", "customer", "amount", "status"]
)
backfill_df = backfill_df.withColumn("order_date", to_date("order_date"))
```

**Existing target table (gap on Jan 10-12):**

| order_date | order_id | customer | amount | status    |
|------------|----------|----------|--------|-----------|
| 2024-01-08 | ord_001  | Alice    | 120.00 | completed |
| 2024-01-08 | ord_002  | Bob      | 85.50  | completed |
| 2024-01-09 | ord_003  | Charlie  | 200.00 | completed |
| 2024-01-09 | ord_004  | Diana    | 310.00 | completed |
| 2024-01-13 | ord_010  | Ivy      | 175.00 | completed |
| 2024-01-13 | ord_011  | Jack     | 90.00  | completed |
| 2024-01-14 | ord_012  | Karen    | 260.00 | completed |

**Backfill source data (the missing days):**

| order_date | order_id | customer | amount | status    |
|------------|----------|----------|--------|-----------|
| 2024-01-10 | ord_005  | Eve      | 145.00 | completed |
| 2024-01-10 | ord_006  | Frank    | 430.00 | completed |
| 2024-01-11 | ord_007  | Grace    | 78.00  | completed |
| 2024-01-11 | ord_008  | Hank     | 225.00 | completed |
| 2024-01-12 | ord_009  | Ivy      | 310.00 | completed |

### Expected Behavior
- After backfill: all dates from Jan 8–14 are present with correct data.
- Re-running the backfill for the same date range produces the same result — no duplicates.
- Current-day processing (Jan 14+) is not affected during the backfill.

---

## Method 1: Partition Overwrite with `replaceWhere` (Delta Lake)

```python
# Write existing data as a Delta table
target_path = "/tmp/backfill/orders_delta"
existing_df.write.format("delta").mode("overwrite") \
    .partitionBy("order_date").save(target_path)

# Backfill the missing dates using replaceWhere
# replaceWhere guarantees ONLY the specified partitions are touched
backfill_df.write.format("delta") \
    .mode("overwrite") \
    .option("replaceWhere",
            "order_date >= '2024-01-10' AND order_date <= '2024-01-12'") \
    .save(target_path)

# Verify: all dates present, no duplicates
result = spark.read.format("delta").load(target_path)
result.groupBy("order_date").count().orderBy("order_date").show()

# Safe to re-run — replaceWhere is idempotent
# Running the exact same command again produces identical results
backfill_df.write.format("delta") \
    .mode("overwrite") \
    .option("replaceWhere",
            "order_date >= '2024-01-10' AND order_date <= '2024-01-12'") \
    .save(target_path)
```

### Step-by-Step Explanation

**How `replaceWhere` works:**
1. Delta Lake deletes all existing data matching the predicate (`order_date` between Jan 10-12).
2. The new data is written into those partitions.
3. All other partitions (Jan 8-9, Jan 13-14) are completely untouched.
4. The operation is atomic — if it fails partway through, the table remains in its prior state.

**After backfill — partition counts:**

| order_date | count |
|------------|-------|
| 2024-01-08 | 2     |
| 2024-01-09 | 2     |
| 2024-01-10 | 2     |
| 2024-01-11 | 2     |
| 2024-01-12 | 1     |
| 2024-01-13 | 2     |
| 2024-01-14 | 1     |

**Why `replaceWhere` over dynamic partition overwrite:**
- `replaceWhere` is explicit — it declares exactly which partitions will be replaced.
- If the backfill data accidentally contains records outside the date range, the write fails with an error. This prevents accidental overwrites of production partitions.
- Dynamic partition overwrite silently replaces any partition present in the DataFrame, which can cause unintended damage if the backfill data is malformed.

---

## Method 2: MERGE-Based Backfill (Upsert Pattern)

```python
target_path = "/tmp/backfill/orders_merge"
existing_df.write.format("delta").mode("overwrite") \
    .partitionBy("order_date").save(target_path)

delta_table = DeltaTable.forPath(spark, target_path)

# MERGE: insert missing records, update existing ones if they changed
delta_table.alias("target").merge(
    backfill_df.alias("source"),
    "target.order_id = source.order_id"
).whenMatchedUpdate(
    condition="""
        target.customer != source.customer OR
        target.amount != source.amount OR
        target.status != source.status
    """,
    set={
        "customer": "source.customer",
        "amount": "source.amount",
        "status": "source.status",
        "order_date": "source.order_date"
    }
).whenNotMatchedInsertAll(
).execute()

# Verify
spark.read.format("delta").load(target_path) \
    .orderBy("order_date", "order_id").show()
```

### Step-by-Step Explanation

**What happens for each backfill record:**

| source.order_id | Match in target? | Result                          |
|-----------------|------------------|---------------------------------|
| ord_005         | No               | Inserted (new record for Jan 10)|
| ord_006         | No               | Inserted (new record for Jan 10)|
| ord_007         | No               | Inserted (new record for Jan 11)|
| ord_008         | No               | Inserted (new record for Jan 11)|
| ord_009         | No               | Inserted (new record for Jan 12)|

**Why MERGE for backfill:**
- Handles both missing records (inserts) and corrupted records (updates) in a single pass.
- Idempotent: re-running the same MERGE with the same source data produces the same result. The `whenMatchedUpdate` condition skips rows where nothing changed, and `whenNotMatchedInsert` is a no-op for records that already exist.
- ACID-compliant: the entire operation is atomic.

**When to prefer MERGE over replaceWhere:**
- When the target partition may contain some correct records mixed with missing/incorrect ones (partial failures).
- When you cannot guarantee the backfill source contains ALL records for the partition (replaceWhere would delete any records not in the backfill data).

---

## Method 3: High Watermark with Gap Detection

```python
# Step 1: Detect which dates are missing from the target
target_path = "/tmp/backfill/orders_gaps"
existing_df.write.format("delta").mode("overwrite") \
    .partitionBy("order_date").save(target_path)

target = spark.read.format("delta").load(target_path)

# Generate a complete date range
date_range = spark.sql("""
    SELECT explode(sequence(
        to_date('2024-01-08'),
        to_date('2024-01-14'),
        interval 1 day
    )) AS expected_date
""")

# Find present dates in the target
present_dates = target.select("order_date").distinct()

# Gap detection: dates that SHOULD exist but DO NOT
missing_dates = date_range.alias("expected").join(
    present_dates.alias("present"),
    col("expected.expected_date") == col("present.order_date"),
    "left_anti"
)
missing_dates.show()

# Step 2: Filter backfill source to only missing dates
dates_to_backfill = [
    row.expected_date for row in missing_dates.collect()
]
print(f"Dates to backfill: {dates_to_backfill}")

filtered_backfill = backfill_df.filter(
    col("order_date").isin(dates_to_backfill)
)

# Step 3: Process only the gaps
filtered_backfill.write.format("delta") \
    .mode("append") \
    .save(target_path)

# Step 4: Verify gaps are filled
spark.read.format("delta").load(target_path) \
    .groupBy("order_date").count().orderBy("order_date").show()
```

### Step-by-Step Explanation

**After Step 1 — Missing dates detected:**

| expected_date |
|---------------|
| 2024-01-10    |
| 2024-01-11    |
| 2024-01-12    |

**Why gap detection matters:**
- In a large table with months of data, you do not want to scan or reprocess everything. Gap detection identifies exactly which dates need attention.
- Useful for automated monitoring: schedule a job to detect gaps and trigger backfill only when needed.

**Making this idempotent:**
- The gap detection itself provides idempotency: if you run it again after backfill, `missing_dates` will be empty, and no data is written. However, if the pipeline is interrupted between writing and the next gap check, duplicates could occur. For full safety, combine with MERGE or `replaceWhere`.

---

## Method 4: Parameterized Pipeline with Date Range

```python
def run_daily_pipeline(spark, start_date: str, end_date: str,
                       source_path: str, target_path: str):
    """
    Idempotent daily pipeline that processes a date range.
    Can be called for normal daily runs OR for backfill.

    Args:
        start_date: inclusive start date (YYYY-MM-DD)
        end_date: inclusive end date (YYYY-MM-DD)
        source_path: path to raw/bronze data
        target_path: path to target Delta table
    """
    print(f"Processing date range: {start_date} to {end_date}")

    # Step 1: Read source data for the date range (partition pruning)
    source = spark.read.format("delta").load(source_path) \
        .filter(
            (col("order_date") >= lit(start_date)) &
            (col("order_date") <= lit(end_date))
        )

    record_count = source.count()
    if record_count == 0:
        print(f"No source data for {start_date} to {end_date}. Skipping.")
        return

    print(f"Found {record_count} records to process.")

    # Step 2: Apply business transformations
    transformed = source \
        .withColumn("processed_at", current_timestamp()) \
        .withColumn("amount_with_tax", col("amount") * 1.08)

    # Step 3: Write using replaceWhere for idempotency
    replace_predicate = (
        f"order_date >= '{start_date}' AND order_date <= '{end_date}'"
    )

    transformed.write.format("delta") \
        .mode("overwrite") \
        .option("replaceWhere", replace_predicate) \
        .save(target_path)

    print(f"Successfully processed {start_date} to {end_date}.")


# --- Normal daily run ---
run_daily_pipeline(spark,
    start_date="2024-01-14",
    end_date="2024-01-14",
    source_path="/tmp/bronze/orders",
    target_path="/tmp/silver/orders")

# --- Backfill run (same function, different date range) ---
run_daily_pipeline(spark,
    start_date="2024-01-10",
    end_date="2024-01-12",
    source_path="/tmp/bronze/orders",
    target_path="/tmp/silver/orders")

# --- Safe to re-run: replaceWhere makes it idempotent ---
run_daily_pipeline(spark,
    start_date="2024-01-10",
    end_date="2024-01-12",
    source_path="/tmp/bronze/orders",
    target_path="/tmp/silver/orders")
```

### Step-by-Step Explanation

**Why parameterized pipelines:**
- The same code handles both daily runs and backfills. No separate "backfill script" to maintain.
- Orchestration tools (Airflow, Databricks Workflows) can pass date parameters: normal runs use today's date, backfill runs pass the failed date range.
- Testing is straightforward: call the function with any date range and verify the output.

**Partition pruning for efficient reads:**
- The filter `col("order_date") >= start_date` pushes down to the file scan. Only files in the relevant partitions are read from storage.
- On a table with years of daily partitions, this means reading 3 partitions instead of thousands.

**Airflow example for triggering backfill:**
```python
# In an Airflow DAG, backfill is just re-running with specific dates:
# airflow dags backfill my_etl_dag --start-date 2024-01-10 --end-date 2024-01-12
# Each task receives execution_date as a parameter and processes only that date.
```

---

## Method 5: Idempotent Append with MERGE (Avoid Duplicates)

```python
target_path = "/tmp/backfill/orders_idempotent"
existing_df.write.format("delta").mode("overwrite") \
    .partitionBy("order_date").save(target_path)

delta_table = DeltaTable.forPath(spark, target_path)

# Idempotent append: insert only if the record does not already exist
delta_table.alias("target").merge(
    backfill_df.alias("source"),
    "target.order_id = source.order_id"
).whenNotMatchedInsertAll(
).execute()

# Re-run the same MERGE — no duplicates produced
delta_table.alias("target").merge(
    backfill_df.alias("source"),
    "target.order_id = source.order_id"
).whenNotMatchedInsertAll(
).execute()

# Verify: count per order_id should all be 1
result = spark.read.format("delta").load(target_path)
result.groupBy("order_id").count().filter(col("count") > 1).show()  # Empty
result.orderBy("order_date", "order_id").show()
```

### Step-by-Step Explanation

**First run:**
- All 5 records in `backfill_df` have no match in the target (Jan 10-12 data is missing). All 5 are inserted.

**Second run (re-run):**
- All 5 records now match existing rows in the target. `whenNotMatchedInsertAll` has nothing to insert. Zero rows written.

**Result after any number of re-runs:**

| order_date | order_id | customer | amount | status    |
|------------|----------|----------|--------|-----------|
| 2024-01-08 | ord_001  | Alice    | 120.00 | completed |
| 2024-01-08 | ord_002  | Bob      | 85.50  | completed |
| 2024-01-09 | ord_003  | Charlie  | 200.00 | completed |
| 2024-01-09 | ord_004  | Diana    | 310.00 | completed |
| 2024-01-10 | ord_005  | Eve      | 145.00 | completed |
| 2024-01-10 | ord_006  | Frank    | 430.00 | completed |
| 2024-01-11 | ord_007  | Grace    | 78.00  | completed |
| 2024-01-11 | ord_008  | Hank     | 225.00 | completed |
| 2024-01-12 | ord_009  | Ivy      | 310.00 | completed |
| 2024-01-13 | ord_010  | Ivy      | 175.00 | completed |
| 2024-01-13 | ord_011  | Jack     | 90.00  | completed |
| 2024-01-14 | ord_012  | Karen    | 260.00 | completed |

**SQL equivalent using INSERT ... WHERE NOT EXISTS:**
```python
backfill_df.createOrReplaceTempView("backfill_source")

spark.sql("""
    INSERT INTO delta.`/tmp/backfill/orders_idempotent`
    SELECT * FROM backfill_source s
    WHERE NOT EXISTS (
        SELECT 1 FROM delta.`/tmp/backfill/orders_idempotent` t
        WHERE t.order_id = s.order_id
    )
""")
```

---

## Handling Dependencies Between Tables During Backfill

```python
def backfill_medallion_pipeline(spark, start_date: str, end_date: str):
    """
    Backfill Bronze -> Silver -> Gold in dependency order.
    Each layer must complete before the next begins.
    """
    replace_predicate = (
        f"order_date >= '{start_date}' AND order_date <= '{end_date}'"
    )

    # --- Layer 1: Bronze (raw ingestion) ---
    print(f"[Bronze] Reprocessing {start_date} to {end_date}")
    raw = spark.read.format("json").load("/data/raw/orders/") \
        .filter(
            (col("order_date") >= start_date) &
            (col("order_date") <= end_date)
        )
    raw.write.format("delta") \
        .mode("overwrite") \
        .option("replaceWhere", replace_predicate) \
        .save("/data/bronze/orders")

    # --- Layer 2: Silver (cleaned + deduplicated) ---
    print(f"[Silver] Reprocessing {start_date} to {end_date}")
    bronze = spark.read.format("delta").load("/data/bronze/orders") \
        .filter(
            (col("order_date") >= start_date) &
            (col("order_date") <= end_date)
        )
    silver = bronze \
        .dropDuplicates(["order_id"]) \
        .filter(col("amount") > 0) \
        .withColumn("amount_with_tax", col("amount") * 1.08)

    silver.write.format("delta") \
        .mode("overwrite") \
        .option("replaceWhere", replace_predicate) \
        .save("/data/silver/orders")

    # --- Layer 3: Gold (aggregated) ---
    print(f"[Gold] Reprocessing {start_date} to {end_date}")
    silver_data = spark.read.format("delta").load("/data/silver/orders") \
        .filter(
            (col("order_date") >= start_date) &
            (col("order_date") <= end_date)
        )
    gold = silver_data.groupBy("order_date").agg(
        count("order_id").alias("total_orders"),
        expr("sum(amount_with_tax)").alias("total_revenue"),
        expr("avg(amount_with_tax)").alias("avg_order_value")
    )

    gold.write.format("delta") \
        .mode("overwrite") \
        .option("replaceWhere", replace_predicate) \
        .save("/data/gold/daily_order_summary")

    print(f"Backfill complete for {start_date} to {end_date}.")


# Run backfill across all layers
backfill_medallion_pipeline(spark, "2024-01-10", "2024-01-12")
```

**Key points about dependency ordering:**
- Bronze must finish before Silver reads from it. Silver must finish before Gold reads from it.
- Each layer uses `replaceWhere` to overwrite only the backfill date range. Live data (Jan 13+) is untouched at every layer.
- If the backfill fails at the Silver layer, Bronze is already correct. Re-running from Silver is safe because `replaceWhere` is idempotent.

---

## Parallel vs Sequential Backfill

```python
from concurrent.futures import ThreadPoolExecutor, as_completed

def backfill_single_date(date_str: str):
    """Backfill a single date — suitable for parallel execution."""
    run_daily_pipeline(spark,
        start_date=date_str,
        end_date=date_str,
        source_path="/tmp/bronze/orders",
        target_path="/tmp/silver/orders")
    return date_str

# Sequential backfill: simple, predictable, easier to debug
dates_to_backfill = ["2024-01-10", "2024-01-11", "2024-01-12"]
for d in dates_to_backfill:
    backfill_single_date(d)

# Parallel backfill: faster for independent dates
# WARNING: ensure the target table supports concurrent writes (Delta Lake does)
with ThreadPoolExecutor(max_workers=3) as executor:
    futures = {
        executor.submit(backfill_single_date, d): d
        for d in dates_to_backfill
    }
    for future in as_completed(futures):
        date_str = futures[future]
        try:
            future.result()
            print(f"Backfill succeeded for {date_str}")
        except Exception as e:
            print(f"Backfill FAILED for {date_str}: {e}")
```

**When to use parallel vs sequential:**
- **Sequential:** when layers depend on each other (Bronze before Silver), or when the cluster is already fully utilized.
- **Parallel:** when backfilling the same layer for independent dates. Delta Lake handles concurrent writes with optimistic concurrency control, but watch for write conflicts if multiple jobs touch the same partitions.

---

## Logging and Auditing Backfill Runs

```python
from pyspark.sql.functions import current_timestamp, lit

def log_backfill_run(spark, pipeline_name: str, start_date: str,
                     end_date: str, status: str, records_processed: int,
                     log_path: str = "/tmp/backfill/audit_log"):
    """Log each backfill run for auditing and troubleshooting."""
    log_entry = spark.createDataFrame(
        [(pipeline_name, start_date, end_date, status, records_processed)],
        ["pipeline_name", "start_date", "end_date", "status", "records_processed"]
    ).withColumn("run_timestamp", current_timestamp())

    log_entry.write.format("delta").mode("append").save(log_path)


# Usage in backfill pipeline
try:
    run_daily_pipeline(spark, "2024-01-10", "2024-01-12",
                       "/tmp/bronze/orders", "/tmp/silver/orders")
    log_backfill_run(spark, "silver_orders", "2024-01-10", "2024-01-12",
                     "SUCCESS", records_processed=5)
except Exception as e:
    log_backfill_run(spark, "silver_orders", "2024-01-10", "2024-01-12",
                     "FAILED", records_processed=0)
    raise

# Query audit log to see all backfill history
spark.read.format("delta").load("/tmp/backfill/audit_log") \
    .orderBy("run_timestamp").show(truncate=False)
```

**Sample audit log output:**

| pipeline_name | start_date | end_date   | status  | records_processed | run_timestamp       |
|---------------|------------|------------|---------|-------------------|---------------------|
| silver_orders | 2024-01-10 | 2024-01-12 | SUCCESS | 5                 | 2024-01-14 09:15:00 |

---

## Key Interview Talking Points

1. **`replaceWhere` is the gold standard for partition-level backfill.** It explicitly declares which partitions are being replaced, fails if the new data falls outside the predicate, and is fully atomic. Prefer it over dynamic partition overwrite for safety-critical backfills.

2. **Idempotency means "run it again, get the same result."** Every backfill pattern must be safe to re-run. `replaceWhere` achieves this by deleting then inserting. MERGE achieves this by matching on keys. Append mode is NOT idempotent by default — it requires deduplication logic.

3. **Always process dependencies in order during backfill.** If your pipeline has Bronze, Silver, and Gold layers, backfill Bronze first, then Silver, then Gold. Skipping layers or running them in parallel across layers will produce incorrect results because downstream tables read from upstream tables.

4. **Parameterize pipelines by date range from day one.** A pipeline that only knows "today" cannot be backfilled. Accept `start_date` and `end_date` parameters so the same code handles daily runs and historical reprocessing. Orchestrators like Airflow pass `execution_date` automatically.

5. **Partition pruning makes backfill efficient.** Filtering on the partition column (`order_date`) tells Spark to read only the relevant partition directories. On a table with 3 years of daily data (~1,095 partitions), a 3-day backfill reads only 3 partitions — not the entire table.

6. **MERGE is better when partitions contain a mix of correct and incorrect data.** `replaceWhere` replaces the entire partition, so the backfill source must contain ALL records for that partition. MERGE can surgically insert missing records or update incorrect ones without touching rows that are already correct.

7. **Parallel backfill accelerates recovery but requires care.** Independent dates can be processed in parallel within the same layer. Delta Lake's optimistic concurrency control handles concurrent writes. However, if two jobs attempt to write the same partition simultaneously, one will fail with a `ConcurrentModificationException` and should be retried.

8. **Always log which dates were reprocessed.** An audit log answers critical operational questions: "When was this date last backfilled?", "Which pipeline run produced this data?", "Has this date ever been reprocessed?" Without audit logging, troubleshooting data issues becomes guesswork.

9. **Common interview questions and how to answer them:**
   - *"Pipeline failed for a week, how do you recover?"* — Identify failed dates from pipeline logs, verify raw data is available, run parameterized backfill for the date range using `replaceWhere`, process layers in dependency order (Bronze, Silver, Gold), and validate row counts and aggregates against source.
   - *"How do you make pipelines idempotent?"* — Use overwrite semantics (`replaceWhere`) instead of append. Match on natural keys with MERGE. Design every pipeline so running it twice with the same input produces the same output.
   - *"How do you backfill without affecting live data?"* — Use `replaceWhere` with a date predicate scoped to the backfill range. Live partitions outside the predicate are never touched. Run backfill during off-peak hours to avoid resource contention with production jobs.
   - *"How do you handle downstream dependencies during backfill?"* — Process layers sequentially in dependency order. Use `replaceWhere` at each layer so only the backfill date range is reprocessed. Validate each layer before proceeding to the next. If a mid-layer fails, re-run from that layer forward — upstream layers are already correct.
