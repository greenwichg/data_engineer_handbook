# PySpark Implementation: Graceful Error Handling

## Problem Statement

Production PySpark pipelines must handle dirty, malformed, and unexpected data without crashing. A single corrupt CSV row or a null in a non-nullable JSON field should not bring down a multi-hour ETL job. Robust error handling means detecting bad records, quarantining them for investigation, continuing processing on good records, and reporting error metrics.

**Real-world scenario**: An ingestion pipeline reads CSV files from an SFTP server. Some files have missing columns, extra delimiters, or encoding issues. The pipeline must process valid rows, quarantine bad rows, log error counts, and alert if the error rate exceeds a threshold.

---

## Approach 1: CSV/JSON Read Modes (PERMISSIVE, DROPMALFORMED, FAILFAST)

### Sample Data

```python
# Malformed CSV data (saved to file)
csv_content = """id,name,salary
1,Alice,50000
2,Bob,sixty-thousand
3,Carol,75000
this is completely broken
5,Eve,90000,extra_field
"""
```

### Expected Output

Different behaviors depending on the mode:
- PERMISSIVE: reads all rows, puts corrupt ones in `_corrupt_record`
- DROPMALFORMED: silently drops bad rows
- FAILFAST: throws an exception immediately

### Full Working Code

```python
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, IntegerType, StringType, DoubleType

spark = SparkSession.builder \
    .appName("ErrorHandlingModes") \
    .master("local[*]") \
    .getOrCreate()

# ── 1. Create Malformed CSV File ──────────────────────────────────
csv_content = """id,name,salary
1,Alice,50000
2,Bob,sixty-thousand
3,Carol,75000
this is completely broken
5,Eve,90000,extra_field
"""

csv_path = "/tmp/malformed_data.csv"
with open(csv_path, "w") as f:
    f.write(csv_content)

schema = StructType([
    StructField("id", IntegerType()),
    StructField("name", StringType()),
    StructField("salary", DoubleType()),
])

# ── 2. PERMISSIVE Mode (Default) ──────────────────────────────────
# Puts corrupt records into a _corrupt_record column.
# Non-parseable fields become null.

permissive_schema = StructType([
    StructField("id", IntegerType()),
    StructField("name", StringType()),
    StructField("salary", DoubleType()),
    StructField("_corrupt_record", StringType()),  # must add this column!
])

permissive_df = spark.read \
    .option("header", "true") \
    .option("mode", "PERMISSIVE") \
    .option("columnNameOfCorruptRecord", "_corrupt_record") \
    .schema(permissive_schema) \
    .csv(csv_path)

print("=== PERMISSIVE Mode ===")
permissive_df.show(truncate=False)
# +----+-----+-------+----------------------------+
# |id  |name |salary |_corrupt_record             |
# +----+-----+-------+----------------------------+
# |1   |Alice|50000.0|null                        |  <- good
# |null|null |null   |2,Bob,sixty-thousand        |  <- salary not a number
# |3   |Carol|75000.0|null                        |  <- good
# |null|null |null   |this is completely broken   |  <- totally broken
# |null|null |null   |5,Eve,90000,extra_field     |  <- extra column
# +----+-----+-------+----------------------------+

# Separate good and bad records
good_records = permissive_df.filter("_corrupt_record IS NULL").drop("_corrupt_record")
bad_records = permissive_df.filter("_corrupt_record IS NOT NULL")

print(f"Good records: {good_records.count()}")
print(f"Bad records:  {bad_records.count()}")

# ── 3. DROPMALFORMED Mode ─────────────────────────────────────────
# Silently drops rows that don't conform to the schema.

drop_df = spark.read \
    .option("header", "true") \
    .option("mode", "DROPMALFORMED") \
    .schema(schema) \
    .csv(csv_path)

print("\n=== DROPMALFORMED Mode ===")
drop_df.show()
# Only rows 1, 3 appear. Rows 2, 4, 5 are silently dropped.
# WARNING: No way to know what was dropped or why!

# ── 4. FAILFAST Mode ──────────────────────────────────────────────
# Throws an exception on the first malformed record.

try:
    failfast_df = spark.read \
        .option("header", "true") \
        .option("mode", "FAILFAST") \
        .schema(schema) \
        .csv(csv_path)
    failfast_df.show()
except Exception as e:
    print(f"\n=== FAILFAST Mode ===")
    print(f"Exception: {type(e).__name__}: {str(e)[:200]}")

spark.stop()
```

