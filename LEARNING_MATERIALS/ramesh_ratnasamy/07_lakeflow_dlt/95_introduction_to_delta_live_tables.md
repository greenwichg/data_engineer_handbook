# Introduction to Delta Live Tables

## Introduction

Alright, let's talk about Delta Live Tables -- or DLT as everyone calls it. Recently rebranded
as **Lakeflow Declarative Pipelines** in the Databricks ecosystem, DLT is one of the most
important features to understand for both the exam and real-world Databricks development.

Here's the problem DLT solves: building production data pipelines is hard. You need to handle
data quality, manage dependencies between tables, deal with schema evolution, handle errors
gracefully, orchestrate the pipeline, and monitor everything. Traditionally, data engineers
write hundreds of lines of boilerplate code to manage all of this. DLT lets you focus on the
*what* (your transformation logic) instead of the *how* (all the infrastructure plumbing).

DLT is a **declarative framework** for building reliable, maintainable, and testable data
pipelines on Databricks. Instead of writing imperative code that says "first read this, then
transform that, then write here, then handle this error," you declare what your tables should
look like and what quality expectations they should meet. DLT handles the rest -- orchestration,
error handling, monitoring, and optimization.

## What Makes DLT Different?

Let's compare traditional pipeline development with DLT:

```
Traditional Pipeline Development:

1. Read source data                          (your code)
2. Apply transformations                     (your code)
3. Handle schema evolution                   (your code)
4. Write to target table                     (your code)
5. Manage dependencies between tables        (your code)
6. Handle failures and retries               (your code)
7. Implement data quality checks             (your code)
8. Set up monitoring and alerting            (your code)
9. Manage infrastructure (clusters, etc.)    (your code)

DLT Pipeline Development:

1. Declare your tables and transformations   (your code)
2. Declare data quality expectations         (your code)
3. Everything else                           (DLT handles it)
```

