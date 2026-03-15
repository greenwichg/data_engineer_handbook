# Programming with DLT

## Introduction

Now let's get into the actual code. This is where DLT clicks -- once you see how little code
you need to build a complete, production-grade pipeline, you'll understand why Databricks pushes
DLT so heavily. We'll cover the Python and SQL APIs, how to define streaming tables and
materialized views, how to use expectations for data quality, and how to configure pipeline
settings.

## Python API

The Python DLT API uses decorators to define datasets. You import the `dlt` module and
decorate functions that return DataFrames:

### Defining a Streaming Table

```python
import dlt
from pyspark.sql.functions import col, current_timestamp

# Streaming Table -- processes data incrementally
@dlt.table(
    comment="Raw orders ingested from landing zone"
)
def bronze_orders():
    return (spark.readStream
        .format("cloudFiles")
        .option("cloudFiles.format", "json")
        .option("cloudFiles.inferColumnTypes", "true")
        .load("s3://data-lake/landing/orders/")
    )
```

Key points:
- The **function name becomes the table name** (`bronze_orders`)
- The function **returns a DataFrame** (streaming or batch)
- Using `spark.readStream` makes it a **streaming table**
- Auto Loader (`cloudFiles`) is the standard way to ingest files in DLT

### Defining a Materialized View

```python
# Materialized View -- fully recomputed when upstream changes
@dlt.table(
    comment="Daily order summary by region"
)
def gold_daily_summary():
    return (spark.read.table("LIVE.silver_orders")
        .groupBy("order_date", "region")
        .agg(
            count("*").alias("order_count"),
            sum("amount").alias("total_revenue"),
            avg("amount").alias("avg_order_value")
        )
    )
```

Key points:
- Using `spark.read` (not `readStream`) makes it a **materialized view**
- References `LIVE.silver_orders` -- DLT resolves this dependency automatically
- The entire result is recomputed whenever the pipeline runs

### Streaming Table Reading from Another Streaming Table

```python
@dlt.table(
    comment="Cleaned and validated orders"
)
def silver_orders():
    return (spark.readStream.table("LIVE.bronze_orders")
        .filter(col("order_id").isNotNull())
        .withColumn("ingested_at", current_timestamp())
        .select("order_id", "customer_id", "amount", "order_date", "ingested_at")
    )
```

When a streaming table reads from another streaming table using `spark.readStream.table("LIVE.xxx")`,
it processes data incrementally -- only the new records that flowed through the upstream table.

## SQL API

DLT also has a SQL API that's even more concise:

### Streaming Table in SQL

```sql
-- Streaming Table (note the STREAMING keyword)
CREATE OR REFRESH STREAMING TABLE bronze_orders
COMMENT "Raw orders ingested from landing zone"
AS SELECT *
FROM STREAM read_files(
    's3://data-lake/landing/orders/',
    format => 'json',
    inferColumnTypes => 'true'
);
```

### Materialized View in SQL

```sql
-- Materialized View (no STREAMING keyword)
CREATE OR REFRESH MATERIALIZED VIEW gold_daily_summary
COMMENT "Daily order summary by region"
AS SELECT
    order_date,
    region,
    COUNT(*) AS order_count,
    SUM(amount) AS total_revenue,
    AVG(amount) AS avg_order_value
FROM LIVE.silver_orders
GROUP BY order_date, region;
```

### Streaming Table Reading from Upstream

```sql
-- Streaming from another streaming table
CREATE OR REFRESH STREAMING TABLE silver_orders
COMMENT "Cleaned and validated orders"
AS SELECT
    order_id,
    customer_id,
    amount,
    order_date,
    current_timestamp() AS ingested_at
FROM STREAM(LIVE.bronze_orders)
WHERE order_id IS NOT NULL;
```

### Python vs SQL Comparison

