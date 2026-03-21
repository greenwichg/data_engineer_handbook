# PySpark Implementation: Spark Execution Plan Analysis

## Problem Statement

Given a slow-running PySpark job, analyze its execution plan using `EXPLAIN` to identify performance bottlenecks — unnecessary shuffles, missing broadcast hints, suboptimal join strategies, and full table scans. Demonstrate how to read physical and logical plans, identify stages and shuffles, and optimize based on findings.

This question tests your ability to debug and tune Spark jobs at a systems level — a critical skill for senior data engineering roles where you are expected to own pipeline performance.

### Sample Data

**Orders (large fact table):**
```
order_id  product_id  order_date   customer_id  amount
O001      P001        2024-01-15   C100         1999.98
O002      P003        2024-01-16   C101         79.99
O003      P001        2024-01-17   C102         4999.95
O004      P002        2024-01-18   C100         89.97
O005      P004        2024-01-19   C103         349.99
O006      P001        2024-01-20   C104         3999.96
O007      P003        2024-01-21   C105         159.98
O008      P005        2024-01-22   C101         899.94
```

**Products (small dimension table):**
```
product_id  product_name  category      price
P001        Laptop        Electronics   999.99
P002        Mouse         Accessories   29.99
P003        Keyboard      Accessories   79.99
P004        Monitor       Electronics   349.99
P005        Headphones    Audio         149.99
```

---

## Method 1: Using `df.explain(True)` — Full Plan Breakdown

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, broadcast, sum as spark_sum

# Initialize Spark session
spark = SparkSession.builder.appName("ExecutionPlanAnalysis").getOrCreate()

# Orders (large fact table)
orders_data = [
    ("O001", "P001", "2024-01-15", "C100", 1999.98),
    ("O002", "P003", "2024-01-16", "C101", 79.99),
    ("O003", "P001", "2024-01-17", "C102", 4999.95),
    ("O004", "P002", "2024-01-18", "C100", 89.97),
    ("O005", "P004", "2024-01-19", "C103", 349.99),
    ("O006", "P001", "2024-01-20", "C104", 3999.96),
    ("O007", "P003", "2024-01-21", "C105", 159.98),
    ("O008", "P005", "2024-01-22", "C101", 899.94),
]
orders_df = spark.createDataFrame(orders_data,
    ["order_id", "product_id", "order_date", "customer_id", "amount"])

# Products (small dimension table)
products_data = [
    ("P001", "Laptop", "Electronics", 999.99),
    ("P002", "Mouse", "Accessories", 29.99),
    ("P003", "Keyboard", "Accessories", 79.99),
    ("P004", "Monitor", "Electronics", 349.99),
    ("P005", "Headphones", "Audio", 149.99),
]
products_df = spark.createDataFrame(products_data,
    ["product_id", "product_name", "category", "price"])

# A slow join + aggregation query (no optimization hints)
result = orders_df.join(products_df, on="product_id", how="inner") \
    .groupBy("category") \
    .agg(spark_sum("amount").alias("total_revenue"))

