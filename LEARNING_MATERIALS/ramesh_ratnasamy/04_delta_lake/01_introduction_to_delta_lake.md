# Introduction to Delta Lake

## Introduction

Alright, let's talk about Delta Lake. If you've been working with data lakes or Apache Spark, you've
probably run into some frustrating problems. Maybe you had a job fail halfway through writing data,
and now your table is in a corrupted state. Maybe two pipelines tried to write to the same location
at the same time and you ended up with a mess. Or maybe someone changed the schema of a dataset
without telling you, and now your downstream jobs are broken. These are all real-world problems
that data engineers face every single day, and Delta Lake was built specifically to solve them.

So what is Delta Lake? At its core, Delta Lake is an open-source storage layer that sits on top of
your existing data lake and brings reliability to it. Think of it as an upgrade layer. You still
keep your data in cloud storage (S3, ADLS, GCS), you still use Parquet files under the hood, but
now you get ACID transactions, schema enforcement, time travel, and a whole bunch of other features
that make your data lake behave more like a data warehouse. That's the key insight -- Delta Lake
bridges the gap between the flexibility of a data lake and the reliability of a data warehouse.

Delta Lake was originally developed at Databricks, and it became the default storage format in the
Databricks platform. But it's also an open-source project under the Linux Foundation, so you can
use it outside of Databricks too. This is an important distinction that we'll dig into later.

## Delta Lake Architecture

Let's look at where Delta Lake fits in the overall architecture. It's not a separate storage system.
It's not a database. It's a storage layer -- a protocol and set of libraries that add structure and
reliability on top of your existing cloud storage.

```
+------------------------------------------------------------------+
|                      COMPUTE ENGINES                             |
|                                                                  |
|   +------------+    +------------+    +------------+             |
|   |   Apache   |    | Databricks |    |   Presto   |             |
|   |   Spark    |    |  SQL       |    |   Trino    |             |
|   +------+-----+    +------+-----+    +------+-----+             |
|          |                 |                 |                    |
+----------+-----------------+-----------------+-------------------+
           |                 |                 |
           v                 v                 v
+------------------------------------------------------------------+
|                      DELTA LAKE LAYER                            |
|                                                                  |
|   +------------------+  +------------------+  +---------------+  |
|   | ACID Transactions|  | Schema           |  | Time Travel   |  |
|   |                  |  | Enforcement      |  | & Versioning  |  |
|   +------------------+  +------------------+  +---------------+  |
|   +------------------+  +------------------+  +---------------+  |
|   | Scalable         |  | Unified Batch &  |  | Audit         |  |
|   | Metadata         |  | Streaming        |  | History       |  |
|   +------------------+  +------------------+  +---------------+  |
|                                                                  |
|              Transaction Log  (_delta_log/)                      |
|                                                                  |
+------------------------------------------------------------------+
           |                 |                 |
           v                 v                 v
+------------------------------------------------------------------+
|                    CLOUD STORAGE                                 |
|                                                                  |
|   +------------+    +------------+    +------------+             |
|   |  AWS S3    |    | Azure ADLS |    | Google GCS |             |
|   +------------+    +------------+    +------------+             |
|                                                                  |
|   Data stored as Parquet files + _delta_log/ metadata            |
|                                                                  |
+------------------------------------------------------------------+
```

As you can see, Delta Lake sits right between the compute engines (like Spark, Databricks SQL,
Trino) and the cloud storage. The compute engines talk to Delta Lake, and Delta Lake manages
how data is read from and written to cloud storage. The magic is in the transaction log, that
`_delta_log/` directory, which we'll cover in much more detail in the next lesson.

## What is Delta Lake?

Let's be really precise about what Delta Lake is:

1. **An open-source storage layer** -- It's not a database, not a compute engine, not a file format.
   It's a layer that adds capabilities on top of existing storage.

2. **Built on top of Parquet** -- Under the hood, your data is still stored as Parquet files. Delta
   Lake doesn't invent a new file format for the data itself. What it adds is the transaction log
   and the protocol for reading and writing.

3. **Compatible with Apache Spark** -- Delta Lake was designed to work seamlessly with Spark. You
   can read and write Delta tables using the same DataFrame API you already know.

4. **ACID-compliant** -- This is the big one. Delta Lake brings full ACID transaction support to
   your data lake. No more partial writes, no more corrupted tables, no more reading dirty data.