```
┌────────────────────────┬────────────────────────┬────────────────────────┐
│ Feature                │ Python                 │ SQL                    │
├────────────────────────┼────────────────────────┼────────────────────────┤
│ Streaming table        │ @dlt.table +           │ CREATE OR REFRESH      │
│                        │ readStream             │ STREAMING TABLE        │
├────────────────────────┼────────────────────────┼────────────────────────┤
│ Materialized view      │ @dlt.table +           │ CREATE OR REFRESH      │
│                        │ spark.read             │ MATERIALIZED VIEW      │
├────────────────────────┼────────────────────────┼────────────────────────┤
│ Read from pipeline     │ LIVE.table_name        │ LIVE.table_name        │
│ table (batch)          │                        │                        │
├────────────────────────┼────────────────────────┼────────────────────────┤
│ Read from pipeline     │ readStream.table(      │ STREAM(LIVE.table)     │
│ table (streaming)      │  "LIVE.table")         │                        │
├────────────────────────┼────────────────────────┼────────────────────────┤
│ Auto Loader ingest     │ cloudFiles format      │ read_files() function  │
│                        │                        │ with STREAM keyword    │
├────────────────────────┼────────────────────────┼────────────────────────┤
│ Expectations           │ @dlt.expect decorators │ CONSTRAINT keyword     │
└────────────────────────┴────────────────────────┴────────────────────────┘
```

## Data Quality with Expectations

### Python Expectations

```python
@dlt.table
@dlt.expect("valid_order_id", "order_id IS NOT NULL")
@dlt.expect("positive_amount", "amount > 0")
@dlt.expect_or_drop("valid_customer", "customer_id IS NOT NULL")
@dlt.expect_or_fail("valid_date", "order_date >= '2020-01-01'")
def silver_orders():
    return spark.readStream.table("LIVE.bronze_orders")
```

### SQL Expectations

```sql
CREATE OR REFRESH STREAMING TABLE silver_orders (
    -- Expectations as constraints
    CONSTRAINT valid_order_id EXPECT (order_id IS NOT NULL),
    CONSTRAINT positive_amount EXPECT (amount > 0),
    CONSTRAINT valid_customer EXPECT (customer_id IS NOT NULL) ON VIOLATION DROP ROW,
    CONSTRAINT valid_date EXPECT (order_date >= '2020-01-01') ON VIOLATION FAIL UPDATE
)
AS SELECT *
FROM STREAM(LIVE.bronze_orders);
```

### Expectation Behavior Summary

```
┌──────────────────────────┬────────────────────────┬────────────────────┐
│ Python                   │ SQL                    │ Behavior           │
├──────────────────────────┼────────────────────────┼────────────────────┤
│ @dlt.expect              │ EXPECT (expr)          │ Warn & keep record │
│                          │                        │ (log violation)    │
├──────────────────────────┼────────────────────────┼────────────────────┤
│ @dlt.expect_or_drop      │ EXPECT (expr)          │ Silently drop      │
│                          │ ON VIOLATION DROP ROW  │ violating records  │
├──────────────────────────┼────────────────────────┼────────────────────┤
│ @dlt.expect_or_fail      │ EXPECT (expr)          │ Fail the pipeline  │
│                          │ ON VIOLATION FAIL      │ immediately        │
│                          │ UPDATE                 │                    │
└──────────────────────────┴────────────────────────┴────────────────────┘
```

### Multiple Expectations

You can define multiple expectations on a single table. They are evaluated independently:

```python
@dlt.table
@dlt.expect("has_id", "id IS NOT NULL")
@dlt.expect("has_name", "name IS NOT NULL")
@dlt.expect_or_drop("valid_email", "email LIKE '%@%'")
@dlt.expect_or_fail("valid_status", "status IN ('active', 'inactive', 'pending')")
def validated_users():
    return spark.readStream.table("LIVE.bronze_users")
```

```
Evaluation order for a single record:

Record: {id: 1, name: null, email: "bad", status: "active"}

1. has_id:       id IS NOT NULL        → PASS ✓ (keep, no warning)
2. has_name:     name IS NOT NULL      → FAIL ✗ (keep, log warning)
3. valid_email:  email LIKE '%@%'      → FAIL ✗ (DROP record)
4. valid_status: (not evaluated -- record already dropped)

→ Expectations with DROP or FAIL take precedence over WARN
```

