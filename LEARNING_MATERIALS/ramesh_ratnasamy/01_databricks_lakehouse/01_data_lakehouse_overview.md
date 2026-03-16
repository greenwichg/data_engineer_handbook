# Data Lakehouse Architecture

## Introduction

Welcome back.

Before we start working on Databricks, let's try to understand the solution that Databricks helps us deliver.

Databricks basically enables us to build a modern data Lakehouse platform.

The concept of data Lakehouse could be new to most of you, so let's first explore the concept of the Data Lakehouse architecture.

While the term data Lakehouse was originally coined by Databricks, it's now widely adopted by many organizations.

According to Databricks, a data Lakehouse is a new open data architecture that merges the flexibility, cost, efficiency, and scalability of data lakes with the data management and asset transaction capabilities of the data warehouses.

This combination supports both business intelligence and machine learning workloads on a unified platform.

As you can see, the Data Lakehouse is not entirely a new concept.

It essentially blends the architecture of a data lake with some of the core characteristics of data warehouses.

This combination helps create a robust data platform which is suited for handling both BI and ML workloads efficiently.

```
+=====================================================================+
|               DATA PLATFORM EVOLUTION TIMELINE                      |
+=====================================================================+
|                                                                     |
|  1980s              2011               2020+                        |
|    |                  |                  |                          |
|    v                  v                  v                          |
| +----------+    +-----------+    +--------------+                   |
| |  DATA     |    |  DATA     |    |  DATA        |                  |
| | WAREHOUSE |    |  LAKE     |    |  LAKEHOUSE   |                  |
| +----------+    +-----------+    +--------------+                   |
| | Structured|    | All data  |    | All data     |                  |
| | data only |    | types     |    | types        |                  |
| | BI focus  |    | ML focus  |    | BI + ML + AI |                  |
| | ACID yes  |    | ACID no   |    | ACID yes     |                  |
| | Expensive |    | Cheap     |    | Cost-effective|                 |
| | Governed  |    | Ungoverned|    | Governed     |                  |
| +----------+    +-----------+    +--------------+                   |
|       |               |                 ^                           |
|       |   Limitations |    Best of      |                           |
|       +-------+-------+    both worlds  |                           |
|               |                         |                           |
|               +-------------------------+                           |
+=====================================================================+
```

---

## Introduction to Data Warehouses

I understand that some of you might not be familiar with data warehouses and data lakes, so let's begin with an introduction to data warehouses.

Data warehouses emerged during the early 1980s, when businesses needed a centralized place to store all their organizational data.

This allowed them to make decisions based on the full set of information available in the company, rather than relying on separate data sources in individual departments.

A data warehouse primarily consisted of operational data from within the organization.

Some large data warehouses also gathered external data to support better decision making.

The data received in a data warehouse was usually structured, such as SQL tables or semi-structured formats such as JSON or XML files.

However, they couldn't process unstructured data such as images and videos.

The data received then goes through a process called ETL or extract transform load to be loaded into a data warehouse.

Complex data warehouses also had data marts which focused on specific subject areas or regions of the business.

Data marts contained cleaned, validated, and enhanced data, often aggregated to provide key insights like key performance indicators or KPIs.

Analysts and business managers could then access this data through business intelligence reports.

By the early 2000, most large companies had at least one data warehouse because they were crucial for making business decisions.

```
+====================================================================+
|            TRADITIONAL DATA WAREHOUSE ARCHITECTURE                  |
+====================================================================+
|                                                                     |
|  +----------+  +----------+  +----------+                           |
|  | ERP      |  | CRM      |  | Finance  |    Source Systems         |
|  | System   |  | System   |  | System   |                           |
|  +----+-----+  +----+-----+  +----+-----+                           |
|       |             |             |                                 |
|       v             v             v                                 |
|  +==========================================+                       |
|  |          ETL PROCESS                     |                       |
|  |  Extract --> Transform --> Load          |                       |
|  +==========================================+                       |
|                     |                                               |
|                     v                                               |
|  +==========================================+                       |
|  |        DATA WAREHOUSE                    |                       |
|  |  +------------+  +------------+          |                       |
|  |  | Data Mart  |  | Data Mart  |          |                       |
|  |  | (Sales)    |  | (Finance)  |          |                       |
|  |  +------------+  +------------+          |                       |
|  +==========================================+                       |
|                     |                                               |
|                     v                                               |
|  +==========================================+                       |
|  |         BI REPORTS & DASHBOARDS          |                       |
|  +==========================================+                       |
+=====================================================================+
```