## Delta Lake vs Parquet

This is a question that comes up a lot, and it's important to understand the distinction clearly.

When you write data as Parquet, you're just writing files. There's no transaction log, no schema
enforcement beyond what Parquet itself provides, no versioning, no concurrency control. If a job
fails while writing, you might end up with partial files. If two jobs write at the same time, you
might get duplicates or conflicts. Parquet is a great columnar file format, but it doesn't give
you any table-level semantics.

Delta Lake uses Parquet as its underlying data format, but it adds a whole layer of metadata and
transaction management on top. Here's a comparison:

```
+----------------------------+------------------+-------------------+
|        Feature             |     Parquet      |    Delta Lake     |
+============================+==================+===================+
| File Format                | Parquet          | Parquet (same!)   |
+----------------------------+------------------+-------------------+
| Transaction Log            | No               | Yes (_delta_log/) |
+----------------------------+------------------+-------------------+
| ACID Transactions          | No               | Yes               |
+----------------------------+------------------+-------------------+
| Schema Enforcement         | Basic (per file) | Full (table-level)|
+----------------------------+------------------+-------------------+
| Schema Evolution           | No               | Yes               |
+----------------------------+------------------+-------------------+
| Time Travel                | No               | Yes               |
+----------------------------+------------------+-------------------+
| Concurrent Writes          | Unsafe           | Safe (OCC)        |
+----------------------------+------------------+-------------------+
| UPDATE/DELETE/MERGE        | Not supported    | Fully supported   |
+----------------------------+------------------+-------------------+
| Streaming + Batch          | Separate         | Unified           |
+----------------------------+------------------+-------------------+
| Small File Compaction      | Manual           | OPTIMIZE command  |
+----------------------------+------------------+-------------------+
```

The key takeaway: Delta Lake IS Parquet plus a transaction log and protocol. When you look at the
actual files on disk, a Delta table looks like a bunch of Parquet files plus a `_delta_log/`
directory. That's it. The magic is in what the transaction log enables.

## Key Features of Delta Lake

### ACID Transactions

This is arguably the most important feature. ACID stands for Atomicity, Consistency, Isolation,
and Durability. We'll have an entire lesson dedicated to this, but the short version is:

- **Atomicity**: Either all of your write operation succeeds, or none of it does. No partial writes.
- **Consistency**: Your data always moves from one valid state to another. Schema rules are enforced.
- **Isolation**: Concurrent operations don't interfere with each other. Readers see a consistent
  snapshot while writers are doing their thing.
- **Durability**: Once a commit is acknowledged, the data is persisted and won't be lost.

This is what makes Delta Lake reliable for production workloads. Without ACID transactions, your
data lake is fragile -- a single failed job can corrupt your entire dataset.

### Scalable Metadata Handling

In traditional Hive-style data lakes, metadata is stored in the Hive Metastore, which uses a
relational database under the hood. This can become a bottleneck when you have tables with millions
of files. The metastore has to list all the files, track partitions, and manage statistics.

Delta Lake handles metadata differently. The transaction log itself is the metadata, and it's stored
right alongside the data in cloud storage. Spark processes this metadata using the same distributed
processing engine it uses for data. So if your table has millions of files, Spark can parallelize
reading the transaction log just like it parallelizes reading data.

### Unified Streaming and Batch Processing

With Delta Lake, a table can be both a batch table and a streaming source/sink at the same time.
You can have a streaming job that continuously appends data to a Delta table, while a batch job
reads from the same table and runs analytics. They won't interfere with each other because of the
ACID transaction support.

This is huge for real-time data architectures. Before Delta Lake, you often had to maintain separate
systems for batch and streaming data. Now you can have a single table that serves both use cases.