The shift is from **imperative** ("do this, then that") to **declarative** ("here's what I
want the result to look like"). This is similar to how SQL is declarative -- you say *what*
data you want, not *how* to get it.

## Core Concepts

### Datasets

In DLT, everything is a **dataset**. There are two types:

```
DLT Dataset Types:

┌─────────────────────────────────────────────────────────────────┐
│                       STREAMING TABLES                         │
│                                                                │
│  - Append-only (designed for streaming/incremental data)       │
│  - Processed incrementally (each record handled once)          │
│  - Ideal for: raw ingestion, event data, log data              │
│  - Source: Auto Loader (cloudFiles), Kafka, streaming sources  │
│  - Think: "continuously growing fact table"                    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      MATERIALIZED VIEWS                        │
│                                                                │
│  - Fully recomputed when source data changes                   │
│  - Results are materialized (stored) for fast querying          │
│  - Ideal for: aggregations, joins, slowly changing data        │
│  - Source: Any table, batch queries                             │
│  - Think: "precomputed query result, always up-to-date"        │
└─────────────────────────────────────────────────────────────────┘
```

**Streaming tables** are for data that grows incrementally -- new records arrive and are
processed once. **Materialized views** are for transformations that need to consider the
full dataset -- aggregations, lookups, or any query where the result depends on all the data.

### The Medallion Architecture in DLT

DLT naturally fits the Bronze-Silver-Gold medallion pattern:

```
Medallion Architecture with DLT:

  Cloud Storage              DLT Pipeline
  (S3/GCS)
                    ┌──────────────────────────────────────────┐
  ┌──────────┐     │                                          │
  │ Raw JSON │     │  ┌──────────┐  ┌──────────┐  ┌────────┐ │
  │ files    │────▶│  │  BRONZE  │─▶│  SILVER  │─▶│  GOLD  │ │
  │          │     │  │ Streaming│  │ Streaming│  │ Mater. │ │
  │          │     │  │  Table   │  │  Table   │  │  View  │ │
  └──────────┘     │  └──────────┘  └──────────┘  └────────┘ │
                    │                                          │
                    │  Raw ingest    Cleaned &     Aggregated  │
                    │  (append-only) validated     (recomputed)│
                    └──────────────────────────────────────────┘

Bronze: Streaming Table -- raw data ingested via Auto Loader
Silver: Streaming Table -- cleaned, validated, deduplicated
Gold:   Materialized View -- business-level aggregations
```

### Data Quality with Expectations

One of DLT's killer features is **expectations** -- declarative data quality constraints:

```python
@dlt.table
@dlt.expect("valid_id", "id IS NOT NULL")
@dlt.expect_or_drop("valid_amount", "amount > 0")
@dlt.expect_or_fail("valid_timestamp", "timestamp IS NOT NULL")
def silver_orders():
    return spark.readStream.table("LIVE.bronze_orders")
```

```
Expectation Actions:

┌──────────────────────┬─────────────────────────────────────────────┐
│ Decorator            │ On Violation                                │
├──────────────────────┼─────────────────────────────────────────────┤
│ @dlt.expect          │ Record is KEPT, violation is LOGGED         │
│                      │ (warn and continue)                         │
├──────────────────────┼─────────────────────────────────────────────┤
│ @dlt.expect_or_drop  │ Record is DROPPED silently                  │
│                      │ (filter out bad data)                       │
├──────────────────────┼─────────────────────────────────────────────┤
│ @dlt.expect_or_fail  │ Pipeline FAILS immediately                  │
│                      │ (stop on critical data quality issues)      │
└──────────────────────┴─────────────────────────────────────────────┘
```

This is a heavily tested exam topic. Know the three expectation types and their behavior.

## DLT Pipeline Lifecycle

A DLT pipeline goes through several states:

```
Pipeline Lifecycle:

  ┌──────────┐     ┌───────────┐     ┌───────────┐     ┌──────────┐
  │  IDLE    │────▶│ STARTING  │────▶│  RUNNING  │────▶│ COMPLETED│
  └──────────┘     └───────────┘     └───────────┘     └──────────┘
       ▲                                   │
       │                                   │ (on error)
       │           ┌───────────┐           ▼
       └───────────│  FAILED   │◀──────────┘
                   └───────────┘

Pipeline Modes:
- Triggered: Run once, process available data, stop (like availableNow)
- Continuous: Run continuously, process data as it arrives
```

**Triggered mode** is the most common for production pipelines. It processes all available data
and stops, similar to `trigger(availableNow=True)` in Structured Streaming. You schedule it
using Databricks Jobs (e.g., run every hour).

**Continuous mode** keeps the pipeline running and processes data as it arrives, with lower
latency but higher cluster cost.

## DLT vs Manual Pipeline Development

```
┌─────────────────────────┬────────────────────┬─────────────────────┐
│ Capability              │ Manual Pipeline    │ DLT                 │
├─────────────────────────┼────────────────────┼─────────────────────┤
│ Dependency management   │ You manage order   │ Automatic (DAG)     │
│ Data quality checks     │ Custom code        │ Expectations        │
│ Error handling          │ Try/catch blocks   │ Built-in            │
│ Schema evolution        │ mergeSchema option │ Automatic           │
│ Pipeline monitoring     │ Custom dashboards  │ Built-in UI         │
│ Cluster management      │ Manual config      │ Managed by DLT      │
│ Reprocessing            │ Complex logic      │ Full refresh button │
│ Incremental processing  │ Checkpoint mgmt    │ Automatic           │
│ Code complexity         │ High               │ Low                 │
└─────────────────────────┴────────────────────┴─────────────────────┘
```

## DLT Editions

DLT comes in different editions with different feature sets:

```
┌─────────────────────────┬──────────┬──────────┬───────────┐
│ Feature                 │ Core     │ Pro      │ Advanced  │
├─────────────────────────┼──────────┼──────────┼───────────┤
│ Streaming tables        │ ✓        │ ✓        │ ✓         │
│ Materialized views      │ ✓        │ ✓        │ ✓         │
│ Expectations            │ ✓        │ ✓        │ ✓         │
│ Change Data Capture     │          │ ✓        │ ✓         │
│ (CDC / APPLY CHANGES)   │          │          │           │
│ Enhanced autoscaling    │          │          │ ✓         │
└─────────────────────────┴──────────┴──────────┴───────────┘
```

## Key Exam Points

1. **DLT is a declarative framework** -- you declare *what* tables should look like, not *how*
   to build them
2. **Two dataset types**: Streaming Tables (append-only, incremental) and Materialized Views
   (fully recomputed)
3. **Three expectation types**: `expect` (warn), `expect_or_drop` (filter), `expect_or_fail`
   (halt pipeline)
4. **Medallion architecture** maps naturally to DLT: Bronze (streaming table), Silver
   (streaming table), Gold (materialized view)
5. **Pipeline modes**: Triggered (run and stop) vs Continuous (run forever)
6. **DLT manages**: dependency ordering, cluster infrastructure, error handling, monitoring,
   and incremental processing automatically
7. **DLT is now called Lakeflow Declarative Pipelines** -- but the exam may use either name
8. **Streaming tables use Auto Loader** under the hood for file ingestion
9. **Materialized views recompute fully** when upstream data changes
10. **Expectations provide data quality** monitoring and enforcement without custom code
