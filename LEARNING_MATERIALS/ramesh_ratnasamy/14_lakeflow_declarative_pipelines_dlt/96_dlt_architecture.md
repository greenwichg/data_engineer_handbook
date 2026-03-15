# DLT Architecture

## Introduction

Now let's look at how Delta Live Tables works under the hood. Understanding the architecture
is important because it explains *why* DLT can manage so much complexity for you -- dependency
resolution, cluster management, incremental processing, and error recovery all stem from how
the system is designed.

## Pipeline Architecture

A DLT pipeline is more than just a collection of table definitions. It's a managed execution
environment that Databricks operates on your behalf:

```
DLT Pipeline Architecture:

┌─────────────────────────────────────────────────────────────────┐
│                      DLT PIPELINE                              │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    SOURCE NOTEBOOKS                      │  │
│  │                                                          │  │
│  │  notebook_1.py    notebook_2.py    notebook_3.sql        │  │
│  │  (bronze layer)   (silver layer)   (gold layer)          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           │                                    │
│                           ▼                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    DAG BUILDER                            │  │
│  │                                                          │  │
│  │  Analyzes all @dlt.table and @dlt.view definitions       │  │
│  │  Resolves LIVE.table_name references                     │  │
│  │  Builds dependency graph automatically                   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           │                                    │
│                           ▼                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                 EXECUTION ENGINE                          │  │
│  │                                                          │  │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────────────┐    │  │
│  │  │ Cluster   │  │ Checkpoint│  │ Expectation       │    │  │
│  │  │ Manager   │  │ Manager   │  │ Evaluator         │    │  │
│  │  └───────────┘  └───────────┘  └───────────────────┘    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                           │                                    │
│                           ▼                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                  TARGET CATALOG                           │  │
│  │                                                          │
│  │  catalog.schema.bronze_table                              │  │
│  │  catalog.schema.silver_table                              │  │
│  │  catalog.schema.gold_view                                 │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## The Dependency Graph (DAG)

DLT's most powerful architectural feature is automatic dependency resolution. When you reference
`LIVE.table_name` in your code, DLT builds a directed acyclic graph (DAG) of all table
dependencies:

```python
# DLT automatically resolves these dependencies into a DAG

@dlt.table
def bronze_orders():
    return spark.readStream.format("cloudFiles") \
        .option("cloudFiles.format", "json") \
        .load("s3://landing/orders/")

@dlt.table
def bronze_customers():
    return spark.readStream.format("cloudFiles") \
        .option("cloudFiles.format", "json") \
        .load("s3://landing/customers/")

@dlt.table
def silver_orders():
    return spark.readStream.table("LIVE.bronze_orders") \
        .filter(col("order_id").isNotNull())

@dlt.table
def gold_order_summary():
    orders = spark.read.table("LIVE.silver_orders")
    customers = spark.read.table("LIVE.bronze_customers")
    return orders.join(customers, "customer_id") \
        .groupBy("region").agg(sum("amount"))
```

```
Automatically Generated DAG:

  ┌──────────────┐     ┌───────────────────┐
  │ bronze_      │     │ bronze_           │
  │ orders       │     │ customers         │
  │ (streaming)  │     │ (streaming)       │
  └──────┬───────┘     └────────┬──────────┘
         │                      │
         ▼                      │
  ┌──────────────┐              │
  │ silver_      │              │
  │ orders       │              │
  │ (streaming)  │              │
  └──────┬───────┘              │
         │                      │
         ▼                      ▼
  ┌─────────────────────────────────────┐
  │ gold_order_summary                  │
  │ (materialized view)                 │
  └─────────────────────────────────────┘

DLT ensures:
  1. bronze tables are processed BEFORE silver
  2. silver and bronze_customers are processed BEFORE gold
  3. Parallel execution where possible (both bronze tables run concurrently)
```

Key point: **you never specify the execution order**. DLT figures it out from your table
references. This is the core benefit of the declarative approach.

## The LIVE Virtual Schema

The `LIVE` keyword is a virtual schema that references tables within the same DLT pipeline:

```python
# LIVE.table_name refers to a table defined in THIS pipeline
df = spark.read.table("LIVE.silver_orders")

# This is NOT the same as reading from the catalog directly
# LIVE resolves at pipeline execution time, not at definition time
```

```
LIVE vs Direct Table Reference:

┌───────────────────────┬──────────────────────────────────────────┐
│ LIVE.table_name       │ catalog.schema.table_name                │
├───────────────────────┼──────────────────────────────────────────┤
│ References within     │ References any table in the catalog      │
│ the DLT pipeline      │                                          │
│                       │                                          │
│ DLT manages the       │ You manage the dependency                │
│ dependency            │                                          │
│                       │                                          │
│ Table may not exist   │ Table must exist before pipeline runs    │
│ yet (DLT creates it)  │                                          │
│                       │                                          │
│ Resolved at pipeline  │ Resolved at query execution time         │
│ planning time         │                                          │
└───────────────────────┴──────────────────────────────────────────┘
```

## Pipeline Storage Architecture

DLT manages several storage locations behind the scenes:

```
Pipeline Storage:

┌─────────────────────────────────────────────────────────────┐
│                    Unity Catalog                            │
│                                                             │
│  catalog.schema.bronze_orders    ← Delta table              │
│  catalog.schema.silver_orders    ← Delta table              │
│  catalog.schema.gold_summary     ← Materialized view        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   Managed Storage                           │
│                                                             │
│  /pipelines/{pipeline_id}/                                  │
│  ├── system/                                                │
│  │   ├── events/        ← Pipeline event logs               │
│  │   └── expectations/  ← Data quality metrics              │
│  ├── checkpoints/       ← Streaming checkpoints             │
│  │   ├── bronze_orders/                                     │
│  │   └── silver_orders/                                     │
│  └── tables/            ← Table data (if using pipeline     │
│      └── ...              storage instead of UC)            │
└─────────────────────────────────────────────────────────────┘
```

DLT automatically manages:
- **Checkpoints** for each streaming table (no manual `checkpointLocation` needed)
- **Event logs** that record pipeline runs, data quality metrics, and lineage
- **Schema evolution** when source data changes

## Cluster Management

DLT manages its own compute clusters, separate from interactive or job clusters:

```
DLT Cluster Architecture:

┌─────────────────────────────────────────────┐
│              DLT Pipeline                   │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │         DLT-Managed Cluster         │    │
│  │                                     │    │
│  │  ┌─────────┐  ┌─────────────────┐   │    │
│  │  │ Driver  │  │ Workers (auto-  │   │    │
│  │  │ Node    │  │ scaled by DLT)  │   │    │
│  │  └─────────┘  └─────────────────┘   │    │
│  │                                     │    │
│  │  - Cluster size managed by DLT      │    │
│  │  - Autoscaling based on workload    │    │
│  │  - Cluster starts/stops with        │    │
│  │    pipeline runs                    │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘

You configure:
  - Min/max workers (autoscaling bounds)
  - Instance type
  - Spark configuration (optional)
  - Photon acceleration (optional)

DLT manages:
  - When to start/stop clusters
  - How many workers to use
  - Resource allocation across pipeline stages
```

## Event Log

Every DLT pipeline maintains a detailed event log that's stored as a Delta table:

```python
# Query the event log for a pipeline
event_log = spark.read.table("event_log('{pipeline_id}')")

# Or access from the system schema
event_log = spark.sql("""
    SELECT *
    FROM event_log('{pipeline_id}')
    WHERE event_type = 'flow_progress'
    ORDER BY timestamp DESC
""")
```

The event log captures:
- **Pipeline starts/stops** -- when and why
- **Data quality metrics** -- expectation pass/fail counts per batch
- **Flow progress** -- which tables were updated, how many records
- **Errors** -- detailed error messages and stack traces
- **Lineage** -- data flow between tables

```
Event Log Contents:

┌──────────────┬────────────────────────────────────────────┐
│ Event Type   │ Information Captured                       │
├──────────────┼────────────────────────────────────────────┤
│ create_update│ Pipeline created or settings changed       │
│ user_action  │ Start, stop, or full refresh requested     │
│ flow_progress│ Records processed per table per batch      │
│ flow_definition│ Table definitions and dependencies       │
│ planning     │ DAG construction and execution plan        │
│ cluster_resources│ Cluster start/stop/resize events      │
│ data_quality │ Expectation results (pass/fail counts)     │
└──────────────┴────────────────────────────────────────────┘
```

## Full Refresh vs Incremental

DLT supports two update strategies:

```
Update Strategies:

Incremental Update (default for streaming tables):
  ┌───────────────┐
  │ Existing data │ + New data  → Process only NEW data
  │ (already      │   arrives     (efficient, fast)
  │  processed)   │
  └───────────────┘

Full Refresh:
  ┌───────────────┐
  │ ALL data      │ → Reprocess EVERYTHING from scratch
  │ (drop and     │   (slow but gives clean state)
  │  recreate)    │
  └───────────────┘

When to use Full Refresh:
  - Schema changes that break incremental processing
  - Data quality issues that corrupted historical data
  - Logic changes that need to be applied retroactively
  - Pipeline checkpoint corruption
```

Full refresh can be triggered from the DLT UI or API. It drops all tables and reprocesses
from the sources.

## Key Exam Points

1. **DLT automatically builds a DAG** from `LIVE.table_name` references -- no manual ordering
2. **LIVE is a virtual schema** that resolves table references within the same pipeline
3. **DLT manages its own clusters** -- separate from interactive/job clusters, with autoscaling
4. **Event log** records pipeline progress, data quality metrics, errors, and lineage
5. **Checkpoints are managed automatically** -- no need to specify `checkpointLocation`
6. **Full refresh** drops and recreates all tables from scratch; **incremental** processes
   only new data
7. **Multiple notebooks** can be part of one pipeline -- DLT combines all definitions into a
   single DAG
8. **Pipeline storage** includes checkpoints, event logs, and expectation metrics
9. **Parallel execution** happens automatically where the DAG allows (independent branches)
10. **DLT resolves dependencies at planning time**, not at query execution time