```
+---------------------+                    +---------------------+
|  Streaming Source   |                    |   Batch Source      |
|  (Kafka, Kinesis)   |                    |   (Files, JDBC)     |
+---------+-----------+                    +---------+-----------+
          |                                          |
          v                                          v
+---------+-----------+                    +---------+-----------+
| Spark Structured    |                    | Spark Batch         |
| Streaming Write     |                    | Write               |
+---------+-----------+                    +---------+-----------+
          |                                          |
          +------------------+   +-------------------+
                             |   |
                             v   v
                   +---------+---+---------+
                   |    Delta Lake Table   |
                   |                       |
                   |  (Single unified      |
                   |   source of truth)    |
                   +---------+---+---------+
                             |   |
                   +---------+   +---------+
                   |                       |
                   v                       v
          +--------+--------+    +---------+---------+
          | Streaming Read  |    | Batch Read        |
          | (Downstream     |    | (BI, Analytics,   |
          |  pipelines)     |    |  ML)              |
          +-----------------+    +-------------------+
```

### Schema Enforcement and Schema Evolution

**Schema enforcement** (also called schema validation) means that Delta Lake rejects writes that
don't match the table's schema. If your table has columns (id INT, name STRING, age INT), and
someone tries to write data with a column (id INT, name STRING, salary DOUBLE), Delta Lake will
throw an error. This prevents accidental data corruption.

**Schema evolution** is the controlled counterpart to schema enforcement. When you intentionally
want to change the schema -- say, add a new column -- you can do so using the `mergeSchema` option:

```python
df.write.format("delta") \
    .option("mergeSchema", "true") \
    .mode("append") \
    .save("/path/to/delta-table")
```

Or you can enable automatic schema evolution at the table level. The key point is that schema
changes are explicit and tracked in the transaction log, not accidental.

### Time Travel (Data Versioning)

Every write to a Delta table creates a new version. Delta Lake keeps a history of all these
versions, and you can query any previous version of the table. This is called time travel.

```sql
-- Query version 5 of the table
SELECT * FROM my_table VERSION AS OF 5;

-- Query the table as it was yesterday
SELECT * FROM my_table TIMESTAMP AS OF '2024-01-15';
```

This is incredibly useful for auditing, debugging, and reproducibility. If someone asks "what did
this table look like last Tuesday?", you can answer that question. We'll dedicate an entire lesson
to time travel.

### Audit History

Because every change to a Delta table is recorded in the transaction log, you have a complete
audit trail. You can see who changed what, when they changed it, and what exactly changed. The
`DESCRIBE HISTORY` command gives you this information:

```sql
DESCRIBE HISTORY my_table;
```

This returns a table with columns like version, timestamp, operation, operationParameters, and
userName. It's invaluable for compliance and debugging.

## Delta Lake as the Default Format in Databricks

Starting with Databricks Runtime, Delta Lake is the default format. When you create a table
in Databricks without specifying a format, it's a Delta table. When you use `CREATE TABLE`,
`CTAS`, or save a DataFrame without specifying the format, you get Delta.

```sql
-- This creates a Delta table by default in Databricks
CREATE TABLE my_table (
    id INT,
    name STRING,
    created_at TIMESTAMP
);

-- This also creates a Delta table
CREATE TABLE my_table AS
SELECT * FROM source_table;
```

This is a significant design choice because it means every table in Databricks benefits from
ACID transactions, schema enforcement, time travel, and all the other Delta Lake features by
default. You don't have to opt in.

## How Delta Lake Works Under the Hood

When you create a Delta table, here's what actually happens on disk:

```
my_delta_table/
|
+-- _delta_log/
|   +-- 00000000000000000000.json    <-- Commit 0 (table creation)
|   +-- 00000000000000000001.json    <-- Commit 1 (first write)
|   +-- 00000000000000000002.json    <-- Commit 2 (second write)
|   +-- ...
|
+-- part-00000-abc123.snappy.parquet  <-- Data file
+-- part-00001-def456.snappy.parquet  <-- Data file
+-- part-00002-ghi789.snappy.parquet  <-- Data file
+-- ...
```

The `_delta_log/` directory contains the transaction log -- a series of JSON files (one per commit)
that record every change made to the table. The Parquet files contain the actual data. When you
read a Delta table, the Delta Lake library first reads the transaction log to figure out which
Parquet files are currently part of the table, then reads those files.

This is fundamentally different from reading plain Parquet, where you just list all the files in
a directory and read them. With Delta Lake, the transaction log tells you which files are "active"
and which have been removed (because of DELETE or UPDATE operations).

## CONCEPT GAP: Delta Lake vs Apache Iceberg vs Apache Hudi

Delta Lake is not the only open table format out there. Two major competitors are Apache Iceberg
and Apache Hudi. All three solve similar problems but with different architectures and trade-offs.

