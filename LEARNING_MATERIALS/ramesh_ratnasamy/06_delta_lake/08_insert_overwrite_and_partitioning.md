# Insert Overwrite & Partitioning

## Introduction

Alright, let's dig into two closely related topics -- INSERT OVERWRITE and partitioning in Delta
Lake. These are fundamental concepts for building efficient data pipelines. INSERT OVERWRITE lets
you replace data in a table (or specific partitions of a table) atomically, while partitioning
controls how data is physically organized on disk. Understanding how these two work together is
essential for writing performant ETL pipelines.

Most production data engineering pipelines use some form of partition-based overwrite. Instead of
reprocessing your entire table every time, you just overwrite the partitions that have new data.
This is faster, cheaper, and more scalable. Let's see how it all works.

## INSERT INTO vs INSERT OVERWRITE

First, let's be clear about the difference between INSERT INTO and INSERT OVERWRITE.

```
+====================================================================+
|            INSERT INTO vs INSERT OVERWRITE                          |
+====================================================================+
|                                                                    |
|  INSERT INTO                      INSERT OVERWRITE                 |
|  ───────────                      ────────────────                 |
|                                                                    |
|  - APPENDS data to the table      - REPLACES data in the table    |
|  - Existing data is untouched     - Existing data is removed      |
|  - Can create duplicates if       - Idempotent: safe to re-run    |
|    run multiple times             - Atomically swaps data         |
|  - Good for streaming/            - Good for batch ETL            |
|    incremental loads                                               |
|                                                                    |
+====================================================================+
```

### INSERT INTO

```sql
-- Appends new rows to the table
INSERT INTO employees
VALUES (101, 'Alice', 'Engineering', 95000);

-- Insert from a query
INSERT INTO gold_sales
SELECT product, SUM(amount) as total
FROM silver_sales
WHERE sale_date = '2025-01-15'
GROUP BY product;
```

**Warning**: If you run the same INSERT INTO multiple times, you'll get duplicate rows. There's
no deduplication built in. This is why INSERT INTO is typically used for incremental/streaming
loads where you have guarantees about not re-processing the same data.

### INSERT OVERWRITE

```sql
-- Replaces ALL data in the table
INSERT OVERWRITE employees
SELECT * FROM staging_employees;

-- With explicit values
INSERT OVERWRITE TABLE small_lookup_table
VALUES ('US', 'United States'), ('UK', 'United Kingdom'), ('DE', 'Germany');
```

INSERT OVERWRITE replaces the entire contents of a table atomically. The old data files are
logically removed (marked as removed in the transaction log) and new data files are added.
The old files still exist on disk until VACUUM cleans them up, which means time travel still
works.

## Partitioning in Delta Lake

Partitioning is a technique for organizing data into subdirectories based on column values.
When you partition a table, Delta Lake stores the data in a directory structure where each
unique partition value gets its own subdirectory.

```
Partitioned Table Structure (partitioned by year and month):

my_table/
├── _delta_log/
│   ├── 00000000000000000000.json
│   └── 00000000000000000001.json
├── year=2024/
│   ├── month=01/
│   │   ├── part-00000.parquet
│   │   └── part-00001.parquet
│   ├── month=02/
│   │   └── part-00000.parquet
│   └── month=12/
│       └── part-00000.parquet
└── year=2025/
    ├── month=01/
    │   └── part-00000.parquet
    └── month=02/
        └── part-00000.parquet
```

### Creating Partitioned Tables

```sql
-- Partition by a single column
CREATE TABLE sales (
    order_id INT,
    product STRING,
    amount DOUBLE,
    sale_date DATE,
    region STRING
)
PARTITIONED BY (region);

-- Partition by multiple columns
CREATE TABLE events (
    event_id INT,
    event_type STRING,
    payload STRING,
    event_date DATE,
    year INT,
    month INT
)
PARTITIONED BY (year, month);
```

### Using PySpark

```python
# Create a partitioned Delta table
df.write.format("delta") \
    .partitionBy("region") \
    .saveAsTable("sales")

# Write with multiple partition columns
df.write.format("delta") \
    .partitionBy("year", "month") \
    .saveAsTable("events")
```

## Dynamic and Static Partition Overwrite

This is where INSERT OVERWRITE and partitioning come together. When you INSERT OVERWRITE a
partitioned table, you have two modes: **static** and **dynamic** partition overwrite.

### Static Partition Overwrite

With static partition overwrite, you explicitly specify which partition(s) to overwrite using
a WHERE-like partition specification.

```sql
-- Overwrite a specific partition
INSERT OVERWRITE TABLE sales
PARTITION (region = 'US')
SELECT order_id, product, amount, sale_date
FROM staging_sales
WHERE region = 'US';
```

This only replaces data in the `region=US` partition. All other partitions are untouched.

### Dynamic Partition Overwrite

With dynamic partition overwrite, Delta Lake automatically determines which partitions to
overwrite based on the data being written. Only partitions that appear in the new data are
replaced -- other partitions are untouched.

```sql
-- Dynamic partition overwrite (SQL)
INSERT OVERWRITE TABLE sales
SELECT order_id, product, amount, sale_date, region
FROM staging_sales;
```

In PySpark, you need to set a configuration to enable dynamic partition overwrite:

```python
# Enable dynamic partition overwrite mode
spark.conf.set("spark.sql.sources.partitionOverwriteMode", "dynamic")

# Now overwrite only the partitions present in the DataFrame
df.write.format("delta") \
    .mode("overwrite") \
    .saveAsTable("sales")

# Or use insertInto for an existing table
df.write.format("delta") \
    .mode("overwrite") \
    .insertInto("sales")
```