## Table Properties and Configuration

### Python

```python
@dlt.table(
    name="silver_orders",                      # Override table name
    comment="Cleaned order data",              # Table description
    table_properties={                         # Delta table properties
        "quality": "silver",
        "delta.autoOptimize.optimizeWrite": "true",
        "delta.autoOptimize.autoCompact": "true"
    },
    partition_cols=["order_date"],              # Partitioning columns
    temporary=False                            # Persist in catalog (default)
)
def silver_orders_table():
    return spark.readStream.table("LIVE.bronze_orders")
```

### Temporary Tables

```python
# Temporary table -- NOT published to the catalog
# Used for intermediate computations within the pipeline
@dlt.table(temporary=True)
def intermediate_calculation():
    return spark.read.table("LIVE.bronze_orders") \
        .filter(col("region") == "US")
```

Temporary tables:
- Are **not visible** in Unity Catalog after the pipeline runs
- Are used for **intermediate steps** that don't need to be queried externally
- Still participate in the DAG and dependency resolution
- Help keep the catalog clean by hiding implementation details

### Views (Not Materialized)

```python
# DLT View -- computed but NOT stored
# Used as an intermediate transformation step
@dlt.view
def enriched_orders_view():
    orders = spark.read.table("LIVE.silver_orders")
    customers = spark.read.table("LIVE.dim_customers")
    return orders.join(customers, "customer_id")
```

```
Dataset Types in DLT:

┌─────────────────────┬──────────┬───────────┬──────────────────────┐
│ Type                │ Stored?  │ In Catalog│ Use Case             │
├─────────────────────┼──────────┼───────────┼──────────────────────┤
│ Streaming Table     │ Yes      │ Yes       │ Incremental data     │
│ Materialized View   │ Yes      │ Yes       │ Aggregations, joins  │
│ Temporary Table     │ Yes      │ No        │ Intermediate steps   │
│ View (@dlt.view)    │ No       │ No        │ Reusable transforms  │
└─────────────────────┴──────────┴───────────┴──────────────────────┘
```

## Complete Pipeline Example

Here's a complete, production-ready DLT pipeline:

```python
import dlt
from pyspark.sql.functions import col, current_timestamp, to_date, sum, count, avg

# ==================== BRONZE LAYER ====================

@dlt.table(
    comment="Raw orders from landing zone",
    table_properties={"quality": "bronze"}
)
def bronze_orders():
    return (spark.readStream
        .format("cloudFiles")
        .option("cloudFiles.format", "json")
        .option("cloudFiles.inferColumnTypes", "true")
        .option("cloudFiles.rescuedDataColumn", "_rescued_data")
        .load("s3://data-lake/landing/orders/")
    )

@dlt.table(
    comment="Raw customer data from landing zone",
    table_properties={"quality": "bronze"}
)
def bronze_customers():
    return (spark.readStream
        .format("cloudFiles")
        .option("cloudFiles.format", "csv")
        .option("header", "true")
        .option("cloudFiles.inferColumnTypes", "true")
        .load("s3://data-lake/landing/customers/")
    )

# ==================== SILVER LAYER ====================

@dlt.table(
    comment="Validated and cleaned orders",
    table_properties={"quality": "silver"}
)
@dlt.expect("valid_order_id", "order_id IS NOT NULL")
@dlt.expect_or_drop("positive_amount", "amount > 0")
@dlt.expect_or_drop("valid_customer", "customer_id IS NOT NULL")
def silver_orders():
    return (spark.readStream.table("LIVE.bronze_orders")
        .withColumn("order_date", to_date(col("timestamp")))
        .withColumn("processed_at", current_timestamp())
        .select("order_id", "customer_id", "product_id",
                "amount", "order_date", "region", "processed_at")
    )

@dlt.table(
    comment="Validated customer records",
    table_properties={"quality": "silver"}
)
@dlt.expect_or_drop("valid_id", "customer_id IS NOT NULL")
@dlt.expect("has_email", "email IS NOT NULL")
def silver_customers():
    return (spark.readStream.table("LIVE.bronze_customers")
        .select("customer_id", "name", "email", "region", "signup_date")
    )

# ==================== GOLD LAYER ====================

@dlt.table(
    comment="Daily revenue summary by region",
    table_properties={"quality": "gold"}
)
def gold_daily_revenue():
    return (spark.read.table("LIVE.silver_orders")
        .groupBy("order_date", "region")
        .agg(
            count("*").alias("order_count"),
            sum("amount").alias("total_revenue"),
            avg("amount").alias("avg_order_value")
        )
    )

@dlt.table(
    comment="Customer lifetime value",
    table_properties={"quality": "gold"}
)
def gold_customer_ltv():
    orders = spark.read.table("LIVE.silver_orders")
    customers = spark.read.table("LIVE.silver_customers")
    return (orders
        .groupBy("customer_id")
        .agg(
            count("*").alias("total_orders"),
            sum("amount").alias("lifetime_value")
        )
        .join(customers, "customer_id")
        .select("customer_id", "name", "region",
                "total_orders", "lifetime_value")
    )
```