---

## Approach 2: JSON Corrupt Record Handling

### Full Working Code

```python
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, IntegerType, StringType

spark = SparkSession.builder \
    .appName("JSONErrorHandling") \
    .master("local[*]") \
    .getOrCreate()

# ── 1. Create Malformed JSON File ─────────────────────────────────
json_content = """{"id": 1, "name": "Alice", "age": 30}
{"id": 2, "name": "Bob", "age": "not-a-number"}
{"id": 3, "name": "Carol"}
{invalid json here}
{"id": 5, "name": "Eve", "age": 25, "extra": "field"}
"""

json_path = "/tmp/malformed_data.json"
with open(json_path, "w") as f:
    f.write(json_content)

# ── 2. PERMISSIVE with Corrupt Record Column ──────────────────────
schema = StructType([
    StructField("id", IntegerType()),
    StructField("name", StringType()),
    StructField("age", IntegerType()),
    StructField("_corrupt_record", StringType()),
])

df = spark.read \
    .option("mode", "PERMISSIVE") \
    .option("columnNameOfCorruptRecord", "_corrupt_record") \
    .schema(schema) \
    .json(json_path)

print("=== JSON PERMISSIVE Mode ===")
df.show(truncate=False)
# +----+-----+----+---------------------------------------------+
# |id  |name |age |_corrupt_record                              |
# +----+-----+----+---------------------------------------------+
# |1   |Alice|30  |null                                         |
# |null|null |null|{"id": 2, "name": "Bob", "age": "not-a-..."}|
# |3   |Carol|null|null                                         |  <- missing field OK
# |null|null |null|{invalid json here}                          |
# |5   |Eve  |25  |null                                         |  <- extra field OK
# +----+-----+----+---------------------------------------------+

# Note: Missing fields -> null (not corrupt). Extra fields -> ignored (not corrupt).
# Only type mismatches and malformed JSON trigger _corrupt_record.

# ── 3. Quarantine Bad Records ─────────────────────────────────────
quarantine_path = "/tmp/quarantine/json_errors"
corrupt = df.filter("_corrupt_record IS NOT NULL")
corrupt.write.mode("overwrite").json(quarantine_path)
print(f"Quarantined {corrupt.count()} records to {quarantine_path}")

# ── 4. Multi-line JSON ────────────────────────────────────────────
# For pretty-printed JSON, use multiLine option
# Errors in multi-line JSON affect the entire file, not just one record
multiline_json = """[
    {"id": 1, "name": "Alice"},
    {"id": 2, "name": "Bob"}
]"""

ml_path = "/tmp/multiline.json"
with open(ml_path, "w") as f:
    f.write(multiline_json)

ml_df = spark.read.option("multiLine", "true").json(ml_path)
ml_df.show()

spark.stop()
```

---

## Approach 3: Accumulator-Based Error Counting

### Full Working Code

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, udf, when
from pyspark.sql.types import StringType, IntegerType

spark = SparkSession.builder \
    .appName("AccumulatorErrors") \
    .master("local[*]") \
    .getOrCreate()

# ── 1. Create Accumulators ────────────────────────────────────────
total_records = spark.sparkContext.accumulator(0)
error_records = spark.sparkContext.accumulator(0)
null_salary_count = spark.sparkContext.accumulator(0)
negative_salary_count = spark.sparkContext.accumulator(0)

# ── 2. Sample Data with Issues ────────────────────────────────────
data = [
    (1, "Alice", 50000),
    (2, "Bob", None),          # null salary
    (3, "Carol", -5000),       # negative salary
    (4, "Dave", 75000),
    (5, None, 60000),          # null name
    (6, "Frank", 0),           # zero salary
    (7, "Grace", 90000),
]
df = spark.createDataFrame(data, ["id", "name", "salary"])

