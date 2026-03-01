Excellent! Let me give you a **comprehensive deep dive into PySpark patterns** specifically for data engineering interviews. This will cover both foundational patterns and advanced optimization techniques.

---

# **PySpark Patterns & Anti-Patterns Deep Dive**

## **Table of Contents**
1. Core PySpark Concepts (Mental Model)
2. Transformation Patterns
3. Action Patterns
4. Join Optimization Strategies
5. Partitioning & Data Skew
6. Window Functions
7. UDFs vs Built-in Functions
8. Memory & Performance Optimization
9. Common Interview Problems
10. Production Best Practices

---

## **PART 1: Core PySpark Mental Model**

### **Lazy Evaluation - The Foundation**

**Key Concept:** Nothing happens until you call an ACTION.

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum as spark_sum

spark = SparkSession.builder.appName("patterns").getOrCreate()

# ❌ WRONG MENTAL MODEL: "This filters the data now"
df = spark.read.parquet("data.parquet")
filtered_df = df.filter(col("age") > 21)  # NO EXECUTION YET!
# Nothing happened! No data read, no filter applied

# ✅ CORRECT MENTAL MODEL: "This builds an execution plan"
# 1. Transformations build a DAG (Directed Acyclic Graph)
df = spark.read.parquet("data.parquet")       # Transformation
filtered_df = df.filter(col("age") > 21)      # Transformation
grouped_df = filtered_df.groupBy("country")   # Transformation
result_df = grouped_df.agg(spark_sum("sales")) # Transformation

# 2. Action triggers execution of entire DAG
result_df.show()  # ← ACTION! Now everything executes
```

**Visualization:**

```
USER CODE (Transformations):
read → filter → groupBy → agg → show()
                                  ↑
                               ACTION!
                                  
SPARK EXECUTION:
┌─────────────────────────────────────────────┐
│ Logical Plan (What user wants)              │
│ Filter(age > 21)                            │
│   └─ Scan(data.parquet)                     │
└──────────────┬──────────────────────────────┘
               ↓