---

## Challenges with Traditional Data Warehouses

However, they also had several significant challenges.

With the growth of the internet, data volumes increased dramatically and new type of unstructured data like videos, images, and text files became important for decision making.

Traditional data warehouses were not designed to handle these type of data in a data warehouse.

Data was only loaded after its quality was checked and transformed.

This led to longer development times to add new data into the data warehouse.

Data warehouses were built on traditional relational databases or massively parallel processing engines or MPP engines, which used proprietary file formats and could create vendor lock in.

Traditional on premises data warehouses were hard to scale, sometimes requiring large migration projects to increase capacity.

Storage was expensive with these traditional solutions, and it was impossible to expand storage independently of computing resources.

And finally, traditional data warehouses didn't provide enough support for data science, machine learning, and AI workloads.

Those issues paved the way for data lakes.

```
+====================================================================+
|          DATA WAREHOUSE CHALLENGES SUMMARY                          |
+====================================================================+
|                                                                     |
|  [X] Cannot handle unstructured data (images, video, text)          |
|  [X] Long development times (ETL before load)                       |
|  [X] Proprietary formats --> vendor lock-in                         | 
|  [X] Difficult to scale (on-premises hardware)                      |
|  [X] Coupled storage + compute --> expensive                        |
|  [X] No support for ML/AI workloads                                 |
|  [X] MPP engines are costly at scale                                |
|                                                                     |
+====================================================================+
```

---

## Introduction to Data Lakes

Data lakes were introduced around the year 2011 to address some of the challenges we saw with the data warehouses.

Data lakes are designed to handle not only structured and semi-structured data, but they can also handle unstructured data.

Unstructured data makes up roughly 90% of the data available today in a data lake house architecture.

Raw data is ingested directly into the data lake without any initial cleansing or transformation.

This approach allowed for quicker solution development and faster ingestion times.

Data lakes were built on cheap storage solutions like HDFS and cloud object stores such as Amazon S3, Azure Data Lake Storage Gen2, and Google Cloud Storage, which kept the costs low.

They also utilized open source file formats like parquet, ORC and Avro, allowing for a wide range of tools and libraries to be used for processing and analysis.

Data lakes supported data science and machine learning workloads by providing access to both raw and transformed data.

However, there was one major problem.

Data lakes were too slow for interactive BI reports and lacked proper data governance.

To solve this, companies often copied a subset of the data from the data lake to a warehouse to support BI reporting, which led to a complex architecture with too many moving parts.

```
+====================================================================+
|                DATA LAKE ARCHITECTURE                               |
+====================================================================+
|                                                                     |
|  +-----------+  +-----------+  +-----------+  +-----------+         |
|  | Databases |  | IoT/Logs  |  | Files     |  | APIs      |         |
|  | (struct.) |  | (semi-st.)|  | (unstruct)|  | (JSON)    |         |
|  +-----+-----+  +-----+-----+  +-----+-----+  +-----+-----+         |
|        |              |              |              |               |
|        v              v              v              v               |
|  +======================================================+           |
|  |              RAW INGESTION (No ETL)                   |          |
|  +======================================================+           |
|                          |                                          |
|                          v                                          |
|  +======================================================+           |
|  |                  DATA LAKE                            |          |
|  |          (HDFS / S3 / ADLS / GCS)                      |         |
|  |        Parquet, ORC, Avro, JSON, CSV                  |          |
|  +======================================================+           |
|           |                              |                          |
|           v                              v                          |
|  +-----------------+          +-------------------+                 |
|  | ML / Data       |          | Copy to Warehouse |  <-- Problem!   |
|  | Science         |          | for BI Reporting  |                 |
|  +-----------------+          +-------------------+                 |
+=====================================================================+
```