```
+----------------------------+----------------+----------------+----------------+
|        Feature             |  Delta Lake    | Apache Iceberg | Apache Hudi    |
+============================+================+================+================+
| Origin                     | Databricks     | Netflix        | Uber           |
+----------------------------+----------------+----------------+----------------+
| Underlying Format          | Parquet        | Parquet, ORC,  | Parquet, ORC   |
|                            |                | Avro           |                |
+----------------------------+----------------+----------------+----------------+
| Metadata Storage           | JSON + Parquet | Manifest files | Timeline +     |
|                            | (tx log)       | (Avro)         | Metadata table |
+----------------------------+----------------+----------------+----------------+
| ACID Transactions          | Yes            | Yes            | Yes            |
+----------------------------+----------------+----------------+----------------+
| Time Travel                | Yes            | Yes (snapshots)| Yes            |
+----------------------------+----------------+----------------+----------------+
| Schema Evolution           | Yes            | Yes (full)     | Yes            |
+----------------------------+----------------+----------------+----------------+
| Partition Evolution         | Limited        | Yes (hidden    | No             |
|                            |                | partitioning)  |                |
+----------------------------+----------------+----------------+----------------+
| Engine Support             | Spark-primary  | Multi-engine   | Spark-primary  |
|                            |                | (broad)        |                |
+----------------------------+----------------+----------------+----------------+
| Incremental Processing     | Change Data    | Incremental    | Built-in CDC  |
|                            | Feed           | reads          | support        |
+----------------------------+----------------+----------------+----------------+
| Governance                 | Unity Catalog  | Multiple       | Limited        |
|                            | (Databricks)   | catalogs       |                |
+----------------------------+----------------+----------------+----------------+
```

**Key distinctions to know for interviews:**

- **Apache Iceberg** has the best multi-engine support. It works well with Spark, Flink, Trino,
  Presto, Dremio, and others. Its hidden partitioning and partition evolution features are superior
  to Delta Lake's. It uses a tree of manifest files (in Avro) for metadata instead of a linear log.

- **Apache Hudi** was designed specifically for incremental data processing and upserts. It has
  first-class support for CDC (Change Data Capture) patterns. It introduced the concept of
  "Copy-on-Write" vs "Merge-on-Read" storage types.

- **Delta Lake** has the tightest integration with Spark and Databricks. Its transaction log
  approach is simpler to understand. The Databricks ecosystem (Unity Catalog, DLT, etc.) provides
  the most complete managed experience.

In practice, your choice often depends on your existing stack. If you're on Databricks, Delta Lake
is the natural choice. If you need broad engine support, Iceberg might be better. If your primary
use case is streaming upserts, Hudi has strengths there.

## CONCEPT GAP: Delta Lake Open Source vs Databricks Delta Lake

This is important to understand because there are real differences between the open-source Delta
Lake project and the version that runs on Databricks.

**Open-Source Delta Lake** is available on GitHub and can be used with any Spark deployment. It
provides the core features: ACID transactions, time travel, schema enforcement/evolution, and
the transaction log.

**Databricks Delta Lake** (sometimes called "Delta Lake on Databricks") includes everything in
the open-source version plus additional proprietary features:

```
+---------------------------------------------------+
|           Databricks Delta Lake                   |
|                                                   |
|  +---------------------------------------------+ |
|  |        Open-Source Delta Lake                | |
|  |                                             | |
|  |  - ACID Transactions                        | |
|  |  - Time Travel                              | |
|  |  - Schema Enforcement / Evolution           | |
|  |  - Transaction Log                          | |
|  |  - Basic OPTIMIZE                           | |
|  |  - Z-ORDER (via open-source)                | |
|  +---------------------------------------------+ |
|                                                   |
|  Additional Databricks Features:                  |
|  - OPTIMIZE with auto-compaction                  |
|  - Predictive I/O                                 |
|  - Delta Sharing (open protocol)                  |
|  - Photon engine optimizations                    |
|  - Unity Catalog integration                      |
|  - Liquid Clustering                              |
|  - Deletion Vectors                               |
|  - Row-Level Concurrency                          |
|  - Change Data Feed (CDF)                         |
|  - Dynamic File Pruning                           |
|  +---------------------------------------------+ |
+---------------------------------------------------+
```