┌─────────────────────────────────────────────┐
│ Optimized Plan (Spark's optimization)       │
│ Project + Filter (PUSHED to Parquet)        │
│   └─ Scan(data.parquet, filter=age>21)      │
└──────────────┬──────────────────────────────┘
               ↓
┌─────────────────────────────────────────────┐
│ Physical Plan (How to execute)              │
│ Execute on cluster in parallel              │
└─────────────────────────────────────────────┘
```

---

### **Transformations vs Actions**

```python
# TRANSFORMATIONS (Lazy - return DataFrame)
# Wide transformations - require shuffle
.groupBy()
.join()
.repartition()
.orderBy() / .sort()
.distinct()

# Narrow transformations - no shuffle
.select()
.filter() / .where()
.withColumn()
.drop()
.map() / .flatMap()

# ACTIONS (Eager - trigger execution)
.show()
.collect()
.count()
.take(n)
.write.parquet()
.foreach()
.first()
```

**Interview Question:** *"What's the difference between `df.count()` and `df.cache().count()`?"*

```python
# Version 1: Count without cache
df = spark.read.parquet("large_data.parquet")
filtered = df.filter(col("status") == "active")
count1 = filtered.count()  # Reads from parquet, filters, counts
count2 = filtered.count()  # Reads from parquet AGAIN, filters AGAIN, counts
# ❌ Inefficient: Reads data twice

# Version 2: Count with cache
df = spark.read.parquet("large_data.parquet")
filtered = df.filter(col("status") == "active")
filtered.cache()           # Mark for caching
count1 = filtered.count()  # Reads, filters, counts, CACHES result
count2 = filtered.count()  # Uses CACHED data (fast!)
filtered.unpersist()       # Clean up
# ✅ Efficient: Reads data once
```

---

## **PART 2: Essential Transformation Patterns**

### **Pattern 1: Column Operations - The Right Way**

```python
from pyspark.sql.functions import col, lit, when, coalesce

# ❌ ANTI-PATTERN: String column references
df.select("name", "age")  # Fragile, no type checking
df.filter(df["age"] > 21)  # Harder to compose

# ✅ PATTERN: Use col() for composability
df.select(col("name"), col("age"))
df.filter(col("age") > 21)

# ✅ PATTERN: Chain operations on columns
df.withColumn(
    "age_category",
    when(col("age") < 18, "minor")
    .when(col("age") < 65, "adult")
    .otherwise("senior")
)

# ✅ PATTERN: Handle nulls with coalesce
df.withColumn("safe_value", coalesce(col("nullable_col"), lit(0)))
```

---

### **Pattern 2: Adding/Modifying Columns**

```python
from pyspark.sql.functions import current_timestamp, year, concat, lit

# ❌ ANTI-PATTERN: Multiple withColumn calls
df = df.withColumn("col1", col("a") + 1)
df = df.withColumn("col2", col("b") * 2)
df = df.withColumn("col3", col("c") / 3)
# Each withColumn creates a new DataFrame object (overhead)

# ✅ PATTERN: Single select with multiple new columns
df = df.select(
    "*",  # Keep all existing columns
    (col("a") + 1).alias("col1"),
    (col("b") * 2).alias("col2"),
    (col("c") / 3).alias("col3")
)
# More efficient, single operation

# ✅ ALTERNATIVE: Use dictionary unpacking (3.3+)
new_cols = {
    "col1": col("a") + 1,
    "col2": col("b") * 2,
    "col3": col("c") / 3
}
for name, expr in new_cols.items():
    df = df.withColumn(name, expr)

# ✅ PATTERN: Complex transformations
df = df.withColumn(
    "full_name",
    concat(col("first_name"), lit(" "), col("last_name"))
).withColumn(
    "birth_year",
    year(col("birth_date"))
).withColumn(
    "processed_at",
    current_timestamp()
)
```

---

### **Pattern 3: Filtering - Performance Tips**

```python
# ✅ PATTERN: Filter early (before expensive operations)
df = spark.read.parquet("huge_data.parquet")

# BAD ORDER:
result = df.join(other_df, "id") \
    .groupBy("category").agg(spark_sum("amount")) \
    .filter(col("category") == "electronics")  # Filter AFTER expensive ops

# GOOD ORDER:
filtered_df = df.filter(col("category") == "electronics")  # Filter FIRST
result = filtered_df.join(other_df, "id") \
    .groupBy("category").agg(spark_sum("amount"))

# ✅ PATTERN: Combine filters in single operation
# Instead of:
df = df.filter(col("age") > 18)
df = df.filter(col("country") == "USA")
df = df.filter(col("active") == True)

# Do this:
df = df.filter(
    (col("age") > 18) & 
    (col("country") == "USA") & 
    (col("active") == True)
)

# ✅ PATTERN: Use SQL for complex filtering
df.createOrReplaceTempView("users")
filtered = spark.sql("""
    SELECT *
    FROM users
    WHERE age > 18
      AND country = 'USA'
      AND active = true
      AND registration_date >= '2024-01-01'
""")
```

---

### **Pattern 4: Aggregations**

```python
from pyspark.sql.functions import (
    count, sum, avg, max, min, 
    collect_list, collect_set,
    countDistinct, approx_count_distinct
)

# ✅ PATTERN: Multiple aggregations efficiently
result = df.groupBy("category").agg(
    count("*").alias("total_records"),
    sum("amount").alias("total_amount"),
    avg("amount").alias("avg_amount"),
    max("amount").alias("max_amount"),
    min("amount").alias("min_amount"),
    countDistinct("user_id").alias("unique_users")
)

# ✅ PATTERN: Conditional aggregation
from pyspark.sql.functions import sum, when

result = df.groupBy("category").agg(
    sum(when(col("status") == "completed", col("amount")).otherwise(0))
        .alias("completed_amount"),
    sum(when(col("status") == "pending", col("amount")).otherwise(0))
        .alias("pending_amount"),
    count(when(col("status") == "failed", 1))
        .alias("failed_count")
)

# ✅ PATTERN: Approximate distinct for performance (when exact not needed)
# Exact count (slow on large data)
exact = df.agg(countDistinct("user_id")).collect()[0][0]

# Approximate count (much faster, ~2% error)
approx = df.agg(approx_count_distinct("user_id", 0.02)).collect()[0][0]

# ✅ PATTERN: Collect arrays (careful with memory!)
# Small datasets only
df.groupBy("user_id").agg(
    collect_list("product_id").alias("purchased_products"),  # With duplicates
    collect_set("product_id").alias("unique_products")       # Without duplicates
)
```

---

## **PART 3: Join Optimization Strategies**

### **The 5 Join Types & When to Use Each**

```python
# 1. BROADCAST JOIN (Broadcast Hash Join)
# Use when: One side is small (<10MB, configurable)
# Performance: FASTEST - no shuffle
from pyspark.sql.functions import broadcast

large_df = spark.read.parquet("large_sales.parquet")  # 1 TB
small_df = spark.read.parquet("small_products.parquet")  # 5 MB

# ✅ PATTERN: Explicitly broadcast small table
result = large_df.join(
    broadcast(small_df),  # Forces broadcast
    "product_id"
)
# Spark sends small_df to every executor (no shuffle!)

# 2. SHUFFLE HASH JOIN
# Use when: Both sides medium, but one smaller
# Performance: Medium - shuffle required

# 3. SORT-MERGE JOIN (default for large joins)
# Use when: Both sides large
# Performance: Requires shuffle + sort
result = large_df1.join(large_df2, "key")

# 4. CARTESIAN JOIN (Cross Join)
# Use when: Actually need all combinations (rare!)
# Performance: SLOWEST - avoid if possible
result = df1.crossJoin(df2)  # Every row × every row

# 5. BROADCAST NESTED LOOP JOIN
# Use when: No join keys (Spark's last resort)
# Performance: Very slow
```

### **Join Optimization Patterns**

```python
# ❌ ANTI-PATTERN: Multiple small joins
result = df1.join(lookup1, "id")
result = result.join(lookup2, "id")
result = result.join(lookup3, "id")
result = result.join(lookup4, "id")
# Each join might trigger shuffle

# ✅ PATTERN: Combine small lookup tables first
combined_lookup = lookup1.join(lookup2, "id") \
                         .join(lookup3, "id") \
                         .join(lookup4, "id")
result = df1.join(broadcast(combined_lookup), "id")
# Single broadcast join

# ✅ PATTERN: Filter before join
# BAD:
result = large_df.join(other_df, "id").filter(col("status") == "active")

# GOOD:
filtered_df = large_df.filter(col("status") == "active")
result = filtered_df.join(other_df, "id")

# ✅ PATTERN: Select only needed columns before join
# BAD:
result = df1.join(df2, "id")  # Joins all 50 columns from both

# GOOD:
df1_slim = df1.select("id", "col1", "col2")  # Only needed columns
df2_slim = df2.select("id", "col3", "col4")
result = df1_slim.join(df2_slim, "id")

# ✅ PATTERN: Handle skewed joins
# Problem: One key has 90% of data (data skew)
# Solution: Salting technique
from pyspark.sql.functions import rand, concat, lit

# Add random salt to skewed key
df1_salted = df1.withColumn("salt", (rand() * 10).cast("int")) \
                .withColumn("join_key", concat(col("key"), lit("_"), col("salt")))

df2_exploded = df2.withColumn("salt", explode(array([lit(i) for i in range(10)]))) \
                  .withColumn("join_key", concat(col("key"), lit("_"), col("salt")))

result = df1_salted.join(df2_exploded, "join_key")
```

### **Join Type Selection Guide**

```python
"""
DECISION TREE:

1. Is one DataFrame < 10MB?
   YES → Use broadcast join
   NO → Continue

2. Are you joining on the same column you partitioned by?
   YES → Partition-wise join (very fast)
   NO → Continue

3. Are both DataFrames very large?
   YES → Use sort-merge join (default)
   NO → Use shuffle hash join

4. Is there data skew in join keys?
   YES → Use salting technique
   NO → Use default strategy
"""

# Check if broadcast is happening
df.explain()
# Look for "BroadcastHashJoin" in plan
```

---

## **PART 4: Partitioning & Data Skew**

### **Understanding Partitions**

```python
# ✅ PATTERN: Check partition count
num_partitions = df.rdd.getNumPartitions()
print(f"Current partitions: {num_partitions}")

# ✅ PATTERN: Repartition for parallelism
# Rule of thumb: 2-4 partitions per CPU core
num_cores = 100  # Your cluster
ideal_partitions = num_cores * 3

df = df.repartition(ideal_partitions)

# ✅ PATTERN: Partition by column for better locality
# Use when filtering/joining on same column frequently
df = df.repartition(200, "country")  # Data with same country in same partition

# vs coalesce (reduces partitions without shuffle)
df = df.coalesce(50)  # Reduce from 200 to 50 (no shuffle)

# When to use each:
# repartition() - Increase OR decrease partitions, full shuffle
# coalesce() - ONLY decrease partitions, minimal shuffle
```

### **Detecting Data Skew**

```python
from pyspark.sql.functions import spark_partition_id, count

# ✅ PATTERN: Detect skewed partitions
partition_distribution = df.withColumn("partition_id", spark_partition_id()) \
    .groupBy("partition_id") \
    .agg(count("*").alias("row_count")) \
    .orderBy("row_count", ascending=False)

partition_distribution.show()
"""
+------------+---------+
|partition_id|row_count|
+------------+---------+
|         42 | 9000000 | ← SKEWED! 90% of data in one partition
|         10 |  500000 |
|         15 |  300000 |
+------------+---------+
"""

# ✅ PATTERN: Check value distribution in join key
df.groupBy("join_key").count() \
    .orderBy("count", ascending=False) \
    .show(10)
"""
If one key has 10x more rows than others → SKEW!
"""
```

### **Handling Data Skew**

```python
# TECHNIQUE 1: Salting (for joins)
from pyspark.sql.functions import rand, concat, lit, array, explode

# Identify skewed key
SKEWED_KEY = "user_123"

# For skewed records, add random salt
df1_salted = df1.withColumn(
    "is_skewed",
    when(col("user_id") == SKEWED_KEY, lit(True)).otherwise(lit(False))
).withColumn(
    "salt",
    when(col("is_skewed"), (rand() * 100).cast("int")).otherwise(lit(0))
).withColumn(
    "salted_key",
    concat(col("user_id"), lit("_"), col("salt"))
)

# Replicate other side for skewed keys
df2_replicated = df2.withColumn(
    "is_skewed",
    when(col("user_id") == SKEWED_KEY, lit(True)).otherwise(lit(False))
).withColumn(
    "salt",
    when(col("is_skewed"), 
         explode(array([lit(i) for i in range(100)]))
    ).otherwise(lit(0))
).withColumn(
    "salted_key",
    concat(col("user_id"), lit("_"), col("salt"))
)

result = df1_salted.join(df2_replicated, "salted_key")

# TECHNIQUE 2: Isolated Skewed Key Processing
# Separate skewed keys, process differently
skewed_df = df.filter(col("user_id") == SKEWED_KEY)
normal_df = df.filter(col("user_id") != SKEWED_KEY)

# Process normal data normally
normal_result = normal_df.join(other_df, "user_id")

# Process skewed data with broadcast
skewed_result = skewed_df.join(broadcast(other_df), "user_id")

# Union results
final_result = normal_result.union(skewed_result)

# TECHNIQUE 3: Adaptive Query Execution (Spark 3.0+)
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
# Spark automatically handles skew!
```

---

## **PART 5: Window Functions**

### **Window Function Patterns**

```python
from pyspark.sql.window import Window
from pyspark.sql.functions import (
    row_number, rank, dense_rank, 
    lag, lead, first, last,
    sum as spark_sum, avg, max, min
)

# ✅ PATTERN: Ranking within groups
window_spec = Window.partitionBy("category").orderBy(col("sales").desc())

result = df.withColumn("rank", row_number().over(window_spec)) \
           .withColumn("dense_rank", dense_rank().over(window_spec)) \
           .withColumn("rank_with_gaps", rank().over(window_spec))

"""
Difference:
row_number(): 1, 2, 3, 4, 5, ... (always sequential)
dense_rank(): 1, 2, 2, 3, 4, ... (no gaps after ties)
rank():       1, 2, 2, 4, 5, ... (gaps after ties)
"""

# ✅ PATTERN: Running totals
window_running = Window.partitionBy("user_id") \
                       .orderBy("transaction_date") \
                       .rowsBetween(Window.unboundedPreceding, Window.currentRow)

df_with_running = df.withColumn(
    "running_total",
    spark_sum("amount").over(window_running)
)

# ✅ PATTERN: Moving averages
window_moving = Window.partitionBy("stock_id") \
                      .orderBy("date") \
                      .rowsBetween(-6, 0)  # Last 7 days (including current)

df_with_ma = df.withColumn(
    "moving_avg_7d",
    avg("price").over(window_moving)
)

# ✅ PATTERN: Previous/Next row values
window_ordered = Window.partitionBy("user_id").orderBy("timestamp")

df_with_lag_lead = df.withColumn("prev_action", lag("action", 1).over(window_ordered)) \
                     .withColumn("next_action", lead("action", 1).over(window_ordered))

# ✅ PATTERN: First/Last value in window
window_all = Window.partitionBy("session_id").orderBy("timestamp") \
                   .rowsBetween(Window.unboundedPreceding, Window.unboundedFollowing)

df_session = df.withColumn("session_start", first("timestamp").over(window_all)) \
               .withColumn("session_end", last("timestamp").over(window_all))

# ✅ PATTERN: Range-based windows (time-based)
# Last 30 days of data
window_days = Window.partitionBy("user_id") \
                    .orderBy(col("date").cast("long")) \
                    .rangeBetween(-30*86400, 0)  # 30 days in seconds

df_30d = df.withColumn(
    "sales_last_30d",
    spark_sum("amount").over(window_days)
)
```

### **Window Function Performance Tips**

```python
# ❌ ANTI-PATTERN: Multiple windows with same partitioning
window1 = Window.partitionBy("user_id").orderBy("date")
window2 = Window.partitionBy("user_id").orderBy("date")
window3 = Window.partitionBy("user_id").orderBy("date")

df = df.withColumn("rank", row_number().over(window1)) \
       .withColumn("running_total", spark_sum("amount").over(window2)) \
       .withColumn("avg", avg("amount").over(window3))
# Spark might compute window 3 times!

# ✅ PATTERN: Single window, multiple functions
window = Window.partitionBy("user_id").orderBy("date")

df = df.withColumn("rank", row_number().over(window)) \
       .withColumn("running_total", spark_sum("amount").over(window)) \
       .withColumn("avg", avg("amount").over(window))
# Spark optimizes to single window computation

# ✅ PATTERN: Partition before window operation
df = df.repartition("user_id")  # Partition by same key
window = Window.partitionBy("user_id").orderBy("date")
df = df.withColumn("rank", row_number().over(window))
# Reduces shuffle
```

---

## **PART 6: UDFs vs Built-in Functions**

### **The Performance Gap**

```python
from pyspark.sql.functions import udf, col
from pyspark.sql.types import StringType

# ❌ ANTI-PATTERN: Python UDF (SLOW)
def categorize_age_udf(age):
    if age < 18:
        return "minor"
    elif age < 65:
        return "adult"
    else:
        return "senior"

categorize = udf(categorize_age_udf, StringType())
df = df.withColumn("category", categorize(col("age")))
# Serializes data to Python, loses Catalyst optimization

# ✅ PATTERN: Use built-in when() instead
from pyspark.sql.functions import when

df = df.withColumn(
    "category",
    when(col("age") < 18, "minor")
    .when(col("age") < 65, "adult")
    .otherwise("senior")
)
# ~10-100x faster than UDF!

# Performance comparison:
"""
Built-in functions: Execute in JVM (optimized)
Python UDF:        Serialize → Python → Deserialize (slow)
Pandas UDF:        Vectorized in Python (better than UDF)
"""
```

### **When UDFs Are Necessary**

```python
# Use UDFs for:
# 1. Complex business logic not expressible in SQL
# 2. External library calls
# 3. Complex regex/text processing

# ✅ PATTERN: Pandas UDF (Vectorized) when UDF needed
from pyspark.sql.functions import pandas_udf
import pandas as pd

@pandas_udf(StringType())
def complex_transformation(s: pd.Series) -> pd.Series:
    # Operates on entire column at once (vectorized)
    # Much faster than row-by-row UDF
    return s.str.upper() + "_PROCESSED"

df = df.withColumn("processed", complex_transformation(col("text")))

# ✅ PATTERN: Use SQL expressions for string operations
# Instead of UDF for string manipulation:
from pyspark.sql.functions import upper, concat, lit, regexp_replace

df = df.withColumn(
    "processed",
    concat(upper(col("text")), lit("_PROCESSED"))
)
```

---

## **PART 7: Memory & Performance Optimization**

### **Caching Strategies**

```python
# ✅ PATTERN: Cache when reusing DataFrame
df = spark.read.parquet("large_data.parquet")
filtered = df.filter(col("status") == "active")

# Used multiple times
filtered.cache()  # or .persist()

# Multiple operations on cached data
count = filtered.count()
stats = filtered.agg(avg("amount"), max("amount"))
top10 = filtered.orderBy(col("amount").desc()).limit(10)

# Clean up when done
filtered.unpersist()

# ✅ PATTERN: Cache at right granularity
# Too early:
df.cache()  # Caches everything before filtering
filtered = df.filter(col("date") == "2024-01-01")  # Only need 1 day!

# Too late:
filtered = df.filter(col("date") == "2024-01-01")
processed = filtered.withColumn("new_col", col("a") + col("b"))
processed.cache()  # Should cache filtered instead

# Just right:
filtered = df.filter(col("date") == "2024-01-01")
filtered.cache()  # Cache after filter, before expensive ops
processed = filtered.withColumn("new_col", col("a") + col("b"))

# ✅ PATTERN: Different storage levels
from pyspark import StorageLevel

# Memory only (default)
df.cache()  # Same as MEMORY_AND_DISK

# Memory only, deserialized
df.persist(StorageLevel.MEMORY_ONLY)

# Memory and disk (spills to disk if needed)
df.persist(StorageLevel.MEMORY_AND_DISK)

# Disk only
df.persist(StorageLevel.DISK_ONLY)

# With replication
df.persist(StorageLevel.MEMORY_AND_DISK_2)  # 2x replication
```

### **Configuration Tuning**

```python
# ✅ PATTERN: Optimize for your workload

# For large shuffles
spark.conf.set("spark.sql.shuffle.partitions", "400")  # Default: 200
# Rule: 2-4x number of cores

# For broadcast joins
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "50MB")  # Default: 10MB
# Increase if you have memory

