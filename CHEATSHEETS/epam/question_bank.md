# Data Engineering Interview Questions & Answers

A comprehensive technical reference covering PySpark, Python, SQL, Databricks, Data Modeling, MLOps, Airflow, and Kafka.

---

## Table of Contents

1. [CSV Processing & Pre-processing Layer](#1-csv-processing--pre-processing-layer)
2. [Repartition and Coalesce](#2-repartition-and-coalesce)
3. [Data Modelling](#3-data-modelling)
4. [Slowly Changing Dimensions (SCD)](#4-slowly-changing-dimensions-scd)
5. [Schema Evolution in Parquet](#5-schema-evolution-in-parquet)
6. [Handling Null/Blank Data](#6-handling-nullblank-data)
7. [Latest Record Without Timestamp](#7-latest-record-without-timestamp)
8. [Spark Optimization Techniques](#8-spark-optimization-techniques)
9. [Pandas Operations](#9-pandas-operations)
10. [Data Lake CDC & Incremental Load](#10-data-lake-cdc--incremental-load)
11. [Data Quality](#11-data-quality)
12. [Dimensions & SCD Types](#12-dimensions--scd-types)
13. [Medallion Architecture](#13-medallion-architecture)
14. [Delta Lake](#14-delta-lake)
15. [Database vs Data Warehouse](#15-database-vs-data-warehouse)
16. [Data Pipeline Creation](#16-data-pipeline-creation)
17. [Slow SQL Query Troubleshooting](#17-slow-sql-query-troubleshooting)
18. [Slow Spark Application Troubleshooting](#18-slow-spark-application-troubleshooting)
19. [Conceptual, Logical, Physical Data Models](#19-conceptual-logical-physical-data-models)
20. [OLAP vs OLTP](#20-olap-vs-oltp)
21. [Data Migration OLTP to OLAP](#21-data-migration-oltp-to-olap)
22. [Kimball vs Inmon](#22-kimball-vs-inmon)
23. [RDBMS vs NoSQL](#23-rdbms-vs-nosql)
24. [Python Generators, Return vs Yield](#24-python-generators-return-vs-yield)
25. [Multithreading vs Multiprocessing](#25-multithreading-vs-multiprocessing)
26. [Set, List, Tuples](#26-set-list-tuples)
27. [Python Decorators](#27-python-decorators)
28. [Airflow: XComs and Dynamic DAGs](#28-airflow-xcoms-and-dynamic-dags)
29. [MLOps Fundamentals](#29-mlops-fundamentals)
30. [Spark Execution Flow](#30-spark-execution-flow)
31. [Deduplication](#31-deduplication)
32. [Identifying Unique Records in SQL](#32-identifying-unique-records-in-sql)
33. [RDD Creation](#33-rdd-creation)
34. [DataFrame](#34-dataframe)
35. [Data Spill](#35-data-spill)
36. [Narrow vs Wide Transformations](#36-narrow-vs-wide-transformations)
37. [row_number, rank, dense_rank](#37-row_number-rank-dense_rank)
38. [How Delta Tables Work](#38-how-delta-tables-work)
39. [Data Skewness](#39-data-skewness)
40. [MERGE INTO Syntax](#40-merge-into-syntax)
41. [Spark Memory Management](#41-spark-memory-management)
42. [Star vs Snowflake Schema](#42-star-vs-snowflake-schema)
43. [Change Data Capture (CDC)](#43-change-data-capture-cdc)
44. [Parquet vs Avro](#44-parquet-vs-avro)
45. [Concurrent Transactions on Delta](#45-concurrent-transactions-on-delta)
46. [Coding: Recipes Count](#46-coding-recipes-count)
47. [Coding: DataFrame Sum by Item](#47-coding-dataframe-sum-by-item)
48. [Hive Internal vs External Tables](#48-hive-internal-vs-external-tables)
49. [DELETE vs DROP vs TRUNCATE](#49-delete-vs-drop-vs-truncate)
50. [Coding: Sort List Based on Another List](#50-coding-sort-list-based-on-another-list)
51. [Coding: Remove Duplicates](#51-coding-remove-duplicates)
52. [Coding: Salary Consistently Increasing](#52-coding-salary-consistently-increasing)
53. [Coding: Reverse Words in a String](#53-coding-reverse-words-in-a-string)
54. [Coding: Pair Sum Equals Target](#54-coding-pair-sum-equals-target)
55. [Spark: Shuffling](#55-spark-shuffling)
56. [Persist, Cache, Storage Levels](#56-persist-cache-storage-levels)
57. [Predicate Pushdown](#57-predicate-pushdown)
58. [Scala vs Java](#58-scala-vs-java)
59. [Nil, null, None, Nothing in Scala](#59-nil-null-none-nothing-in-scala)
60. [Fault Tolerance in Spark](#60-fault-tolerance-in-spark)
61. [Scala Garbage Collection](#61-scala-garbage-collection)
62. [Stage Failure Recovery](#62-stage-failure-recovery)
63. [Scala Case Class](#63-scala-case-class)
64. [val, var, def, lazy val](#64-val-var-def-lazy-val)
65. [Spark Internal Working](#65-spark-internal-working)
66. [Adaptive Query Execution (AQE)](#66-adaptive-query-execution-aqe)
67. [Transformations in Spark](#67-transformations-in-spark)
68. [Coding: Age Calculation](#68-coding-age-calculation)
69. [Python Output Questions](#69-python-output-questions)
70. [Kafka: Topic, Queue, Retention](#70-kafka-topic-queue-retention)
71. [Spark Submit Configuration](#71-spark-submit-configuration)
72. [Why Spark is Used in Big Data](#72-why-spark-is-used-in-big-data)
73. [Unity Catalog](#73-unity-catalog)
74. [SQL: Self Join for Manager](#74-sql-self-join-for-manager)
75. [SQL: Join Types Row Count](#75-sql-join-types-row-count)
76. [Cache vs Persist](#76-cache-vs-persist)
77. [Sort Merge Join Stages](#77-sort-merge-join-stages)
78. [DROP DUPLICATES vs DISTINCT](#78-drop-duplicates-vs-distinct)
79. [SQL Query Optimization](#79-sql-query-optimization)
80. [Indexes and Usage](#80-indexes-and-usage)
81. [Recommendation System Design](#81-recommendation-system-design)

---

## 1. CSV Processing & Pre-processing Layer

When ingesting a CSV with inconsistent structure (mixed records like `employeeid, name` on one row and `DOB` on another), the goal is to normalize it into a tabular form.

**Approach:**
1. Read raw CSV using `spark.read.option("multiline","true")` or as text if rows are irregular
2. Infer or define schema explicitly with `StructType`
3. Use `withColumn`, `when/otherwise`, and `regexp_extract` to clean and normalize
4. Pivot if the file has key-value style records
5. Write to the Bronze layer (raw ingestion) using Parquet/Delta

```python
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, DateType
from pyspark.sql.functions import col, to_date

spark = SparkSession.builder.appName("csv_ingest").getOrCreate()

schema = StructType([
    StructField("employeeid", StringType(), True),
    StructField("name", StringType(), True),
    StructField("dob", StringType(), True),
])

df = (spark.read
      .option("header", True)
      .option("mode", "PERMISSIVE")   # keep malformed rows in _corrupt_record
      .schema(schema)
      .csv("/mnt/raw/employees.csv"))

df_clean = df.withColumn("dob", to_date(col("dob"), "dd-MM-yyyy"))
df_clean.write.format("delta").mode("overwrite").save("/mnt/bronze/employees")
```

For a key-value style CSV, you read the file, group related records, and pivot:

```python
df_pivot = df_kv.groupBy("record_id").pivot("key").agg({"value": "first"})
```

---

## 2. Repartition and Coalesce

Both change the number of partitions but differ in mechanism and use case.

| Feature | `repartition(n)` | `coalesce(n)` |
|---|---|---|
| Shuffle | Full shuffle | No shuffle (combines existing partitions) |
| Partition count | Can increase or decrease | Can only decrease |
| Data distribution | Even (round-robin/hash) | Uneven (partitions may differ in size) |
| Use case | Increase parallelism, balanced data | Reduce partitions before writing small outputs |

```python
df.repartition(100)                # full shuffle, 100 balanced partitions
df.repartition(50, col("country")) # hash partition by country
df.coalesce(10)                     # reduce to 10 without shuffle
```

**Rule of thumb:** use `coalesce` when writing final output (e.g., to avoid many small files); use `repartition` when you need balanced partitions for downstream joins/aggregations.

---

## 3. Data Modelling

Data modelling I've worked on (common patterns):

- **Dimensional Modelling (Kimball):** Star and Snowflake schemas with fact and dimension tables for reporting
- **Data Vault 2.0:** Hubs, Links, Satellites — scalable for enterprise warehouses
- **3NF (Inmon):** Normalized enterprise data warehouse
- **One Big Table (OBT):** Denormalized wide tables for analytics engines like BigQuery/Snowflake
- **Medallion (Bronze/Silver/Gold):** Lakehouse pattern in Databricks

Choice depends on query patterns, source complexity, and tooling.

---

## 4. Slowly Changing Dimensions (SCD)

SCD handles changes in dimension attributes over time.

| Type | Behavior | Use Case |
|---|---|---|
| SCD 0 | Never changes | Static attributes (DOB, SSN) |
| SCD 1 | Overwrite | Corrections; no history needed |
| SCD 2 | Add new row with effective dates + active flag | Full history (most common) |
| SCD 3 | Add new column (prev_value, current_value) | Limited history, only last change |
| SCD 4 | Separate history table | Frequent changes, keep main dim small |
| SCD 6 | Combination of 1+2+3 (hybrid) | Complex tracking needs |

**SCD Type 2 Example (PySpark):**

```python
from pyspark.sql.functions import current_date, lit

# new_data = incoming changes; dim = existing dimension
updates = new_data.join(dim, "cust_id", "left") \
    .filter("dim.name <> new_data.name OR dim.cust_id IS NULL")

# Close old records
closed = dim.join(updates.select("cust_id"), "cust_id", "inner") \
    .withColumn("end_date", current_date()) \
    .withColumn("is_active", lit(False))

# Insert new records
new_rows = new_data.withColumn("start_date", current_date()) \
    .withColumn("end_date", lit(None).cast("date")) \
    .withColumn("is_active", lit(True))

final = dim.unionByName(closed).unionByName(new_rows)
```

---

## 5. Schema Evolution in Parquet

When the gold layer is Parquet and schema changes while moving to curated:

**Options:**
1. **Use Delta Lake instead** — supports `mergeSchema` and schema evolution natively
2. **Merge Schema at read time:**
   ```python
   df = spark.read.option("mergeSchema", "true").parquet("/gold/")
   ```
3. **Schema-on-read with explicit mapping:** read with target schema, null-fill missing columns
4. **Versioned partitions:** write new data to new folder, union at read time
5. **Evolve schema pre-write:** add missing columns via `withColumn(col_name, lit(None).cast(type))`

```python
# Handling new columns added at source
target_cols = ["id", "name", "dept", "new_col"]
for c in target_cols:
    if c not in df.columns:
        df = df.withColumn(c, lit(None))
df.select(*target_cols).write.mode("append").parquet("/curated/")
```

---

## 6. Handling Null/Blank Data

To decide if null/blank in a non-primary column is needed:
1. **Check business rules:** is the field mandatory for downstream use?
2. **Profile the data:** `df.filter(col("x").isNull()).count()` — high null % may indicate source issue
3. **Check source contract / schema:** is it nullable by design?
4. **Check downstream dependencies:** reports, ML features, joins

If null is invalid: either reject, alert, or impute. If valid: represent explicitly.

**Representing null/blank with constants:**

```python
from pyspark.sql.functions import col, when, lit

df = df.withColumn("status", when(col("status").isNull() | (col("status") == ""), lit("UNKNOWN")).otherwise(col("status")))
df = df.withColumn("amount", when(col("amount").isNull(), lit(-1)).otherwise(col("amount")))
```

- **String columns:** use `"UNKNOWN"`, `"N/A"`, or `""`
- **Integer columns:** use `-1`, `0`, or a sentinel like `-9999` (ensure it won't collide with valid values)
- **Avoid** overwriting nulls silently without documenting the rule

---

## 7. Latest Record Without Timestamp

If there's no timestamp/version flag and duplicates exist, you need another signal — monotonic ID at ingest, or file-level metadata.

```python
# Example data:
# employeeid | name  | desg
# 1          | Shank | sw
# 2          | Sam   | sw
# 1          | Shank | ssw   <- latest

from pyspark.sql.functions import monotonically_increasing_id, row_number
from pyspark.sql.window import Window

# Add an ingestion ordering column
df = df.withColumn("ingest_id", monotonically_increasing_id())

w = Window.partitionBy("employeeid").orderBy(col("ingest_id").desc())
latest = df.withColumn("rn", row_number().over(w)).filter("rn = 1").drop("rn")
```

**Better long-term fix:** add `ingest_timestamp` or `file_modification_time` using `input_file_name()` and file metadata on load.

---

## 8. Spark Optimization Techniques

1. **Partitioning & Bucketing** — reduce shuffle
2. **Broadcast join** for small tables: `broadcast(df_small)`
3. **Cache/Persist** frequently reused DataFrames
4. **Predicate Pushdown** — filter early, push filters to source
5. **Projection Pushdown** — select only needed columns
6. **Avoid `collect()`** on large data
7. **Use columnar formats** (Parquet/Delta) with compression (Snappy/ZSTD)
8. **Salting** for skewed keys
9. **Adaptive Query Execution (AQE):** `spark.sql.adaptive.enabled=true`
10. **Tune shuffle partitions:** `spark.sql.shuffle.partitions`
11. **Avoid UDFs** when built-in functions exist (they break Catalyst optimization)
12. **Use `repartition(col)` before join** on same keys for co-location
13. **Dynamic Partition Pruning (DPP)** for star schema joins
14. **Z-Ordering (Delta)** for multi-column filter optimization

---

## 9. Pandas Operations

### Extract data from DB
```python
import pandas as pd
from sqlalchemy import create_engine

engine = create_engine("postgresql://user:pwd@host:5432/db")
df = pd.read_sql("SELECT * FROM employees WHERE dept='IT'", engine)
```

### Read/write Excel
```python
df = pd.read_excel("input.xlsx", sheet_name="Sheet1")
df.to_excel("output.xlsx", index=False, sheet_name="Result")
```

### Merge and Join
```python
# merge = SQL-style join
merged = pd.merge(df1, df2, on="emp_id", how="inner")  # inner, left, right, outer

# join uses index by default
joined = df1.set_index("emp_id").join(df2.set_index("emp_id"), how="left")

# concat stacks DataFrames
combined = pd.concat([df1, df2], axis=0)   # rows
combined = pd.concat([df1, df2], axis=1)   # columns
```

---

## 10. Data Lake CDC & Incremental Load

**Techniques to manage CDC in a data lake (ADLS Gen2 / S3):**

1. **Timestamp / watermark based** — track `last_modified` column, load `WHERE updated_at > last_run_ts`
2. **Change tracking / CDC from source** — use source DB's CDC feature (Debezium, log-based)
3. **MERGE INTO Delta** for upserts
4. **Delta Live Tables (DLT)** — declarative pipeline with `APPLY CHANGES INTO`
5. **File-based** — only process new files (autoloader / triggers)

**Incremental load pattern with Delta:**

```python
from delta.tables import DeltaTable

target = DeltaTable.forPath(spark, "/silver/customers")
target.alias("t").merge(
    source.alias("s"),
    "t.cust_id = s.cust_id"
).whenMatchedUpdateAll() \
 .whenNotMatchedInsertAll() \
 .execute()
```

---

## 11. Data Quality

Common data quality checks:
- **Null/blank checks** on critical columns
- **Uniqueness** on primary keys
- **Range checks** (age > 0, amount >= 0)
- **Referential integrity** (foreign key exists)
- **Schema validation** (column count, types)
- **Duplicate detection**
- **Regex / pattern** (email, phone)
- **Row count drift** vs expected
- **Freshness** (max timestamp within SLA)

Tools: **Great Expectations, Deequ, Soda, dbt tests, Delta constraints**

```python
# Delta table constraint
spark.sql("""
  ALTER TABLE customers
  ADD CONSTRAINT valid_age CHECK (age > 0 AND age < 120)
""")
```

---

## 12. Dimensions & SCD Types

**Dimension** = descriptive/contextual attribute of a business entity (Customer, Product, Date, Store) used to slice/filter facts.

SCD types: see section [4](#4-slowly-changing-dimensions-scd).

---

## 13. Medallion Architecture

A layered data organization pattern:

| Layer | Purpose | Quality |
|---|---|---|
| **Bronze** | Raw ingestion, append-only, schema-on-read | As-is from source |
| **Silver** | Cleansed, deduplicated, joined, standardized | Validated |
| **Gold** | Business-level aggregates, feature tables, KPIs | Curated for consumption |

**Benefits:** reprocessing from any stage, lineage, separation of concerns, consumer-friendly gold tables.

---

## 14. Delta Lake

**Key features:**
- **ACID transactions** via transaction log (`_delta_log/*.json`)
- **Time travel:** `SELECT * FROM t VERSION AS OF 5` or `TIMESTAMP AS OF '2024-01-01'`
- **Schema enforcement & evolution**
- **MERGE / UPDATE / DELETE** support
- **Scalable metadata**
- **Z-Ordering** for multi-dim locality
- **OPTIMIZE** for compaction, **VACUUM** for cleanup
- **Change Data Feed (CDF)** for downstream CDC

**How Delta stores data:** Parquet files + transaction log. Every write creates a new version in `_delta_log`. Readers reconstruct the current state by replaying the log.

```sql
-- Time travel
SELECT * FROM events VERSION AS OF 10;

-- Optimize & compact
OPTIMIZE events ZORDER BY (user_id);

-- Clean old files
VACUUM events RETAIN 168 HOURS;
```

---

## 15. Database vs Data Warehouse

| Aspect | Database (OLTP) | Data Warehouse (OLAP) |
|---|---|---|
| Purpose | Transactions | Analytics & reporting |
| Schema | Normalized (3NF) | Denormalized (star/snowflake) |
| Query type | Short, many small reads/writes | Long, complex, aggregations |
| Data | Current, operational | Historical, integrated |
| Users | Apps, customers | Analysts, BI |
| Size | GBs | TBs–PBs |
| Examples | PostgreSQL, MySQL, Oracle | Snowflake, BigQuery, Redshift, Synapse |

---

## 16. Data Pipeline Creation

**Generic steps to build a data pipeline:**
1. **Source identification** (DB, API, file, stream)
2. **Ingestion** (batch/stream, full/incremental)
3. **Landing/Bronze** in raw format
4. **Validation & cleansing** to Silver
5. **Transformation & business rules** to Gold
6. **Storage & publishing** (warehouse / serving layer)
7. **Orchestration** (Airflow, ADF, Databricks Workflows)
8. **Monitoring, logging, alerting**
9. **Data quality & observability** (Great Expectations, Monte Carlo)
10. **CI/CD & version control** (Git, dbt, pytest)

---

## 17. Slow SQL Query Troubleshooting

1. **Check the execution plan:** `EXPLAIN ANALYZE` / `EXPLAIN FORMATTED`
2. **Look for full table scans** — add indexes on filter/join columns
3. **Check statistics** — run `ANALYZE TABLE`
4. **Rewrite the query:**
   - replace `SELECT *` with required columns
   - push filters before joins
   - avoid `OR` in WHERE; use `UNION ALL`
   - replace correlated subqueries with joins or CTEs
5. **Check join strategy** — nested loop vs hash vs merge
6. **Partition/Bucket** large tables
7. **Materialize intermediate results** (temp tables / CTEs)
8. **Check for data skew** and lock contention
9. **Increase warehouse size** if it's a compute issue

---

## 18. Slow Spark Application Troubleshooting

1. **Spark UI:** check stages, tasks, shuffle read/write, GC time
2. **Identify skew** — task duration variance, one task taking much longer
3. **Check spills** to disk (memory pressure)
4. **Review DAG** — unnecessary shuffles? wide transformations?
5. **Check partition count** — too few (under-parallelism) or too many (small files)
6. **Broadcast** small tables
7. **Cache** reused DataFrames
8. **Tune executors:** cores, memory, instances
9. **Enable AQE** for dynamic optimization
10. **Profile the data:** null-heavy keys, skewed keys → salt them

---

## 19. Conceptual, Logical, Physical Data Models

| Model | Scope | Content |
|---|---|---|
| **Conceptual** | High-level entities & relationships | Entity names (Customer, Order), no attributes |
| **Logical** | Attributes, keys, relationships | Detailed ER model, no physical details |
| **Physical** | DB-specific implementation | Tables, columns, datatypes, indexes, partitions |

---

## 20. OLAP vs OLTP

| Aspect | OLTP | OLAP |
|---|---|---|
| Workload | Transactional | Analytical |
| Operations | Insert/update/delete, small reads | Large aggregations, complex queries |
| Schema | Normalized | Star/snowflake, denormalized |
| Data | Current | Historical |
| Response time | ms | Seconds to minutes |
| Users | 1000s of concurrent users | Few analysts |

---

## 21. Data Migration OLTP to OLAP

**Steps:**
1. **Discovery:** catalog tables, volumes, dependencies, SLAs
2. **Design target model** (dimensional model, fact/dim tables)
3. **Source-to-target mapping** for each attribute
4. **Build ingestion:** initial full load + CDC/incremental
5. **Transformation:** data type casting, business rules, SCD
6. **Data quality & reconciliation:** row counts, checksum, sum checks
7. **Cutover strategy:** parallel run, then switchover
8. **Decommission legacy**

**If only DDL + sample data available (no legacy DB access):**
- Use DDL to build the schema
- Use sample data to infer types, null patterns, cardinalities
- Build the target model based on sample + interview with SMEs
- Plan for a data migration once access is granted; until then, stub with the sample

**If 500 select SQLs from reports are available:**
- Parse SQLs to identify: used tables, used columns, join keys, filters, aggregations
- This tells you which columns/tables are *actually in use* (prioritize those)
- Identify business KPIs from aggregations
- Detect derived columns and map to target gold model

---

## 22. Kimball vs Inmon

| Aspect | Kimball (bottom-up) | Inmon (top-down) |
|---|---|---|
| Approach | Data marts first, then enterprise view | Enterprise DW first, then marts |
| Modeling | Dimensional (star schema) | Normalized (3NF) |
| Delivery | Faster, iterative | Slower, comprehensive |
| Storage | Denormalized | Normalized |
| Querying | Faster for BI | Requires joins |
| Best for | Departmental analytics | Enterprise-wide integration |

My preference depends on context — Kimball for agile BI delivery, Inmon for regulated, enterprise-wide data integration.

---

## 23. RDBMS vs NoSQL

| Feature | RDBMS | NoSQL |
|---|---|---|
| Schema | Fixed | Flexible |
| Scaling | Vertical | Horizontal |
| ACID | Yes | Often eventual consistency |
| Query | SQL | Varies (key-value, doc, graph) |
| Use case | Transactions, structured | Large-scale, semi/unstructured |
| Examples | PostgreSQL, MySQL | MongoDB, Cassandra, Redis, DynamoDB |

**NoSQL categories:** key-value (Redis), document (MongoDB), column-family (Cassandra), graph (Neo4j).

---

## 24. Python Generators, Return vs Yield

A **generator** is a lazy iterator. It produces values one at a time, saving memory.

```python
def count_up_to(n):
    i = 1
    while i <= n:
        yield i
        i += 1

for x in count_up_to(5):
    print(x)   # 1 2 3 4 5
```

**`return` vs `yield`:**
- `return` ends the function and returns one value (or tuple)
- `yield` pauses the function, returning a value; next call resumes from that point

**Can we use `return` and `yield` in the same function?**
Yes — `return` inside a generator raises `StopIteration` with the returned value (accessible via `StopIteration.value`). You can't use `return expr` in Python 2, but in Python 3 it's allowed in generators.

```python
def gen():
    yield 1
    yield 2
    return "done"   # legal, signals end
```

---

## 25. Multithreading vs Multiprocessing

| Aspect | Multithreading | Multiprocessing |
|---|---|---|
| Memory | Shared | Separate per process |
| GIL impact | Yes (CPython) — limits CPU parallelism | No |
| Best for | I/O-bound (network, disk) | CPU-bound (computation) |
| Overhead | Low | High (process creation) |
| Communication | Easy (shared memory) | Via queues, pipes, shared mem |

```python
# Multithreading (I/O-bound)
from concurrent.futures import ThreadPoolExecutor
with ThreadPoolExecutor(max_workers=4) as ex:
    ex.map(download_url, urls)

# Multiprocessing (CPU-bound)
from multiprocessing import Pool
with Pool(4) as p:
    p.map(heavy_compute, data)
```

---

## 26. Set, List, Tuples

| Feature | List | Tuple | Set |
|---|---|---|---|
| Syntax | `[1,2,3]` | `(1,2,3)` | `{1,2,3}` |
| Mutable | Yes | No | Yes |
| Ordered | Yes | Yes | No (insertion-ordered in 3.7+ but semantically unordered) |
| Duplicates | Yes | Yes | No |
| Indexable | Yes | Yes | No |
| Use case | Sequences that change | Fixed records | Unique items, set ops |

```python
# Common operations
lst = [1, 2, 3]; lst.append(4); lst[0] = 9
tup = (1, 2, 3)  # cannot modify
st = {1, 2, 3}; st.add(4); st & {2, 4}   # {2, 4}
```

---

## 27. Python Decorators

A decorator is a function that takes another function and returns a modified one — used for cross-cutting concerns (logging, auth, timing, caching).

```python
import time
from functools import wraps

def timer(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        start = time.time()
        result = func(*args, **kwargs)
        print(f"{func.__name__} took {time.time()-start:.4f}s")
        return result
    return wrapper

@timer
def slow_add(a, b):
    time.sleep(0.5)
    return a + b

slow_add(2, 3)   # slow_add took 0.5003s
```

**Uses:** `@staticmethod`, `@classmethod`, `@property`, `@lru_cache`, Flask/FastAPI routing, auth checks, retry logic.

---

## 28. Airflow: XComs and Dynamic DAGs

### XComs (Cross-Communication)
Mechanism for tasks to share small pieces of data. Stored in metadata DB.

```python
def push_fn(**ctx):
    ctx["ti"].xcom_push(key="count", value=42)

def pull_fn(**ctx):
    val = ctx["ti"].xcom_pull(key="count", task_ids="push_task")
    print(val)   # 42
```

**Use for small values** (IDs, file names). Not suited for large data.

### Dynamic DAGs
DAGs generated programmatically based on config/metadata.

```python
# dag_factory.py
def create_dag(dag_id, schedule):
    dag = DAG(dag_id, schedule_interval=schedule, start_date=datetime(2024,1,1))
    # ...
    return dag

configs = [{"id": "dag_a", "sched": "@daily"}, {"id": "dag_b", "sched": "@hourly"}]
for cfg in configs:
    globals()[cfg["id"]] = create_dag(cfg["id"], cfg["sched"])
```

**Dynamic Task Mapping (Airflow 2.3+):**
```python
@task
def process(file): ...
process.expand(file=["a.csv", "b.csv", "c.csv"])
```

---

## 29. MLOps Fundamentals

**MLOps = ML + DevOps + DataOps**, focused on productionizing ML.

**Why MLOps:**
- Reproducibility, versioning (code, data, model)
- Automated retraining and deployment
- Monitoring for drift and performance degradation
- Governance, compliance, audit trail

**Key concepts:**
- **Pipelines:** training, inference, retraining
- **Model registry:** versioned models with stages (staging, production)
- **Feature store:** centralized, versioned feature definitions
- **Model monitoring:** data drift, concept drift, prediction drift, latency
- **Model analysis:** SHAP/LIME for explainability, fairness metrics, confusion matrix, ROC-AUC
- **Model versioning:** MLflow, DVC — track `code + data + params + metrics + artifacts`
- **Rollout strategies:** shadow, canary, A/B, blue-green — mitigate global impact
- **Retraining triggers:** scheduled, drift-based, performance-based

**Data Scientist vs MLOps Engineer:**
- Data Scientist: exploration, feature engineering, model training, evaluation
- MLOps Engineer: CI/CD, pipelines, deployment, monitoring, infrastructure, reliability

**Python libraries:** `mlflow`, `dvc`, `kubeflow`, `bentoml`, `evidently`, `whylogs`, `great_expectations`, `feast` (feature store), `seldon-core`, `ray`.

**If deployed model underperforms:**
1. Detect via monitoring (drift, metrics)
2. Root-cause: data drift, feature issue, label shift, pipeline bug
3. Rollback to previous version
4. Retrain with recent data
5. Re-evaluate and redeploy (shadow/canary)

---

## 30. Spark Execution Flow

When a job is submitted:
1. **Driver** builds a **logical plan** from code
2. **Catalyst optimizer** produces an **optimized logical plan** → **physical plan**
3. Action triggers a **Job**
4. DAG scheduler splits into **Stages** (at shuffle boundaries)
5. Each stage splits into **Tasks** (1 per partition)
6. **Tasks** run on **Executors** (workers)
7. Results return to driver (or written out)

```
Job  →  Stages  →  Tasks
```

Narrow transformations stay in one stage; wide transformations (shuffle) create a new stage.

---

## 31. Deduplication

**Spark syntax:**
```python
# all columns
df_dedup = df.dropDuplicates()

# based on subset of columns
df_dedup = df.dropDuplicates(["emp_id", "dept"])

# distinct is similar but for ALL columns only
df_distinct = df.distinct()
```

**SQL:**
```sql
SELECT DISTINCT emp_id, name FROM employees;

-- keep latest per emp_id
SELECT * FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY emp_id ORDER BY updated_at DESC) rn
  FROM employees
) WHERE rn = 1;
```

---

## 32. Identifying Unique Records in SQL

```sql
-- Option 1: DISTINCT
SELECT DISTINCT * FROM employees;

-- Option 2: GROUP BY with HAVING
SELECT emp_id, COUNT(*) cnt
FROM employees
GROUP BY emp_id
HAVING cnt = 1;

-- Option 3: ROW_NUMBER
SELECT * FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY emp_id ORDER BY emp_id) rn
  FROM employees
) WHERE rn = 1;
```

---

## 33. RDD Creation

Different ways to create RDDs:

```python
sc = spark.sparkContext

# 1. parallelize a local collection
rdd1 = sc.parallelize([1, 2, 3, 4, 5])

# 2. from an external file
rdd2 = sc.textFile("file.txt")

# 3. from a DataFrame
rdd3 = df.rdd

# 4. from an existing RDD (transformation)
rdd4 = rdd1.map(lambda x: x * 2)

# 5. from Hadoop InputFormat
rdd5 = sc.newAPIHadoopFile(...)
```

---

## 34. DataFrame

A **DataFrame** is a distributed collection of data organized into named columns — equivalent to a table in RDBMS or a Pandas DataFrame but partitioned across a cluster.

- Built on top of RDD but adds **schema** and **Catalyst optimizer**
- Immutable, lazy-evaluated
- Supports SQL and DataFrame API
- Columnar execution via Tungsten
- Much more optimized than raw RDDs

```python
df = spark.read.parquet("/data/employees")
df.printSchema()
df.filter("dept = 'IT'").show()
```

---

## 35. Data Spill

**Spill** = when a task's data exceeds available memory and is written to disk, slowing the job.

**Causes:**
- Skewed partitions
- Too few partitions (large partition size)
- Insufficient executor memory
- Expensive operations (join, groupBy) on large data

**How to handle:**
- Increase `spark.executor.memory`
- Increase `spark.sql.shuffle.partitions`
- Repartition by skewed key with salting
- Broadcast small tables instead of shuffling
- Reduce data before wide transformations (filter, project)
- Enable AQE to automatically coalesce/split

---

## 36. Narrow vs Wide Transformations

| Transformation | Characteristic | Examples |
|---|---|---|
| **Narrow** | One parent partition → one child partition. No shuffle. | `map`, `filter`, `union`, `mapPartitions` |
| **Wide** | Multiple parent partitions → one child (requires shuffle) | `groupByKey`, `reduceByKey`, `join`, `distinct`, `repartition` |

**How Spark identifies:** at DAG building time, the execution plan sees the type of partitioner requirement. Wide transformations inject a **ShuffleDependency**; narrow ones have **NarrowDependency**. Each shuffle creates a new **Stage**.

---

## 37. row_number, rank, dense_rank

```python
from pyspark.sql.window import Window
from pyspark.sql.functions import row_number, rank, dense_rank

w = Window.partitionBy("dept").orderBy(col("salary").desc())

df.withColumn("rn", row_number().over(w)) \
  .withColumn("rk", rank().over(w)) \
  .withColumn("drk", dense_rank().over(w))
```

| Function | Behavior on ties |
|---|---|
| `row_number` | Unique per row (1,2,3,4) |
| `rank` | Same rank for ties, skips next (1,2,2,4) |
| `dense_rank` | Same rank for ties, no skip (1,2,2,3) |

---

## 38. How Delta Tables Work

A Delta table = Parquet files + `_delta_log/` directory containing JSON commit files.

- Each write produces a new JSON log file describing the actions (add file, remove file, metadata)
- Reader reads the log (with periodic Parquet checkpoints) to reconstruct the current state
- Supports ACID through optimistic concurrency control (OCC) on the log
- Time travel is reading an older log version

```
/my_table/
  _delta_log/
    00000000000000000000.json
    00000000000000000001.json
    00000000000000000010.checkpoint.parquet
  part-00000-abc.snappy.parquet
  part-00001-xyz.snappy.parquet
```

---

## 39. Data Skewness

**Skew** = one (or few) keys have disproportionately large amount of data → one task runs much longer than others.

**How to detect:** Spark UI stage details show very long task duration for a subset; large input size on few tasks.

**How to resolve:**
1. **Salting:** append random prefix to skewed keys, then aggregate in two stages
2. **Broadcast join** when one side is small
3. **Skew join hint:** `SELECT /*+ SKEW('table', 'key') */ ...`
4. **AQE skew join optimization** (automatic in Spark 3+)
5. **Filter skewed key separately** and process independently

```python
# Salting example
from pyspark.sql.functions import concat, lit, rand, floor, expr

# Left side: salt the skew key
left_salted = df_left.withColumn("salt", floor(rand() * 10)) \
                     .withColumn("key_salted", concat(col("key"), lit("_"), col("salt")))

# Right side: explode by salt range
right_exploded = df_right.withColumn("salt", explode(expr("sequence(0, 9)"))) \
                         .withColumn("key_salted", concat(col("key"), lit("_"), col("salt")))

result = left_salted.join(right_exploded, "key_salted")
```

---

## 40. MERGE INTO Syntax

```sql
MERGE INTO target t
USING source s
  ON t.id = s.id
WHEN MATCHED AND s.op = 'DELETE' THEN DELETE
WHEN MATCHED THEN UPDATE SET t.name = s.name, t.updated_at = s.updated_at
WHEN NOT MATCHED THEN INSERT (id, name, updated_at) VALUES (s.id, s.name, s.updated_at)
WHEN NOT MATCHED BY SOURCE THEN UPDATE SET t.is_active = false;  -- Delta feature
```

---

## 41. Spark Memory Management

Executor memory is divided into:

- **Reserved memory** (~300 MB): Spark internals
- **User memory** (40% of remaining): user data structures, UDFs
- **Spark memory** (60% of remaining, controlled by `spark.memory.fraction`):
  - **Execution** (shuffle, join, sort, aggregation)
  - **Storage** (cache, broadcast)
  - Dynamic sharing: execution can evict storage

**Off-heap memory** (`spark.memory.offHeap.enabled`, `spark.memory.offHeap.size`): avoids GC by allocating outside JVM heap — useful for very large datasets.

Key parameters:
- `spark.executor.memory` — JVM heap per executor
- `spark.executor.memoryOverhead` — off-heap and container overhead
- `spark.memory.fraction` — fraction of heap for Spark (default 0.6)
- `spark.memory.storageFraction` — fraction of Spark memory for storage (default 0.5)

---

## 42. Star vs Snowflake Schema

| Aspect | Star | Snowflake |
|---|---|---|
| Dimensions | Denormalized (single table per dim) | Normalized (dim split into sub-dims) |
| Joins | Fewer joins | More joins |
| Query speed | Faster | Slower |
| Storage | More redundancy | Less redundancy |
| ETL | Simpler | More complex |

**Use Star** when query performance matters most (most BI cases).
**Use Snowflake** when storage is a concern, dimensions are large, or hierarchies need modeling.

---

## 43. Change Data Capture (CDC)

**CDC** = capturing changes (insert/update/delete) in a source system to propagate downstream.

**Methods:**
1. **Timestamp/version columns** (`updated_at`)
2. **Triggers** on source tables
3. **Log-based** (DB transaction log — Debezium, Oracle GoldenGate, SQL Server CDC)
4. **Diff-based** (compare snapshots — expensive)

**Implementation in Spark:**

```python
from delta.tables import DeltaTable

source = spark.read.format("delta").load("/cdc_source")  # has op column I/U/D

target = DeltaTable.forPath(spark, "/silver/customers")
target.alias("t").merge(
    source.alias("s"),
    "t.id = s.id"
).whenMatchedDelete("s.op = 'D'") \
 .whenMatchedUpdate(condition="s.op = 'U'", set={"name": "s.name", "email": "s.email"}) \
 .whenNotMatchedInsert(condition="s.op = 'I'", values={"id": "s.id", "name": "s.name", "email": "s.email"}) \
 .execute()
```

**Delta Change Data Feed (CDF)** auto-tracks changes:
```sql
ALTER TABLE t SET TBLPROPERTIES (delta.enableChangeDataFeed = true);
SELECT * FROM table_changes('t', 5, 10);
```

---

## 44. Parquet vs Avro

| Feature | Parquet | Avro |
|---|---|---|
| Format | Columnar | Row-based |
| Use case | Analytics, OLAP | Streaming, serialization, OLTP-style |
| Compression | Excellent (columnar) | Good (row) |
| Schema evolution | Supports add/remove | Very strong schema evolution |
| Splittable | Yes | Yes |
| Read efficiency | Great for partial columns | Great for full rows |

**Rule of thumb:** Parquet for analytics (where you read few columns at a time); Avro for streaming/Kafka payloads.

---

## 45. Concurrent Transactions on Delta

Delta uses **optimistic concurrency control**:
1. Each writer reads the latest snapshot version
2. Performs its transformation
3. At commit time, writes a new log file with version N+1
4. If another writer already committed N+1, this writer's commit fails and Delta checks if the conflicting changes affect the same files
5. If no conflict, Delta retries; if there is conflict, the transaction fails

**Isolation levels:** `WriteSerializable` (default) and `Serializable`.

Data is stored as Parquet files; each transaction adds/removes files atomically via the log. Conflicts happen on the same files, not individual rows.

---

## 46. Coding: Recipes Count

```python
recipes = {
    "Pancakes": ["flour", "eggs", "milk", "butter"],
    "Omelette": ["eggs", "milk", "cheese", "spinach"],
    "Smoothie": ["banana", "milk", "honey", "berries"],
    "Salad":    ["spinach", "nuts", "berries", "cheese"]
}

ingredients = {"milk": 20, "egg": 10, "butter": 2}

def count_recipes(recipes, available):
    count = 0
    for name, needed in recipes.items():
        # Normalize "eggs" -> "egg" if needed
        if all(i in available and available[i] > 0 for i in needed):
            count += 1
    return count

# Note: the data has 'eggs' in recipes but 'egg' in ingredients.
# Depending on the interpretation, you normalize with a mapping
# or require an exact match. Assuming normalization:

def normalize(name):
    return name.rstrip("s")   # crude; use singularize lib in prod

def count_recipes_norm(recipes, available):
    avail_norm = {normalize(k): v for k, v in available.items()}
    count = 0
    for name, needed in recipes.items():
        if all(normalize(i) in avail_norm and avail_norm[normalize(i)] > 0 for i in needed):
            count += 1
    return count

print(count_recipes_norm(recipes, ingredients))
# Pancakes needs flour - not in ingredients → 0
# With only {milk, egg, butter}, no recipe is makeable
```

---

## 47. Coding: DataFrame Sum by Item

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import sum as _sum

spark = SparkSession.builder.getOrCreate()

data = [(1, "apple", 15, 10),
        (2, "banana", 30, 20),
        (3, "orange", 10, 30),
        (2, "banana", 30, 40)]
schema = ["product_id", "item", "quantity", "price"]

df = spark.createDataFrame(data, schema)

# total quantity per item
result = df.groupBy("item").agg(_sum("quantity").alias("total_quantity"))
result.show()

# total production value per item (quantity * price)
from pyspark.sql.functions import col
result2 = df.withColumn("value", col("quantity") * col("price")) \
            .groupBy("item").agg(_sum("value").alias("total_value"))
result2.show()
```

---

## 48. Hive Internal vs External Tables

| Feature | Internal (Managed) | External |
|---|---|---|
| Data location | Managed by Hive (warehouse dir) | User-specified path |
| Drop table | Deletes metadata + data | Deletes metadata only; data remains |
| Use case | Temp / Hive-owned data | Shared data, data shared across tools |
| LOAD behavior | Moves files into warehouse | References files in place |

```sql
-- Internal
CREATE TABLE emp (id INT, name STRING);

-- External
CREATE EXTERNAL TABLE emp_ext (id INT, name STRING)
LOCATION '/data/emp';
```

**Partitions** physically subdivide data by column values (e.g., `year`, `month`) → enables partition pruning.

---

## 49. DELETE vs DROP vs TRUNCATE

| Operation | Removes | Structure | Rollback | Logging |
|---|---|---|---|---|
| `DELETE` | Specific rows (WHERE) | Kept | Yes (DML) | Full |
| `TRUNCATE` | All rows | Kept | Usually no (DDL) | Minimal |
| `DROP` | Everything (table + metadata) | Removed | No | Minimal |

```sql
DELETE FROM emp WHERE dept = 'IT';  -- 20 rows gone, structure remains
TRUNCATE TABLE emp;                 -- all rows gone, table structure intact
DROP TABLE emp;                     -- table completely removed
```

---

## 50. Coding: Sort List Based on Another List

**Python:**
```python
l1 = ['a', 'b', 'c']
l2 = [10, 5, 20]

# Sort l1 based on l2's values
sorted_l1 = [x for _, x in sorted(zip(l2, l1))]
print(sorted_l1)   # ['b', 'a', 'c']
```

**PySpark:**
```python
df = spark.createDataFrame([("a", 10), ("b", 5), ("c", 20)], ["label", "val"])
df.orderBy("val").select("label").show()
# +-----+
# |label|
# +-----+
# |    b|
# |    a|
# |    c|
# +-----+
```

---

## 51. Coding: Remove Duplicates

```python
l = [0, 1, 1, 2, 3, 3, 4]

# 1. Using set (order not preserved)
unique1 = list(set(l))                       # [0,1,2,3,4]

# 2. Using dict.fromkeys (order preserved, Py3.7+)
unique2 = list(dict.fromkeys(l))             # [0,1,2,3,4]

# 3. Manual loop
unique3 = []
for x in l:
    if x not in unique3:
        unique3.append(x)                    # [0,1,2,3,4]
```

**Completely remove duplicated values (keep only those that appear once):**
```python
from collections import Counter
l = [0, 1, 1, 2, 3, 3, 4]
only_once = [x for x, c in Counter(l).items() if c == 1]
print(only_once)   # [0, 2, 4]
```

---

## 52. Coding: Salary Consistently Increasing

Input:
```
emp_id, salary, year
1, 10, 2019
1, 8,  2018
1, 7,  2017
2, 100, 2019
2, 90,  2018
2, 95,  2017   <- 2017 salary > 2018 → not consistently increasing
```

```sql
WITH ordered AS (
  SELECT emp_id, year, salary,
         LAG(salary) OVER (PARTITION BY emp_id ORDER BY year) AS prev_salary
  FROM employee_salary
)
SELECT emp_id
FROM ordered
WHERE year > (SELECT MIN(year) FROM employee_salary es WHERE es.emp_id = ordered.emp_id)
GROUP BY emp_id
HAVING MIN(salary - prev_salary) > 0;
```

Result: `emp_id = 1` (all year-over-year diffs positive).

---

## 53. Coding: Reverse Words in a String

**Simple reverse:**
```python
s = "Hello! welcome to scala!!"
print(" ".join(s.split()[::-1]))   # "scala!! to welcome Hello!"
```

**Reverse words without moving punctuation:**

Input:  `"Hello! welcome to scala!!"`
Output: `"scala! to welcome Hello!!"`

The trick is to reverse only the word **characters**, keeping punctuation positions fixed.

```python
import re

def reverse_keep_punct(s):
    # Extract words only
    words = re.findall(r"[A-Za-z]+", s)
    reversed_words = words[::-1]

    # Walk through original, replacing each word region in order
    result = []
    i = 0
    word_idx = 0
    while i < len(s):
        if s[i].isalpha():
            # collect the word region in original
            j = i
            while j < len(s) and s[j].isalpha():
                j += 1
            # replace with reversed word
            result.append(reversed_words[word_idx])
            word_idx += 1
            i = j
        else:
            result.append(s[i])
            i += 1
    return "".join(result)

print(reverse_keep_punct("Hello! welcome to scala!!"))
# Output: "scala! welcome to Hello!!"
```

*(Note: exact output differs slightly from the spec due to word-count alignment; the idea is punctuation stays anchored to its original position.)*

---

## 54. Coding: Pair Sum Equals Target

Find index pairs whose values sum to a target.

```python
from itertools import combinations

arr = [1, 4, 2, 5, 6, 8, 9]
target = 10

# All index pairs
pairs = [(i, j) for i, j in combinations(range(len(arr)), 2) if arr[i] + arr[j] == target]
print(pairs)
# [(0, 5), (1, 3), (2, 5) ...]  (1+8, 4+6, etc.)

# Find FIRST pair only
def first_pair(arr, target):
    seen = {}
    for i, v in enumerate(arr):
        if target - v in seen:
            return (seen[target - v], i)
        seen[v] = i
    return None

print(first_pair(arr, 10))   # (1, 3) for 4+6=10
```

**Alt: sum is 13 from `[2,11,9,4,5,8,6,10,3]`:**
```python
from itertools import combinations
l = [2, 11, 9, 4, 5, 8, 6, 10, 3]
print([p for p in combinations(l, 2) if sum(p) == 13])
# [(2,11), (9,4), (5,8), (3,10)]
```

---

## 55. Spark: Shuffling

**Shuffle** = redistributing data across partitions, typically across network, to bring related records to the same executor for operations like `join`, `groupBy`, `distinct`, `repartition`.

It happens because data for a wide transformation (e.g., same key) may live on different executors.

**Why shuffles are expensive:**
- Network I/O
- Disk I/O (shuffle files written to disk)
- Serialization/deserialization
- Can cause spills

**How to minimize:**
- Broadcast small tables
- Pre-partition by join key
- Avoid unnecessary `groupBy` / `distinct`
- Use `reduceByKey` over `groupByKey`

---

## 56. Persist, Cache, Storage Levels

`cache()` = `persist(StorageLevel.MEMORY_AND_DISK)` (default for DataFrames).

Storage levels:

| Level | Memory | Disk | Deserialized | Replication |
|---|---|---|---|---|
| MEMORY_ONLY | ✓ | ✗ | ✓ | 1 |
| MEMORY_ONLY_SER | ✓ | ✗ | ✗ | 1 |
| MEMORY_AND_DISK | ✓ | ✓ | ✓ | 1 |
| MEMORY_AND_DISK_SER | ✓ | ✓ | ✗ | 1 |
| DISK_ONLY | ✗ | ✓ | ✓ | 1 |
| OFF_HEAP | off-heap | ✓ | ✗ | 1 |

```python
from pyspark.storagelevel import StorageLevel
df.persist(StorageLevel.MEMORY_AND_DISK_SER)
```

**Does data spill when caching?** Yes — `MEMORY_AND_DISK*` will spill to disk if memory is insufficient. `MEMORY_ONLY` will recompute partitions that don't fit.

---

## 57. Predicate Pushdown

**Predicate pushdown** = pushing filter conditions as close to the data source as possible, so less data is read.

Example: reading from Parquet with `WHERE year = 2024` reads only files/row-groups where `year = 2024` (using Parquet's column statistics).

Happens when:
- Source supports it (Parquet, ORC, JDBC, Delta)
- Filter is on a supported column
- The filter expression is understandable by the source

```python
# Parquet will push this down using min/max stats per row group
df = spark.read.parquet("/events").filter(col("event_date") == "2024-01-01")
```

**Projection pushdown** is analogous but for columns.

---

## 58. Scala vs Java

| Aspect | Scala | Java |
|---|---|---|
| Paradigm | Functional + OOP | OOP (functional since 8) |
| Verbosity | Concise | More verbose |
| Type inference | Strong | Weaker (improved in 10+) |
| Interop | Calls Java libs seamlessly | — |
| Immutability | Default | Optional |
| Pattern matching | Rich | Limited (since 17) |
| Used for | Spark, Akka, Kafka Streams | General purpose |

**Why Scala can access Java libraries:** both compile to JVM bytecode, so Scala can import and use any Java class directly.

---

## 59. Nil, null, None, Nothing in Scala

| Type | Meaning |
|---|---|
| `Nil` | Empty list (`List()`), of type `List[Nothing]` |
| `null` | Absence of value for reference types (Java interop) |
| `None` | Empty value in `Option[T]` (idiomatic in Scala) |
| `Nothing` | Bottom type — subtype of every other type, has no values |

```scala
val xs: List[Int] = Nil
val s: String = null            // avoid
val opt: Option[Int] = None     // preferred
def error(): Nothing = throw new RuntimeException()
```

---

## 60. Fault Tolerance in Spark

Spark achieves fault tolerance through:

1. **RDD Lineage (DAG):** each RDD remembers the transformations that built it. If a partition is lost, Spark recomputes it from lineage.
2. **Data replication** in cluster storage (HDFS/Cloud)
3. **Write-Ahead Logs (WAL)** for streaming
4. **Checkpointing** for long lineages — materializes RDD to reliable storage
5. **Task retries** on failure
6. **Speculative execution** for straggler tasks

---

## 61. Scala Garbage Collection

Scala runs on the JVM, so it uses JVM garbage collection. There is no Scala-specific GC. Common JVM GCs: **G1 (default in recent JDKs), Parallel, ZGC, Shenandoah, CMS (deprecated).**

For Spark workloads, G1 or ZGC are preferred for large heaps to minimize pause times.

---

## 62. Stage Failure Recovery

Scenario: Stage 3 has tasks `100/100, 50/50, 40/39 (1 fail)`. What happens?

- The failed task is **retried** (default up to `spark.task.maxFailures = 4`)
- If retries succeed, stage completes
- If retries exhaust, the **stage fails** → Spark attempts to re-run the stage
- Data for the failed task is **recomputed from the parent stage's shuffle output** (if still available) or by recomputing the lineage
- If the failure is due to executor/node loss, shuffle output may be lost → the **parent stage** is also re-executed to regenerate shuffle files

---

## 63. Scala Case Class

```scala
case class A(f1: String, f2: String)
val a = new A("1", "2")
a.f1 = "v2"   // ❌ does NOT work — case class fields are val (immutable) by default
```

To allow mutation:
```scala
case class A(var f1: String, var f2: String)
val a = A("1", "2")
a.f1 = "v2"   // ✓ now works
```

---

## 64. val, var, def, lazy val

| Keyword | Evaluation | Mutability | When evaluated |
|---|---|---|---|
| `val` | Eagerly, once | Immutable | At declaration |
| `var` | Eagerly, once | Mutable | At declaration (can reassign) |
| `def` | Every time called | — | On each access |
| `lazy val` | First access only | Immutable | On first access (cached after) |

```scala
val a = compute()       // compute() called now
var b = compute()       // compute() called now; b can be reassigned
def c = compute()       // compute() called each time c is accessed
lazy val d = compute()  // compute() called only on first access to d
```

---

## 65. Spark Internal Working

1. **User code → Driver** builds a logical plan
2. **Catalyst** optimizes → physical plan
3. **Action** triggers a **Job**
4. **DAG Scheduler** divides into **Stages** at shuffle boundaries
5. **Task Scheduler** sends tasks to **Executors** on worker nodes
6. Executors read data, process partitions, write shuffle output
7. Results returned to driver

**Commands like `select from t1`, `select from t2`, `join`, `filter`, `groupBy`, `saveAsTable`:**
- Spark builds one DAG across all transformations
- **Jobs:** triggered per action — `saveAsTable` (action) = 1 job typically; if you also call `.count()` etc., each action is a job
- **Stages:** narrow ops stay in one stage; each shuffle (join, groupBy) = new stage
- **Tasks:** one per partition per stage

So with `select → filter → join → groupBy → saveAsTable`:
- 1 action = 1 job
- Stages: depends on shuffles. A join on unpartitioned data = 2 stages (one per side) + shuffle + 1 merge stage; groupBy after join = another shuffle + stage. Typically 3–5 stages.
- Tasks per stage = number of partitions

---

## 66. Adaptive Query Execution (AQE)

AQE dynamically re-optimizes the query plan at runtime based on actual shuffle statistics. Introduced in Spark 3.0.

**Key features:**
- **Dynamic partition coalescing:** merges small shuffle partitions
- **Dynamic join strategy switching:** sort-merge → broadcast if one side turns small after filters
- **Dynamic skew join optimization:** splits skewed partitions

Enable with:
```python
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
```

---

## 67. Transformations in Spark

**Narrow:** `map`, `filter`, `flatMap`, `mapPartitions`, `union`, `sample`, `coalesce` (no shuffle)

**Wide:** `groupByKey`, `reduceByKey`, `join`, `cogroup`, `distinct`, `repartition`, `aggregateByKey`, `sortByKey`

**Actions** (trigger execution): `collect`, `count`, `take`, `first`, `reduce`, `foreach`, `saveAsTextFile`, `show`, `write.save`

---

## 68. Coding: Age Calculation

Input: `1995-12-01`

**Python:**
```python
from datetime import date
dob = date(1995, 12, 1)
today = date.today()
age = today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))
print(age)
```

**PySpark:**
```python
from pyspark.sql.functions import current_date, floor, months_between

df = spark.createDataFrame([("1995-12-01",)], ["dob"])
df.withColumn("age", floor(months_between(current_date(), col("dob")) / 12)).show()
```

**SQL:**
```sql
SELECT FLOOR(DATEDIFF(CURRENT_DATE, dob) / 365.25) AS age FROM t;
-- or more accurate:
SELECT TIMESTAMPDIFF(YEAR, dob, CURRENT_DATE) AS age FROM t;
```

---

## 69. Python Output Questions

### Q: `lst = ['a','b','c']; lst[-1:] = 'de'; print(lst)`
```
['a', 'b', 'd', 'e']
```
Slice assignment replaces the last element with the iterable `'de'` (which iterates to `['d', 'e']`).

### Q: Last two elements of `[1,4,7,9,12]`
```python
lst = [1,4,7,9,12]
print(lst[-2:])   # [9, 12]
```

### Q: Every third element of `[1,4,7,9,12,45,67,98,12]`
```python
lst = [1,4,7,9,12,45,67,98,12]
print(lst[::3])   # [1, 9, 67]
# (indices 0, 3, 6)
```

### Q: `tup = ('a','b',[1,2,3]); tup[2].append(99); print(tup)`
```
('a', 'b', [1, 2, 3, 99])
```
The tuple is immutable but the list inside is mutable.

### Q: 
```python
lst1 = ['cat'] + ['dog']
lst2 = lst1
lst2 += lst2
print(lst1)
```
Output: `['cat', 'dog', 'cat', 'dog']`

Because `lst2` and `lst1` point to the same list object. `lst2 += lst2` mutates the list in place (equivalent to `extend`), so `lst1` is also modified.

### Q: 
```python
class Test:
    print("hello test")   # runs when class is DEFINED

    def displ(self):
        try:
            print("hello there")
        except Exception as e:
            print("Caught an exception:", e)
        finally:
            print("Reached finally block")

tst = Test()
tst.displ()
```
Output:
```
hello test        <- from class body (runs once at definition)
hello there
Reached finally block
```

No exception is raised inside `try`, so `except` doesn't fire. `finally` always executes.

---

## 70. Kafka: Topic, Queue, Retention

**Topic:** named category where messages are published. Partitioned and replicated.

**Queue vs Topic:**
- Traditional queue: message consumed by one consumer, then gone
- Kafka topic: messages retained for a configurable period, multiple consumer groups can read independently. Within a consumer group, each partition is read by exactly one consumer.

**Retention period:** how long Kafka keeps messages. Configured per topic with `retention.ms` (time-based, default 7 days) or `retention.bytes` (size-based). After retention, old segments are deleted.

**Reading from specific index/offset from the beginning:**
```python
from kafka import KafkaConsumer, TopicPartition

consumer = KafkaConsumer(bootstrap_servers="localhost:9092",
                         auto_offset_reset="earliest",
                         enable_auto_commit=False,
                         group_id="my_group")
tp = TopicPartition("my_topic", 0)
consumer.assign([tp])
consumer.seek(tp, 0)    # start from offset 0
# or consumer.seek_to_beginning(tp)
for msg in consumer:
    print(msg.value)
```

In Spark Structured Streaming:
```python
df = (spark.readStream.format("kafka")
      .option("kafka.bootstrap.servers", "host:9092")
      .option("subscribe", "my_topic")
      .option("startingOffsets", "earliest")   # or JSON per-partition offsets
      .load())
```

---

## 71. Spark Submit Configuration

```bash
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --name my_app \
  --num-executors 10 \
  --executor-cores 4 \
  --executor-memory 8G \
  --driver-memory 4G \
  --conf spark.sql.shuffle.partitions=200 \
  --conf spark.sql.adaptive.enabled=true \
  --py-files deps.zip \
  --files config.yml \
  my_app.py arg1 arg2
```

Key configs:
- `spark.executor.instances` — number of executors
- `spark.executor.cores` — cores per executor (typically 4–5)
- `spark.executor.memory` — JVM heap per executor
- `spark.executor.memoryOverhead` — off-heap overhead (~10% of executor memory)
- `spark.driver.memory`
- `spark.sql.shuffle.partitions` — shuffle partitions (default 200)

---

## 72. Why Spark is Used in Big Data

- **In-memory computation** — 10–100× faster than MapReduce
- **Unified API** — batch, streaming, SQL, ML, graph
- **Lazy evaluation + Catalyst** optimizer
- **Language support** — Scala, Java, Python, R, SQL
- **Fault-tolerant** via RDD lineage
- **Scalable** to thousands of nodes
- **Rich ecosystem** — Delta, MLlib, Structured Streaming, GraphX

---

## 73. Unity Catalog

Unity Catalog is Databricks' centralized governance solution for data and AI assets, providing:
- **Three-level namespace:** `catalog.schema.table`
- **Fine-grained access control** (GRANT/REVOKE on table, view, column, row)
- **Data lineage** tracking
- **Audit logging**
- **Data discovery** via search
- **Centralized metadata** across workspaces
- **Delta Sharing** for cross-org data sharing

**vs Hive Metastore:** Hive is per-workspace, flat namespace, limited governance; Unity is account-level, hierarchical, with lineage and fine-grained ACLs.

---

## 74. SQL: Self Join for Manager

Table: `employee(emp_id, name, manager_id)`

```sql
SELECT e.name AS employee, m.name AS manager
FROM employee e
LEFT JOIN employee m ON e.manager_id = m.emp_id;
```

LEFT JOIN ensures top-level managers (with `manager_id IS NULL`) are still shown.

---

## 75. SQL: Join Types Row Count

Product and Category:
- Product: `(p1, c1), (p2, c1), (p3, c2), (p4, NULL)`
- Category: `(c1), (c2), (c3)`

| Join | Result rows |
|---|---|
| INNER | 3 (p1-c1, p2-c1, p3-c2) |
| LEFT | 4 (adds p4 with null category) |
| RIGHT | 4 (adds c3 with null product) |
| FULL OUTER | 5 |
| CROSS | 4 × 3 = 12 |

---

## 76. Cache vs Persist

- `cache()` = `persist(MEMORY_AND_DISK)` for DataFrames (MEMORY_ONLY for RDDs)
- `persist(level)` lets you choose any storage level (see section [56](#56-persist-cache-storage-levels))

Both are lazy — they only materialize on the next action.

---

## 77. Sort Merge Join Stages

1. **Map stage 1:** read left, partition by join key (hash), sort within partition
2. **Map stage 2:** read right, partition by join key (hash), sort within partition
3. **Reduce stage:** shuffle so matching keys co-locate; merge sorted streams in one pass

Prerequisite: both sides partitioned by the same key and sorted. Spark handles this via shuffle.

Triggered when `spark.sql.join.preferSortMergeJoin=true` and data sizes prevent broadcast.

---

## 78. DROP DUPLICATES vs DISTINCT

- `distinct()` = deduplicates based on **all columns**
- `dropDuplicates()` = deduplicates based on all columns OR a **subset** when you provide column names

```python
df.distinct()                     # all-column dedup
df.dropDuplicates()               # same as distinct()
df.dropDuplicates(["id", "date"]) # subset-based dedup
```

---

## 79. SQL Query Optimization

- Add **indexes** on filter/join columns
- Avoid `SELECT *`
- Replace correlated subqueries with joins/CTEs
- Use `EXISTS` over `IN` for large subqueries
- **Partition** and **cluster** large tables
- Push predicates close to source
- Pre-aggregate with **materialized views**
- Avoid functions on indexed columns (`WHERE UPPER(col) = 'X'` defeats indexes)
- Rewrite `OR` as `UNION ALL`
- Use `LIMIT` when possible
- Keep statistics updated (`ANALYZE TABLE`)
- Choose correct **join order** (smallest result first)

---

## 80. Indexes and Usage

| Index Type | Use |
|---|---|
| **B-tree** | Equality and range queries (default) |
| **Hash** | Equality only, very fast |
| **Bitmap** | Low-cardinality columns (gender, status) |
| **Clustered** | Physically sorts table (one per table) |
| **Non-clustered** | Secondary index pointing to rows |
| **Unique** | Enforces uniqueness |
| **Composite** | Multiple columns |
| **Covering** | Includes all columns needed by query |
| **Partial / Filtered** | Indexes only rows matching a condition |
| **Full-text** | Text search |

Trade-off: indexes speed reads but slow writes and use storage. Index only columns used in WHERE/JOIN/ORDER BY frequently.

---

## 81. Recommendation System Design

**Design a food recommendation system that suggests items based on user login time, in realtime.**

### 1. Data Model

**Tables:**
- `users(user_id, name, dob, preferences, ...)`
- `restaurants(rest_id, name, location, cuisine, ...)`
- `items(item_id, rest_id, name, category, price, tags[], ...)`
- `orders(order_id, user_id, item_id, ordered_at, rating)`
- `user_sessions(session_id, user_id, login_ts, device, location)`
- `item_stats(item_id, hour_of_day, orders_count, avg_rating)` — precomputed
- `user_profile(user_id, top_cuisines[], avg_spend, preferred_times[])`

### 2. Components

- **Event ingestion:** Kafka topic for login events
- **Stream processor:** Spark Structured Streaming / Flink — enriches login with user profile
- **Feature store:** (Feast, Redis) — serves user + item features at low latency
- **Model serving:** REST/gRPC serving a trained recommendation model
- **Cache:** Redis for hot recommendations (per user + time bucket)
- **Storage:** data lake (Bronze/Silver/Gold), serving DB (Cassandra/DynamoDB)
- **Offline training pipeline:** Airflow/Databricks — retrain nightly/weekly

### 3. Data Flow

```
User login → API → Kafka (login event)
                     ↓
              Stream processor
               ↓         ↓
       Feature store   Model server
                             ↓
                    Recommendations
                             ↓
                         Cache (Redis)
                             ↓
                          API returns to user
```

Vice versa: user's clicks, orders, ratings → Kafka → stream update features + event log for training.

### 4. Data Store Options for Recommendation Engine

- **Redis / Memcached** — ultra-low-latency cached recommendations
- **Cassandra / DynamoDB** — user-item scores at scale
- **Elasticsearch** — text + filter-based search
- **Vector DB (Pinecone, Milvus, FAISS)** — semantic/embedding-based similarity
- **Feature store** for features

### 5. How User App Gets Updated Recommendations

- **Pull model:** app calls `/recommend?user_id=X` on each login; API computes or retrieves cache
- **Push model:** backend precomputes top-K per user and pushes to user's device (notifications)
- **WebSocket / SSE:** long-lived connection for realtime updates
- Combine: on login, return cached; subscribe for subsequent push updates

### 6. Fault Tolerance

- **Kafka replication** (replication factor ≥ 3)
- **Stream processing checkpoints** (S3, HDFS)
- **Stateless services** behind a load balancer → horizontal scaling
- **Retry + dead-letter queues** for failed events
- **Database replicas** (read + failover)
- **Fallback logic:** if model serving is down, return popular items per time bucket
- **Health checks + auto-recovery** (K8s)

### 7. Handling Failures at Each Stage

| Stage | Failure | Mitigation |
|---|---|---|
| Ingestion | Kafka down | Buffer at client, retry |
| Stream processor | Node failure | Checkpoint + restart from last offset |
| Feature store | Redis miss | Fall back to feature DB |
| Model serving | Model error | Fallback to popularity-based recs |
| Cache | Cold cache | Pre-warm at deployment |
| Storage | DB failure | Replica / multi-region |

### 8. Batch Processing in Curated Layer

Although the serving is realtime (event-based), the **training and aggregations** are batch:
- Daily ETL aggregating user behavior → updates `user_profile` and `item_stats`
- Retrain the recommendation model (collaborative filtering, two-tower neural net, etc.)
- Push new model to model server via a model registry

### 9. Tech Stack Summary

- **Ingest:** Kafka
- **Stream:** Spark Structured Streaming / Flink
- **Batch:** Spark on Databricks, orchestrated by Airflow
- **Storage:** Delta Lake (Bronze/Silver/Gold), Redis (cache), Cassandra (serving)
- **ML:** MLflow for tracking, model registry, serving
- **API:** FastAPI / gRPC
- **Monitoring:** Prometheus + Grafana, Evidently for model drift

---


# Part 2 — Categorized Q&A (Additional Interview Questions)

This section contains additional interview questions organized by technology category.

## Categories

- [Databricks](#databricks)
- [Spark / PySpark](#spark--pyspark)
- [SQL](#sql)
- [Scala](#scala)
- [Python](#python)
- [Airflow](#airflow)
- [AWS](#aws)
- [Snowflake](#snowflake)
- [dbt](#dbt)
- [NoSQL](#nosql)
- [CI/CD & DevOps](#cicd--devops)
- [Cloud & Architecture (General)](#cloud--architecture-general)
- [Coding Problems](#coding-problems)

---

## Databricks

### D1. Delta Table
A Delta table is a Parquet-backed table with an additional `_delta_log/` transaction log that provides ACID guarantees, time travel, schema enforcement/evolution, and efficient upserts. See [section 14](#14-delta-lake) and [section 38](#38-how-delta-tables-work) in Part 1.

### D2. Delta Live Tables (DLT)
Declarative framework for building reliable data pipelines in Databricks. You define transformations as SQL/Python and DLT handles orchestration, data quality (expectations), lineage, error handling, and incremental processing.

```python
import dlt
from pyspark.sql.functions import col

@dlt.table
@dlt.expect_or_drop("valid_id", "id IS NOT NULL")
def silver_customers():
    return (dlt.read_stream("bronze_customers")
              .filter(col("country") == "US"))
```

**Key features:** auto-manages checkpoints, auto-retries, built-in data-quality expectations (`expect`, `expect_or_drop`, `expect_or_fail`), and support for `APPLY CHANGES INTO` for CDC.

### D3. Unity Catalog
Unified governance layer for data and AI assets in Databricks. See Part 1 [section 73](#73-unity-catalog).

**Unity Catalog vs Hive Metastore:**
| Feature | Hive Metastore | Unity Catalog |
|---|---|---|
| Scope | Per-workspace | Account-level |
| Namespace | 2-level (db.table) | 3-level (catalog.schema.table) |
| Lineage | No | Yes |
| Fine-grained ACLs | Limited | Row/column level |
| Data discovery | Manual | Built-in search |
| Audit logs | Limited | Comprehensive |

### D4. Autoloader
Databricks feature for incrementally processing new files arriving in cloud storage. Uses structured streaming with `cloudFiles` source, auto-detects schema, and maintains state via RocksDB.

```python
df = (spark.readStream
      .format("cloudFiles")
      .option("cloudFiles.format", "json")
      .option("cloudFiles.schemaLocation", "/mnt/schema/")
      .load("/mnt/raw/events/"))

(df.writeStream
   .option("checkpointLocation", "/mnt/chk/events/")
   .trigger(availableNow=True)
   .toTable("bronze.events"))
```

**Benefits:** exactly-once processing, schema inference & evolution, handles millions of files efficiently.

### D5. Shallow vs Deep Clone
- **Shallow Clone:** copies only the metadata (transaction log pointers). Data files are shared. Fast and cheap; good for short-lived experimentation.
- **Deep Clone:** copies both metadata and data files. Full, independent copy. Good for backup, disaster recovery, test-env copies.

```sql
CREATE TABLE bronze_copy SHALLOW CLONE bronze;
CREATE TABLE bronze_backup DEEP CLONE bronze;
```

### D6. Views in Databricks
- **Temporary views** (`CREATE TEMP VIEW`): session-scoped, not persisted
- **Global temp views** (`CREATE GLOBAL TEMP VIEW`): cross-session within a cluster, live in `global_temp` database
- **Regular views**: persisted in the metastore; view definition executes at query time
- **Materialized views** (Unity Catalog): results precomputed and incrementally refreshed

### D7. Troubleshoot & Optimize Databricks Jobs
1. Inspect **Spark UI / Jobs tab** for slow stages
2. Check for **skew** (one task much slower)
3. Verify **cluster sizing** — too small causes GC, too large wastes money
4. **Partition pruning** — ensure filters target partition columns
5. **Broadcast joins** for small tables
6. Use **Delta OPTIMIZE + ZORDER** for query locality
7. Enable **AQE** and **Photon** engine where available
8. Reduce **data shuffle** — repartition by join key, coalesce before write
9. Check **autoscaling** behavior and executor count
10. Use **result caching** for repeated queries (SQL Warehouse)

### D8. Liquid Clustering
A Delta Lake feature that replaces partitioning and Z-ordering. Data layout is adaptive — Delta reorganizes data based on actual query patterns without requiring partition column choice upfront.

```sql
CREATE TABLE events (id BIGINT, ts TIMESTAMP, user_id STRING, ...)
CLUSTER BY (user_id, ts);

-- Alter existing table
ALTER TABLE events CLUSTER BY (user_id);

-- Trigger clustering
OPTIMIZE events;
```

**Benefits:** no bad partition decisions, automatic rebalancing, better for high-cardinality keys, cheaper than traditional partitioning.

### D9. Delta Table vs Parquet File

| Aspect | Parquet | Delta |
|---|---|---|
| Format | Columnar files | Parquet + transaction log |
| ACID | No | Yes |
| Updates/Deletes | Requires rewrite | Supported natively |
| Time travel | No | Yes |
| Schema enforcement | No | Yes |
| Concurrent writes | Unsafe | Safe via OCC |
| Streaming | Limited | First-class |

### D10. Advantages of Delta Tables
ACID transactions, time travel, schema enforcement, unified batch + streaming, `MERGE` for upserts, scalable metadata, cheap clones, Z-order/liquid clustering, change data feed, data skipping via file stats.

### D11. Checkpoint (Structured Streaming)
A checkpoint stores the state of a streaming query — source offsets, in-progress aggregation state, and commit log — so the query can recover exactly-once after a failure/restart.

```python
(df.writeStream
   .option("checkpointLocation", "/mnt/chk/my_query/")
   .start())
```

Location must be a reliable, writable path (DBFS, ADLS, S3). **Never share** checkpoint locations across queries.

### D12. Interactive Cluster vs Job Cluster
- **Interactive (All-Purpose) Cluster:** long-running, shared by multiple users for notebooks, exploration. More expensive per DBU.
- **Job Cluster:** ephemeral, created per job run, terminated on completion. Cheaper per DBU; preferred for scheduled production workloads.

### D13. Joining Static Data with Streaming Data
Spark Structured Streaming supports stream-static joins:

```python
static_df = spark.read.format("delta").load("/dim/customers")
stream_df = (spark.readStream.format("kafka")
             .option("subscribe", "orders").load())

# Inner/left join supported
joined = stream_df.join(static_df, "customer_id", "left")
```

- Static side is re-read periodically (Delta cache); updates are reflected at micro-batch boundaries
- Right/outer joins on static side require watermark considerations
- For stream-stream joins, you need watermarks on both sides

### D14. Static vs Streaming
- **Static:** bounded dataset, processed once (batch)
- **Streaming:** unbounded, continuously arriving data processed incrementally

Spark Structured Streaming treats a stream as an "ever-growing table" — the same DataFrame API works on both.

### D15. Cluster Configuration Ideology
When sizing a cluster:
- Estimate **data volume** and **transformation complexity**
- Pick instance type: memory-optimized (joins/aggregations), compute-optimized (CPU-heavy), storage-optimized (I/O heavy)
- **Executor memory**: typical 8–32 GB, with ~10% overhead
- **Cores per executor**: 4–5 for good parallelism without GC pressure
- Enable **autoscaling** (min/max workers)
- Use **spot instances** for cost savings on tolerant workloads
- **Photon** for SQL-heavy workloads
- Separate **job clusters** for prod, **shared** for dev

### D16. Handling ODBC/JDBC Libraries at Runtime
For Databricks notebook connecting to Oracle DB:
1. Upload JDBC JAR to DBFS or workspace libraries
2. Attach library to cluster via **Cluster → Libraries → Install New → JAR**
3. Alternatively, set `spark.jars` or `spark.jars.packages` in cluster config
4. For job-specific dependencies, use `libraries` in Jobs API config

```python
df = (spark.read.format("jdbc")
      .option("url", "jdbc:oracle:thin:@host:1521:orcl")
      .option("dbtable", "employees")
      .option("user", dbutils.secrets.get("scope", "user"))
      .option("password", dbutils.secrets.get("scope", "pwd"))
      .option("driver", "oracle.jdbc.OracleDriver")
      .load())
```

### D17. Configure Connection Details Securely
Use **Databricks Secrets** (backed by Unity Catalog or key vault):

```python
user = dbutils.secrets.get(scope="prod-secrets", key="db-user")
pwd  = dbutils.secrets.get(scope="prod-secrets", key="db-pwd")
```

Never hardcode credentials in notebooks.

### D18. Call a Notebook from Another Notebook
```python
# Run and return
dbutils.notebook.run("/path/to/child_notebook", timeout_seconds=600, arguments={"env": "prod"})

# In child, return a value
dbutils.notebook.exit("success")
```

Alternatively, `%run /path/to/notebook` executes the code in-line (shares variables).

### D19. Types of Clusters
- **All-Purpose (Interactive)** — shared, for development
- **Job Cluster** — ephemeral, per-job
- **SQL Warehouse (Serverless / Pro / Classic)** — for BI/SQL workloads
- **High-Concurrency** — legacy, for multi-user shared workloads
- **Single-node** — for small / local-style workloads

### D20. How Many Files Created When Writing to Delta?
Equals the number of partitions in the DataFrame at write time (one file per partition per Spark task), plus one transaction log JSON.

Control with `repartition(n)` / `coalesce(n)` before write. `OPTIMIZE` later compacts small files into ~1 GB files.

### D21. Databricks Services / Features
Workspace, Notebooks, Jobs, Workflows, Delta Lake, Delta Live Tables, Unity Catalog, Autoloader, MLflow, Model Serving, Feature Store, SQL Warehouse, Photon, Delta Sharing, Asset Bundles, Repos (Git integration), Secrets, Mosaic AI.

### D22. CDF (Change Data Feed) in Databricks
Delta feature that emits change events (insert/update/delete) for downstream CDC.

```sql
ALTER TABLE customers SET TBLPROPERTIES (delta.enableChangeDataFeed = true);

-- Consume changes
SELECT * FROM table_changes('customers', 10)   -- from version 10
SELECT * FROM table_changes('customers', '2024-01-01', '2024-01-31');
```

### D23. Difference Between Delta Table and Delta File
- **Delta table:** a registered table in the metastore (Hive/Unity Catalog) pointing to a Delta location
- **Delta file:** the physical storage layout on disk — Parquet files + `_delta_log/`

A Delta table is a logical/metastore concept; Delta files are the physical artifacts.

### D24. Rollback from Silver Layer (Bad Data)
Use Delta time travel:
```sql
-- Identify good version
DESCRIBE HISTORY silver.customers;

-- Restore to previous version
RESTORE TABLE silver.customers TO VERSION AS OF 42;
-- or by timestamp
RESTORE TABLE silver.customers TO TIMESTAMP AS OF '2024-01-15 00:00:00';
```

### D25. Strategy if Bad Data Reaches Gold for a Specific Area
1. Identify the bad records and impacted rows
2. Isolate via `RESTORE` or targeted `MERGE` / `DELETE` + `INSERT`
3. Use **quarantine table** for bad records; notify upstream
4. Patch source issue; backfill affected partitions
5. Add **data-quality expectations** (DLT expectations or Delta constraints) to prevent recurrence

### D26. Delta Log Files
Stored in `_delta_log/` — one JSON per commit (`00000000000000000001.json`), plus periodic Parquet **checkpoints** (`00000000000000000010.checkpoint.parquet`) that snapshot the state. The log is the source of truth for table state.

### D27. Medallion Architecture
See Part 1 [section 13](#13-medallion-architecture).

### D28. Potential Causes of Cache Miss / Issues
- Memory pressure — evicted by other cached data
- Wrong storage level for data size
- Unpersist called too early
- Cluster restart — cache is in-memory only
- Query plan change prevents cache reuse (different filter/projection)

### D29. Cache Error / "Table Already in Use"
This typically happens when you try to overwrite a Delta table that's being read/cached by another operation. Fix:
- Uncache: `spark.catalog.clearCache()` or `df.unpersist()`
- Write to a temp location and then swap
- Use `MERGE` instead of overwrite when possible
- If streaming is writing, stop the stream first

### D30. PySpark Context
- **SparkContext** — entry point to the RDD API (low-level)
- **SparkSession** (Spark 2.0+) — unified entry point; wraps SparkContext, SQLContext, HiveContext
- Accessed via `spark.sparkContext`

---

## Spark / PySpark

### S1. Spark Architecture
1. **Driver** — runs the application `main()`, creates SparkContext, converts code to DAG, schedules tasks
2. **Cluster Manager** — YARN / Kubernetes / Standalone / Mesos — allocates executors
3. **Executors** — JVM processes on worker nodes that run tasks and hold data in memory/disk
4. **Tasks** — units of work, one per partition per stage
5. **Stages** — set of tasks with narrow dependencies; stage boundaries = shuffles

```
[Driver] ──(schedule)──> [Cluster Manager] ──> [Executors] ──> [Tasks on partitions]
```

### S2. Spark Internal Working
See Part 1 [section 65](#65-spark-internal-working).

### S3. Spark Optimization Techniques
See Part 1 [section 8](#8-spark-optimization-techniques).

### S4. Explode Function
Used to flatten array columns — one row per array element.

```python
from pyspark.sql.functions import explode, explode_outer

df = spark.createDataFrame([(1, ["a", "b", "c"])], ["id", "arr"])
df.withColumn("item", explode("arr")).show()
# +---+---+----+
# | id|arr|item|
# +---+---+----+
# |  1|..| a  |
# |  1|..| b  |
# |  1|..| c  |
# +---+---+----+

# explode_outer keeps rows with null/empty arrays
```

### S5. Flatten Nested JSON / Struct
```python
from pyspark.sql.functions import col

df = spark.read.json("/data/events.json")
# Suppose schema: {id, user:{name, email}, items:[...]}

# Flatten struct
df_flat = df.select(
    "id",
    col("user.name").alias("user_name"),
    col("user.email").alias("user_email"),
    explode("items").alias("item")
).select("id", "user_name", "user_email", "item.*")
```

Generic recursive flatten:
```python
from pyspark.sql.types import StructType, ArrayType

def flatten(df):
    while True:
        complex_fields = {c.name: c.dataType for c in df.schema.fields
                          if isinstance(c.dataType, (StructType, ArrayType))}
        if not complex_fields:
            break
        for name, dtype in complex_fields.items():
            if isinstance(dtype, StructType):
                expanded = [col(f"{name}.{n}").alias(f"{name}_{n}") for n in [s.name for s in dtype.fields]]
                df = df.select("*", *expanded).drop(name)
            elif isinstance(dtype, ArrayType):
                df = df.withColumn(name, explode(name))
    return df
```

### S6. Shuffling
See Part 1 [section 55](#55-spark-shuffling).

### S7. Persist, Cache, Storage Levels
See Part 1 [section 56](#56-persist-cache-storage-levels).

### S8. Predicate Pushdown
See Part 1 [section 57](#57-predicate-pushdown).

### S9. What Happens if Task 1 Fails in Stage 3
See Part 1 [section 62](#62-stage-failure-recovery).

### S10. Find Columns of a DataFrame
```python
df.columns                 # list of column names
df.schema                  # full schema
df.dtypes                  # [(col, type), ...]
df.printSchema()           # pretty print
```

### S11. 1000 Files × 50 MB — Average Age by Nationality
```python
df = spark.read.option("header", True).csv("/data/people/*.csv")
# df columns: nationality, age

from pyspark.sql.functions import avg
df.groupBy("nationality").agg(avg("age").alias("avg_age")).show()
```

Since 1000 files × 50 MB = 50 GB, ensure adequate partitions (Spark will create ~1 partition per file or per block).

### S12. Non-Null Columns After Joining Two DataFrames (Scala)
```scala
import org.apache.spark.sql.DataFrame
import org.apache.spark.sql.functions._

def joinAndKeepNonNullCols(df1: DataFrame, df2: DataFrame, joinKey: String): DataFrame = {
  val joined = df1.join(df2, Seq(joinKey), "inner")
  val colsWithValues = joined.columns.filter { c =>
    joined.filter(col(c).isNotNull).limit(1).count() > 0
  }
  joined.select(colsWithValues.map(col): _*)
}
```

### S13. Spark AQE (Adaptive Query Execution)
See Part 1 [section 66](#66-adaptive-query-execution-aqe).

### S14. How Many Transformations in Spark?
There's no fixed number. Transformations fall into:
- **Narrow:** `map`, `filter`, `flatMap`, `union`, `coalesce`, `mapPartitions`, `sample`
- **Wide:** `groupByKey`, `reduceByKey`, `aggregateByKey`, `join`, `cogroup`, `distinct`, `repartition`, `sortByKey`, `intersection`, `subtract`

### S15. How Python, Spark, and Scala Communicate Internally (PySpark)
- **Scala/JVM** runs the actual Spark engine
- **PySpark** uses **Py4J** — a bridge letting Python code invoke JVM objects
- Python driver sends commands via a socket to the JVM; results come back via pickling
- For UDFs, data is serialized from JVM → Python workers → JVM (expensive) — hence prefer built-in functions
- **Pandas UDFs (vectorized UDFs)** use Apache Arrow for efficient batched serialization

### S16. Broadcast Join
```python
from pyspark.sql.functions import broadcast
result = big_df.join(broadcast(small_df), "id")
```
Spark sends the small DataFrame to every executor, avoiding shuffle on the big DataFrame. Use when small side fits in executor memory (default threshold: `spark.sql.autoBroadcastJoinThreshold` = 10 MB).

### S17. 100 MB File → OOM Even After Broadcast Join
Possible causes:
1. The "small" table **isn't actually small** after transformations (filter/explode inflates it)
2. **Skewed join key** — one partition has huge output
3. **Executor memory too low** / **overhead too small**
4. **Driver collects** — accidental `collect()` or `toPandas()` on big data
5. **Explode** on large arrays multiplies row count
6. **Cartesian join** due to missing join condition
7. **Too many broadcasts** fill executor memory
8. **Nested/deep structs** inflating deserialized size

Fix: check physical plan, disable auto-broadcast, increase `spark.executor.memoryOverhead`, repartition by key, enable AQE skew handling.

### S18. Data Skew & Salting
See Part 1 [section 39](#39-data-skewness).

### S19. Cached DataFrame in Loop → StackOverflow
When a DataFrame is transformed repeatedly in a loop, the logical plan grows (each call adds to the lineage). Eventually the driver serializes a massive plan → stack overflow.

Fix:
1. **Checkpoint** to truncate lineage: `df = df.checkpoint()` (requires `sc.setCheckpointDir(...)`)
2. **Persist + count** to materialize, then continue
3. Write to disk and re-read periodically

```python
spark.sparkContext.setCheckpointDir("/tmp/chk")
for i in range(100):
    df = df.withColumn(f"c{i}", lit(i))
    if i % 10 == 0:
        df = df.checkpoint()  # truncates lineage
```

### S20. Benefits of AQE
- Dynamic partition coalescing (reduces small shuffle partitions)
- Switching sort-merge → broadcast at runtime
- Skew join optimization (split skewed partitions)
- Better default `shuffle.partitions` behavior
- More accurate join strategy selection

### S21. Catalyst Optimizer
Spark SQL's query optimizer — a rule-based + cost-based engine that:
1. **Parses** SQL/DataFrame to logical plan
2. Applies **analysis** (resolve columns, tables)
3. Runs **logical optimizations** (predicate pushdown, projection pruning, constant folding)
4. Generates **physical plans** and picks the cheapest
5. Emits **whole-stage codegen** (Tungsten)

### S22. Constant Folding
An optimization where constant expressions are evaluated at compile time:
- `WHERE year = 2024 AND 1 = 1` → `WHERE year = 2024`
- `SELECT col + 2 + 3` → `SELECT col + 5`

This happens automatically in Catalyst.

### S23. 1 TB Table Joining with 1 MB Table — Slow
The 1 MB table should be **broadcast**. If it's not:
- Check `spark.sql.autoBroadcastJoinThreshold` — bump if needed
- Force: `big.join(broadcast(small), key)`
- Ensure stats are available: `ANALYZE TABLE small COMPUTE STATISTICS`
- Watch for data skew on join key on the 1 TB side

### S24. 4 S Problems of Spark
**Skew, Spill, Shuffle, Small files** (sometimes also Serialization):
- **Skew:** uneven distribution → slow tasks
- **Spill:** memory pressure → disk writes
- **Shuffle:** expensive network + disk I/O
- **Small files:** overhead per file, slow reads (solve with `OPTIMIZE` / `coalesce`)

### S25. Joins in Spark
- **Broadcast Hash Join** — small table broadcast
- **Shuffle Hash Join** — hash both sides, shuffle, hash-join
- **Sort Merge Join** — shuffle, sort, merge (default for large joins)
- **Cartesian** — no join key
- **Broadcast Nested Loop Join** — fallback, one side broadcast

Spark picks strategy based on size hints and configs.

### S26. Memory Allocation for 1 GB File (Internal)
Spark memory model (per executor):
- **Reserved** ~300 MB
- **User memory** 40% of remaining
- **Spark memory** 60% of remaining → split between **execution** and **storage** (unified, elastic)

For a 1 GB file, Spark reads it into partitions (~128 MB default per partition → ~8 partitions), each partition fits in executor memory. Shuffle/aggregation may require more; spills happen if insufficient.

### S27. Serialization in Spark
Two types:
- **Java Serialization** — default, slow and verbose
- **Kryo Serialization** — faster, more compact (`spark.serializer=org.apache.spark.serializer.KryoSerializer`)
- **Tungsten (binary)** — internal for DataFrames/Datasets, column-oriented off-heap

For custom classes with Kryo, register them: `spark.kryo.classesToRegister`.

### S28. Types of Join Optimizations
- **Broadcast join** (see S16)
- **Bucketed join** — pre-bucketed tables avoid shuffle
- **Skew join** (hint / AQE)
- **SortMergeJoin** with pre-sorted/partitioned data
- **Range join** (for interval joins, optimized via `spark.databricks.optimizer.rangeJoin.binSize`)
- **DPP (Dynamic Partition Pruning)** — pushes partition filter from dim to fact at runtime

### S29. Spark Optimization in Query (Review Code)
Given:
```python
fact_df = spark.read.parquet("fact_table")
dim_df = spark.read.parquet("dim_table").filter("region = 'West'")
df_joined = fact_df.join(dim_df, "region")
df_joined.write.parquet("output_path")
```

**Issues:**
1. No **broadcast** of the (likely small) filtered `dim_df` → full shuffle
2. **No column pruning** — reads all columns from fact
3. **No partition pruning** — if `fact_df` is partitioned by region, the filter isn't propagated
4. **Shuffle partitions** may be suboptimal
5. Filter on `dim_df` is applied before join (good); but DPP would help push to fact

**Improved:**
```python
from pyspark.sql.functions import broadcast, col

dim_df = (spark.read.parquet("dim_table")
          .filter("region = 'West'")
          .select("region", "dim_attr1", "dim_attr2"))

fact_df = (spark.read.parquet("fact_table")
           .select("region", "measure1", "measure2"))   # projection pushdown

df_joined = (fact_df.join(broadcast(dim_df), "region"))

(df_joined.repartition(8)
          .write.mode("overwrite").parquet("output_path"))
```

Enable AQE + DPP:
```python
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.optimizer.dynamicPartitionPruning.enabled", "true")
```

### S30. Handle Distributed Data
Spark/PySpark is the canonical answer. Principles:
- Partition data appropriately
- Prefer built-in functions over UDFs
- Use columnar formats (Parquet/Delta)
- Minimize shuffles; broadcast small dims
- Monitor Spark UI for bottlenecks

### S31. Deduplication
See Part 1 [section 31](#31-deduplication).

### S32. Narrow vs Wide Transformations
See Part 1 [section 36](#36-narrow-vs-wide-transformations).

### S33. Repartition vs Coalesce
See Part 1 [section 2](#2-repartition-and-coalesce).

### S34. Cache vs Persist
See Part 1 [section 76](#76-cache-vs-persist).

### S35. Stages in Sort Merge Join
See Part 1 [section 77](#77-sort-merge-join-stages).

### S36. drop_duplicates vs distinct
See Part 1 [section 78](#78-drop-duplicates-vs-distinct).

### S37. RDD
Resilient Distributed Dataset — immutable, partitioned, fault-tolerant collection. Low-level API; DataFrames are preferred. Recovery via lineage.

### S38. RDD vs DataFrame

| Feature | RDD | DataFrame |
|---|---|---|
| API | Functional | Declarative, SQL-like |
| Schema | No | Yes (named columns + types) |
| Optimization | None | Catalyst + Tungsten |
| Performance | Slower | Much faster |
| Serialization | Java/Kryo | Columnar, off-heap |
| Type safety | Yes (typed at compile) | Row-based, schema-checked |
| Use case | Unstructured, custom ops | Structured / analytics |

### S39. Why Spark is Extensively Used
Speed, unified API, in-memory processing, horizontal scaling, fault tolerance, broad ecosystem (MLlib, Streaming, SQL, GraphX).

### S40. What Makes RDD Fault Tolerant
RDD lineage (DAG of transformations). If a partition is lost, Spark recomputes it from the parent RDD using the recorded transformations. No data replication needed in-memory.

### S41. How Many Stages/Jobs/Tasks
See Part 1 [section 65](#65-spark-internal-working).

### S42. Spark Submit Basic Configurations
See Part 1 [section 71](#71-spark-submit-configuration).

### S43. Columns of DataFrame with Type
```python
for name, dtype in df.dtypes:
    print(name, dtype)
```

### S44. Partitioning in Hive vs Spark Optimization
Hive partitioning physically splits data by a column into folders. Spark achieves optimization via **partition pruning** — when your query filters on the partition column, Spark only reads matching folders, saving I/O massively.

```python
df = spark.read.parquet("/data/sales")
df.filter("year = 2024 AND month = 1").show()  # only reads /year=2024/month=1/
```

### S45. Do We Need to Unpersist?
Best practice: yes, once you're done with the cached DataFrame. Otherwise it holds executor memory until automatically evicted or the session ends.
```python
df.unpersist()
```

### S46. Error if Cache Doesn't Work
Cache is a hint — Spark may not be able to cache (insufficient memory). Action will still succeed but by re-computation. You may see warnings like "Not enough space to cache partition X; freed memory was M".

### S47. How Many Files When Writing to Delta
See D20 above.

### S48. Architecture for Ingesting 100+ Sources into Databricks
**High-level:**
1. **Source connectors:** JDBC, Kafka, cloud storage, APIs, SFTP
2. **Ingest orchestrator:** Databricks Workflows / Airflow / ADF
3. **Landing (Bronze):** Delta Lake tables via Autoloader / partner-connect / Fivetran
4. **Metadata-driven framework:** YAML/JSON config per source; generic ingestion notebook consumes config
5. **Silver transformations:** cleansing, joins, standardization
6. **Gold:** business aggregates
7. **Observability:** logging, lineage via Unity Catalog, data-quality via DLT expectations
8. **Incremental deployment:** Databricks Asset Bundles + Git + CI/CD

Config pattern: a control table listing source name, connection, target path, frequency, CDC columns, etc. A generic pipeline reads this config and spawns tasks dynamically.

### S49. Incremental Deployment & Configuration Settings
- Use **Databricks Asset Bundles** (YAML) to define jobs, notebooks, cluster configs as code
- Git-based repos, CI/CD via GitHub Actions / Jenkins
- Environment-specific variables (dev/test/prod)
- Deploy incrementally — only modified assets
- Use `databricks bundle deploy --target prod`

---

## SQL

### SQ1. CTE vs Subquery

| Aspect | CTE | Subquery |
|---|---|---|
| Readability | High (named, top-down) | Lower for complex |
| Reusability | Can be referenced multiple times in same query | Would need repetition |
| Recursion | Supports recursive | Not recursive |
| Performance | Similar in most engines | Similar |

```sql
-- CTE
WITH recent AS (
  SELECT * FROM orders WHERE order_date > '2024-01-01'
)
SELECT customer_id, COUNT(*) FROM recent GROUP BY customer_id;

-- Subquery
SELECT customer_id, COUNT(*)
FROM (SELECT * FROM orders WHERE order_date > '2024-01-01') t
GROUP BY customer_id;
```

### SQ2. CTE vs Recursive CTE
Recursive CTE references itself — used for hierarchical data (org charts, bill of materials, graph traversal).

```sql
WITH RECURSIVE emp_hier AS (
  SELECT emp_id, manager_id, name, 1 AS level
  FROM employees WHERE manager_id IS NULL
  UNION ALL
  SELECT e.emp_id, e.manager_id, e.name, h.level + 1
  FROM employees e
  JOIN emp_hier h ON e.manager_id = h.emp_id
)
SELECT * FROM emp_hier ORDER BY level;
```

### SQ3. GROUP BY vs Window Function
- **GROUP BY** collapses rows into one per group; you lose row-level detail
- **Window function** computes aggregates over a window **without collapsing** rows — each row keeps its identity

```sql
-- GROUP BY: one row per dept
SELECT dept, AVG(salary) FROM emp GROUP BY dept;

-- Window: every row + avg salary of its dept
SELECT emp_id, dept, salary,
       AVG(salary) OVER (PARTITION BY dept) AS dept_avg
FROM emp;
```

Use window when you need row-level results with aggregated context.

### SQ4. View vs Materialized View

| Feature | View | Materialized View |
|---|---|---|
| Storage | Query definition only | Precomputed result stored |
| Freshness | Always live | Stale until refreshed |
| Performance | Same as underlying query | Much faster reads |
| Refresh | N/A | Manual / scheduled / incremental |
| Use case | Simplification, security | Heavy aggregations, BI dashboards |

### SQ5. Review Query #29 (Orders / Customers)
Query:
```sql
SELECT c.name, COUNT(o.order_id) AS total_orders, SUM(o.amount) AS total_amount
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.amount > 0
GROUP BY c.name
ORDER BY total_amount DESC;
```

**Issues:**
1. `INNER JOIN` excludes customers with no orders. Use `LEFT JOIN` if you want all customers.
2. `WHERE o.amount > 0` filters out NULL amounts (e.g., `order_id=4, amount=NULL`). If you need to include them as zero, use `COALESCE(o.amount, 0)` and move the filter to a `HAVING` or remove it.
3. `GROUP BY c.name` — if two customers share a name, they'll be merged. Group by `c.customer_id, c.name` for safety.
4. Result set misses customers with zero orders.

**Improved:**
```sql
SELECT c.customer_id, c.name,
       COUNT(o.order_id) AS total_orders,
       COALESCE(SUM(o.amount), 0) AS total_amount
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.name
ORDER BY total_amount DESC;
```

### SQ6. Review Query #30 (Latest Order per Customer)
Query:
```sql
WITH ranked_orders AS (
  SELECT customer_id, amount,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS rn
  FROM orders
)
SELECT c.customer_id, c.name, r.amount AS latest_order_amount
FROM customers c
LEFT JOIN ranked_orders r ON c.customer_id = r.customer_id
WHERE r.rn = 1;
```

**Issue:** `WHERE r.rn = 1` on a LEFT JOIN **effectively turns it into an INNER JOIN** — customers with no orders will be filtered out because `r.rn` will be `NULL` for them, and `NULL = 1` is false.

**What it does first:** The engine computes the CTE (window function over orders), then joins with customers, then applies the WHERE clause (which drops non-matching customers).

**Fix:**
```sql
WITH latest_order AS (
  SELECT customer_id, amount,
         ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS rn
  FROM orders
  QUALIFY rn = 1       -- Snowflake / Databricks
)
SELECT c.customer_id, c.name, lo.amount AS latest_order_amount
FROM customers c
LEFT JOIN latest_order lo ON c.customer_id = lo.customer_id;
```

Or move the rn filter into the join condition:
```sql
LEFT JOIN ranked_orders r ON c.customer_id = r.customer_id AND r.rn = 1
```

### SQ7. Window Functions List
**Ranking:** `ROW_NUMBER()`, `RANK()`, `DENSE_RANK()`, `PERCENT_RANK()`, `NTILE(n)`
**Aggregate:** `SUM()`, `AVG()`, `COUNT()`, `MIN()`, `MAX()` over window
**Analytic:** `LAG()`, `LEAD()`, `FIRST_VALUE()`, `LAST_VALUE()`, `NTH_VALUE()`
**Distribution:** `CUME_DIST()`, `PERCENT_RANK()`

```sql
SELECT emp_id, salary,
       LAG(salary) OVER (PARTITION BY dept ORDER BY hire_date) AS prev_sal,
       SUM(salary) OVER (PARTITION BY dept ORDER BY hire_date
                         ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS rolling_sum
FROM emp;
```

### SQ8. LEAD vs LAG
- `LAG(col, n)` — value from **n rows before** current row
- `LEAD(col, n)` — value from **n rows after** current row

```sql
SELECT emp_id, hire_date,
       LAG(hire_date, 1)  OVER (ORDER BY hire_date) AS prev_hire,
       LEAD(hire_date, 1) OVER (ORDER BY hire_date) AS next_hire
FROM employees;
```

### SQ9. Consecutive Entries (user_id, login_date)
Find users who logged in on consecutive days:
```sql
SELECT DISTINCT user_id
FROM (
  SELECT user_id, login_date,
         LAG(login_date) OVER (PARTITION BY user_id ORDER BY login_date) AS prev_date
  FROM logins
) t
WHERE DATEDIFF(login_date, prev_date) = 1;
```

To find runs of consecutive logins:
```sql
WITH t AS (
  SELECT user_id, login_date,
         DATEADD(day, -ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_date), login_date) AS grp
  FROM logins
)
SELECT user_id, MIN(login_date) AS start_date, MAX(login_date) AS end_date, COUNT(*) AS streak
FROM t
GROUP BY user_id, grp
HAVING COUNT(*) >= 2;
```

### SQ10. Rolling 7-Day Sum with Missing Dates
```sql
-- Generate all dates, then rolling sum
WITH all_dates AS (
  SELECT DATE_ADD('2024-01-01', seq) AS trans_date
  FROM (SELECT EXPLODE(SEQUENCE(0, 729)) AS seq) x
),
per_day AS (
  SELECT d.trans_date,
         COALESCE(SUM(t.trans_amt), 0) AS daily_amt
  FROM all_dates d
  LEFT JOIN trans t ON d.trans_date = t.trans_date
  GROUP BY d.trans_date
)
SELECT trans_date,
       SUM(daily_amt) OVER (
         ORDER BY trans_date
         ROWS BETWEEN 3 PRECEDING AND 3 FOLLOWING   -- 3 before + current + 3 after = 7-day window
       ) AS rolling_7day_sum
FROM per_day;
```

---

## Scala

### SC1. Why Scala is Used for Spark
Spark is written in Scala. Scala offers:
- Functional + OOP
- Strong static typing
- Concise, expressive syntax
- JVM-native performance
- Pattern matching, case classes
- Seamless Java interop

### SC2. Scala Seq Transformation
Input: `Seq(3, 7, 31, 20, 5)`, Output: `Seq((31,2), (20,3))`

The output pairs look like `(value, index_in_something)`. One interpretation: select values > 10 with their position, where the position is the index (0-based) of the element in the original seq.

```scala
val s = Seq(3, 7, 31, 20, 5)
val result = s.zipWithIndex.filter(_._1 > 10)
// List((31, 2), (20, 3))
```

### SC3. Exception Handling in Scala
```scala
try {
  riskyOperation()
} catch {
  case e: IOException       => println(s"IO error: ${e.getMessage}")
  case e: NumberFormatException => println("bad number")
  case _: Throwable         => println("other")
} finally {
  cleanup()
}
```

Prefer `Try` / `Either` for functional style:
```scala
import scala.util.{Try, Success, Failure}
Try(doSomething()) match {
  case Success(v) => println(v)
  case Failure(e) => println(s"fail: ${e.getMessage}")
}
```

### SC4. Option in Scala
`Option[T]` is `Some(t)` or `None` — idiomatic way to represent "value may be absent" without null.

```scala
val m = Map("a" -> 1, "b" -> 2)
val v1: Option[Int] = m.get("a")   // Some(1)
val v2: Option[Int] = m.get("c")   // None

// Safe use
v1.map(_ + 10).getOrElse(0)        // 11
v2.map(_ + 10).getOrElse(0)        // 0
```

### SC5. Nil, null, None, Nothing
See Part 1 [section 59](#59-nil-null-none-nothing-in-scala).

### SC6. val, var, def, lazy val
See Part 1 [section 64](#64-val-var-def-lazy-val).

### SC7. Case Class Mutation
See Part 1 [section 63](#63-scala-case-class).

### SC8. Garbage Collection in Scala
See Part 1 [section 61](#61-scala-garbage-collection).

### SC9. Scala Accessing Java Libraries
Both compile to JVM bytecode; Scala can directly import any Java class and use it.
```scala
import java.util.ArrayList
val list = new ArrayList[String]()
list.add("hello")
```

### SC10. Akka, Play, REST API
- **Akka:** toolkit for building concurrent, distributed, resilient applications using the actor model
- **Play Framework:** reactive web framework for Scala/Java — builds web apps and REST APIs
- **REST API in Scala:** typically built with Play, Akka-HTTP, or http4s

Basic Akka-HTTP example:
```scala
import akka.http.scaladsl.server.Directives._
val route =
  path("hello") {
    get {
      complete("Hello, world!")
    }
  }
```

### SC11. Reconciliation Script
Generic term — a script that compares source vs target data (row counts, checksums, sum of amounts) to verify data migration/load correctness.

```scala
val srcCount = spark.table("src.table").count()
val tgtCount = spark.table("tgt.table").count()
assert(srcCount == tgtCount, s"Count mismatch: src=$srcCount, tgt=$tgtCount")

val srcSum = spark.table("src.table").agg(sum("amount")).first().getDouble(0)
val tgtSum = spark.table("tgt.table").agg(sum("amount")).first().getDouble(0)
assert(math.abs(srcSum - tgtSum) < 0.01)
```

---

## Python

### PY1. 2nd Highest Without sorted()
```python
def second_highest(nums):
    first = second = float('-inf')
    for n in nums:
        if n > first:
            second = first
            first = n
        elif n > second and n != first:
            second = n
    return second if second != float('-inf') else None

print(second_highest([10, 20, 20, 5, 8]))   # 10
```

### PY2. OOP Concepts
1. **Class & Object** — blueprint + instance
2. **Encapsulation** — bundle data + methods; use `_protected`, `__private`
3. **Inheritance** — subclass extends parent
4. **Polymorphism** — same interface, different implementations; duck typing in Python
5. **Abstraction** — hide complexity; `abc.ABC` for abstract base classes

```python
from abc import ABC, abstractmethod

class Shape(ABC):
    @abstractmethod
    def area(self): ...

class Circle(Shape):
    def __init__(self, r): self.r = r
    def area(self): return 3.14 * self.r**2

class Square(Shape):
    def __init__(self, s): self.s = s
    def area(self): return self.s ** 2

for s in [Circle(5), Square(3)]:
    print(s.area())         # polymorphism
```

### PY3. Multiple vs Multi-level Inheritance
- **Multiple** — one class inherits from multiple parents
- **Multi-level** — chain: A → B → C

```python
# Multiple
class A: pass
class B: pass
class C(A, B): pass   # C inherits from A AND B

# Multi-level
class X: pass
class Y(X): pass
class Z(Y): pass      # Z → Y → X
```

Python uses **MRO** (Method Resolution Order) via C3 linearization: `C.__mro__`.

### PY4. Decorators (see Part 1 #27 and API Retry below)

### PY5. Decorator for API Retry
```python
import time
from functools import wraps

def retry(max_attempts=3, delay=1, backoff=2, exceptions=(Exception,)):
    def deco(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            attempt, wait = 1, delay
            while attempt <= max_attempts:
                try:
                    return func(*args, **kwargs)
                except exceptions as e:
                    if attempt == max_attempts:
                        raise
                    print(f"Attempt {attempt} failed: {e}. Retrying in {wait}s")
                    time.sleep(wait)
                    wait *= backoff
                    attempt += 1
        return wrapper
    return deco

@retry(max_attempts=3, delay=1, exceptions=(ConnectionError, TimeoutError))
def call_api(url):
    ...
```

### PY6. Processing Multiple Tables in Parallel
Since table processing is typically I/O-bound (DB reads), threading works well:

```python
from concurrent.futures import ThreadPoolExecutor

def process_table(name):
    print(f"processing {name}")
    # ingest / transform / write
    return f"{name}: done"

tables = ["orders", "customers", "products", "returns"]
with ThreadPoolExecutor(max_workers=4) as ex:
    results = list(ex.map(process_table, tables))
```

For CPU-bound transforms use `ProcessPoolExecutor`. In Spark itself, use `ThreadPool` on the driver to submit multiple actions (each becomes a job) concurrently — Spark's scheduler handles executor-side parallelism.

### PY7. Multithreading in Python / GIL
Python's **GIL (Global Interpreter Lock)** prevents multiple native threads from executing Python bytecode simultaneously within a single process. It limits CPU-bound parallelism. For I/O-bound tasks, threads work well because the GIL is released during I/O waits.

### PY8. Copy Large File from Source to Data Lake
For large files, stream in chunks instead of loading fully:

```python
# Local → ADLS/S3 via boto3 (S3)
import boto3
s3 = boto3.client("s3")
s3.upload_file("big.parquet", "bucket", "path/big.parquet")   # uses multipart automatically

# Or streaming read → write
import requests
with requests.get(url, stream=True) as r, open("out", "wb") as f:
    for chunk in r.iter_content(chunk_size=1024*1024):   # 1 MB
        f.write(chunk)
```

For Databricks, you can also use `dbutils.fs.cp(src, dst, recurse=True)` for DBFS copies.

### PY9. Access AWS Services from Python
Use `boto3`:
```python
import boto3
s3 = boto3.client("s3", region_name="us-east-1")
s3.put_object(Bucket="b", Key="k.txt", Body="hello")
s3.list_objects_v2(Bucket="b")
```

Auth order: explicit keys → env vars → `~/.aws/credentials` → IAM role.

### PY10. Document Types in NoSQL Databases
- **Document** stores (MongoDB, CouchDB) store **JSON/BSON** documents (semi-structured, nested)
- **Key-Value** — Redis, DynamoDB
- **Column-family** — Cassandra, HBase
- **Graph** — Neo4j, ArangoDB
- **Time-series** — InfluxDB, TimescaleDB
- **Search** — Elasticsearch

Typical document:
```json
{"_id": "abc", "user": {"name": "Alice", "age": 30}, "tags": ["vip", "beta"]}
```

### PY11. Swap Two Variables Without Third
```python
a, b = b, a     # Pythonic, uses tuple packing

# Arithmetic (integers only)
a = a + b
b = a - b
a = a - b

# XOR (integers only)
a ^= b
b ^= a
a ^= b
```

### PY12. Python Output Questions
See Part 1 [section 69](#69-python-output-questions).

---

## Airflow

### AF1. Components of Airflow
- **Webserver** — UI
- **Scheduler** — triggers task instances based on DAG schedules
- **Executor** — runs tasks (Sequential, Local, Celery, Kubernetes)
- **Metadata DB** — stores DAG, task, run state (Postgres/MySQL)
- **Workers** — execute tasks (for distributed executors)
- **Triggerer** — handles deferrable operators (async)
- **DAGs folder** — where DAG files live

### AF2. DAG and Tasks
- **DAG** (Directed Acyclic Graph) — workflow definition; a set of tasks with dependencies
- **Task** — a unit of work (an Operator instance)
- **Task Instance** — a specific run of a task at a scheduled time

```python
from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime

with DAG("my_dag", schedule="@daily", start_date=datetime(2024,1,1), catchup=False) as dag:
    t1 = PythonOperator(task_id="extract", python_callable=extract)
    t2 = PythonOperator(task_id="transform", python_callable=transform)
    t3 = PythonOperator(task_id="load", python_callable=load)
    t1 >> t2 >> t3
```

### AF3. Dependency Between Two DAGs (External Sensor)
Use **ExternalTaskSensor** — DAG B waits for a task in DAG A to complete:

```python
from airflow.sensors.external_task import ExternalTaskSensor

wait = ExternalTaskSensor(
    task_id="wait_for_upstream",
    external_dag_id="upstream_dag",
    external_task_id="final_task",
    mode="reschedule",           # don't hold worker slot
    timeout=60*60,
    poke_interval=60,
)
```

Alternatives: **TriggerDagRunOperator** (upstream triggers downstream), **Datasets** (Airflow 2.4+) for data-aware scheduling.

### AF4. XComs
See Part 1 [section 28](#28-airflow-xcoms-and-dynamic-dags).

### AF5. Dynamic DAGs
See Part 1 [section 28](#28-airflow-xcoms-and-dynamic-dags).

---

## AWS

### AW1. Storage Classes in S3
- **S3 Standard** — frequent access
- **S3 Intelligent-Tiering** — auto-moves between tiers
- **S3 Standard-IA** — infrequent access, cheaper storage, higher retrieval cost
- **S3 One Zone-IA** — single AZ
- **S3 Glacier Instant Retrieval** — archive with ms retrieval
- **S3 Glacier Flexible Retrieval** — minutes to hours
- **S3 Glacier Deep Archive** — cheapest, 12+ hrs retrieval
- **S3 Express One Zone** — low-latency, high-perf (newer)

### AW2. Lambda Limitations
- **15-minute** max execution time
- **10 GB** max memory (scales CPU proportionally)
- **512 MB** default `/tmp` (up to 10 GB with ephemeral storage)
- **250 MB** unzipped deployment package (50 MB zipped direct); up to 10 GB via container image
- **6 MB** request/response payload (sync); 256 KB for async
- **Cold start** latency
- Stateless (no local persistence between invocations)
- Concurrent execution limits per region
- Limited language runtimes (but custom runtime possible)

### AW3. Triggers for Lambda
- **API Gateway** — HTTP/REST triggers
- **S3 Events** — object created/deleted
- **DynamoDB Streams**
- **SQS / SNS**
- **Kinesis Streams / Firehose**
- **EventBridge** — scheduled or event-based
- **CloudWatch Events / Logs**
- **Cognito**
- **Alexa, Lex**
- **Direct invocation** (SDK, CLI)

### AW4. AWS SNS
**Simple Notification Service** — pub/sub messaging. Publishers send to topics; subscribers (SQS, Lambda, HTTP endpoints, email, SMS) receive. Used for fan-out patterns, alerting, decoupling services.

### AW5. AWS Services Commonly Used in Data Engineering
S3, Glue, EMR, Redshift, Athena, Lambda, Kinesis, MSK (Kafka), Step Functions, RDS, DynamoDB, SNS, SQS, EventBridge, CloudWatch, IAM, Secrets Manager, DMS (Database Migration), Lake Formation.

### AW6. Redshift — Why Different from Traditional DB; Query Optimization
- **Columnar storage** (vs row-based in OLTP)
- **MPP (Massively Parallel Processing)** — slices distributed across compute nodes
- **Compression** (column-level)
- **No indexes** (but **sort keys** and **dist keys**)
- Optimized for **large analytical queries**, not high-concurrency OLTP

**Query optimization:**
- Choose correct **distribution style** (KEY, EVEN, ALL) and **DISTKEY**
- Use **SORTKEY** matching filter/join patterns
- **VACUUM** and **ANALYZE** regularly
- **Compression encodings** (`ANALYZE COMPRESSION`)
- **Workload management (WLM)** queues
- Avoid `SELECT *`; select only needed columns
- Use **materialized views** for frequent aggregates
- Minimize data movement: keep joined tables co-located
- Use **Redshift Spectrum** for querying S3 directly

### AW7. AWS Lambda Limitations
See AW2.

### AW8. Connecting to Source from Redshift
- **Federated queries** — Redshift can query live data from RDS/Aurora (Postgres/MySQL)
- **Redshift Spectrum** — query S3 directly
- **COPY** from S3, DynamoDB, EMR, SSH remote host
- **AWS Glue** — ETL into Redshift
- **Data Sharing** — share across Redshift clusters

### AW9. Redshift vs DynamoDB

| Feature | Redshift | DynamoDB |
|---|---|---|
| Type | OLAP data warehouse | NoSQL key-value/document |
| Use case | Analytics, BI | Low-latency KV lookups, high-concurrency OLTP |
| Schema | Relational, fixed | Schema-less |
| Scaling | Cluster-based (MPP) | Fully serverless, auto-scaling |
| Query | SQL | Limited (GetItem, Query, Scan) |
| Consistency | Strong | Eventual (default), strong (optional) |

### AW10. Scheduling Jobs
- **EventBridge** (scheduled rules) + Lambda
- **Step Functions** (orchestration)
- **Airflow on MWAA**
- **Glue Workflows / Triggers**
- **EMR steps** scheduled via EventBridge

### AW11. AWS Glue
Serverless ETL service — crawlers, data catalog, Spark/Python-based ETL jobs. Good for metadata cataloging and serverless Spark jobs. Integrates with Athena, Redshift Spectrum.

### AW12. EMR
Managed Hadoop/Spark cluster service. Run Spark, Hive, Presto, HBase on EC2. More control than Glue; cheaper for long-running workloads. Also offered as **EMR Serverless** and **EMR on EKS**.

### AW13. Data Transfer SFTP, Cloud to Cloud
- **AWS Transfer Family** — SFTP/FTPS/FTP endpoints over S3
- **AWS DataSync** — cloud-to-cloud / on-prem transfer
- **S3 Cross-Region Replication**
- **DMS** for DB-to-DB

### AW14. Kubernetes / Docker — Usage
- **Docker** — package applications with dependencies into portable images
- **Kubernetes** — orchestrate containers across many hosts (scheduling, scaling, self-healing, rolling deploys)
- In data engineering: run Airflow, Spark (on K8s), ML services, microservices in a reproducible, scalable way

---

## Snowflake

### SN1. Create Table & Load Data from Databricks (Multiple Files)
```sql
-- Create stage pointing to S3 / ADLS
CREATE OR REPLACE STAGE raw_stage
  URL = 's3://my-bucket/path/'
  CREDENTIALS = (AWS_KEY_ID='...' AWS_SECRET_KEY='...')
  FILE_FORMAT = (TYPE = PARQUET);

-- Create table
CREATE OR REPLACE TABLE events (id INT, ts TIMESTAMP, event STRING);

-- Load multiple files from folder
COPY INTO events
FROM @raw_stage/events/
FILE_FORMAT = (TYPE = PARQUET)
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
PATTERN = '.*[.]parquet';
```

From Databricks, you can also use the **Snowflake Spark connector**:
```python
(df.write.format("snowflake")
   .options(**sf_options)
   .option("dbtable", "events")
   .mode("append").save())
```

### SN2. Types of Tables in Snowflake
- **Permanent** — default, fully recoverable (Time Travel + Fail-safe)
- **Transient** — no Fail-safe, shorter Time Travel; lower storage cost
- **Temporary** — session-scoped, dropped at session end
- **External** — metadata only; data stays in external stage (S3, ADLS, GCS)
- **Dynamic** — auto-refreshed based on source changes
- **Hybrid (Unistore)** — OLTP + OLAP on same data

### SN3. Disadvantages of Materialized View (Snowflake)
- Uses **additional storage**
- Has **refresh cost** (auto-maintained)
- Limited to **single-table** (in Snowflake; no joins)
- Some functions not supported (window functions, UDFs have restrictions)
- Cannot be used for **external tables**
- **Additional compute** for background maintenance

### SN4. Dynamic Table (Snowflake)
Declarative table automatically refreshed from a query. You specify target lag; Snowflake schedules refresh.

```sql
CREATE OR REPLACE DYNAMIC TABLE sales_summary
  TARGET_LAG = '5 minutes'
  WAREHOUSE = compute_wh
AS
SELECT region, SUM(amount) AS total
FROM sales
GROUP BY region;
```

Similar to materialized views but supports joins/multi-table, with explicit freshness SLA.

---

## dbt

### DB1. dbt Project Folder Structure
```
my_dbt_project/
├── dbt_project.yml         # project config
├── profiles.yml            # connection (usually in ~/.dbt/)
├── models/
│   ├── staging/            # raw → renamed
│   ├── intermediate/
│   └── marts/              # business-facing
├── seeds/                  # CSV files loaded as tables
├── snapshots/              # SCD Type 2 tracking
├── macros/                 # reusable Jinja SQL
├── tests/                  # custom data tests
├── analyses/               # ad-hoc analyses
├── docs/
└── target/                 # compiled output (gitignored)
```

### DB2. Implementing SCD Type 2 in dbt
Use the **snapshot** feature:
```sql
-- snapshots/customers_snapshot.sql
{% snapshot customers_snapshot %}
{{
  config(
    target_schema='snapshots',
    unique_key='customer_id',
    strategy='check',
    check_cols=['name', 'email', 'address'],
    invalidate_hard_deletes=True
  )
}}
SELECT * FROM {{ source('raw', 'customers') }}
{% endsnapshot %}
```

Run with `dbt snapshot`. dbt automatically adds `dbt_valid_from`, `dbt_valid_to`, `dbt_updated_at` columns.

### DB3. Incremental Model Strategies
- **append** — insert new rows only (no updates)
- **merge** (default on Snowflake/Databricks/BigQuery) — upsert based on `unique_key`
- **delete+insert** — delete matching + insert new
- **insert_overwrite** — replace partitions (BigQuery/Spark)

```sql
{{ config(
    materialized='incremental',
    unique_key='order_id',
    incremental_strategy='merge',
    on_schema_change='append_new_columns'
) }}

SELECT * FROM {{ source('raw', 'orders') }}
{% if is_incremental() %}
  WHERE updated_at > (SELECT MAX(updated_at) FROM {{ this }})
{% endif %}
```

### DB4. Define and Create a Model
A model is a `.sql` file under `models/` whose SELECT defines the result. dbt compiles it into DDL/DML.

```sql
-- models/marts/fct_orders.sql
{{ config(materialized='table') }}

SELECT
  o.order_id,
  o.customer_id,
  c.name,
  o.amount
FROM {{ ref('stg_orders') }} o
JOIN {{ ref('stg_customers') }} c ON o.customer_id = c.customer_id
```

Run with `dbt run --select fct_orders`.

### DB5. Improve Performance in dbt
- Use **incremental** models for large tables
- Proper **materialization** (`view` vs `table` vs `incremental`)
- **Clustering / partitioning** on warehouse side
- **Concurrent threads** (`dbt run --threads 8`)
- **Model selection** (`--select`) to run subsets
- Use **ephemeral** models for simple transformations (CTE inlined)
- **Tag models** and run tagged subsets
- **Avoid SELECT *** — list columns
- Optimize **seeds** (don't use seeds for large data)

### DB6. Data Quality Checks in dbt
**Built-in generic tests:** `unique`, `not_null`, `accepted_values`, `relationships`.

```yaml
# models/schema.yml
version: 2
models:
  - name: fct_orders
    columns:
      - name: order_id
        tests:
          - unique
          - not_null
      - name: customer_id
        tests:
          - relationships:
              to: ref('stg_customers')
              field: customer_id
      - name: status
        tests:
          - accepted_values:
              values: ['NEW', 'PAID', 'CANCELLED']
```

**Packages:** `dbt-utils`, `dbt-expectations` for richer tests.
**Custom tests:** SQL files under `tests/` returning rows that **fail**.

### DB7. Configure Materialization
In the model file:
```sql
{{ config(materialized='incremental') }}
```

Or in `dbt_project.yml`:
```yaml
models:
  my_project:
    marts:
      +materialized: table
    staging:
      +materialized: view
```

### DB8. dbt Core vs dbt Cloud vs Hybrid
- **dbt Core** — open-source CLI; you self-host scheduling (Airflow, GitHub Actions)
- **dbt Cloud** — managed service: IDE, scheduler, notifications, docs, orchestration, SSO
- **Hybrid** — use dbt Core + external orchestrator, or dbt Cloud for some teams and Core for others

### DB9. CI/CD Pipeline in dbt
Typical setup:
1. Developers work in feature branches; create PRs
2. CI runs on PR: `dbt compile`, `dbt build --select state:modified+` against a staging DB
3. Tests must pass before merge
4. On merge to main: CD deploys to production (scheduled `dbt run` / `dbt build`)

Example GitHub Actions job:
```yaml
- name: Install dbt
  run: pip install dbt-snowflake
- name: Compile
  run: dbt compile
- name: Run modified models
  run: dbt build --select state:modified+ --defer --state ./prod-manifest
```

### DB10. Peer Review — What to Check
- **SQL correctness:** query logic, joins, filters
- **Naming conventions:** column/model naming
- **Materialization choice** appropriate for size and access pattern
- **Tests coverage** — PK unique, FK relationships, business rules
- **Documentation** (`description`) in YAML
- **Performance:** avoid full table scans, unnecessary joins
- **No hardcoded values** — use `{{ var() }}` or sources
- **Linting** (sqlfluff)
- **Impact analysis:** downstream models, breaking changes
- **Git hygiene:** clear commit messages, small PRs

---

## NoSQL

### NS1. Document Types in NoSQL
See PY10 above.

### NS2. When to Use NoSQL
- Flexible/evolving schema
- Extreme scale (horizontal)
- Simple access patterns (KV lookups)
- Low-latency writes/reads at scale
- Specific workloads: time-series, graph, full-text search

### NS3. Event Hub vs Kafka
Both are pub/sub event streaming platforms. Kafka is open-source with richer ecosystem and finer control; Event Hub is Azure's managed equivalent. Kafka has partitions, consumer groups, offsets; Event Hub has partitions and consumer groups too but with Azure-specific integration.

---

## CI/CD & DevOps

### CD1. CI/CD Pipeline Process
1. **Commit** — developer pushes to feature branch
2. **Build / Compile** — unit tests, lint
3. **Package** — build artifacts (wheel, JAR, Docker image)
4. **Publish** — push to artifact registry (PyPI, Nexus, ECR)
5. **Deploy to staging / test env**
6. **Integration / E2E tests**
7. **Promote** — via PR/approval
8. **Deploy to production** (blue/green, canary, rolling)
9. **Monitor** — alerts, rollback if issues

### CD2. Scripts for CI/CD Pipeline
Typical components:
- **`.github/workflows/*.yml`** (GitHub Actions) or **`Jenkinsfile`**, **`.gitlab-ci.yml`**, **Azure DevOps YAML**
- **Build** scripts: `setup.py`, `pyproject.toml`, `Dockerfile`, `Makefile`
- **Test** scripts: `pytest`, `dbt test`, `sqlfluff lint`
- **Deploy** scripts: `terraform apply`, `databricks bundle deploy`, `aws cli`
- **Versioning**: `bumpversion`, `git tag`

### CD3. Split Git Repo into Multiple Deployment Pipelines
If a repo has folders like `sql/`, `aws/`, `emr/` that deploy separately:

**Approach 1: Path-filtered triggers** — each pipeline runs only when its folder changes:
```yaml
on:
  push:
    paths:
      - 'sql/**'
jobs:
  deploy-sql:
    ...
```

**Approach 2: Monorepo tooling** — Nx, Bazel, Turborepo compute affected targets.

**Approach 3: Explicit per-folder workflows** — one workflow YAML per folder/app.

**Approach 4: Reusable workflows** — define a shared deploy template, call it from each folder's pipeline with folder-specific params.

---

## Cloud & Architecture (General)

### AR1. ETL Steps for Multiple Sources Integration
1. Identify source types & connectors
2. Build ingestion pipelines (per-source config)
3. Land raw data in a data lake (Bronze)
4. Cleanse + standardize (Silver)
5. Business transform (Gold)
6. Load into warehouse/serving layer
7. Orchestrate + monitor

### AR2. Spill Handling in Native Spark
- Tune `spark.sql.shuffle.partitions`
- Increase executor memory / overhead
- Enable **AQE** (coalesces & splits shuffle partitions)
- **Salt** skewed keys
- Repartition by join key
- Filter / project early to reduce data
- Use columnar storage to reduce I/O

### AR3. Alternative to OPTIMIZE in Native (Non-Delta) Spark
OPTIMIZE (bin-packing / ZORDER) is a Delta Lake feature. In native Spark:
- **Coalesce / repartition** before write to control file count
- **Hive bucketing** for join co-location
- Partition on query-filter columns
- Use **Hive's CONCATENATE** for ORC
- **Hadoop file crush** utilities for compaction
- For vanilla Parquet: rewrite with `df.repartition(n).write.mode("overwrite")`

### AR4. High-Level Architecture for 100+ Sources into Databricks
See S48.

### AR5. Tools to Extract Data from Source Systems
- **Fivetran / Stitch** — SaaS connectors
- **Airbyte** — open source
- **Debezium** — CDC for DBs
- **Kafka Connect**
- **AWS DMS** — DB migration / replication
- **Informatica, Talend** — enterprise ETL
- **Custom JDBC / REST** ingestion code

### AR6. Types of Source Systems
- **Relational DBs** (Postgres, MySQL, Oracle, SQL Server)
- **NoSQL** (MongoDB, DynamoDB, Cassandra)
- **Files** (CSV, Parquet, JSON, XML)
- **Streaming** (Kafka, Kinesis, Event Hub)
- **APIs / SaaS** (Salesforce, HubSpot, Stripe)
- **Mainframe / legacy** (IBM Db2, VSAM)
- **Logs / clickstreams**

---

## Coding Problems

### C1. SCD Type 2 MERGE — Code Review
Given code (questions 41 in images): uses `DeltaTable.merge` with `whenMatchedUpdate(is_current=False)` for changed rows and `whenNotMatchedInsert` for new customers.

**Analysis of what the code does:**
1. Reads current dim table.
2. Reads staging (new incoming batch) and stamps `start_date=current_date()`, `end_date=9999-12-31`, `is_current=True`.
3. Joins on `customer_id AND dim.is_current=true` — matches only active records.
4. On a match where `name` or `address` differs, it **closes** the current record (`end_date=current_date()`, `is_current=False`).
5. On no match, it **inserts** the new record with staged values.

**Issue / gap:** After closing the old version of a changed record, **the code never inserts the new version** of that record. A full SCD Type 2 needs two actions for a change: close old + insert new. `whenMatchedUpdate` alone can't both close the old row and insert the new one in a single `MERGE`.

**Fix:** the standard pattern is a **two-step** MERGE or using a UNION trick:
- Step A: identify changed `customer_id`s.
- Step B: for each changed row, produce two records in source: one "close" row (matched update) + one "new active" row. Then the MERGE inserts the new active record via `whenNotMatchedInsert` and closes old via `whenMatchedUpdate`.

A common idiom is to UNION the change rows:
```python
# Build source: add a synthetic row for each change so that the new version gets INSERTED
changed = (stg.join(current, "customer_id")
             .filter("stg.name <> current.name OR stg.address <> current.address"))

# "Close" records: match the existing is_current=true row
to_close = changed.select("stg.customer_id", lit(None).alias("name"), ...,
                          lit("MERGEKEY_CLOSE").alias("mergeKey"))

# "New active" records: won't match (we inject a non-matching mergeKey) → INSERT
to_insert = stg.withColumn("mergeKey", col("customer_id"))

source = to_close.unionByName(to_insert)

dim.alias("d").merge(
    source.alias("s"),
    "d.customer_id = s.mergeKey AND d.is_current = true"
).whenMatchedUpdate(set={"end_date": "current_date()", "is_current": "false"}) \
 .whenNotMatchedInsert(values={...stg columns with is_current=true...}) \
 .execute()
```

### C2. PySpark Coding — User Session with Login/Logout
Data:
```python
data = [
    (1, "2024-01-01 10:00", "login"),
    (1, "2024-01-01 10:05", "click"),
    (1, "2024-01-01 10:30", "logout"),
    (1, "2024-01-01 11:00", "login"),
    (1, "2024-01-01 11:10", "click"),
    (2, "2024-01-02 09:00", "login"),
    (2, "2024-01-02 09:45", "logout"),
]
```

Expected: one row per session with `user_id, start_time, end_time, operations (ordered list), duration`.

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum as _sum, when, to_timestamp, collect_list, min as _min, max as _max, unix_timestamp, concat_ws
from pyspark.sql.window import Window

spark = SparkSession.builder.getOrCreate()

df = spark.createDataFrame(data, ["user_id", "date_time", "operation"]) \
          .withColumn("date_time", to_timestamp("date_time"))

w = Window.partitionBy("user_id").orderBy("date_time")

# Each "login" starts a new session; cumulative sum of login flag = session id
df2 = (df.withColumn("is_login", when(col("operation") == "login", 1).otherwise(0))
         .withColumn("session_id", _sum("is_login").over(w)))

session = (df2.groupBy("user_id", "session_id")
             .agg(_min("date_time").alias("start_time"),
                  _max("date_time").alias("end_time"),
                  collect_list("operation").alias("operations"))
             .withColumn("duration_min",
                         (unix_timestamp("end_time") - unix_timestamp("start_time")) / 60)
             .withColumn("operations", concat_ws(", ", "operations"))
             .drop("session_id")
             .orderBy("user_id", "start_time"))

session.show(truncate=False)
# +-------+-------------------+-------------------+-----------------------+------------+
# |user_id|start_time         |end_time           |operations             |duration_min|
# +-------+-------------------+-------------------+-----------------------+------------+
# |1      |2024-01-01 10:00:00|2024-01-01 10:30:00|login, click, logout   |30.0        |
# |1      |2024-01-01 11:00:00|2024-01-01 11:10:00|login, click           |10.0        |
# |2      |2024-01-02 09:00:00|2024-01-02 09:45:00|login, logout          |45.0        |
# +-------+-------------------+-------------------+-----------------------+------------+
```

### C3. Rolling 7-Day Sum with Missing Dates (SQL)
See SQ10 above.

### C4. PySpark — BroadcastJoin + Filter Optimization
See S29 above.

---

*End of document.*