# ── 3. Validation with Accumulators via RDD ────────────────────────
def validate_row(row):
    total_records.add(1)
    errors = []

    if row.salary is None:
        null_salary_count.add(1)
        errors.append("null_salary")
    elif row.salary < 0:
        negative_salary_count.add(1)
        errors.append("negative_salary")

    if row.name is None:
        errors.append("null_name")

    if errors:
        error_records.add(1)
        return (row.id, row.name, row.salary, ",".join(errors))
    else:
        return (row.id, row.name, row.salary, None)

validated_rdd = df.rdd.map(validate_row)
validated_df = validated_rdd.toDF(["id", "name", "salary", "errors"])

# Force evaluation (accumulators only update when actions are triggered)
validated_df.cache()
validated_df.count()

print("=== Validated Data ===")
validated_df.show(truncate=False)

print(f"\n=== Error Summary ===")
print(f"Total records:         {total_records.value}")
print(f"Error records:         {error_records.value}")
print(f"Null salaries:         {null_salary_count.value}")
print(f"Negative salaries:     {negative_salary_count.value}")
print(f"Error rate:            {error_records.value / total_records.value * 100:.1f}%")

# ── 4. Alert on High Error Rate ───────────────────────────────────
ERROR_THRESHOLD = 0.20  # 20%
error_rate = error_records.value / total_records.value

if error_rate > ERROR_THRESHOLD:
    print(f"\nALERT: Error rate {error_rate:.1%} exceeds threshold {ERROR_THRESHOLD:.0%}!")
    # In production: send alert via SNS, Slack, PagerDuty, etc.
else:
    print(f"\nError rate {error_rate:.1%} is within acceptable range.")

spark.stop()
```

---

## Approach 4: DataFrame-Based Data Quality with Quarantine

### Full Working Code

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (col, when, lit, concat_ws, array,
                                    current_timestamp, length, trim)

spark = SparkSession.builder \
    .appName("DataQualityQuarantine") \
    .master("local[*]") \
    .getOrCreate()

# ── 1. Sample Data ────────────────────────────────────────────────
data = [
    (1, "Alice",  "alice@email.com",  50000, "US"),
    (2, "Bob",    "invalid-email",    60000, "EU"),
    (3, "",       "carol@email.com",  -5000, "US"),   # empty name, negative salary
    (4, "Dave",   None,               70000, "XX"),   # null email, invalid country
    (5, "Eve",    "eve@email.com",    80000, "US"),
    (6, "Frank",  "frank@email.com",  None,  "EU"),   # null salary
    (7, "Grace",  "grace@email.com",  99999999, "APAC"),  # suspiciously high salary
]

df = spark.createDataFrame(data, ["id", "name", "email", "salary", "country"])

# ── 2. Define Validation Rules ─────────────────────────────────────
valid_countries = ["US", "EU", "APAC", "LATAM"]

validated = df.withColumn(
    "errors",
    array(
        when(col("name").isNull() | (trim(col("name")) == ""),
             lit("EMPTY_NAME")),
        when(col("email").isNull(),
             lit("NULL_EMAIL")),
        when(col("email").isNotNull() & ~col("email").contains("@"),
             lit("INVALID_EMAIL")),
        when(col("salary").isNull(),
             lit("NULL_SALARY")),
        when(col("salary") < 0,
             lit("NEGATIVE_SALARY")),
        when(col("salary") > 10000000,
             lit("SUSPICIOUS_SALARY")),
        when(~col("country").isin(valid_countries),
             lit("INVALID_COUNTRY")),
    )
)

# Remove nulls from the array (array() keeps nulls for non-matching whens)
from pyspark.sql.functions import expr
validated = validated.withColumn(
    "errors",
    expr("filter(errors, x -> x IS NOT NULL)")
)
validated = validated.withColumn(
    "error_count", expr("size(errors)")
)

print("=== All Records with Validation ===")
validated.show(truncate=False)

# ── 3. Split into Clean and Quarantine ─────────────────────────────
clean_df = validated.filter("error_count = 0").drop("errors", "error_count")
quarantine_df = validated.filter("error_count > 0") \
    .withColumn("quarantine_ts", current_timestamp()) \
    .withColumn("error_list", concat_ws(", ", "errors"))

print(f"=== Clean Records: {clean_df.count()} ===")
clean_df.show()

print(f"=== Quarantined Records: {quarantine_df.count()} ===")
quarantine_df.select("id", "name", "error_list", "quarantine_ts").show(truncate=False)

# ── 4. Write to Separate Paths ────────────────────────────────────
clean_df.write.mode("overwrite").parquet("/tmp/clean_data")
quarantine_df.write.mode("overwrite").parquet("/tmp/quarantine_data")

# ── 5. Error Summary Report ───────────────────────────────────────
from pyspark.sql.functions import explode

error_summary = quarantine_df \
    .select(explode("errors").alias("error_type")) \
    .groupBy("error_type").count() \
    .orderBy("count", ascending=False)

print("=== Error Summary ===")
error_summary.show()

spark.stop()
```