# Show ALL four plan levels
result.explain(True)
```

### Output: The Four Plan Levels

```
== Parsed Logical Plan ==
'Aggregate ['category], ['category, unresolvedalias('sum('amount))]
+- 'Join Inner, ('product_id = 'product_id)
   :- 'UnresolvedRelation [orders_df]
   +- 'UnresolvedRelation [products_df]

== Analyzed Logical Plan ==
category: string, total_revenue: double
Aggregate [category], [category, sum(amount) AS total_revenue]
+- Join Inner, (product_id = product_id)
   :- LocalRelation [order_id, product_id, order_date, customer_id, amount]
   +- LocalRelation [product_id, product_name, category, price]

== Optimized Logical Plan ==
Aggregate [category], [category, sum(amount) AS total_revenue]
+- Project [amount, category]
   +- Join Inner, (product_id = product_id)
      :- LocalRelation [product_id, amount]
      +- LocalRelation [product_id, category]

== Physical Plan ==
*(3) HashAggregate(keys=[category], functions=[sum(amount)])
+- Exchange hashpartitioning(category, 200)
   +- *(2) HashAggregate(keys=[category], functions=[partial_sum(amount)])
      +- *(2) Project [amount, category]
         +- *(2) SortMergeJoin [product_id], [product_id], Inner
            :- *(1) Sort [product_id ASC], false, 0
            :  +- Exchange hashpartitioning(product_id, 200)
            :     +- LocalTableScan [product_id, amount]
            +- *(1) Sort [product_id ASC], false, 0
               +- Exchange hashpartitioning(product_id, 200)
                  +- LocalTableScan [product_id, category]
```

### Step-by-Step: How to Read Each Plan Level

1. **Parsed Logical Plan:** Raw parse tree. Column names are unresolved — Spark has not yet checked if they exist. Useful for verifying the query structure.

2. **Analyzed Logical Plan:** Column names are resolved to actual data types. Schema validation is complete. Shows output schema at the top.

3. **Optimized Logical Plan:** The Catalyst optimizer has applied rules. Notice `Project [amount, category]` — Spark pruned all unnecessary columns (column pruning). Only `product_id`, `amount`, and `category` are read.

4. **Physical Plan:** The actual execution strategy. This is where you find bottlenecks:
   - `Exchange` = **shuffle** (data moves across the network)
   - `SortMergeJoin` = both sides are shuffled and sorted before joining
   - `*(N)` = whole-stage code generation (good — means Spark compiled this into optimized Java bytecode)

---

## Method 2: Using `df.explain("formatted")` for Readable Output

```python
# "formatted" mode gives a structured, easier-to-read plan
result.explain("formatted")
```

### Output

```
== Physical Plan ==
* HashAggregate (7)
+- Exchange (6)
   +- * HashAggregate (5)
      +- * Project (4)
         +- * SortMergeJoin Inner (3)
            :- * Sort (1)
            :  +- Exchange (0)
            :     +- LocalTableScan
            +- * Sort (2)
               +- Exchange (0)
                  +- LocalTableScan

(0) Exchange
Input: [product_id, amount]
Arguments: hashpartitioning(product_id, 200)

(1) Sort
Input: [product_id, amount]
Arguments: [product_id ASC NULLS FIRST], false, 0

(2) Sort
Input: [product_id, category]
Arguments: [product_id ASC NULLS FIRST], false, 0

(3) SortMergeJoin
Left keys: [product_id]
Right keys: [product_id]
Join condition: None

(4) Project
Output: [amount, category]

(5) HashAggregate
Keys: [category]
Functions: [partial_sum(amount)]

(6) Exchange
Input: [category, sum]
Arguments: hashpartitioning(category, 200)

(7) HashAggregate
Keys: [category]
Functions: [sum(amount)]
```

### How to Read Formatted Plans

- Each node is numbered — read bottom-up (data flows from leaf nodes to the root).
- `Exchange` nodes are the critical performance indicators — each one is a shuffle.
- The plan above has **three shuffles**: two for the SortMergeJoin (one per table) and one for the aggregation. This is a red flag for a simple join+agg query.

---

## Method 3: Reading the Spark UI — Stages, Tasks, Shuffle, and Spill

```python
# The Spark UI is available at http://<driver-host>:4040 while the job runs.
# Key tabs and what to look for:

# 1. Jobs tab — see overall job progress
# 2. Stages tab — THIS IS WHERE YOU DEBUG
# 3. SQL tab — see the visual DAG of the query plan
```

### What to Look For in the Spark UI

```
Stages Tab — Key Metrics:
┌──────────────┬────────────────────────────────────────────────┐
│ Metric       │ What It Tells You                              │
├──────────────┼────────────────────────────────────────────────┤
│ Duration     │ How long each stage took (look for stragglers) │
│ Input Size   │ Data read from storage                         │
│ Shuffle Read │ Data pulled from other executors (network I/O) │
│ Shuffle Write│ Data written for the next stage to read        │
│ Spill (Mem)  │ Data that didn't fit in memory → serialized    │
│ Spill (Disk) │ Data that overflowed to disk (VERY BAD)        │
│ Tasks        │ Total tasks and their distribution             │
└──────────────┴────────────────────────────────────────────────┘

Red Flags:
- Shuffle Read/Write in the GB+ range → too much data moving
- Spill (Disk) > 0 → partitions are too large for memory
- One task takes 10x+ longer than others → data skew
- 200 tasks for a small dataset → default shuffle partitions too high
```

### Checking Shuffle Partitions

```python
# Default is 200 — often too high for small datasets, too low for large ones
print(spark.conf.get("spark.sql.shuffle.partitions"))  # 200

# For small/medium datasets, reduce to avoid excessive task overhead
spark.conf.set("spark.sql.shuffle.partitions", "20")

# For large datasets (TB-scale), increase
spark.conf.set("spark.sql.shuffle.partitions", "2000")
```

---

## Method 4: Identifying Common Bottlenecks and Fixes

### Bottleneck 1: SortMergeJoin When BroadcastHashJoin is Better

**Before (unoptimized):**
```python
# No broadcast hint — Spark defaults to SortMergeJoin
slow_result = orders_df.join(products_df, on="product_id", how="inner")
slow_result.explain()
```

```
== Physical Plan ==
*(2) SortMergeJoin [product_id], [product_id], Inner     <-- TWO SHUFFLES
:- *(1) Sort [product_id ASC]
:  +- Exchange hashpartitioning(product_id, 200)          <-- Shuffle 1
:     +- LocalTableScan [order_id, product_id, ...]
+- *(1) Sort [product_id ASC]
   +- Exchange hashpartitioning(product_id, 200)          <-- Shuffle 2
      +- LocalTableScan [product_id, product_name, ...]
```

**After (optimized with broadcast hint):**
```python
# Add broadcast hint for the small table
fast_result = orders_df.join(broadcast(products_df), on="product_id", how="inner")
fast_result.explain()
```

```
== Physical Plan ==
*(2) Project [order_id, product_id, ...]
+- *(2) BroadcastHashJoin [product_id], [product_id], Inner   <-- NO SHUFFLE
   :- *(2) LocalTableScan [order_id, product_id, ...]
   +- BroadcastExchange HashedRelationBroadcastMode            <-- Small table broadcast
      +- *(1) LocalTableScan [product_id, product_name, ...]
```

**What changed:** Two `Exchange` (shuffle) nodes disappeared. The small table is broadcast to all executors instead. The large table stays in place — no network movement.

---

### Bottleneck 2: Unnecessary Shuffle with repartition vs coalesce

**Before (unnecessary full shuffle):**
```python
# repartition triggers a FULL shuffle — every record moves
output = result.repartition(10)
output.explain()
```

```
== Physical Plan ==
Exchange RoundRobinPartitioning(10)       <-- FULL SHUFFLE of all data
+- *(1) ...
```

**After (coalesce to reduce partitions without full shuffle):**
```python
# coalesce merges partitions locally — no full shuffle
output = result.coalesce(10)
output.explain()
```

```
== Physical Plan ==
Coalesce 10                               <-- NO SHUFFLE, just merges partitions
+- *(1) ...
```

**When to use which:**
- `coalesce(N)`: Use when reducing the number of partitions (e.g., before writing files). No shuffle.
- `repartition(N)`: Use when increasing partitions or need even distribution. Full shuffle.
- `repartition(N, col("key"))`: Use when you need data partitioned by a specific key for downstream joins.

---

### Bottleneck 3: Full Table Scan — Missing Filter Pushdown

**Before (filter applied after scan):**
```python
# Writing the filter AFTER the join — Spark may not push it down
slow = orders_df.join(products_df, on="product_id") \
    .filter(col("order_date") >= "2024-01-18")
slow.explain()
```

```
== Physical Plan ==
*(2) Filter (order_date >= 2024-01-18)            <-- Filter AFTER join
+- *(2) SortMergeJoin [product_id], [product_id]
   :- *(1) LocalTableScan [...]                   <-- Full scan of orders
   +- *(1) LocalTableScan [...]
```

**After (filter before join — predicate pushdown):**
```python
# Apply the filter BEFORE the join — reduces data volume early
fast = orders_df.filter(col("order_date") >= "2024-01-18") \
    .join(broadcast(products_df), on="product_id")
fast.explain()
```

```
== Physical Plan ==
*(2) BroadcastHashJoin [product_id], [product_id], Inner
:- *(2) Filter (order_date >= 2024-01-18)         <-- Filter BEFORE join
:  +- *(2) LocalTableScan [...]                   <-- Fewer rows to join
+- BroadcastExchange HashedRelationBroadcastMode
   +- *(1) LocalTableScan [...]
```

**Note:** For Parquet/Delta tables with partitioned columns, Spark performs **partition pruning** — it skips entire files that do not match the filter. This only works if the filter column is the partition column.

---

## Adaptive Query Execution (AQE) and Key Configurations

```python
# Enable AQE (default in Spark 3.2+)
spark.conf.set("spark.sql.adaptive.enabled", "true")

# AQE features:
# 1. Coalesce shuffle partitions — merges small partitions after shuffle
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")

# 2. Convert SortMergeJoin to BroadcastHashJoin at runtime
#    If one side of a join turns out to be small after filtering,
#    AQE converts to broadcast automatically
spark.conf.set("spark.sql.adaptive.localShuffleReader.enabled", "true")

# 3. Skew join optimization — splits skewed partitions
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")

# Check current plan with AQE
result_aqe = orders_df.join(products_df, on="product_id") \
    .groupBy("category") \
    .agg(spark_sum("amount").alias("total_revenue"))

result_aqe.explain("formatted")
```

### Other Critical Optimizations

```python
# Partition Pruning — for partitioned Parquet/Delta tables
# Only reads files in matching partitions
spark.read.parquet("/data/orders") \
    .filter(col("order_date") >= "2024-01-18")  # Skips partitions before Jan 18

# Predicate Pushdown — push filters into the data source scan
# Works automatically for Parquet, ORC, Delta, JDBC
# Verify by checking the plan: filter should appear inside Scan node
spark.read.parquet("/data/orders") \
    .filter(col("amount") > 100) \
    .explain()
# Look for: PushedFilters: [IsNotNull(amount), GreaterThan(amount, 100)]

# Column Pruning — only read needed columns
# Spark automatically prunes columns in the optimized plan
orders_df.select("product_id", "amount") \
    .join(broadcast(products_df.select("product_id", "category")),
          on="product_id") \
    .explain()
# Look for: ReadSchema shows only selected columns, not all columns
```

---

## Summary: Reading an Execution Plan Checklist

```
Step 1: Run df.explain(True) or df.explain("formatted")
Step 2: Read the Physical Plan bottom-up
Step 3: Look for these patterns:

 GOOD signs:
  ✓ BroadcastHashJoin         → small table broadcast, no shuffle
  ✓ WholeStageCodegen (*)     → compiled to optimized bytecode
  ✓ PushedFilters             → filters pushed to data source
  ✓ PartitionFilters          → partition pruning active
  ✓ Coalesce                  → partition reduction without shuffle

 BAD signs:
  ✗ SortMergeJoin + Exchange  → two full shuffles (check if broadcast is possible)
  ✗ Exchange (multiple)       → excessive shuffles
  ✗ CartesianProduct          → cross join (usually a mistake)
  ✗ BroadcastNestedLoopJoin   → fallback join strategy (very slow)
  ✗ No PushedFilters          → full table scan despite having filters
```

---

## Key Interview Talking Points

1. **"Walk me through this EXPLAIN output."** "I read the physical plan bottom-up. I look for Exchange nodes which represent shuffles — the most expensive operations. I check the join strategy: BroadcastHashJoin is ideal for small-to-large joins, SortMergeJoin is needed for large-to-large. I verify that filters appear as PushedFilters inside Scan nodes for predicate pushdown. The asterisk `*(N)` indicates whole-stage code generation, which means Spark compiled multiple operators into a single optimized Java function."

2. **"How do you debug a slow Spark job?"** "First, I check the Spark UI Stages tab for stragglers — one task taking much longer than others indicates data skew. I look at shuffle read/write metrics — high shuffle volume means too much data is moving across the network. I check for spill to disk, which means partitions are too large for executor memory. Then I run `explain(True)` to see if the optimizer chose an efficient plan: broadcast joins where possible, filter pushdown, and column pruning."

3. **"What does Exchange mean in the plan?"** "Exchange is Spark's shuffle operator. It redistributes data across partitions, usually by hashing a key (`hashpartitioning`) or round-robin. Each Exchange creates a stage boundary — upstream tasks write shuffle files to local disk, downstream tasks pull them over the network. Shuffles are expensive because they involve serialization, disk I/O, and network transfer. The goal is to minimize the number of Exchange nodes and the volume of data shuffled."

4. **"What is the difference between explain(True) and explain('formatted')?"** "`explain(True)` shows all four plan levels: parsed, analyzed, optimized logical, and physical. `explain('formatted')` shows only the physical plan but with numbered operators and detailed input/output schemas for each node, making it easier to trace data flow."

5. **"How does AQE help?"** "Adaptive Query Execution re-optimizes the plan at runtime based on actual data statistics collected after each shuffle. It can convert SortMergeJoin to BroadcastHashJoin if one side turns out to be small, coalesce many small shuffle partitions into fewer larger ones, and split skewed partitions into multiple tasks."

6. **"What is whole-stage code generation?"** "The asterisk `*` in the plan indicates that Spark used whole-stage codegen to fuse multiple physical operators into a single Java function. Instead of calling virtual methods for each row through each operator, Spark generates a tight loop that processes rows through all fused operators at once. This dramatically improves CPU efficiency by reducing virtual dispatch overhead and enabling CPU cache optimization."