---

## Challenges with Data Lakes

Now that we understand the basics of the Data Lake architecture, let's summarize its challenges.

Data lakes did not have built in support for asset transactions, which are essential for reliable data management.

In case you're not familiar with the acronym Acid, it stands for atomicity, consistency, isolation, and durability, which is essential for reliable data management.

Lack of acid transaction support led to many issues.

And let's go through some of those here.

Fail jobs could leave behind partially loaded files requiring additional cleanup processes during reruns.

There was no guarantee of consistent reads, leading to the possibility of users accessing partially written data, which compromised reliability.

Data lakes offered no direct support for updates to correct or update data.

Developers had to partition the files and rewrite entire partitions, which was both time consuming as well as error prone.

There was no way to roll back changes, which made it difficult to recover from failures.

Under GDPR, users have the right to be forgotten, which means that their data must be deleted when requested.

Since the data lakes didn't support deletions well, entire files sometimes had to be rewritten to remove an individual's data, which was again both time consuming and expensive.

Data lakes lacked version control, which made it harder to track changes, perform rollbacks, or ensure data governance.

Also, data lakes struggled to provide fast, interactive query performance and lacked adequate support for basic needs such as security and governance.

Setting up and managing data lakes was complex and required significant expertise in a data lake.

Streaming and batch data needed to be processed separately, leading to complex lambda architectures.

---

## Data Warehouses vs Data Lakes

In summary, data warehouses excelled at handling BA workloads, but they lack the support for streaming data science and machine learning workloads.

On the other hand, data lakes were designed for data science and machine learning workloads, but they fell short in supporting BA workloads effectively.

---

## Data Lakehouse Architecture

The Data Lakehouse architecture combines the best features of both data warehouses and data lakes.

It is designed to effectively support business intelligence and data science, machine learning and AI workloads.

Let's take a closer look at how a data Lakehouse architecture works.

Similar to data lakes, we can ingest both operational and external data into a data lake house.

A data lake house is essentially a data lake with built in acid transaction controls and data governance capabilities.

Data lakes achieve this using the file format Delta Lake and a data governance solution called Unity Catalog.

With Acid support offered by the Delta Lake file format, we can seamlessly combine streaming and batch batch workloads, eliminating the need for a complex Lambda architecture.

Data from the Lakehouse platform can be used for data science and machine learning tasks.

Additionally, the Lakehouse integrates with the popular BI tools such as power BI and Tableau, while also providing role based access control for governance.

This eliminates the need to copy the data into a separate data warehouse.

```
+====================================================================+
|              DATA LAKEHOUSE ARCHITECTURE                            |
+====================================================================+
|                                                                     |
|  +-----------+  +-----------+  +-----------+  +-----------+         |
|  | Databases |  | IoT/Logs  |  | Files     |  | APIs      |         |
|  +-----+-----+  +-----+-----+  +-----+-----+  +-----+-----+         |
|        |              |              |              |               |
|        v              v              v              v               |
|  +======================================================+           |
|  |        INGESTION (Batch + Streaming Unified)          |          |
|  +======================================================+           |
|                          |                                          |
|                          v                                          |
|  +======================================================+           |
|  |              DATA LAKEHOUSE                           |          |
|  |  +--------------------------------------------------+|           |
|  |  |  Delta Lake (ACID Transactions + Open Format)     ||          |
|  |  +--------------------------------------------------+|           |
|  |  |  Unity Catalog (Governance + Access Control)      ||          |
|  |  +--------------------------------------------------+|           |
|  |  |  Cloud Object Storage (S3 / ADLS / GCS)          ||           |
|  |  +--------------------------------------------------+|           |
|  +======================================================+           |
|         |              |                |                           |
|         v              v                v                           |
|  +------------+  +------------+  +--------------+                   |
|  | BI Reports |  | ML / AI    |  | Data Science |                   |
|  | (Tableau,  |  | Workloads  |  | (Notebooks)  |                   |
|  |  Power BI) |  |            |  |              |                   |
|  +------------+  +------------+  +--------------+                   |
+=====================================================================+
```