```
Generated DAG:

  S3 orders/          S3 customers/
      │                    │
      ▼                    ▼
┌────────────┐     ┌────────────────┐
│ bronze_    │     │ bronze_        │
│ orders     │     │ customers      │
└─────┬──────┘     └───────┬────────┘
      │                    │
      ▼                    ▼
┌────────────┐     ┌────────────────┐
│ silver_    │     │ silver_        │
│ orders     │     │ customers      │
└──┬──────┬──┘     └──┬─────────────┘
   │      │           │
   ▼      │           │
┌────────┐│           │
│ gold_  ││           │
│ daily_ ││           │
│ revenue││           │
└────────┘│           │
          ▼           ▼
     ┌──────────────────────┐
     │ gold_customer_ltv    │
     └──────────────────────┘
```

## Pipeline Configuration

When creating a DLT pipeline in Databricks, you configure:

```json
{
    "name": "orders_pipeline",
    "target": "catalog.schema",
    "notebooks": [
        "/Repos/team/pipelines/orders_pipeline"
    ],
    "configuration": {
        "source_path": "s3://data-lake/landing/orders/",
        "env": "production"
    },
    "clusters": [
        {
            "autoscale": {
                "min_workers": 1,
                "max_workers": 5
            }
        }
    ],
    "continuous": false,
    "photon": true,
    "edition": "ADVANCED"
}
```

Access configuration values in your pipeline code:

```python
@dlt.table
def bronze_orders():
    source_path = spark.conf.get("source_path")
    return (spark.readStream
        .format("cloudFiles")
        .option("cloudFiles.format", "json")
        .load(source_path)
    )
```

## Key Exam Points

1. **Python API**: `@dlt.table` decorator + function returning a DataFrame
2. **SQL API**: `CREATE OR REFRESH STREAMING TABLE` or `CREATE OR REFRESH MATERIALIZED VIEW`
3. **Function name = table name** in Python; explicitly named in SQL
4. **`readStream` = streaming table**; `spark.read` = materialized view
5. **LIVE.table_name** references tables within the same pipeline (both Python and SQL)
6. **STREAM(LIVE.table)** in SQL for streaming reads from upstream streaming tables
7. **Three expectation levels**: expect (warn), expect_or_drop (filter), expect_or_fail (halt)
8. **SQL expectations** use `CONSTRAINT name EXPECT (expr) ON VIOLATION {DROP ROW|FAIL UPDATE}`
9. **Temporary tables** (`temporary=True`) are not published to the catalog
10. **`@dlt.view`** creates a non-materialized view -- computed but not stored
11. **Pipeline configuration** values are accessed via `spark.conf.get()` in notebook code
12. **Multiple notebooks** can be part of one pipeline -- all `@dlt.table` definitions are
    combined into a single DAG
