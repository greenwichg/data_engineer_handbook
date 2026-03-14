# Medallion Architecture in Data Lakehouse

## Introduction

Welcome back. As we saw in the last lesson, Databricks enables us to build a modern Data Lakehouse platform.

While the Data Lakehouse can be shown as a single entity in diagrams, it's more involved than that. Let's delve deeper into the data architecture within the Data Lakehouse platform.

---

## What is Medallion Architecture?

The data architecture used in the Data Lakehouse is commonly referred to as **Medallion Architecture**—a term originally coined by Databricks and now widely adopted in the industry.

### Key Points to Understand:

- **Not an architectural pattern, but a data design pattern**
- Has existed in data warehouses and data lakes for some time
- Databricks refined it within the Data Lakehouse model using a simple three-layer structure: **Bronze, Silver, and Gold**
- The term "medallion" comes from these layer names

### Data Flow and Quality

In the Medallion Architecture, data flows through these layers (Bronze → Silver → Gold), and **as data progresses through each layer, its quality improves**.

```
+====================================================================+
|              MEDALLION ARCHITECTURE DATA FLOW                       |
+====================================================================+
|                                                                     |
|  DATA SOURCES                                                       |
|  +---------+  +---------+  +---------+  +---------+                |
|  |  RDBMS  |  |  APIs   |  |  Files  |  | Streams |                |
|  +----+----+  +----+----+  +----+----+  +----+----+                |
|       |            |            |            |                       |
|       +------+-----+-----+-----+            |                       |
|              |           |                   |                       |
|              v           v                   v                       |
|  +======================================================+          |
|  |  BRONZE LAYER (Raw)                                   |          |
|  |  "Land data as-is"                                    |          |
|  |  Quality: LOW        Format: Raw / near-raw           |          |
|  +==========================+===========================+          |
|                              |                                      |
|                              v                                      |
|  +======================================================+          |
|  |  SILVER LAYER (Cleansed)                              |          |
|  |  "Validate, deduplicate, standardize"                 |          |
|  |  Quality: MEDIUM     Format: Structured / enriched    |          |
|  +==========================+===========================+          |
|                              |                                      |
|                              v                                      |
|  +======================================================+          |
|  |  GOLD LAYER (Business-Ready)                          |          |
|  |  "Aggregate for business consumption"                 |          |
|  |  Quality: HIGH       Format: Aggregated / KPI-ready   |          |
|  +======================================================+          |
|              |                  |                  |                 |
|              v                  v                  v                 |
|       +------------+    +------------+    +--------------+          |
|       | BI Reports |    |  ML / AI   |    |  Dashboards  |          |
|       +------------+    +------------+    +--------------+          |
+=====================================================================+
```

### Flexibility in Layer Count:

- **Most common**: Three layers (Bronze, Silver, Gold)
- **Extended projects**: May include a fourth "Platinum" layer
- **Simpler projects**: May have only two layers
- **Key principle**: Clearly identify and define each layer's characteristics upfront to gain maximum benefits

---

## The Three Layers

### Bronze Layer: Raw Data

The Bronze layer contains **raw data as received from various data sources**.

**Characteristics:**

- Minimal to no transformation
- May include additional metadata:
  - Load timestamp
  - Source file name
  - Other tracking information for auditing and issue identification

**Benefits:**

- Maintains historical record of all data received
- Easy to replay data if pipeline issues occur
- Supports fast ingestion of high-volume and high-velocity data

---

### Silver Layer: Cleansed and Structured Data

The Silver layer holds **filtered, cleansed, and enriched data** with structure applied and schema either enforced or evolved to maintain consistency.

**Data Processing Activities:**

- Quality checks performed
- Invalid records removed
- Column values standardized
- Duplicates eliminated
- Missing values replaced or removed
- Required context or descriptions added

**Result:**

Structured, high-quality, and reliable data suitable for:
- Data science workloads
- Machine learning
- AI applications

---

### Gold Layer: Business-Ready Data

The Gold layer contains **business-level aggregated data**.

**Characteristics:**

