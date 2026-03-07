# PySpark Implementation: Broadcast Join Optimization

## Problem Statement

Given a large **orders** table and a small **products** lookup table, demonstrate how to use **broadcast joins** to avoid expensive shuffle operations. Explain when Spark automatically broadcasts, how to force a broadcast, and the performance implications. This is a core performance optimization question in data engineering interviews.

### Sample Data

**Orders (large fact table):**
```
order_id  product_id  quantity  customer_id
O001      P001        2         C100
O002      P003        1         C101
O003      P001        5         C102
O004      P002        3         C100
O005      P004        1         C103
O006      P001        4         C104
O007      P003        2         C105
O008      P005        6         C101
```

**Products (small dimension table):**
```
product_id  product_name     price
P001        Laptop           999.99
P002        Mouse            29.99
P003        Keyboard         79.99
P004        Monitor          349.99
P005        Headphones       149.99
```

### Expected Output

| order_id | product_id | quantity | product_name | total_price |
|----------|-----------|----------|--------------|-------------|
| O001     | P001      | 2        | Laptop       | 1999.98     |
| O002     | P003      | 1        | Keyboard     | 79.99       |
| O003     | P001      | 5        | Laptop       | 4999.95     |
| O004     | P002      | 3        | Mouse        | 89.97       |
| O005     | P004      | 1        | Monitor      | 349.99      |
| O006     | P001      | 4        | Laptop       | 3999.96     |
| O007     | P003      | 2        | Keyboard     | 159.98      |
| O008     | P005      | 6        | Headphones   | 899.94      |

---

## Method 1: Explicit Broadcast Join

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, broadcast, round as spark_round

# Initialize Spark session
spark = SparkSession.builder.appName("BroadcastJoinOptimization").getOrCreate()

# Orders (large table)
orders_data = [
    ("O001", "P001", 2, "C100"), ("O002", "P003", 1, "C101"),
    ("O003", "P001", 5, "C102"), ("O004", "P002", 3, "C100"),
    ("O005", "P004", 1, "C103"), ("O006", "P001", 4, "C104"),
    ("O007", "P003", 2, "C105"), ("O008", "P005", 6, "C101")
]
orders_df = spark.createDataFrame(orders_data, ["order_id", "product_id", "quantity", "customer_id"])

# Products (small lookup table)
products_data = [
    ("P001", "Laptop", 999.99), ("P002", "Mouse", 29.99),
    ("P003", "Keyboard", 79.99), ("P004", "Monitor", 349.99),
    ("P005", "Headphones", 149.99)
]
products_df = spark.createDataFrame(products_data, ["product_id", "product_name", "price"])

# Step 1: Explicit broadcast join — force the small table to be broadcast
result = orders_df.join(
    broadcast(products_df),  # Broadcast hint
    on="product_id",
    how="inner"
)

# Step 2: Calculate total price
result = result.withColumn(
    "total_price",
    spark_round(col("quantity") * col("price"), 2)
).select("order_id", "product_id", "quantity", "product_name", "total_price")

result.orderBy("order_id").show(truncate=False)
```

### Step-by-Step Explanation

#### Step 1: broadcast(products_df)
- **What happens:** The entire `products_df` is collected to the driver and then sent to every executor node. Each executor holds a complete copy in memory.
- **Why it matters:** The large `orders_df` does NOT need to be shuffled. Each executor joins its local partition of orders against the local copy of products.

#### Step 2: Output

| order_id | product_id | quantity | product_name | total_price |
|----------|-----------|----------|--------------|-------------|
| O001     | P001      | 2        | Laptop       | 1999.98     |
| O002     | P003      | 1        | Keyboard     | 79.99       |
| O003     | P001      | 5        | Laptop       | 4999.95     |
| O004     | P002      | 3        | Mouse        | 89.97       |
| O005     | P004      | 1        | Monitor      | 349.99      |
| O006     | P001      | 4        | Laptop       | 3999.96     |
| O007     | P003      | 2        | Keyboard     | 159.98      |
| O008     | P005      | 6        | Headphones   | 899.94      |

---

## How Broadcast Join Works Internally

```
Regular Sort-Merge Join (without broadcast):
  Orders partitions:  [P1] [P2] [P3] [P4]
                        ↓    ↓    ↓    ↓
                      SHUFFLE (expensive network I/O)
                        ↓    ↓    ↓    ↓
  Products partitions: [P1] [P2] [P3] [P4]
                        ↓    ↓    ↓    ↓
                      JOIN   JOIN JOIN JOIN

Broadcast Join (with broadcast):
  Driver collects products_df → sends to all executors

  Executor 1: Orders[P1] + full products → JOIN locally
  Executor 2: Orders[P2] + full products → JOIN locally
  Executor 3: Orders[P3] + full products → JOIN locally
  Executor 4: Orders[P4] + full products → JOIN locally

  No shuffle of the large table!
```

---

## Method 2: Auto-Broadcast via Configuration

```python
# Spark auto-broadcasts tables smaller than this threshold
# Default is 10MB (10485760 bytes)
print(spark.conf.get("spark.sql.autoBroadcastJoinThreshold"))

# Increase threshold to auto-broadcast larger tables
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "50m")  # 50MB

# Now Spark will automatically broadcast any table < 50MB
result_auto = orders_df.join(products_df, on="product_id", how="inner")
result_auto.explain()  # Check the plan — should show BroadcastHashJoin
```

### Checking the Query Plan

```python
# Use explain() to verify broadcast is being used
result.explain(True)