# For adaptive query execution (Spark 3.0+)
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")

# For memory management
spark.conf.set("spark.memory.fraction", "0.8")  # 80% for execution/storage
spark.conf.set("spark.memory.storageFraction", "0.3")  # 30% of that for storage

# For Parquet optimization
spark.conf.set("spark.sql.files.maxPartitionBytes", "128MB")
spark.conf.set("spark.sql.parquet.compression.codec", "snappy")

# For CSV reading
spark.conf.set("spark.sql.files.maxRecordsPerFile", "0")  # Unlimited
```

### **Optimizing Writes**

```python
# ❌ ANTI-PATTERN: Writing many small files
df.write.parquet("output/")  # Creates 1000s of tiny files

# ✅ PATTERN: Coalesce before writing
df.coalesce(10).write.parquet("output/")  # 10 reasonably-sized files

# ✅ PATTERN: Partition output smartly
df.write \
  .partitionBy("year", "month") \
  .parquet("output/")
# Creates hierarchical structure: year=2024/month=01/

# ✅ PATTERN: Control file size
df.repartition(100) \
  .write \
  .option("maxRecordsPerFile", 1000000) \
  .parquet("output/")

# ✅ PATTERN: Write mode selection
df.write.mode("overwrite").parquet("output/")  # Replace
df.write.mode("append").parquet("output/")     # Add to existing
df.write.mode("errorIfExists").parquet("output/")  # Fail if exists
df.write.mode("ignore").parquet("output/")     # Skip if exists

