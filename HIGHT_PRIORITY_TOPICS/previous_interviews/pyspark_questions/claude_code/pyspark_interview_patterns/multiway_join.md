# PySpark Implementation: Multi-Way Join Optimization

## Problem Statement

When joining three or more tables in PySpark, naive implementations can cause excessive shuffles, data skew, and out-of-memory errors. Optimize multi-way joins by choosing the right join order, using broadcast hints for small tables, leveraging bucketing, and avoiding unnecessary shuffles. This is a common interview question at data-intensive companies (Uber, Netflix, LinkedIn) and tests your understanding of Spark's physical execution plan and distributed join strategies.

### Sample Data

**Orders (large table, ~millions of rows):**

| order_id | customer_id | product_id | store_id | order_date | amount |
|----------|-------------|------------|----------|------------|--------|
| 1        | C001        | P001       | S01      | 2024-01-15 | 100    |
| 2        | C002        | P002       | S02      | 2024-01-16 | 200    |
| 3        | C001        | P003       | S01      | 2024-01-17 | 150    |

**Customers (medium table, ~100K rows):**

| customer_id | name  | region  |
|-------------|-------|---------|
| C001        | Alice | US-East |
| C002        | Bob   | US-West |

**Products (small table, ~10K rows):**

| product_id | product_name | category    |
|------------|-------------|-------------|
| P001       | Laptop      | Electronics |
| P002       | Shirt       | Clothing    |
| P003       | Book        | Books       |

**Stores (tiny table, ~500 rows):**

| store_id | store_name | city     |
|----------|-----------|----------|
| S01      | Store A   | New York |
| S02      | Store B   | LA       |

### Expected Output

| order_id | name  | product_name | store_name | region  | amount |
|----------|-------|-------------|------------|---------|--------|
| 1        | Alice | Laptop      | Store A    | US-East | 100    |
| 2        | Bob   | Shirt       | Store B    | US-West | 200    |
| 3        | Alice | Book        | Store A    | US-East | 150    |

---

## Method 1: Naive vs. Optimized Join Order

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

# Initialize Spark
spark = SparkSession.builder \
    .appName("Multi-Way Join Optimization") \
    .master("local[*]") \
    .config("spark.sql.autoBroadcastJoinThreshold", "10m") \
    .getOrCreate()

# --- Sample Data ---
orders_data = [
    (1, "C001", "P001", "S01", "2024-01-15", 100),
    (2, "C002", "P002", "S02", "2024-01-16", 200),
    (3, "C001", "P003", "S01", "2024-01-17", 150),
    (4, "C003", "P001", "S03", "2024-01-18", 300),
    (5, "C002", "P002", "S01", "2024-01-19", 250),
]

customers_data = [
    ("C001", "Alice", "US-East"),
    ("C002", "Bob", "US-West"),
    ("C003", "Carol", "EU-West"),
]

products_data = [
    ("P001", "Laptop", "Electronics"),
    ("P002", "Shirt", "Clothing"),
    ("P003", "Book", "Books"),
]

stores_data = [
    ("S01", "Store A", "New York"),
    ("S02", "Store B", "LA"),
    ("S03", "Store C", "London"),
]

orders_df = spark.createDataFrame(orders_data, ["order_id", "customer_id", "product_id", "store_id", "order_date", "amount"])
customers_df = spark.createDataFrame(customers_data, ["customer_id", "name", "region"])
products_df = spark.createDataFrame(products_data, ["product_id", "product_name", "category"])
stores_df = spark.createDataFrame(stores_data, ["store_id", "store_name", "city"])

# ========================================
# ANTI-PATTERN: Naive join (no optimization)
# ========================================
print("=== NAIVE JOIN (no hints) ===")
naive_result = orders_df \
    .join(customers_df, "customer_id") \
    .join(products_df, "product_id") \
    .join(stores_df, "store_id")

naive_result.explain()
naive_result.show()

# ========================================
# OPTIMIZED: Broadcast small tables
# ========================================
print("=== OPTIMIZED: Broadcast small tables ===")
optimized_result = orders_df \
    .join(F.broadcast(stores_df), "store_id") \
    .join(F.broadcast(products_df), "product_id") \
    .join(customers_df, "customer_id")