---

## Benefits of Data Lakehouse Architecture

Let's now quickly summarize the benefits of using the Data Lakehouse architecture.

Similar to traditional data lakes, lake houses can also handle all types of data such as structured, semi-structured, and unstructured.

Data Lake houses run on cost effective cloud object storage, such as Amazon S3, using the open source file format such as Delta Lake.

They support a wide range of workloads, including by data science and machine learning.

Data lake houses allow direct integration with BI tools, which helps eliminate the need for duplicating the data into a data warehouse.

Most importantly, they provide asset support, data versioning, and history, thus preventing the creation of unreliable data swamps.

Lake houses offer better performance compared to traditional data lakes.

And finally, by removing the need for a lambda architecture and reducing the reliance on separate data warehouses, lake houses simplify the overall architecture.

---

## CONCEPT GAP: ACID Transactions Explained

ACID transactions are a foundational concept that the Lakehouse architecture brings to data lake storage. Understanding each property is critical for the certification exam.

```
+====================================================================+
|                    ACID TRANSACTIONS                                |
+====================================================================+
|                                                                     |
|  +------------------+    +------------------+                       |
|  | A - ATOMICITY    |    | C - CONSISTENCY  |                       |
|  |                  |    |                  |                       |
|  | "All or Nothing" |    | "Valid State     |                       |
|  |                  |    |  Guaranteed"     |                       |
|  | Either the whole |    |                  |                       |
|  | transaction      |    | Data always      |                       |
|  | succeeds, or     |    | moves from one   |                       |
|  | none of it does. |    | valid state to   |                       |
|  |                  |    | another.         |                       |
|  +------------------+    +------------------+                       |
|                                                                     |
|  +------------------+    +------------------+                       |
|  | I - ISOLATION    |    | D - DURABILITY   |                       |
|  |                  |    |                  |                       |
|  | "Concurrent ops  |    | "Committed =     |                       |
|  |  don't interfere"|    |  Permanent"      |                       |
|  |                  |    |                  |                       |
|  | Multiple users   |    | Once committed,  |                       |
|  | reading/writing  |    | data survives    |                       |
|  | simultaneously   |    | crashes, power   |                       |
|  | see consistent   |    | failures, etc.   |                       |
|  | results.         |    |                  |                       |
|  +------------------+    +------------------+                       |
+====================================================================+
```

### What Goes Wrong Without ACID

| ACID Property | Without It | Real-World Example |
|---|---|---|
| **Atomicity** | Partial writes on failure | A job writing 10 files crashes after file 7. You now have 7 orphaned files with no rollback. Next run may create duplicates. |
| **Consistency** | Corrupted or invalid data | Schema changes mid-write leave some rows with 5 columns and others with 6. Downstream queries break. |
| **Isolation** | Dirty reads | A dashboard query reads a table while a pipeline is mid-write. Users see half-updated numbers and make wrong decisions. |
| **Durability** | Data loss after commit | A write is acknowledged as complete but a crash before flushing to disk loses the data permanently. |

### How Delta Lake Provides ACID on a Data Lake

Delta Lake uses a **transaction log** (`_delta_log/`) that records every change as an ordered, atomic commit. Key mechanisms:

- **Optimistic concurrency control** - Multiple writers can work simultaneously; conflicts are detected and resolved
- **Write-ahead log** - Changes are recorded in the log before data files are modified
- **Snapshot isolation** - Readers always see a consistent snapshot, even during concurrent writes
- **Time travel** - Every commit is versioned, enabling rollback and audit