- Data from Silver layer is further aggregated
- Enriched with additional context
- Ready for high-level business reporting and analysis
- Used for advanced analytics and applications

---

```
+====================================================================+
|           DETAILED LAYER COMPARISON                                  |
+====================================================================+
|                                                                     |
|  BRONZE               SILVER               GOLD                    |
|  +----------------+   +----------------+   +----------------+      |
|  | Raw data       |   | Cleaned data   |   | Aggregated     |      |
|  | as-is from     |   | validated,     |   | business-level |      |
|  | source         |   | deduplicated   |   | data           |      |
|  +----------------+   +----------------+   +----------------+      |
|  | Schema: source |   | Schema:        |   | Schema:        |      |
|  | schema or      |   | enforced /     |   | star schema /  |      |
|  | schema-on-read |   | evolved        |   | aggregations   |      |
|  +----------------+   +----------------+   +----------------+      |
|  | Consumers:     |   | Consumers:     |   | Consumers:     |      |
|  | Data engineers |   | Data scientists|   | Business       |      |
|  |                |   | ML engineers   |   | analysts, KPIs |      |
|  +----------------+   +----------------+   +----------------+      |
|  | Retention:     |   | Retention:     |   | Retention:     |      |
|  | Long-term      |   | Medium-term    |   | As needed by   |      |
|  | (full history) |   |                |   | business       |      |
|  +----------------+   +----------------+   +----------------+      |
|                                                                     |
+====================================================================+
```

| Attribute | Bronze | Silver | Gold |
|---|---|---|---|
| **Data quality** | Low (raw) | Medium (validated) | High (business-ready) |
| **Schema enforcement** | None or minimal | Enforced / evolved | Strict, well-defined |
| **Transformations** | None or metadata only | Filter, clean, deduplicate, join | Aggregate, summarize, enrich |
| **Typical format** | Raw JSON, CSV, Parquet | Delta tables (structured) | Delta tables (aggregated) |
| **Primary consumers** | Data engineers | Data scientists, ML engineers | Business analysts, executives |
| **Update frequency** | Near real-time / batch | Scheduled or triggered | Scheduled or on-demand |
| **Storage cost** | Highest (all raw data) | Moderate | Lowest (aggregated) |
| **GDPR compliance role** | Holds PII in raw form | PII masked/pseudonymized | PII removed or aggregated |

---

## Benefits of Medallion Architecture

### 1. Improved Data Lineage and Traceability

Moving data through clearly defined layers (Bronze, Silver, Gold) makes it easier to:
- Track where data came from
- Understand how it's transformed
- Monitor how it's used in applications

### 2. Enhanced Data Governance and Compliance

The layered approach helps enforce compliance policies such as:
- GDPR
- CCPA
- Other regulatory requirements

Each layer has defined meaning and data granularity, which helps define:
- Retention policies
- Access controls
- Compliance requirements

### 3. Incremental Processing Support

Allows for processing only **new and changed data** received at the Data Lakehouse, which:
- Reduces computational costs
- Improves performance

### 4. Better Workload Management

The layered approach enables:
- Workload management for each layer
- Creation of scalable solutions

### 5. Enhanced Security Control

Provides better control through:
- Role-based access control (RBAC)
- Ensuring only authorized users access secure and sensitive data

**Example**: Users can be granted access to only the Gold layer if they shouldn't have access to transactional-level customer data available in Bronze and Silver layers.

---

## Summary

The Medallion Architecture provides a **flexible data design pattern** that can be adapted based on your project requirements.

By clearly defining each layer's purpose and characteristics, you can ensure:
- Data consistency
- Data quality
- Efficiency throughout your data pipeline

---

## CONCEPT GAP: Implementing Medallion Architecture with Delta Live Tables (DLT)

Delta Live Tables is Databricks' declarative ETL framework that is purpose-built to implement the Medallion Architecture. Understanding DLT is critical for both the certification exam and real-world Databricks projects.

