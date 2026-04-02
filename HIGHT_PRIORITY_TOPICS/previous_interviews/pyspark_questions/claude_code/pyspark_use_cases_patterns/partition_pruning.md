# PySpark Implementation: Partition Pruning

## Problem Statement

In large-scale data lakes, tables often contain terabytes or petabytes of data. When a query only needs a small subset (e.g., last week's sales in the US), reading the entire dataset is wasteful. **Partition pruning** is Spark's ability to skip irrelevant partitions (directories/files) entirely during query planning, drastically reducing I/O and speeding up queries.

Understanding partition pruning is essential because:
- It is the single biggest performance lever for analytical queries on partitioned data.
- Misconfigured partitioning leads to full table scans even when filters are present.
- Dynamic Partition Pruning (DPP), introduced in Spark 3.0, extends this optimization to join queries.

---

## Approach 1: Writing Partitioned Data and Demonstrating Static Pruning

### Sample Data

```python
sales_data = [
    ("2024-01-15", "US", "Electronics", 1200.00),
    ("2024-01-15", "US", "Clothing", 350.00),
    ("2024-01-15", "EU", "Electronics", 980.00),
    ("2024-02-10", "US", "Electronics", 1500.00),
    ("2024-02-10", "EU", "Clothing", 420.00),
    ("2024-03-05", "US", "Furniture", 2200.00),
    ("2024-03-05", "APAC", "Electronics", 870.00),
    ("2024-03-05", "APAC", "Clothing", 310.00),
]
```

### Expected Output

When querying for `region = 'US'` and `sale_date = '2024-01-15'`, Spark should only read files under `sale_date=2024-01-15/region=US/` and skip all other directories.

### Full Working Code

```python
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, DoubleType

spark = SparkSession.builder \
    .appName("PartitionPruning") \
    .master("local[*]") \
    .getOrCreate()

# ── 1. Create Sample Data ──────────────────────────────────────────
schema = StructType([
    StructField("sale_date", StringType(), False),
    StructField("region", StringType(), False),
    StructField("category", StringType(), False),
    StructField("amount", DoubleType(), False),
])

sales_data = [
    ("2024-01-15", "US", "Electronics", 1200.00),
    ("2024-01-15", "US", "Clothing", 350.00),
    ("2024-01-15", "EU", "Electronics", 980.00),
    ("2024-02-10", "US", "Electronics", 1500.00),
    ("2024-02-10", "EU", "Clothing", 420.00),
    ("2024-03-05", "US", "Furniture", 2200.00),
    ("2024-03-05", "APAC", "Electronics", 870.00),
    ("2024-03-05", "APAC", "Clothing", 310.00),
]

df = spark.createDataFrame(sales_data, schema)

# ── 2. Write Partitioned by date and region ─────────────────────────
output_path = "/tmp/partitioned_sales"

df.write \
    .partitionBy("sale_date", "region") \
    .mode("overwrite") \
    .parquet(output_path)

# This creates a directory structure like:
# /tmp/partitioned_sales/
#   sale_date=2024-01-15/
#     region=US/
#       part-00000.parquet
#     region=EU/
#       part-00000.parquet
#   sale_date=2024-02-10/
#     ...

# ── 3. Read with Partition Filter ──────────────────────────────────
partitioned_df = spark.read.parquet(output_path)

# Filter on partition columns -> triggers partition pruning
filtered = partitioned_df.filter(
    (partitioned_df.sale_date == "2024-01-15") &
    (partitioned_df.region == "US")
)

filtered.show()
# +----------+------+------+
# |  category|amount|sale_date|region|
# +----------+------+---------+------+
# |Electronics|1200.0|2024-01-15|   US|
# |  Clothing| 350.0|2024-01-15|   US|
# +----------+------+---------+------+

# ── 4. Verify Pruning via explain() ────────────────────────────────
filtered.explain(True)
# In the physical plan, look for:
#   PartitionFilters: [isnotnull(sale_date), (sale_date = 2024-01-15),
#                      isnotnull(region), (region = US)]
# This confirms Spark pushes the filter to the file listing stage
# and skips directories that don't match.

# ── 5. Filter on non-partition column (NO pruning) ─────────────────
no_pruning = partitioned_df.filter(partitioned_df.category == "Electronics")
no_pruning.explain(True)
# The physical plan will show:
#   PartitionFilters: []
#   PushedFilters: [IsNotNull(category), EqualTo(category, Electronics)]
# Spark must scan ALL partitions and apply the filter after reading.

spark.stop()
```

---

## Approach 2: Dynamic Partition Pruning (DPP) in Joins

Dynamic Partition Pruning (Spark 3.0+) optimizes joins where one side is a small dimension table and the other is a large partitioned fact table. Spark pushes the join filter into the scan of the fact table at runtime.

### Sample Data

```python
# Large fact table (partitioned by region)
fact_data = [
    (1, "US", 100), (2, "EU", 200), (3, "APAC", 150),
    (4, "US", 300), (5, "LATAM", 50), (6, "EU", 175),
]

# Small dimension table
dim_data = [
    ("US", "North America"),
    ("EU", "Europe"),
]
```

### Expected Output

When joining fact with dim on `region`, Spark should only scan the `US` and `EU` partitions of the fact table, skipping `APAC` and `LATAM` entirely.

### Full Working Code

```python
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, IntegerType

spark = SparkSession.builder \
    .appName("DynamicPartitionPruning") \
    .master("local[*]") \
    .config("spark.sql.optimizer.dynamicPartitionPruning.enabled", "true") \
    .getOrCreate()

# ── 1. Create and Write Partitioned Fact Table ─────────────────────
fact_schema = StructType([
    StructField("id", IntegerType()),
    StructField("region", StringType()),
    StructField("amount", IntegerType()),
])

fact_data = [
    (1, "US", 100), (2, "EU", 200), (3, "APAC", 150),
    (4, "US", 300), (5, "LATAM", 50), (6, "EU", 175),
]

fact_df = spark.createDataFrame(fact_data, fact_schema)

fact_path = "/tmp/fact_partitioned"
fact_df.write.partitionBy("region").mode("overwrite").parquet(fact_path)

# ── 2. Create Dimension Table ──────────────────────────────────────
dim_data = [("US", "North America"), ("EU", "Europe")]
dim_df = spark.createDataFrame(dim_data, ["region", "continent"])

# ── 3. Join with DPP ──────────────────────────────────────────────
fact_read = spark.read.parquet(fact_path)

joined = fact_read.join(dim_df, "region")
joined.explain(True)
# Look for "DynamicPruningExpression" in the physical plan.
# Spark inserts a subquery that first evaluates the dim table,
# collects the distinct region values (US, EU), and uses them
# to prune partitions of the fact table BEFORE scanning.

joined.show()
# +------+---+------+--------------+
# |region| id|amount|     continent|
# +------+---+------+--------------+
# |    US|  1|   100|North America |
# |    US|  4|   300|North America |
# |    EU|  2|   200|       Europe |
# |    EU|  6|   175|       Europe |
# +------+---+------+--------------+

# ── 4. Confirm DPP is Active ──────────────────────────────────────
# Check the Spark UI -> SQL tab -> the scan node will show
# "number of partitions read" = 2 (US, EU) instead of 4.
# Or check explain output for:
#   DynamicPruningExpression(region IN (subquery))

spark.stop()
```

---

## Approach 3: Partition Pruning with Hive-Style Tables

### Full Working Code

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("HivePartitionPruning") \
    .master("local[*]") \
    .config("spark.sql.warehouse.dir", "/tmp/spark-warehouse") \
    .enableHiveSupport() \
    .getOrCreate()

# ── 1. Create a Hive Partitioned Table ────────────────────────────
spark.sql("DROP TABLE IF EXISTS sales_hive")
spark.sql("""
    CREATE TABLE sales_hive (
        category STRING,
        amount DOUBLE
    )
    PARTITIONED BY (sale_date STRING, region STRING)
    STORED AS PARQUET
""")

# ── 2. Insert Data ────────────────────────────────────────────────
spark.sql("""
    INSERT INTO sales_hive PARTITION(sale_date='2024-01-15', region='US')
    VALUES ('Electronics', 1200.0), ('Clothing', 350.0)
""")
spark.sql("""
    INSERT INTO sales_hive PARTITION(sale_date='2024-02-10', region='EU')
    VALUES ('Clothing', 420.0)
""")

# ── 3. Query with Pruning ─────────────────────────────────────────
result = spark.sql("""
    SELECT * FROM sales_hive
    WHERE sale_date = '2024-01-15' AND region = 'US'
""")
result.explain(True)
# Physical plan shows PartitionFilters applied at scan level.

result.show()

# ── 4. SHOW PARTITIONS to see what exists ─────────────────────────
spark.sql("SHOW PARTITIONS sales_hive").show()
# +------------------------------------+
# |                           partition|
# +------------------------------------+
# |sale_date=2024-01-15/region=US      |
# |sale_date=2024-02-10/region=EU      |
# +------------------------------------+

spark.stop()
```

---

## Key Takeaways

| Concept | Detail |
|---|---|
| **What is pruned** | Entire directories (partitions) are skipped at the file-listing stage, before any data is read. |
| **Static pruning** | Filter predicates on partition columns in WHERE clauses. Works since Spark 1.x. |
| **Dynamic pruning** | Spark 3.0+ pushes join-key filters from a small table into the scan of a large partitioned table at runtime. |
| **How to verify** | Use `df.explain(True)` and look for `PartitionFilters` or `DynamicPruningExpression`. |
| **Partition column choice** | Choose low-cardinality columns frequently used in WHERE/JOIN (date, region, status). |
| **Over-partitioning trap** | Too many partitions (e.g., partitioning by user_id) creates millions of tiny directories -- the small files problem. |
| **Filter placement matters** | Applying filters AFTER a shuffle (e.g., after a groupBy) prevents pruning. Filter early. |

## Interview Tips

- Always mention the `explain(True)` trick to verify pruning -- interviewers love candidates who can prove optimizations work.
- Distinguish between **partition pruning** (skips files) and **predicate pushdown** (pushes filters into the file reader, e.g., Parquet row-group skipping). Both happen, but at different levels.
- Know that DPP has requirements: the dimension side must be broadcastable (small enough), and the join key must be a partition column of the fact table.
- A common mistake is filtering on a derived column like `YEAR(sale_date)` when the partition column is `sale_date` -- Spark cannot prune because the expression doesn't directly match the partition column.