optimized_result.explain()
optimized_result.show()

# Key insight: broadcast the smallest tables first to reduce
# the size of intermediate results before the shuffle join

spark.stop()
```

## Method 2: SQL with Join Hints

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("Multi-Way Join - SQL Hints") \
    .master("local[*]") \
    .getOrCreate()

# --- Data ---
orders_data = [
    (1, "C001", "P001", "S01", 100),
    (2, "C002", "P002", "S02", 200),
    (3, "C001", "P003", "S01", 150),
    (4, "C003", "P001", "S03", 300),
    (5, "C002", "P002", "S01", 250),
]

customers_data = [("C001", "Alice", "US-East"), ("C002", "Bob", "US-West"), ("C003", "Carol", "EU-West")]
products_data = [("P001", "Laptop", "Electronics"), ("P002", "Shirt", "Clothing"), ("P003", "Book", "Books")]
stores_data = [("S01", "Store A", "New York"), ("S02", "Store B", "LA"), ("S03", "Store C", "London")]

spark.createDataFrame(orders_data, ["order_id", "customer_id", "product_id", "store_id", "amount"]).createOrReplaceTempView("orders")
spark.createDataFrame(customers_data, ["customer_id", "name", "region"]).createOrReplaceTempView("customers")
spark.createDataFrame(products_data, ["product_id", "product_name", "category"]).createOrReplaceTempView("products")
spark.createDataFrame(stores_data, ["store_id", "store_name", "city"]).createOrReplaceTempView("stores")

# --- Method A: BROADCAST hint in SQL ---
print("=== SQL BROADCAST Hint ===")
broadcast_sql = spark.sql("""
    SELECT /*+ BROADCAST(p), BROADCAST(s) */
        o.order_id,
        c.name,
        p.product_name,
        s.store_name,
        c.region,
        o.amount
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN products p ON o.product_id = p.product_id
    JOIN stores s ON o.store_id = s.store_id
""")
broadcast_sql.explain()
broadcast_sql.show()

# --- Method B: SHUFFLE_HASH hint for medium tables ---
print("=== SQL SHUFFLE_HASH Hint ===")
shuffle_hash_sql = spark.sql("""
    SELECT /*+ SHUFFLE_HASH(c) */
        o.order_id,
        c.name,
        o.amount
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
""")
shuffle_hash_sql.explain()
shuffle_hash_sql.show()

# --- Method C: MERGE hint (Sort-Merge Join) for large-large joins ---
print("=== SQL MERGE Hint ===")
merge_sql = spark.sql("""
    SELECT /*+ MERGE(o, c) */
        o.order_id,
        c.name,
        o.amount
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
""")
merge_sql.explain()
merge_sql.show()

spark.stop()
```

## Method 3: Advanced Optimization Techniques

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("Multi-Way Join - Advanced") \
    .master("local[*]") \
    .config("spark.sql.adaptive.enabled", "true") \
    .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
    .config("spark.sql.adaptive.skewJoin.enabled", "true") \
    .getOrCreate()

# --- Larger sample data ---
orders_data = [(i, f"C{(i % 5):03d}", f"P{(i % 3):03d}", f"S{(i % 2):02d}", i * 10)
               for i in range(1, 21)]
customers_data = [(f"C{i:03d}", f"Customer_{i}", f"Region_{i % 3}") for i in range(5)]
products_data = [(f"P{i:03d}", f"Product_{i}", f"Cat_{i % 2}") for i in range(3)]
stores_data = [(f"S{i:02d}", f"Store_{i}", f"City_{i}") for i in range(2)]

orders_df = spark.createDataFrame(orders_data, ["order_id", "customer_id", "product_id", "store_id", "amount"])
customers_df = spark.createDataFrame(customers_data, ["customer_id", "name", "region"])
products_df = spark.createDataFrame(products_data, ["product_id", "product_name", "category"])
stores_df = spark.createDataFrame(stores_data, ["store_id", "store_name", "city"])