# Look for "BroadcastHashJoin" in the physical plan
# If you see "SortMergeJoin" instead, the broadcast is NOT being used
```

**Example explain output with broadcast:**
```
== Physical Plan ==
*(2) Project [order_id, product_id, quantity, product_name, total_price]
+- *(2) BroadcastHashJoin [product_id], [product_id], Inner
   :- *(2) Scan [order_id, product_id, quantity, customer_id]
   +- BroadcastExchange HashedRelationBroadcastMode
      +- *(1) Scan [product_id, product_name, price]
```

---

## Method 3: Broadcast Join with Left Join (Handling Missing Products)

```python
# Left join to keep all orders even if product is missing
orders_with_unknown = orders_df.union(
    spark.createDataFrame([("O009", "P999", 1, "C106")],
                          ["order_id", "product_id", "quantity", "customer_id"])
)

result_left = orders_with_unknown.join(
    broadcast(products_df),
    on="product_id",
    how="left"
).withColumn(
    "total_price",
    spark_round(col("quantity") * col("price"), 2)
)

result_left.orderBy("order_id").show(truncate=False)
```

**Output:**

| order_id | product_id | quantity | product_name | price  | total_price |
|----------|-----------|----------|--------------|--------|-------------|
| O001     | P001      | 2        | Laptop       | 999.99 | 1999.98     |
| ...      | ...       | ...      | ...          | ...    | ...         |
| O009     | P999      | 1        | null         | null   | null        |

---

## Method 4: Disabling Broadcast (Force Sort-Merge Join)

```python
# Sometimes you want to PREVENT broadcast (e.g., during testing)
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "-1")  # Disable auto-broadcast

# Or use a SQL hint to prevent broadcast on a specific join
orders_df.createOrReplaceTempView("orders")
products_df.createOrReplaceTempView("products")

# Force sort-merge join even for small tables
spark.sql("""
    SELECT /*+ MERGE(p) */ o.order_id, o.product_id, o.quantity, p.product_name
    FROM orders o
    JOIN products p ON o.product_id = p.product_id
""").explain()
```

---

## Method 5: Broadcast with Multiple Small Tables

```python
# Category lookup
categories_data = [
    ("P001", "Electronics"), ("P002", "Accessories"),
    ("P003", "Accessories"), ("P004", "Electronics"),
    ("P005", "Audio")
]
categories_df = spark.createDataFrame(categories_data, ["product_id", "category"])

# Broadcast multiple small tables in a chain
result_enriched = orders_df \
    .join(broadcast(products_df), on="product_id", how="inner") \
    .join(broadcast(categories_df), on="product_id", how="inner") \
    .select(
        "order_id", "product_id", "quantity",
        "product_name", "category",
        spark_round(col("quantity") * col("price"), 2).alias("total_price")
    )

result_enriched.orderBy("order_id").show(truncate=False)
```

**Output:**

| order_id | product_id | quantity | product_name | category    | total_price |
|----------|-----------|----------|--------------|-------------|-------------|
| O001     | P001      | 2        | Laptop       | Electronics | 1999.98     |
| O002     | P003      | 1        | Keyboard     | Accessories | 79.99       |
| O003     | P001      | 5        | Laptop       | Electronics | 4999.95     |
| O004     | P002      | 3        | Mouse        | Accessories | 89.97       |
| O005     | P004      | 1        | Monitor      | Electronics | 349.99      |
| O006     | P001      | 4        | Laptop       | Electronics | 3999.96     |
| O007     | P003      | 2        | Keyboard     | Accessories | 159.98      |
| O008     | P005      | 6        | Headphones   | Audio       | 899.94      |

---

## When to Use (and NOT Use) Broadcast Joins

| Scenario | Broadcast? | Reason |
|----------|-----------|--------|
| Small lookup + large fact table | Yes | Avoids shuffling the large table |
| Both tables are large (GB+) | No | Broadcasting GB of data causes OOM |
| Small table < 10MB | Auto | Spark broadcasts by default |
| Small table 10MB–2GB | Manual | Use `broadcast()` hint explicitly |
| Small table > 2GB | No | Exceeds driver/executor memory |
| Left join, small on right | Yes | Broadcast the right (small) side |
| Left join, small on left | Careful | Broadcast left loses unmatched rows in some engines |

---

## Key Interview Talking Points

1. **What is a broadcast join?** "The small table is collected to the driver, then broadcast to every executor. Each executor joins its local partitions of the large table against the full copy of the small table — no shuffle needed for the large table."

2. **Auto-broadcast threshold:** Default `spark.sql.autoBroadcastJoinThreshold` is 10MB. Spark checks the table size statistics and auto-broadcasts if below threshold. Set to `-1` to disable.

3. **OOM risk:** Broadcasting a table that is too large will cause OutOfMemoryError on the driver (during collect) or executors (during deserialization). Always verify the size of the table being broadcast.

4. **Statistics accuracy:** Auto-broadcast relies on Spark's size estimates. After filtering, Spark may overestimate table size and skip broadcast. Use `ANALYZE TABLE` or explicit `broadcast()` hint to fix this.

5. **Broadcast vs. shuffle trade-off:** Broadcasting a 500MB table to 100 executors = 50GB total network traffic. A shuffle of a 10GB table with 100 partitions = 10GB. For medium-sized tables, do the math.

6. **Real-world pattern:** Star schema joins — fact table (billions of rows) joined with dimension tables (thousands to millions of rows). Broadcast all dimension tables for maximum performance.