# ✅ PATTERN: Optimize for read patterns
# If queries always filter by date:
df.write \
  .partitionBy("date") \  # Partition by date
  .sortBy("user_id") \     # Sort within partition
  .parquet("output/")
# Fast queries: "WHERE date = '2024-01-01' AND user_id = 123"
```

---

## **PART 8: Common Interview Problems**

### **Problem 1: Deduplication**

```python
"""
Remove duplicate records, keeping the most recent one
"""

from pyspark.sql.window import Window
from pyspark.sql.functions import row_number, col

# ❌ ANTI-PATTERN: groupBy + collect
duplicates = df.groupBy("user_id").agg(
    collect_list("timestamp").alias("timestamps")
)
# Doesn't scale, memory issues

# ✅ PATTERN: Window function
window = Window.partitionBy("user_id").orderBy(col("timestamp").desc())

deduplicated = df.withColumn("row_num", row_number().over(window)) \
                 .filter(col("row_num") == 1) \
                 .drop("row_num")

# ✅ ALTERNATIVE: dropDuplicates (if only key matters)
deduplicated = df.dropDuplicates(["user_id"])

# ✅ ALTERNATIVE: dropDuplicates with ordering (Spark 3.4+)
deduplicated = df.orderBy(col("timestamp").desc()) \
                 .dropDuplicates(["user_id"])