For Databricks certification exams, you'll want to know about features that are specific to the
Databricks platform, like Liquid Clustering, Deletion Vectors, and Predictive I/O. For general
data engineering interviews, focus on the core open-source concepts.

Note that Delta Lake has been moving toward greater openness. The UniForm feature in newer versions
allows Delta tables to be read by Iceberg and Hudi readers, which is a step toward format
interoperability.

## Interview Q&A

**Q: What is Delta Lake, and what problem does it solve?**
A: Delta Lake is an open-source storage layer that brings ACID transaction support to data lakes.
It solves the reliability problems inherent in traditional data lakes, such as partial writes from
failed jobs, lack of schema enforcement, no support for concurrent writes, and inability to do
UPDATE/DELETE operations. It sits on top of existing cloud storage (S3, ADLS, GCS) and uses Parquet
as its underlying data format, adding a transaction log that enables these reliability features.

**Q: What is the relationship between Delta Lake and Parquet?**
A: Delta Lake uses Parquet as its underlying data storage format. A Delta table consists of Parquet
data files plus a `_delta_log/` directory containing the transaction log. The transaction log is
what differentiates Delta from plain Parquet -- it tracks which files are part of the table, records
schema information, and enables ACID transactions, time travel, and other features. You can think
of Delta Lake as "Parquet plus a transaction log and protocol."

**Q: What are the key features of Delta Lake?**
A: The key features are: (1) ACID transactions for reliable reads and writes, (2) scalable metadata
handling using Spark's distributed processing, (3) unified streaming and batch processing on a
single table, (4) schema enforcement to prevent bad data from being written, (5) schema evolution
to support controlled schema changes, (6) time travel to query historical versions of data, and
(7) audit history to track all changes made to a table.

**Q: Why is Delta Lake the default format in Databricks?**
A: Delta Lake is the default format because it provides reliability guarantees that plain Parquet
or other formats lack. By making it the default, Databricks ensures that every table automatically
benefits from ACID transactions, schema enforcement, time travel, and audit history without
requiring the user to explicitly opt in. This aligns with Databricks' goal of making the lakehouse
architecture reliable and easy to use.

**Q: How does Delta Lake handle schema enforcement?**
A: Delta Lake validates the schema of incoming data against the table's existing schema on every
write. If the schemas don't match (e.g., a column is missing, a data type is different, or there's
an extra column), the write is rejected with an error. This prevents accidental data corruption.
When you intentionally want to change the schema, you can use the `mergeSchema` option or
`overwriteSchema` option to allow the write to proceed with schema changes.

**Q: How does Delta Lake compare to Apache Iceberg and Apache Hudi?**
A: All three are open table formats that bring ACID transactions and other reliability features to
data lakes. Delta Lake (from Databricks) has the tightest Spark integration and simplest metadata
model (linear transaction log). Iceberg (from Netflix) excels at multi-engine support and has
superior partition evolution with hidden partitioning. Hudi (from Uber) was designed for streaming
upserts and has built-in CDC support. The choice often depends on your existing stack: Delta for
Databricks, Iceberg for multi-engine environments, Hudi for streaming-heavy CDC workloads.

**Q: What is the difference between open-source Delta Lake and Databricks Delta Lake?**
A: Open-source Delta Lake provides core features like ACID transactions, time travel, schema
enforcement/evolution, and the transaction log. Databricks Delta Lake includes all of these plus
proprietary features like auto-compaction, Liquid Clustering, Deletion Vectors, Predictive I/O,
Row-Level Concurrency, Change Data Feed, and tight integration with Unity Catalog and Photon
engine. For production use on Databricks, you get significant performance and usability benefits
beyond what the open-source version offers.

**Q: Can you use Delta Lake outside of Databricks?**
A: Yes. Delta Lake is an open-source project under the Linux Foundation. You can use it with any
Apache Spark deployment, whether that's on-premises, on AWS EMR, on Google Dataproc, or any other
Spark environment. You add the Delta Lake library as a dependency, and then you can create and read
Delta tables using the standard Spark APIs. However, some advanced features (like Liquid Clustering,
Deletion Vectors, and Predictive I/O) are only available on Databricks. The Delta Lake connectors
also exist for non-Spark engines like Flink, Presto, and Trino, though Spark has the richest
feature support.