```
+====================================================================+
|         DELTA LIVE TABLES + MEDALLION ARCHITECTURE                   |
+====================================================================+
|                                                                     |
|  @dlt.table (Bronze)          @dlt.table (Silver)                   |
|  +---------------------+     +---------------------+               |
|  | raw_orders           |     | clean_orders         |              |
|  |                     | --> |                     |               |
|  | dlt.read_stream     |     | dlt.read_stream     |               |
|  | ("source")          |     | ("raw_orders")      |               |
|  +---------------------+     +---------------------+               |
|                                        |                            |
|                                        v                            |
|                              @dlt.table (Gold)                      |
|                              +---------------------+                |
|                              | daily_order_summary  |               |
|                              |                     |                |
|                              | dlt.read_stream     |                |
|                              | ("clean_orders")    |                |
|                              | .groupBy("date")    |                |
|                              +---------------------+                |
+====================================================================+
```

### Key DLT Concepts for Medallion Architecture

- **Streaming Tables**: Used for Bronze and Silver layers; process data incrementally as it arrives
- **Materialized Views**: Used for Gold layer; automatically recompute when upstream data changes
- **Expectations**: Built-in data quality constraints (e.g., `@dlt.expect_or_drop("valid_id", "id IS NOT NULL")`) that enforce quality at each layer transition
- **Pipeline Dependencies**: DLT automatically manages the order of execution based on declared dependencies between tables

### DLT Quality Enforcement with Expectations

| Expectation Type | Behavior | Use Case |
|---|---|---|
| `@dlt.expect` | Logs warning, keeps record | Monitor quality without blocking |
| `@dlt.expect_or_drop` | Silently drops failing records | Silver layer: remove invalid rows |
| `@dlt.expect_or_fail` | Fails the entire pipeline | Critical quality gates |

---

## CONCEPT GAP: Incremental Processing with Auto Loader and Structured Streaming

Efficiently moving data between Medallion layers requires incremental processing. Two key Databricks technologies make this possible.

```
+====================================================================+
|         INCREMENTAL PROCESSING IN MEDALLION LAYERS                   |
+====================================================================+
|                                                                     |
|  Cloud Storage                                                      |
|  (S3 / ADLS / GCS)                                                 |
|       |                                                             |
|       | (Auto Loader detects new files automatically)               |
|       v                                                             |
|  +---------------------------+                                      |
|  |    AUTO LOADER            |                                      |
|  |    cloudFiles format      |                                      |
|  |    - File notification    |                                      |
|  |    - Directory listing    |                                      |
|  +-------------+-------------+                                      |
|                |                                                    |
|                v                                                    |
|  +---------------------------+                                      |
|  |  BRONZE (Streaming Table) |                                      |
|  +-------------+-------------+                                      |
|                |                                                    |
|                | (Structured Streaming reads change feed)            |
|                v                                                    |
|  +---------------------------+                                      |
|  |  SILVER (Streaming Table) |                                      |
|  +-------------+-------------+                                      |
|                |                                                    |
|                | (Change Data Feed propagates updates)               |
|                v                                                    |
|  +---------------------------+                                      |
|  |  GOLD (Materialized View) |                                      |
|  +---------------------------+                                      |
+====================================================================+
```

### Auto Loader

Auto Loader (`cloudFiles` format) is the recommended way to ingest data into the Bronze layer:

- **File notification mode**: Uses cloud events (e.g., AWS SNS/SQS, Azure Event Grid) to detect new files -- scalable for millions of files
- **Directory listing mode**: Periodically lists the directory -- simpler setup, suitable for fewer files
- **Schema inference and evolution**: Automatically detects schema from incoming files and can evolve schema as new columns appear
- **Exactly-once guarantee**: Tracks processed files via checkpointing to avoid duplicates

### Change Data Feed (CDF)

Change Data Feed enables efficient propagation of changes from Silver to Gold:

- Records `INSERT`, `UPDATE`, and `DELETE` operations on Delta tables
- Downstream consumers read only the changes, not the full table
- Enabled per table: `ALTER TABLE SET TBLPROPERTIES (delta.enableChangeDataFeed = true)`

---

## CONCEPT GAP: Medallion Architecture vs Traditional ETL/ELT Patterns

Understanding how Medallion Architecture relates to and differs from traditional data engineering patterns is a common interview topic.

