# PySpark Implementation: Broadcast Join Optimization

## Problem Statement

Joins are the most expensive operations in distributed computing because they require shuffling data across the network. A **broadcast join** (also called a map-side join) avoids the shuffle by sending the smaller DataFrame to every executor node. Interviewers test whether you know when to use broadcast joins, how to force them, how to verify they are being used, and what the limitations are.

### Sample Data

```python
# Large table: transactions (millions of rows in production)
transactions_data = [
    (1, "TXN001", 100, "2024-01-01"),
    (2, "TXN002", 200, "2024-01-01"),
    (1, "TXN003", 150, "2024-01-02"),
    (3, "TXN004", 300, "2024-01-02"),
    (2, "TXN005", 250, "2024-01-03"),
    (4, "TXN006", 175, "2024-01-03"),
    (1, "TXN007", 125, "2024-01-04"),
    (5, "TXN008", 400, "2024-01-04"),
]
txn_columns = ["customer_id", "txn_id", "amount", "txn_date"]

# Small table: customers (thousands of rows -- perfect for broadcasting)
customers_data = [
    (1, "Alice", "Gold"),
    (2, "Bob", "Silver"),
    (3, "Charlie", "Bronze"),
    (4, "Diana", "Gold"),
    (5, "Eve", "Silver"),
]
cust_columns = ["customer_id", "name", "tier"]
```

### Expected Output

The join result is the same regardless of whether broadcast is used. The difference is in **performance** -- broadcast avoids shuffling the large table.

---

## How Broadcast Joins Work

```
Without broadcast (Sort-Merge Join / Shuffle Hash Join):
  - Both tables are shuffled by the join key across all executors
  - Each partition of table A is matched with the corresponding partition of table B
  - Expensive: O(n) network transfer for BOTH tables

With broadcast (Broadcast Hash Join):
  - Small table is collected to the driver, then broadcast to ALL executors
  - Each executor has the full small table in memory
  - Large table is NOT shuffled at all
  - Cheap: O(small_table) network transfer only
```

---

## Method 1: Explicit broadcast() Hint

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder.appName("BroadcastJoin").getOrCreate()

transactions_data = [
    (1, "TXN001", 100, "2024-01-01"),
    (2, "TXN002", 200, "2024-01-01"),
    (1, "TXN003", 150, "2024-01-02"),
    (3, "TXN004", 300, "2024-01-02"),
    (2, "TXN005", 250, "2024-01-03"),
    (4, "TXN006", 175, "2024-01-03"),
    (1, "TXN007", 125, "2024-01-04"),
    (5, "TXN008", 400, "2024-01-04"),
]
txn_columns = ["customer_id", "txn_id", "amount", "txn_date"]
transactions = spark.createDataFrame(transactions_data, txn_columns)

customers_data = [
    (1, "Alice", "Gold"),
    (2, "Bob", "Silver"),
    (3, "Charlie", "Bronze"),
    (4, "Diana", "Gold"),
    (5, "Eve", "Silver"),
]
cust_columns = ["customer_id", "name", "tier"]
customers = spark.createDataFrame(customers_data, cust_columns)

# Explicit broadcast hint on the smaller table
result = transactions.join(
    F.broadcast(customers),
    on="customer_id",
    how="inner"
)
result.show()
```

**The `F.broadcast()` function wraps the smaller DataFrame and tells the Catalyst optimizer to use a broadcast hash join.**

---

## Method 2: Auto-Broadcast Threshold Configuration

Spark automatically broadcasts tables smaller than a configurable threshold.

```python
# Check the current auto-broadcast threshold (default: 10MB)
print(spark.conf.get("spark.sql.autoBroadcastJoinThreshold"))
# Output: 10485760 (10 MB in bytes)

# Increase the threshold to 50MB
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", 50 * 1024 * 1024)

# Decrease to 1MB (more conservative)
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", 1 * 1024 * 1024)

# Disable auto-broadcast entirely (force sort-merge join)
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", -1)

# Re-enable with default
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", 10 * 1024 * 1024)
```

**When auto-broadcast is enabled:** Spark estimates the size of each table. If one side is below the threshold, it automatically broadcasts it -- no `F.broadcast()` hint needed.

**When to disable it:** If Spark's size estimates are wrong (common with complex subqueries or UDFs), it might try to broadcast a table that is actually too large, causing OOM errors.

---

## Method 3: Verifying Broadcast Join via explain()

```python
# Without broadcast
print("=== Without broadcast ===")
transactions.join(customers, on="customer_id").explain()