# ========================================
# TECHNIQUE 1: Filter early to reduce join input
# ========================================
print("=== Filter Before Join ===")
# Bad: join everything then filter
bad_plan = orders_df \
    .join(customers_df, "customer_id") \
    .join(products_df, "product_id") \
    .filter(F.col("region") == "Region_0") \
    .filter(F.col("category") == "Cat_0")

# Good: filter dimension tables before joining
good_plan = orders_df \
    .join(customers_df.filter(F.col("region") == "Region_0"), "customer_id") \
    .join(products_df.filter(F.col("category") == "Cat_0"), "product_id")

print("Bad plan (filter after join):")
bad_plan.explain()

print("Good plan (filter before join):")
good_plan.explain()

# ========================================
# TECHNIQUE 2: Reduce columns before join
# ========================================
print("=== Select Only Needed Columns ===")
# Only select columns needed for the final output
slim_result = orders_df.select("order_id", "customer_id", "product_id", "amount") \
    .join(F.broadcast(customers_df.select("customer_id", "name")), "customer_id") \
    .join(F.broadcast(products_df.select("product_id", "product_name")), "product_id")

slim_result.explain()
slim_result.show()

# ========================================
# TECHNIQUE 3: Cache intermediate results for reuse
# ========================================
print("=== Cache Intermediate Results ===")
# If the orders-customers join is used in multiple downstream queries, cache it
orders_with_customers = orders_df.join(
    F.broadcast(customers_df), "customer_id"
).cache()

# First use
result_a = orders_with_customers.join(F.broadcast(products_df), "product_id")
print("Result A (with products):")
result_a.show(5)

# Second use of same intermediate result
result_b = orders_with_customers.join(F.broadcast(stores_df), "store_id")
print("Result B (with stores):")
result_b.show(5)

# Unpersist when done
orders_with_customers.unpersist()

# ========================================
# TECHNIQUE 4: Bucketing for repeated joins
# ========================================
print("=== Bucketing Strategy (conceptual) ===")
# In production, pre-bucket the large table by join key:
#
# orders_df.write \
#     .bucketBy(100, "customer_id") \
#     .sortBy("customer_id") \
#     .saveAsTable("orders_bucketed")
#
# This eliminates the shuffle during subsequent joins on customer_id.
# Both tables must be bucketed by the same key with compatible bucket counts.

print("Bucketing eliminates shuffle for repeated joins on the same key.")
print("Use .bucketBy(n, 'key').sortBy('key').saveAsTable('table') to bucket.")

spark.stop()
```

## Key Concepts

- **Broadcast Join (Map-Side Join)**: Small table is sent to all executors. No shuffle needed. Best when one side fits in memory (default threshold: 10MB).
- **Sort-Merge Join**: Both sides shuffled and sorted by join key. Default for large-large joins. Requires shuffle but handles any data size.
- **Shuffle Hash Join**: One side is hash-partitioned and the other builds a hash table. Good when one side is moderately small.
- **Join Order**: Start with the largest table and join the smallest dimension first. Each broadcast join reduces intermediate size before the next join.
- **AQE (Adaptive Query Execution)**: Spark 3.x feature that dynamically optimizes join strategies at runtime based on actual data sizes.
- **Bucketing**: Pre-partitioning tables by join key eliminates shuffle. Critical for tables joined repeatedly.

## Interview Tips

- Always mention checking the **physical plan** with `.explain(True)` to verify which join strategy Spark chose.
- Know the three join strategies and when each is used: broadcast (small-large), sort-merge (large-large), shuffle-hash (medium-large).
- Discuss **AQE** (Spark 3.0+) as the modern solution: it converts sort-merge to broadcast at runtime if one side turns out to be small after filtering.
- For **data skew**, mention salted joins (add random prefix to skewed keys) or enabling `spark.sql.adaptive.skewJoin.enabled`.
- The order you write joins in code does NOT always determine execution order -- the Catalyst optimizer reorders. But hints override the optimizer.
- In Databricks interviews, mention **Delta table statistics** and **Z-ordering** as additional optimization layers.