```
+====================================================================+
|     TRADITIONAL ETL vs ELT vs MEDALLION                              |
+====================================================================+
|                                                                     |
|  ETL (Traditional Warehouse)                                        |
|  Source --> Extract --> Transform --> Load --> Warehouse             |
|  (Transform BEFORE loading)                                         |
|                                                                     |
|  ELT (Modern Cloud)                                                 |
|  Source --> Extract --> Load --> Transform --> Serve                  |
|  (Transform AFTER loading)                                          |
|                                                                     |
|  MEDALLION (Lakehouse)                                              |
|  Source --> Bronze (Load raw) --> Silver (Transform) --> Gold (Agg)  |
|  (Multi-stage transformation with quality gates)                    |
|                                                                     |
+====================================================================+
```

| Aspect | Traditional ETL | ELT | Medallion Architecture |
|---|---|---|---|
| **Transform timing** | Before load | After load | Progressive (multi-stage) |
| **Raw data preserved** | No (transformed before load) | Yes | Yes (in Bronze) |
| **Replayability** | Difficult | Possible | Easy (replay from Bronze) |
| **Quality enforcement** | At transform step | Post-load validation | At each layer transition |
| **Incremental processing** | Complex to implement | Varies | Native (Auto Loader, CDF) |
| **Platform** | On-prem warehouse | Cloud warehouse | Data Lakehouse |

---

## CONCEPT GAP: Common Anti-Patterns in Medallion Architecture

Knowing what NOT to do is as important as knowing the pattern itself. These anti-patterns frequently appear in interview discussions.

### Anti-Patterns to Avoid

1. **Skipping the Bronze layer**: Loading data directly into Silver loses the ability to replay and audit raw data. Always land raw data first.

2. **Over-transforming in Bronze**: Bronze should have minimal transformations. Adding business logic at this layer defeats its purpose as a raw historical record.

3. **Too many layers**: Adding unnecessary layers (e.g., Bronze-1, Bronze-2, Silver-1, Silver-2) increases complexity without proportional benefit. Keep the architecture simple.

4. **Gold layer as a copy of Silver**: If the Gold layer is just a copy of Silver without meaningful aggregation, it adds storage cost without value.

5. **No schema enforcement at Silver**: Failing to enforce schema at the Silver layer allows bad data to propagate to Gold, undermining data quality.

6. **Ignoring data retention policies**: Keeping all data indefinitely in all layers leads to unnecessary storage costs. Define retention policies per layer.

---

## CONCEPT GAP: Medallion Architecture and Unity Catalog

Unity Catalog provides the governance layer that secures data across all Medallion layers.

```
+====================================================================+
|        UNITY CATALOG GOVERNANCE ACROSS MEDALLION LAYERS              |
+====================================================================+
|                                                                     |
|  Unity Catalog                                                      |
|  +--------------------------------------------------------------+  |
|  |  Metastore                                                    |  |
|  |  +----------------------------------------------------------+|  |
|  |  |  Catalog: production                                      ||  |
|  |  |  +------------------------------------------------------+||  |
|  |  |  |  Schema: bronze    Schema: silver    Schema: gold     |||  |
|  |  |  |  +-------------+  +-------------+  +-------------+   |||  |
|  |  |  |  | raw_orders  |  | clean_orders|  | daily_kpis  |   |||  |
|  |  |  |  | raw_users   |  | clean_users |  | user_metrics|   |||  |
|  |  |  |  | raw_events  |  | clean_events|  | event_aggs  |   |||  |
|  |  |  |  +-------------+  +-------------+  +-------------+   |||  |
|  |  |  +------------------------------------------------------+||  |
|  |  +----------------------------------------------------------+|  |
|  +--------------------------------------------------------------+  |
|                                                                     |
|  Access Control:                                                    |
|  +--------------------------------------------------------------+  |
|  | Data Engineers  --> FULL ACCESS to bronze, silver, gold       |  |
|  | Data Scientists --> READ on silver, gold                      |  |
|  | Business Analysts --> READ on gold ONLY                       |  |
|  | ML Engineers    --> READ on silver, gold                      |  |
|  +--------------------------------------------------------------+  |
+====================================================================+
```