```

### **Problem 2: Sessionization (Web Analytics)**

```python
"""
Group events into sessions (30-min timeout)
"""

from pyspark.sql.functions import lag, when, sum as spark_sum, col
from pyspark.sql.window import Window

# Step 1: Calculate time difference from previous event
window = Window.partitionBy("user_id").orderBy("timestamp")

df_with_diff = df.withColumn(
    "prev_timestamp",
    lag("timestamp").over(window)
).withColumn(
    "time_diff_minutes",
    (col("timestamp").cast("long") - col("prev_timestamp").cast("long")) / 60
)

# Step 2: Mark session boundaries (>30 min gap = new session)
df_with_boundaries = df_with_diff.withColumn(
    "is_new_session",
    when(col("time_diff_minutes").isNull(), 1)  # First event
    .when(col("time_diff_minutes") > 30, 1)      # Timeout
    .otherwise(0)
)

# Step 3: Assign session IDs (cumulative sum)
window_all = Window.partitionBy("user_id").orderBy("timestamp") \
                   .rowsBetween(Window.unboundedPreceding, Window.currentRow)

df_with_sessions = df_with_boundaries.withColumn(
    "session_id",
    spark_sum("is_new_session").over(window_all)
).withColumn(
    "global_session_id",
    concat(col("user_id"), lit("_"), col("session_id"))
)