---

## CONCEPT GAP: Lambda Architecture vs Lakehouse Unified Approach

The Lambda Architecture was a common workaround before Lakehouses. Understanding why it was replaced is an important exam topic.

```
+====================================================================+
|              LAMBDA ARCHITECTURE (Pre-Lakehouse)                    |
+====================================================================+
|                                                                     |
|                   +-------------+                                   |
|                   | Data Source |                                   |
|                   +------+------+                                   |
|                    /           \                                    |
|                   v             v                                   |
|     +----------------+   +----------------+                         |
|     |  BATCH LAYER   |   | SPEED LAYER    |                         |
|     |  (Hadoop/Spark) |   | (Storm/Flink)  |                        |
|     |  High latency   |   | Low latency    |                        |
|     |  Complete data   |   | Recent data    |                       |
|     +-------+--------+   +-------+--------+                         |
|             |                     |                                 |
|             v                     v                                 |
|     +----------------+   +----------------+                         |
|     | Batch Views    |   | Real-time      |                         |
|     |                |   | Views          |                         |
|     +-------+--------+   +-------+--------+                         |
|              \                   /                                  |
|               v                 v                                   |
|           +-----------------------+                                 |
|           |   SERVING LAYER       |                                 |
|           |   (Merge results)     |                                 |
|           +-----------------------+                                 |
+====================================================================+

+====================================================================+
|              LAKEHOUSE UNIFIED APPROACH                             |
+====================================================================+
|                                                                     |
|                   +-------------+                                   |
|                   | Data Source  |                                  |
|                   +------+------+                                   |
|                          |                                          |
|                          v                                          |
|            +---------------------------+                            |
|            |   SINGLE UNIFIED PIPELINE |                            |
|            |   (Spark Structured       |                            |
|            |    Streaming + Batch)     |                            |
|            +---------------------------+                            |
|                          |                                          |
|                          v                                          |
|            +---------------------------+                            |
|            |   DELTA LAKE              |                            |
|            |   (ACID + Versioning)     |                            |
|            |   Batch + Streaming in    |                            |
|            |   one unified table       |                            |
|            +---------------------------+                            |
|                          |                                          |
|                          v                                          |
|            +---------------------------+                            |
|            |   BI / ML / Analytics     |                            |
|            +---------------------------+                            |
+====================================================================+
```

| Aspect | Lambda Architecture | Lakehouse Unified Approach |
|---|---|---|
| **Number of pipelines** | Two (batch + speed) | One unified pipeline |
| **Code duplication** | Same logic written twice | Single codebase |
| **Complexity** | High (two systems to manage) | Low (one platform) |
| **Data consistency** | Eventual (merge at serving) | Immediate (ACID) |
| **Maintenance** | Difficult | Simpler |
| **Technology stack** | Multiple (Hadoop + Storm + serving DB) | Single (Spark + Delta Lake) |

---

## CONCEPT GAP: The Two-Platform Problem

Before lakehouses, most organizations ran both a data lake AND a data warehouse side by side. This is known as the "two-platform problem."

```
+====================================================================+
|                THE TWO-PLATFORM PROBLEM                             |
+====================================================================+
|                                                                     |
|  +-----------------+          +-----------------+                   |
|  |   DATA LAKE     |  copy    |  DATA WAREHOUSE |                   |
|  |                 |--------->|                 |                   |
|  |  Raw data       |  ETL     |  Clean data     |                   |
|  |  ML workloads   |  Sync    |  BI workloads   |                   |
|  |  Cheap storage  |  ???     |  Expensive       |                  |
|  +-----------------+          +-----------------+                   |
|                                                                     |
|  PROBLEMS:                                                          |
|  +--------------------------------------------------------------+   |
|  | 1. Data duplication --> inconsistency between systems        |   |
|  | 2. ETL to copy data --> extra cost, latency, failure points  |   |
|  | 3. Two systems to secure, govern, and maintain               |   |
|  | 4. "Which system has the truth?" --> no single source        |   |
|  | 5. Double licensing and infrastructure costs                 |   |
|  +--------------------------------------------------------------+   |
|                                                                     |
|  LAKEHOUSE SOLUTION:                                                |
|  +--------------------------------------------------------------+   |
|  | Single platform that serves BOTH BI and ML workloads         |   |
|  | No data copying needed                                       |   |
|  | One governance model (Unity Catalog)                         |   |
|  | One source of truth                                          |   |
|  +--------------------------------------------------------------+   |
+====================================================================+
```