### Three-Level Namespace

Unity Catalog uses a three-level namespace: `catalog.schema.table`. A common convention for Medallion Architecture is:

- `production.bronze.raw_orders`
- `production.silver.clean_orders`
- `production.gold.daily_order_summary`

This makes it easy to apply access controls at the schema level, granting different teams access to different layers.

---

## KEY INTERVIEW QUESTIONS AND ANSWERS

### Q1: What is the Medallion Architecture and why is it used?
**A:** The Medallion Architecture is a data design pattern used in the Data Lakehouse that organizes data into three layers -- Bronze (raw), Silver (cleansed), and Gold (business-ready). As data moves through the layers, its quality progressively improves. It is used to ensure data quality, traceability, incremental processing, and proper governance. The pattern supports both batch and streaming workloads and enables different teams to consume data at the appropriate quality level.

### Q2: What kind of data goes into each layer of the Medallion Architecture?
**A:** The Bronze layer stores raw data as-is from source systems with minimal transformation, possibly with added metadata like load timestamps. The Silver layer contains filtered, cleansed, deduplicated, and schema-enforced data suitable for data science and ML. The Gold layer holds business-level aggregations, KPIs, and summary data optimized for BI reporting and dashboards.

### Q3: How does Databricks implement incremental processing across Medallion layers?
**A:** Databricks uses Auto Loader (cloudFiles format) to incrementally ingest new files into Bronze, detecting them via file notification or directory listing with exactly-once guarantees. Between layers, Structured Streaming with Delta Lake's Change Data Feed (CDF) propagates only the changed records downstream, avoiding full table scans. Delta Live Tables automates this entire pattern with declarative pipeline definitions.

### Q4: What are Delta Live Tables Expectations, and how do they relate to the Medallion Architecture?
**A:** DLT Expectations are data quality constraints declared on tables. `@dlt.expect` logs a warning but keeps the record, `@dlt.expect_or_drop` silently drops failing records, and `@dlt.expect_or_fail` stops the pipeline on any violation. They are used at layer transitions -- for example, dropping records with null IDs when moving from Bronze to Silver -- enforcing progressive quality improvement across the architecture.

### Q5: How does the Medallion Architecture help with GDPR compliance?
**A:** The layered approach provides clear separation for handling PII. Bronze retains raw data including PII for audit purposes with restricted access. Silver can apply pseudonymization or masking to PII fields. Gold typically contains aggregated data with no PII. Access controls via Unity Catalog restrict who can access each layer. When a "right to be forgotten" request arrives, you can delete or update the specific records in Bronze and Silver using Delta Lake's DELETE and UPDATE operations, and the changes propagate downstream.

### Q6: What is the difference between Medallion Architecture and traditional ETL?
**A:** Traditional ETL transforms data before loading it into the target system, which means raw data is not preserved and replayability is lost. Medallion Architecture follows an ELT-like approach where raw data is first landed in Bronze, then progressively transformed through Silver and Gold. This preserves the raw historical record, enables replay from Bronze if downstream logic changes, and supports incremental processing natively through Auto Loader and Change Data Feed.

### Q7: Can you have more or fewer than three layers in a Medallion Architecture?
**A:** Yes. While three layers (Bronze, Silver, Gold) is the most common setup, the architecture is flexible. Simpler projects may use only two layers (e.g., raw and curated). Complex projects may add a fourth "Platinum" layer for highly specialized use cases like real-time serving or external data products. The key principle is to clearly define each layer's purpose and characteristics upfront, regardless of how many layers you use.

### Q8: How would you organize Medallion Architecture tables in Unity Catalog?
**A:** The recommended approach is to use Unity Catalog's three-level namespace (catalog.schema.table). A common convention is to create separate schemas for each layer within a catalog -- for example, `production.bronze.raw_orders`, `production.silver.clean_orders`, `production.gold.daily_order_summary`. This enables schema-level access control so you can grant data engineers access to all schemas, data scientists to silver and gold, and business analysts to gold only.

---

*End of lesson*