# Step 4: Session-level aggregations
session_stats = df_with_sessions.groupBy("global_session_id").agg(
    min("timestamp").alias("session_start"),
    max("timestamp").alias("session_end"),
    count("*").alias("event_count"),
    collect_list("page").alias("page_sequence")
)
```

### **Problem 3: Slowly Changing Dimension (SCD) Type 2**

```python
"""
Track historical changes to dimension data
"""

from pyspark.sql.functions import current_timestamp, lit, col, when, max as spark_max

# Current dimension table (with history)
current_dim = spark.read.parquet("dim_customers")
# Schema: customer_id, name, address, valid_from, valid_to, is_current

# New data (updates)
new_data = spark.read.parquet("customer_updates")
# Schema: customer_id, name, address

# Step 1: Find changed records
joined = current_dim.filter(col("is_current") == True) \
    .alias("curr") \
    .join(
        new_data.alias("new"),
        col("curr.customer_id") == col("new.customer_id"),
        "full_outer"
    )

# Step 2: Identify changes
changes = joined.withColumn(
    "change_type",
    when(col("curr.customer_id").isNull(), "INSERT")  # New customer
    .when(col("new.customer_id").isNull(), "NO_CHANGE")  # No update
    .when(
        (col("curr.name") != col("new.name")) | 
        (col("curr.address") != col("new.address")),
        "UPDATE"
    )
    .otherwise("NO_CHANGE")
)