```
Dynamic vs Static Partition Overwrite:

Table 'sales' has partitions: US, UK, DE, FR

Static Overwrite (region = 'US'):
+------+------+------+------+
|  US  |  UK  |  DE  |  FR  |
+------+------+------+------+
|  NEW |  OLD |  OLD |  OLD |   <-- Only US replaced
+------+------+------+------+

Dynamic Overwrite (new data has US and DE):
+------+------+------+------+
|  US  |  UK  |  DE  |  FR  |
+------+------+------+------+
|  NEW |  OLD |  NEW |  OLD |   <-- US and DE replaced
+------+------+------+------+

Full Overwrite (no partitioning logic):
+------+------+------+------+
|  US  |  UK  |  DE  |  FR  |
+------+------+------+------+
|  NEW |  NEW | GONE | GONE |   <-- ALL data replaced
+------+------+------+------+
```

## Partitioning Best Practices

### When to Partition

Partition your table when:
- You have a **very large table** (terabytes of data)
- Queries consistently **filter on the partition column**
- The partition column has **low cardinality** (hundreds, not millions of values)
- You need **partition-level overwrites** for incremental processing

### When NOT to Partition

Do **not** partition when:
- Your table is small (less than 1 TB)
- The partition column has **high cardinality** (creates too many small files)
- Queries don't commonly filter on the partition column
- You're unsure -- start without partitioning and add it later if needed

### The Small Files Problem

Over-partitioning is one of the most common mistakes in data engineering. If your partition
column has too many unique values, you end up with thousands of tiny files instead of a
few large ones. This destroys query performance.

```
Over-partitioned Table (BAD):

sales/
├── date=2025-01-01/
│   └── part-00000.parquet  (50 KB)   <-- Tiny!
├── date=2025-01-02/
│   └── part-00000.parquet  (48 KB)
├── date=2025-01-03/
│   └── part-00000.parquet  (52 KB)
... (365 directories × multiple years = thousands of tiny files)

Properly Partitioned Table (GOOD):

sales/
├── year=2024/
│   ├── part-00000.parquet  (500 MB)
│   ├── part-00001.parquet  (500 MB)
│   └── part-00002.parquet  (500 MB)
└── year=2025/
    ├── part-00000.parquet  (500 MB)
    └── part-00001.parquet  (500 MB)
```

**Rule of thumb**: Each partition should contain at least 1 GB of data. If your partitions
are smaller than this, consider using a coarser partition key or not partitioning at all.
For smaller tables, consider using Liquid Clustering instead (covered in a later lesson).

---

## CONCEPT GAP: replaceWhere in PySpark

PySpark provides a `replaceWhere` option that gives you fine-grained control over which
data gets replaced. This is a Delta-specific feature that works on both partitioned and
non-partitioned tables.

```python
# Replace only rows matching a condition
df.write.format("delta") \
    .mode("overwrite") \
    .option("replaceWhere", "region = 'US' AND year = 2025") \
    .saveAsTable("sales")
```

With `replaceWhere`:
- Only rows matching the condition are removed from the existing table
- The new data is written in place of the removed rows
- Rows that don't match the condition are untouched
- Works on non-partitioned columns too (unlike static partition overwrite)

This is particularly useful when your overwrite logic doesn't align with your partition
structure. For example, you might partition by year but want to overwrite by region.

---

## KEY INTERVIEW QUESTIONS AND ANSWERS

### Q1: What is the difference between INSERT INTO and INSERT OVERWRITE?
**A:** INSERT INTO appends data to an existing table without modifying existing rows, which can create duplicates if run multiple times. INSERT OVERWRITE atomically replaces data in the table (or specific partitions), making it idempotent and safe to re-run in batch ETL pipelines.

### Q2: What is the difference between static and dynamic partition overwrite?
**A:** Static partition overwrite explicitly specifies which partition(s) to replace using a PARTITION clause. Dynamic partition overwrite automatically determines which partitions to replace based on the partition values present in the new data. In both cases, partitions not being overwritten are left untouched.

### Q3: What are the risks of over-partitioning a Delta table?
**A:** Over-partitioning creates too many small files (the "small files problem"), which degrades query performance due to excessive file listing overhead, increased metadata processing, and poor compression. Each partition should ideally contain at least 1 GB of data. Use coarser partition keys or avoid partitioning for smaller tables.

### Q4: How do you enable dynamic partition overwrite in PySpark?
**A:** Set the Spark configuration: `spark.conf.set("spark.sql.sources.partitionOverwriteMode", "dynamic")`. Then use `df.write.format("delta").mode("overwrite").saveAsTable("table_name")` or `.insertInto("table_name")`. Delta Lake will automatically replace only the partitions present in the DataFrame.

### Q5: When should you partition a Delta table?
**A:** Partition when the table is very large (1+ TB), queries consistently filter on the partition column, the partition column has low cardinality (hundreds of values, not millions), and you need partition-level overwrites for incremental processing. If the table is small or the column has high cardinality, don't partition.

### Q6: What is replaceWhere in Delta Lake?
**A:** replaceWhere is a PySpark write option that replaces only the rows matching a specified predicate condition, while leaving all other rows untouched. Unlike partition-based overwrite, replaceWhere works on any column, not just partition columns, giving fine-grained control over which data is replaced.

### Q7: What happens to old data files after INSERT OVERWRITE?
**A:** Old data files are logically removed by being marked as "removed" in the transaction log, but they remain physically on disk. This enables time travel to access previous versions. The files are only physically deleted when VACUUM is run (after the retention period has passed).

---