---

## Approach 5: Try/Except Patterns for Pipeline-Level Error Handling

### Full Working Code

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col
import traceback
import sys

spark = SparkSession.builder \
    .appName("PipelineErrorHandling") \
    .master("local[*]") \
    .getOrCreate()

# ── 1. Pipeline Step Wrapper ──────────────────────────────────────
class PipelineStep:
    """Wraps each ETL step with error handling and logging."""

    def __init__(self, name, spark):
        self.name = name
        self.spark = spark
        self.status = "NOT_STARTED"
        self.error = None
        self.row_count = 0

    def execute(self, func, *args, **kwargs):
        """Execute a function with error handling."""
        print(f"\n[{self.name}] Starting...")
        try:
            result = func(*args, **kwargs)

            if hasattr(result, 'count'):
                self.row_count = result.count()
                print(f"[{self.name}] Processed {self.row_count} rows")

            self.status = "SUCCESS"
            print(f"[{self.name}] Completed successfully")
            return result

        except Exception as e:
            self.status = "FAILED"
            self.error = str(e)
            print(f"[{self.name}] FAILED: {e}")
            traceback.print_exc()
            return None

# ── 2. Define Pipeline Steps ──────────────────────────────────────
def extract(spark):
    """Extract step that might fail."""
    data = [(1, "Alice", 50000), (2, "Bob", 60000), (3, "Carol", 70000)]
    return spark.createDataFrame(data, ["id", "name", "salary"])

def transform(df):
    """Transform step that might fail."""
    if df is None:
        raise ValueError("Input DataFrame is None")
    return df.filter(col("salary") > 55000) \
             .withColumn("tax", col("salary") * 0.3)

def load(df, path):
    """Load step that might fail."""
    if df is None:
        raise ValueError("Input DataFrame is None")
    df.write.mode("overwrite").parquet(path)
    return df

# ── 3. Run Pipeline with Error Handling ────────────────────────────
steps = []

# Extract
extract_step = PipelineStep("EXTRACT", spark)
steps.append(extract_step)
raw_df = extract_step.execute(extract, spark)

# Transform
transform_step = PipelineStep("TRANSFORM", spark)
steps.append(transform_step)
transformed_df = transform_step.execute(transform, raw_df)

# Load
load_step = PipelineStep("LOAD", spark)
steps.append(load_step)
load_step.execute(load, transformed_df, "/tmp/pipeline_output")

# ── 4. Pipeline Summary ───────────────────────────────────────────
print("\n" + "=" * 50)
print("PIPELINE EXECUTION SUMMARY")
print("=" * 50)
all_success = True
for step in steps:
    status_icon = "OK" if step.status == "SUCCESS" else "FAIL"
    print(f"  [{status_icon}] {step.name}: {step.status} ({step.row_count} rows)")
    if step.error:
        print(f"       Error: {step.error}")
        all_success = False

if all_success:
    print("\nPipeline completed successfully!")
else:
    print("\nPipeline FAILED. Check errors above.")
    # In production: sys.exit(1) to signal failure to orchestrator