# Step 3: Close old records (UPDATE case)
closed_records = changes.filter(col("change_type") == "UPDATE") \
    .select(
        col("curr.customer_id").alias("customer_id"),
        col("curr.name").alias("name"),
        col("curr.address").alias("address"),
        col("curr.valid_from").alias("valid_from"),
        current_timestamp().alias("valid_to"),
        lit(False).alias("is_current")
    )

# Step 4: Create new records (UPDATE + INSERT)
new_records = changes.filter(col("change_type").isin(["UPDATE", "INSERT"])) \
    .select(
        col("new.customer_id").alias("customer_id"),
        col("new.name").alias("name"),
        col("new.address").alias("address"),
        current_timestamp().alias("valid_from"),
        lit(None).cast("timestamp").alias("valid_to"),
        lit(True).alias("is_current")
    )

# Step 5: Keep unchanged records
unchanged = changes.filter(col("change_type") == "NO_CHANGE") \
    .select("curr.*")

# Step 6: Union all
updated_dim = closed_records.union(new_records).union(unchanged)

# Write back
updated_dim.write.mode("overwrite").parquet("dim_customers")
```

### **Problem 4: Top-N per Group**

```python
"""
Find top 3 products by revenue in each category
"""

from pyspark.sql.window import Window
from pyspark.sql.functions import row_number, col, desc

# ✅ PATTERN: Window function
window = Window.partitionBy("category").orderBy(col("revenue").desc())

top_products = df.withColumn("rank", row_number().over(window)) \
                 .filter(col("rank") <= 3) \
                 .drop("rank")

# ✅ ALTERNATIVE: SQL
df.createOrReplaceTempView("products")
top_products = spark.sql("""
    SELECT *
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY category ORDER BY revenue DESC) as rank
        FROM products
    )
    WHERE rank <= 3
""")
```

### **Problem 5: Data Validation at Scale**

```python
"""
Validate 1B rows efficiently
"""

from pyspark.sql.functions import (
    count, sum as spark_sum, when, col, 
    isnan, isnull, min, max, mean, stddev
)

# ✅ PATTERN: Single-pass validation
validation_results = df.agg(
    # Row counts
    count("*").alias("total_rows"),
    count("user_id").alias("non_null_user_ids"),
    
    # Null checks
    spark_sum(when(col("user_id").isNull(), 1).otherwise(0)).alias("null_user_ids"),
    spark_sum(when(col("amount").isNull(), 1).otherwise(0)).alias("null_amounts"),
    
    # Range checks
    spark_sum(when(col("amount") < 0, 1).otherwise(0)).alias("negative_amounts"),
    spark_sum(when(col("age") < 0, 1).otherwise(0)).alias("invalid_ages"),
    spark_sum(when(col("age") > 120, 1).otherwise(0)).alias("impossible_ages"),
    
    # Data quality metrics
    min("amount").alias("min_amount"),
    max("amount").alias("max_amount"),
    mean("amount").alias("avg_amount"),
    stddev("amount").alias("stddev_amount"),
    
    # Distinct counts (approximate for performance)
    approx_count_distinct("user_id").alias("unique_users")
).collect()[0]

# Display results
print(f"Total rows: {validation_results['total_rows']:,}")
print(f"Null user_ids: {validation_results['null_user_ids']:,}")
print(f"Negative amounts: {validation_results['negative_amounts']:,}")
print(f"Unique users: {validation_results['unique_users']:,}")

# ✅ PATTERN: Quarantine bad records
good_records = df.filter(
    col("user_id").isNotNull() &
    (col("amount") >= 0) &
    (col("age").between(0, 120))
)

bad_records = df.filter(
    col("user_id").isNull() |
    (col("amount") < 0) |
    ~col("age").between(0, 120)
)

# Write separately
good_records.write.parquet("output/clean/")
bad_records.write.parquet("output/quarantine/")
```

---

## **PART 9: Production Best Practices**

### **Error Handling & Logging**

```python
from pyspark.sql.utils import AnalysisException
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def safe_read_parquet(path, schema=None):
    """Read parquet with error handling."""
    try:
        logger.info(f"Reading parquet from: {path}")
        
        if schema:
            df = spark.read.schema(schema).parquet(path)
        else:
            df = spark.read.parquet(path)
        
        row_count = df.count()
        logger.info(f"Successfully read {row_count:,} rows")
        return df
        
    except AnalysisException as e:
        logger.error(f"Path not found or invalid: {path}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error reading parquet: {e}")
        raise