---

## CONCEPT GAP: Key Enabling Technologies

Three technologies make the Lakehouse architecture possible:

```
+====================================================================+
|           KEY ENABLING TECHNOLOGIES                                 |
+====================================================================+
|                                                                     |
|  +-------------------+  +-------------------+  +----------------+   |
|  |   DELTA LAKE      |  |  UNITY CATALOG    |  |   PHOTON       |   |
|  |                   |  |                   |  |                |   |
|  | Open-source       |  | Unified           |  | Vectorized     |   |
|  | storage layer     |  | governance        |  | query engine   |   |
|  |                   |  | solution          |  |                |   |
|  | - ACID txns       |  | - Access control  |  | - C++ engine   |   |
|  | - Schema enforce  |  | - Data lineage    |  | - 8x faster    |   |
|  | - Time travel     |  | - Audit logging   |  | - Auto-enabled |   |
|  | - Versioning      |  | - Data discovery  |  | - SQL + Spark  |   |
|  | - Unified batch   |  | - Cross-workspace |  |   compatible   |   |
|  |   + streaming     |  |   governance      |  |                |   |
|  | - Schema evolve   |  | - Data sharing    |  |                |   |
|  +-------------------+  +-------------------+  +----------------+   |
|         |                       |                      |            |
|         v                       v                      v            |
|  +--------------------------------------------------------------+   |
|  |             DATA LAKEHOUSE PLATFORM                           |  |
|  +--------------------------------------------------------------+   |
+====================================================================+
```

| Technology | Role in Lakehouse | Open Source? |
|---|---|---|
| **Delta Lake** | Storage format with ACID, versioning, time travel | Yes (Linux Foundation) |
| **Unity Catalog** | Centralized governance, access control, lineage | Yes (recently open-sourced) |
| **Photon** | High-performance C++ query engine | No (Databricks proprietary) |
| **Apache Spark** | Distributed compute engine | Yes (Apache Foundation) |
| **Delta Sharing** | Open protocol for secure data sharing | Yes |

---

## CONCEPT GAP: Comprehensive Comparison -- Warehouse vs Lake vs Lakehouse

```
+====================================================================+
|     COMPREHENSIVE COMPARISON: WAREHOUSE vs LAKE vs LAKEHOUSE       |
+====================================================================+
```

| Feature | Data Warehouse | Data Lake | Data Lakehouse |
|---|---|---|---|
| **Data types** | Structured only | Structured, semi-structured, unstructured | All types |
| **ACID support** | Yes | No | Yes (via Delta Lake) |
| **Schema** | Schema-on-write | Schema-on-read | Both supported |
| **Storage cost** | High (proprietary) | Low (object storage) | Low (object storage) |
| **Storage format** | Proprietary | Open (Parquet, ORC, Avro) | Open (Delta = Parquet + log) |
| **Compute-storage coupling** | Tightly coupled | Decoupled | Decoupled |
| **BI support** | Excellent | Poor (too slow) | Excellent |
| **ML/AI support** | Poor | Good | Excellent |
| **Streaming support** | Limited | Separate pipeline needed | Unified with batch |
| **Data governance** | Strong | Weak | Strong (Unity Catalog) |
| **Data quality** | High (enforced at write) | Low (data swamps) | High (enforced + flexible) |
| **Time travel** | Limited | None | Full versioning |
| **Scalability** | Difficult | Easy | Easy |
| **Vendor lock-in** | High | Low | Low (open formats) |
| **Performance** | Fast (optimized engines) | Slow for queries | Fast (Photon engine) |
| **Typical cost** | $$$$$ | $ | $$ |

