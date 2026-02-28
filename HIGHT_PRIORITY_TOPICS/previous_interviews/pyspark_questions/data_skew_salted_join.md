# PySpark Implementation: Handling Data Skew with Salted Joins

## Problem Statement 

Given two DataFrames where one has a **highly skewed key** (one key value dominates the data), perform an efficient join. Without intervention, Spark sends all records with the same key to the same partition, causing a **data skew** problem — one task takes significantly longer than others, bottlenecking the entire job.

This question tests your understanding of Spark internals, shuffle behavior, and performance optimization — critical for senior data engineering roles.

### Sample Data

**Transactions table (skewed):** Most transactions belong to customer "C001"

```
transaction_id  customer_id  amount
T001            C001         100
T002            C001         200
T003            C001         150
T004            C001         300
T005            C001         250
T006            C001         175
T007            C002         400
T008            C003         500
```

**Customers table (small lookup):**

```
customer_id  customer_name  city
C001         MegaCorp       New York
C002         SmallBiz       Chicago
C003         TinyInc        Boston
```

### The Problem

When joining on `customer_id`, all 6 records for "C001" go to one partition. With real data (millions of records for one customer), this creates a massive performance bottleneck.

---

## Method 1: Salted Join (The Key Technique)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, lit, concat, floor, rand, explode, array

# Initialize Spark session
spark = SparkSession.builder.appName("SaltedJoin").getOrCreate()

# Transactions (skewed - C001 dominates)
txn_data = [
    ("T001", "C001", 100), ("T002", "C001", 200),
    ("T003", "C001", 150), ("T004", "C001", 300),
    ("T005", "C001", 250), ("T006", "C001", 175),
    ("T007", "C002", 400), ("T008", "C003", 500)
]
txn_df = spark.createDataFrame(txn_data, ["transaction_id", "customer_id", "amount"])

# Customers (small dimension)
cust_data = [
    ("C001", "MegaCorp", "New York"),
    ("C002", "SmallBiz", "Chicago"),
    ("C003", "TinyInc", "Boston")
]
cust_df = spark.createDataFrame(cust_data, ["customer_id", "customer_name", "city"])

# Number of salt buckets
NUM_SALTS = 3

# Step 1: Add random salt to the large (skewed) table
txn_salted = txn_df.withColumn(
    "salt",
    floor(rand() * NUM_SALTS).cast("int")
).withColumn(
    "salted_key",
    concat(col("customer_id"), lit("_"), col("salt"))
)

# Step 2: Replicate the small table with all possible salt values
salt_values = spark.range(NUM_SALTS).withColumnRenamed("id", "salt")

cust_replicated = cust_df.crossJoin(salt_values).withColumn(
    "salted_key",
    concat(col("customer_id"), lit("_"), col("salt"))
)

# Step 3: Join on the salted key
result = txn_salted.join(
    cust_replicated,
    on="salted_key",
    how="inner"
).select(
    txn_salted["transaction_id"],
    txn_salted["customer_id"],
    txn_salted["amount"],
    cust_replicated["customer_name"],
    cust_replicated["city"]
)