# ✅ PATTERN: Log key metrics
def log_dataframe_stats(df, name="DataFrame"):
    """Log useful statistics about DataFrame."""
    logger.info(f"=== {name} Stats ===")
    logger.info(f"Schema: {df.schema}")
    logger.info(f"Partitions: {df.rdd.getNumPartitions()}")
    
    # Sample row (don't use collect on large data!)
    logger.info(f"Sample row: {df.first()}")
    
    # Row count (cache if using multiple times)
    row_count = df.count()
    logger.info(f"Row count: {row_count:,}")
```

### **Monitoring & Debugging**

```python
# ✅ PATTERN: Use explain() to understand query plan
df.explain()  # Physical plan
df.explain(True)  # Logical + physical + optimized

# ✅ PATTERN: Check lineage
print(df.rdd.toDebugString().decode())

# ✅ PATTERN: Monitor execution
from time import time

start = time()
result = df.filter(...).groupBy(...).agg(...)
result.write.parquet("output/")
duration = time() - start

logger.info(f"Job completed in {duration:.2f} seconds")

# ✅ PATTERN: Custom metrics with accumulators
from pyspark import AccumulatorParam

records_processed = spark.sparkContext.accumulator(0)
errors_found = spark.sparkContext.accumulator(0)

def process_row(row):
    global records_processed, errors_found
    records_processed += 1
    
    if row.amount < 0:
        errors_found += 1
    
    return row

# After job
print(f"Processed: {records_processed.value:,}")
print(f"Errors: {errors_found.value:,}")
```

### **Testing PySpark Code**

```python
import pytest
from pyspark.sql import SparkSession

@pytest.fixture(scope="session")
def spark():
    """Create Spark session for testing."""
    return SparkSession.builder \
        .master("local[2]") \
        .appName("test") \
        .getOrCreate()

def test_deduplication(spark):
    """Test deduplication logic."""
    # Create test data
    data = [
        (1, "Alice", "2024-01-01"),
        (1, "Alice", "2024-01-02"),  # Duplicate, newer
        (2, "Bob", "2024-01-01"),
    ]
    df = spark.createDataFrame(data, ["id", "name", "date"])
    
    # Apply deduplication
    result = deduplicate(df)
    
    # Assertions
    assert result.count() == 2, "Should have 2 unique users"
    
    alice_rows = result.filter(col("id") == 1).collect()
    assert len(alice_rows) == 1, "Alice should have 1 row"
    assert alice_rows[0]["date"] == "2024-01-02", "Should keep newest"
```

---

## **QUICK REFERENCE CARD**

```
┌────────────────────────────────────────────────────────────┐
│         PYSPARK OPTIMIZATION CHECKLIST                     │
├────────────────────────────────────────────────────────────┤
│                                                            │
│ READING DATA:                                              │
│ □ Use partitioned reads (parquet preferred)               │
│ □ Filter at source (pushdown predicates)                  │
│ □ Select only needed columns early                        │
│                                                            │
│ TRANSFORMATIONS:                                           │
│ □ Use built-in functions over UDFs                        │
│ □ Filter before joins                                     │
│ □ Broadcast small tables (<10MB)                          │
│ □ Repartition for parallelism (2-4x cores)                │
│ □ Single select instead of multiple withColumn            │
│                                                            │
│ JOINS:                                                     │
│ □ Broadcast join for small tables                         │
│ □ Check for data skew (partition distribution)            │
│ □ Use salting for skewed joins                            │
│ □ Select needed columns before join                       │
│                                                            │
│ AGGREGATIONS:                                              │
│ □ Combine multiple aggs in single operation               │
│ □ Use approx_count_distinct for performance               │
│ □ Be careful with collect_list (memory!)                  │
│                                                            │
│ CACHING:                                                   │
│ □ Cache after filter, before expensive ops                │
│ □ Unpersist when done                                     │
│ □ Cache at right granularity                              │
│                                                            │
│ WRITING:                                                   │
│ □ Coalesce before write                                   │
│ □ Partition by query patterns                             │
│ □ Use appropriate compression (snappy)                    │
│ □ Control file sizes (maxRecordsPerFile)                  │
│                                                            │
│ CONFIGURATION:                                             │
│ □ Set shuffle partitions (spark.sql.shuffle.partitions)   │
│ □ Enable AQE (Spark 3.0+)                                 │
│ □ Tune broadcast threshold                                │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

Would you like me to:
1. **Add more complex interview problems** (e.g., graph processing, CDC, streaming)?
2. **Deep dive into Spark SQL optimization**?
3. **Cover Delta Lake patterns**?
4. **Show Spark Streaming (Structured Streaming) patterns**?
5. **Create a troubleshooting guide** for common Spark errors?

**Master these patterns and you'll be ready for any PySpark interview!** 🚀