# With broadcast
print("\n=== With broadcast ===")
transactions.join(F.broadcast(customers), on="customer_id").explain()
```

**What to look for in the plan:**

```
Without broadcast:
== Physical Plan ==
*(5) SortMergeJoin [customer_id#0], [customer_id#10], Inner
    *(2) Sort [customer_id#0 ASC], false, 0
        Exchange hashpartitioning(customer_id#0, 200)    <-- SHUFFLE!
    *(4) Sort [customer_id#10 ASC], false, 0
        Exchange hashpartitioning(customer_id#10, 200)   <-- SHUFFLE!

With broadcast:
== Physical Plan ==
*(2) BroadcastHashJoin [customer_id#0], [customer_id#10], Inner
    BroadcastExchange HashedRelationBroadcastMode       <-- BROADCAST (no shuffle!)
```

**Key indicators:**
- `BroadcastHashJoin` = broadcast join is being used (good)
- `SortMergeJoin` + `Exchange hashpartitioning` = shuffle join (expensive)
- `BroadcastExchange` = the table is being broadcast

---

## Method 4: Extended explain() for More Detail

```python
# explain(True) or explain("extended") shows all plan stages
transactions.join(F.broadcast(customers), on="customer_id").explain(True)

# explain("formatted") for cleaner output (Spark 3.0+)
transactions.join(F.broadcast(customers), on="customer_id").explain("formatted")

# explain("cost") shows estimated costs
transactions.join(F.broadcast(customers), on="customer_id").explain("cost")
```

---

## Method 5: SQL Broadcast Hint

```python
transactions.createOrReplaceTempView("transactions")
customers.createOrReplaceTempView("customers")

# SQL broadcast hint syntax
result_sql = spark.sql("""
    SELECT /*+ BROADCAST(c) */ t.*, c.name, c.tier
    FROM transactions t
    JOIN customers c ON t.customer_id = c.customer_id
""")
result_sql.explain()

# Alternative hint names (all equivalent)
# /*+ BROADCAST(c) */
# /*+ BROADCASTJOIN(c) */
# /*+ MAPJOIN(c) */
```

---

## Method 6: Broadcast with Different Join Types

```python
# Broadcast works with all join types
# Inner join
transactions.join(F.broadcast(customers), on="customer_id", how="inner").explain()

# Left join (broadcast the right/smaller side)
transactions.join(F.broadcast(customers), on="customer_id", how="left").explain()

# Right join (broadcast the left/smaller side)
F.broadcast(customers).join(transactions, on="customer_id", how="right").explain()

# Left anti join (broadcast the right side)
transactions.join(F.broadcast(customers), on="customer_id", how="left_anti").explain()

# IMPORTANT: For left join, broadcast the RIGHT table
# For right join, broadcast the LEFT table
# Broadcast the side that you are looking up, not the side you are keeping
```

**Limitation:** You cannot use broadcast with a **full outer join** in certain Spark versions. Spark may silently fall back to sort-merge join.

---

## Performance Comparison Example

```python
import time

# Create larger DataFrames for meaningful comparison
large_data = [(i % 1000, f"TXN{i}", i * 10) for i in range(100000)]
large_df = spark.createDataFrame(large_data, ["key", "txn_id", "amount"])

small_data = [(i, f"Customer_{i}", f"Tier_{i % 5}") for i in range(1000)]
small_df = spark.createDataFrame(small_data, ["key", "name", "tier"])

# Disable auto-broadcast to force sort-merge join
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", -1)

# Sort-Merge Join (no broadcast)
start = time.time()
result_smj = large_df.join(small_df, on="key").count()
time_smj = time.time() - start
print(f"Sort-Merge Join: {time_smj:.2f}s, rows: {result_smj}")

# Re-enable and force broadcast
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", 10 * 1024 * 1024)

start = time.time()
result_bhj = large_df.join(F.broadcast(small_df), on="key").count()
time_bhj = time.time() - start
print(f"Broadcast Hash Join: {time_bhj:.2f}s, rows: {result_bhj}")

# Verify the join types used
print("\n=== Sort-Merge Join Plan ===")
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", -1)
large_df.join(small_df, on="key").explain()

print("\n=== Broadcast Hash Join Plan ===")
large_df.join(F.broadcast(small_df), on="key").explain()

# Reset
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", 10 * 1024 * 1024)
```

---

## When to Use Broadcast Joins

| Scenario | Use Broadcast? | Why |
|----------|---------------|-----|
| Small dimension table (< 10MB) joined with large fact table | Yes | Classic use case. Avoids shuffling the fact table. |
| Two large tables | No | Broadcasting a large table causes OOM on executors. |
| Lookup/reference data (country codes, config) | Yes | These are typically tiny and static. |
| Skewed join keys | Maybe | Broadcast can avoid skew issues since there is no shuffle. |
| Table size unknown at compile time | Be careful | Auto-broadcast threshold may misestimate. Use explicit hint. |
| Streaming joins | Yes (for static side) | Broadcast the static reference table in structured streaming. |

---

## Limitations and Pitfalls

```python
# 1. Memory limitation: broadcast table must fit in driver + executor memory
# If the table is too large, you get:
# SparkException: Cannot broadcast the table that is larger than 8GB

# 2. Check broadcast size limit
print(spark.conf.get("spark.sql.autoBroadcastJoinThreshold"))  # default 10MB

# 3. Driver memory matters: the broadcast table is first collected to the driver
# then distributed to executors. If driver memory is small, this fails.

# 4. Broadcast variables are immutable. If the small table changes frequently,
# you pay the broadcast cost each time.

# 5. Size estimation can be wrong:
# After filters/transformations, Spark may not know the true size.
# Use explicit broadcast() hint to override bad estimates.

# Example: Spark thinks this is big, but after filtering it's tiny
filtered_customers = customers.filter(F.col("tier") == "Gold")
# Spark may not broadcast this automatically because it estimates based
# on the original table size. Force it:
transactions.join(F.broadcast(filtered_customers), on="customer_id").explain()
```

---

## Broadcast Variables (Lower-Level API)

For non-join use cases, you can broadcast arbitrary data.

```python
# Broadcast a Python dictionary for lookups
tier_discounts = {"Gold": 0.20, "Silver": 0.10, "Bronze": 0.05}
bc_discounts = spark.sparkContext.broadcast(tier_discounts)

# Use in a UDF
from pyspark.sql.types import DoubleType

@F.udf(DoubleType())
def get_discount(tier):
    return bc_discounts.value.get(tier, 0.0)

result = customers.withColumn("discount", get_discount(F.col("tier")))
result.show()

# Clean up when done
bc_discounts.unpersist()
```

**Note:** Prefer `F.broadcast()` in joins over broadcast variables with UDFs. The join approach is optimized by Catalyst; the UDF approach is not.

---

## Key Takeaways

- **Broadcast joins eliminate shuffles** by sending the small table to all executors. This is a major performance win.
- **Default auto-broadcast threshold is 10MB.** Tables below this size are automatically broadcast.
- **Use `F.broadcast(df)`** to explicitly force a broadcast join when Spark's size estimate is wrong or you want to be explicit.
- **Verify with `.explain()`**: Look for `BroadcastHashJoin` and `BroadcastExchange` in the physical plan.
- **Broadcast the smaller side.** Broadcasting a large table causes OOM errors on every executor.
- **Driver memory is a bottleneck.** The broadcast table is collected to the driver first, so driver memory must be sufficient.
- **Cannot broadcast tables > 8GB** (hard Spark limit).
- Setting the threshold to `-1` disables auto-broadcast entirely.

## Interview Tips

- When the interviewer asks "How would you optimize this join?", the first thing to consider is: "Is one side small enough to broadcast?"
- Know the default threshold (10MB) and how to change it. This is a very common follow-up question.
- Always mention checking the plan with `explain()`. Interviewers want to see that you verify optimizations, not just hope they work.
- Explain the tradeoff: broadcast uses more memory on each executor but saves network I/O from the shuffle. For small tables, this is always a net win.
- If asked about skewed joins, mention that broadcast joins inherently avoid skew because there is no shuffle partitioning.
- Know both the DataFrame API (`F.broadcast()`) and the SQL hint (`/*+ BROADCAST(table) */`) syntax.
- Mention that in structured streaming, the static side of a stream-static join is always broadcast. This shows real-world knowledge.