result.orderBy("transaction_id").show()
```

---

## Step-by-Step Explanation with Intermediate DataFrames

### Step 1: Add Salt to Skewed Table

- **What happens:** Each transaction gets a random integer [0, NUM_SALTS-1] appended to its join key. This distributes records for "C001" across multiple partitions.
- **Output (txn_salted):**

  | transaction_id | customer_id | amount | salt | salted_key |
  |---------------|-------------|--------|------|------------|
  | T001          | C001        | 100    | 0    | C001_0     |
  | T002          | C001        | 200    | 2    | C001_2     |
  | T003          | C001        | 150    | 1    | C001_1     |
  | T004          | C001        | 300    | 0    | C001_0     |
  | T005          | C001        | 250    | 1    | C001_1     |
  | T006          | C001        | 175    | 2    | C001_2     |
  | T007          | C002        | 400    | 1    | C002_1     |
  | T008          | C003        | 500    | 0    | C003_0     |

  Now "C001" records are spread across C001_0, C001_1, and C001_2.

### Step 2: Replicate Small Table

- **What happens:** Each customer row is duplicated NUM_SALTS times, once for each salt value. This ensures every salted key in the large table has a match.
- **Output (cust_replicated):**

  | customer_id | customer_name | city     | salt | salted_key |
  |-------------|---------------|----------|------|------------|
  | C001        | MegaCorp      | New York | 0    | C001_0     |
  | C001        | MegaCorp      | New York | 1    | C001_1     |
  | C001        | MegaCorp      | New York | 2    | C001_2     |
  | C002        | SmallBiz      | Chicago  | 0    | C002_0     |
  | C002        | SmallBiz      | Chicago  | 1    | C002_1     |
  | C002        | SmallBiz      | Chicago  | 2    | C002_2     |
  | C003        | TinyInc       | Boston   | 0    | C003_0     |
  | C003        | TinyInc       | Boston   | 1    | C003_1     |
  | C003        | TinyInc       | Boston   | 2    | C003_2     |

### Step 3: Join on Salted Key

- **What happens:** Instead of all C001 records going to one partition, they are now distributed across 3 partitions (C001_0, C001_1, C001_2).
- **Output (result):**

  | transaction_id | customer_id | amount | customer_name | city     |
  |---------------|-------------|--------|---------------|----------|
  | T001          | C001        | 100    | MegaCorp      | New York |
  | T002          | C001        | 200    | MegaCorp      | New York |
  | T003          | C001        | 150    | MegaCorp      | New York |
  | T004          | C001        | 300    | MegaCorp      | New York |
  | T005          | C001        | 250    | MegaCorp      | New York |
  | T006          | C001        | 175    | MegaCorp      | New York |
  | T007          | C002        | 400    | SmallBiz      | Chicago  |
  | T008          | C003        | 500    | TinyInc       | Boston   |

---

## Method 2: Broadcast Join (When One Table is Small)

```python
from pyspark.sql.functions import broadcast

# If the small table fits in memory, broadcast it to all executors
result_broadcast = txn_df.join(
    broadcast(cust_df),
    on="customer_id",
    how="inner"
)

result_broadcast.show()
```

- **Explanation:** Broadcasting sends the entire small table to every executor. No shuffle is needed for the large table — each partition joins locally. This completely avoids the skew problem.
- **When to use:** Small table < `spark.sql.autoBroadcastJoinThreshold` (default 10MB).

---

## Method 3: Adaptive Query Execution (AQE) — Spark 3.0+

```python
# Enable AQE (enabled by default in Spark 3.2+)
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")

# Spark automatically detects and handles skew
result_aqe = txn_df.join(cust_df, on="customer_id", how="inner")
result_aqe.show()
```

- **Explanation:** AQE detects skewed partitions at runtime and automatically splits them into smaller sub-partitions. This is the easiest approach but only available in Spark 3.0+.

---

## When to Use Each Method

| Method | Best For | Pros | Cons |
|--------|----------|------|------|
| Salted Join | Large-to-large joins with known skew | Works with any Spark version | Replicates small table, more complex code |
| Broadcast Join | Small-to-large joins | No shuffle at all, fastest | Small table must fit in memory |
| AQE Skew Join | Any skewed join (Spark 3.0+) | Automatic, no code changes | Requires Spark 3.0+, may not fully resolve extreme skew |

---

## How to Detect Data Skew

```python
# Check key distribution
txn_df.groupBy("customer_id") \
    .count() \
    .orderBy(col("count").desc()) \
    .show()

# Output:
# +----------+-----+
# |customer_id|count|
# +----------+-----+
# |      C001|    6|  <-- heavily skewed
# |      C002|    1|
# |      C003|    1|
# +----------+-----+
```

**Signs of skew in Spark UI:**
- One task takes much longer than others in a stage
- One partition is significantly larger than the median
- "Spill to disk" in shuffle stages

---

## Key Interview Talking Points

1. **What is data skew?** Uneven distribution of data across partitions, causing some tasks to process disproportionately more data.

2. **Why is it a problem?** Spark runs tasks in parallel. The job finishes only when the slowest task completes. One overloaded partition = entire job bottleneck.

3. **Choosing NUM_SALTS:** More salts = better distribution but more replication of the small table. A good starting point is the number of executor cores.

4. **Salting trade-offs:**
   - Increases data volume of the small table by NUM_SALTS factor
   - Adds code complexity
   - But dramatically improves parallelism for the skewed key

5. **Real-world examples:**
   - E-commerce: Amazon/Walmart account for most transactions
   - Social media: Celebrity accounts have millions of interactions
   - Advertising: A few major advertisers dominate impression logs
   - IoT: A few sensors may produce vastly more data

6. **Other techniques:**
   - Isolate the skewed key: Process it separately and union back
   - Repartition with more partitions
   - Use `repartitionByRange()` for more even distribution