# ── 5. Retry Logic ────────────────────────────────────────────────
import time

def retry_with_backoff(func, max_retries=3, backoff_factor=2, *args, **kwargs):
    """Retry a function with exponential backoff."""
    for attempt in range(max_retries):
        try:
            return func(*args, **kwargs)
        except Exception as e:
            if attempt == max_retries - 1:
                raise
            wait = backoff_factor ** attempt
            print(f"Attempt {attempt + 1} failed: {e}. Retrying in {wait}s...")
            time.sleep(wait)

# Usage:
# result = retry_with_backoff(extract, max_retries=3, spark=spark)

spark.stop()
```

---

## Approach 6: badRecordsPath for Automatic Quarantine

### Full Working Code

```python
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, IntegerType, StringType, DoubleType

spark = SparkSession.builder \
    .appName("BadRecordsPath") \
    .master("local[*]") \
    .getOrCreate()

# ── 1. Create Malformed Data ──────────────────────────────────────
csv_content = """id,name,salary
1,Alice,50000
2,Bob,not_a_number
3,Carol,75000
broken_row
5,Eve,90000
"""

csv_path = "/tmp/bad_records_demo.csv"
with open(csv_path, "w") as f:
    f.write(csv_content)

# ── 2. Use badRecordsPath ─────────────────────────────────────────
# Spark writes bad records to a specified directory automatically

schema = StructType([
    StructField("id", IntegerType()),
    StructField("name", StringType()),
    StructField("salary", DoubleType()),
])

bad_records_path = "/tmp/bad_records_output"

df = spark.read \
    .option("header", "true") \
    .option("badRecordsPath", bad_records_path) \
    .schema(schema) \
    .csv(csv_path)

print("=== Good Records ===")
df.show()
# Only valid records appear. Bad records written to bad_records_path.

print("=== Bad Records ===")
import os
import glob as pyglob

bad_files = pyglob.glob(f"{bad_records_path}/**/*.json", recursive=True)
for f in bad_files:
    print(f"File: {f}")
    with open(f) as fh:
        print(fh.read())

# Bad records are stored as JSON with the original row and reason
# This is cleaner than _corrupt_record for production pipelines

spark.stop()
```

---

## Key Takeaways

| Technique | When to Use | Pros | Cons |
|---|---|---|---|
| **PERMISSIVE + _corrupt_record** | Default approach for CSV/JSON | See all data, inspect errors | Must add column to schema |
| **DROPMALFORMED** | Quick prototyping only | Simple | Silent data loss, no audit trail |
| **FAILFAST** | Data quality gates | Catches issues immediately | Blocks entire pipeline |
| **badRecordsPath** | Production pipelines | Automatic quarantine to files | Less flexible than custom logic |
| **Accumulators** | Error counting / metrics | Real-time error rates | Only works with RDD operations |
| **DataFrame validation** | Complex business rules | Flexible, composable rules | More code to write |
| **Try/except wrapper** | Pipeline-level resilience | Graceful degradation | Doesn't handle row-level errors |

## Interview Tips

- **Never use DROPMALFORMED in production** -- you lose data with no audit trail. Interviewers consider this a red flag. Always use PERMISSIVE with quarantine.
- **The _corrupt_record column must be in your schema** -- if you forget to add it, PERMISSIVE mode silently sets unparseable fields to null and you can't distinguish between actual nulls and corrupt records.
- **Accumulators have caveats**: they can double-count in case of task retries (speculative execution, recomputed stages). For exact counts, use a write-and-count approach instead.
- **Data quarantine is a design pattern**: bad records go to a quarantine table/path. A separate process reviews and either fixes or discards them. This is the industry standard for data quality.
- **Error rate thresholds**: production pipelines should fail if the error rate exceeds a threshold (e.g., >5%). An anomalously high error rate usually means a schema change or source system issue, not individual bad records.
- **badRecordsPath** is the cleanest built-in option for Spark 2.3+. It automatically writes corrupt records to JSON files with the reason. Mention this as your go-to for production.