---

## Conclusion

I hope you now have a good understanding about Data Lake House architecture.

And that's the end of this lesson.

I'll see you in the next one.

---

## KEY INTERVIEW QUESTIONS AND ANSWERS

### Q1: What is a Data Lakehouse and why was it created?
**A:** A Data Lakehouse is an open data architecture that combines the flexibility, cost-efficiency, and scale of data lakes with the data management, ACID transactions, and governance capabilities of data warehouses. It was created to solve the "two-platform problem" where organizations had to maintain both a data lake (for ML) and a data warehouse (for BI), leading to data duplication, inconsistency, and high costs.

### Q2: What are the key differences between a Data Warehouse, Data Lake, and Data Lakehouse?
**A:** Data Warehouses handle structured data with strong governance but are expensive and cannot support ML workloads. Data Lakes handle all data types cheaply but lack ACID transactions, governance, and fast BI query performance. Data Lakehouses combine the strengths of both: all data types, low-cost storage on cloud object stores, ACID transactions via Delta Lake, governance via Unity Catalog, and support for both BI and ML workloads.

### Q3: What are ACID transactions and why are they important in a Lakehouse?
**A:** ACID stands for Atomicity (all-or-nothing operations), Consistency (data always in a valid state), Isolation (concurrent operations do not interfere), and Durability (committed data is permanent). Without ACID, data lakes suffered from partial writes, dirty reads, no rollback capability, and difficulty with updates/deletes (especially for GDPR). Delta Lake brings ACID to the Lakehouse via a transaction log.

### Q4: What is the Lambda Architecture and how does the Lakehouse eliminate it?
**A:** Lambda Architecture is a design pattern that uses separate batch and speed (real-time) layers to process data, with a serving layer that merges results. This requires maintaining two codebases with duplicated logic. The Lakehouse eliminates Lambda by using Spark Structured Streaming with Delta Lake, which handles both batch and streaming data in a single unified pipeline with ACID guarantees.

### Q5: What technologies enable the Data Lakehouse architecture?
**A:** The key enabling technologies are: (1) Delta Lake -- an open-source storage layer providing ACID transactions, schema enforcement, and time travel on cloud object storage; (2) Unity Catalog -- a unified governance solution for access control, data lineage, and audit logging; (3) Photon -- a high-performance vectorized query engine written in C++ that makes BI queries fast enough to replace traditional warehouses; (4) Apache Spark -- the distributed compute engine at the foundation.

### Q6: What is the "two-platform problem" and how does the Lakehouse solve it?
**A:** The two-platform problem occurs when organizations maintain both a data lake and a data warehouse. Data must be copied between them, leading to inconsistency, extra ETL costs, dual maintenance, double licensing, and no single source of truth. The Lakehouse solves this by providing one platform that serves both BI and ML workloads directly, eliminating the need for data duplication.

### Q7: How does Delta Lake provide ACID transactions on top of cloud object storage?
**A:** Delta Lake uses a write-ahead transaction log (`_delta_log/` directory) that records every change as an ordered, atomic JSON commit. It employs optimistic concurrency control for concurrent writers, snapshot isolation for consistent reads, and maintains a full version history enabling time travel and rollback. The actual data is stored as Parquet files, and the log tracks which files belong to each version.

### Q8: Why can a Lakehouse support BI workloads that Data Lakes could not?
**A:** Data Lakes were too slow for interactive BI because they lacked indexing, caching, and query optimization. The Lakehouse adds: (1) Photon engine for fast vectorized query execution, (2) Delta Lake's data skipping and Z-ordering for efficient file pruning, (3) caching layers, and (4) direct integration with BI tools like Power BI and Tableau. This delivers warehouse-grade query performance on lake storage.

---
