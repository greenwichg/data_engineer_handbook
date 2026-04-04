# PySpark Implementation: Data Sampling Techniques

## Problem Statement

Sampling is a fundamental technique in data engineering for testing pipelines, creating development datasets, performing exploratory analysis, and handling class imbalance in ML workflows. Interviewers frequently ask about sampling techniques in PySpark to assess a candidate's understanding of random sampling, stratified sampling, and how to maintain data representativeness at scale.

Given a dataset of customer transactions across different regions and product categories, demonstrate various sampling techniques including simple random sampling, stratified sampling, and weighted sampling.

### Sample Data

```
+---------+--------+----------+--------+----------+
|cust_id  |region  |category  |amount  |txn_date  |
+---------+--------+----------+--------+----------+
| C001    | East   | Electronics| 500  |2024-01-01|
| C002    | East   | Clothing |  80    |2024-01-01|
| C003    | West   | Electronics| 350  |2024-01-02|
| C004    | West   | Grocery  | 120    |2024-01-02|
| C005    | East   | Grocery  |  65    |2024-01-03|
| C006    | South  | Electronics| 420  |2024-01-03|
| C007    | South  | Clothing | 150    |2024-01-04|
| C008    | West   | Clothing | 200    |2024-01-04|
| C009    | East   | Electronics| 600  |2024-01-05|
| C010    | South  | Grocery  |  90    |2024-01-05|
| ...     | ...    | ...      | ...    | ...      |
+---------+--------+----------+--------+----------+
```

### Expected Output

**Stratified sample (proportional representation per region):**

| region | original_count | sample_count | sample_pct |
|--------|---------------|-------------|------------|
| East   | 8             | 4           | 50%        |
| West   | 6             | 3           | 50%        |
| South  | 6             | 3           | 50%        |

---

## Method 1: Simple Random Sampling

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("DataSamplingTechniques") \
    .master("local[*]") \
    .getOrCreate()

# Create sample data
data = [
    ("C001", "East",  "Electronics", 500, "2024-01-01"),
    ("C002", "East",  "Clothing",     80, "2024-01-01"),
    ("C003", "West",  "Electronics", 350, "2024-01-02"),
    ("C004", "West",  "Grocery",    120, "2024-01-02"),
    ("C005", "East",  "Grocery",     65, "2024-01-03"),
    ("C006", "South", "Electronics", 420, "2024-01-03"),
    ("C007", "South", "Clothing",   150, "2024-01-04"),
    ("C008", "West",  "Clothing",   200, "2024-01-04"),
    ("C009", "East",  "Electronics", 600, "2024-01-05"),
    ("C010", "South", "Grocery",     90, "2024-01-05"),
    ("C011", "East",  "Clothing",   110, "2024-01-06"),
    ("C012", "West",  "Electronics", 280, "2024-01-06"),
    ("C013", "South", "Electronics", 550, "2024-01-07"),
    ("C014", "East",  "Grocery",    130, "2024-01-07"),
    ("C015", "West",  "Grocery",     75, "2024-01-08"),
    ("C016", "East",  "Electronics", 450, "2024-01-08"),
    ("C017", "South", "Clothing",   180, "2024-01-09"),
    ("C018", "West",  "Clothing",   160, "2024-01-09"),
    ("C019", "East",  "Grocery",     95, "2024-01-10"),
    ("C020", "South", "Grocery",    105, "2024-01-10"),
]

columns = ["cust_id", "region", "category", "amount", "txn_date"]
df = spark.createDataFrame(data, columns)

print(f"Original count: {df.count()}")

# --- Simple random sampling WITHOUT replacement ---
# fraction = probability each row is included (approximate)
sample_no_replace = df.sample(withReplacement=False, fraction=0.5, seed=42)
print(f"\nSample without replacement (fraction=0.5): {sample_no_replace.count()} rows")
sample_no_replace.show()

# --- Simple random sampling WITH replacement ---
# Rows can appear more than once; fraction can exceed 1.0
sample_with_replace = df.sample(withReplacement=True, fraction=0.5, seed=42)
print(f"Sample with replacement (fraction=0.5): {sample_with_replace.count()} rows")

# --- Take N random rows using orderBy + limit ---
random_n = df.orderBy(F.rand(seed=42)).limit(5)
print("Random 5 rows using orderBy(rand()).limit(5):")
random_n.show()
```

## Method 2: Stratified Sampling with sampleBy

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("StratifiedSampling") \
    .master("local[*]") \
    .getOrCreate()

data = [
    ("C001", "East",  "Electronics", 500, "2024-01-01"),
    ("C002", "East",  "Clothing",     80, "2024-01-01"),
    ("C003", "West",  "Electronics", 350, "2024-01-02"),
    ("C004", "West",  "Grocery",    120, "2024-01-02"),
    ("C005", "East",  "Grocery",     65, "2024-01-03"),
    ("C006", "South", "Electronics", 420, "2024-01-03"),
    ("C007", "South", "Clothing",   150, "2024-01-04"),
    ("C008", "West",  "Clothing",   200, "2024-01-04"),
    ("C009", "East",  "Electronics", 600, "2024-01-05"),
    ("C010", "South", "Grocery",     90, "2024-01-05"),
    ("C011", "East",  "Clothing",   110, "2024-01-06"),
    ("C012", "West",  "Electronics", 280, "2024-01-06"),
    ("C013", "South", "Electronics", 550, "2024-01-07"),
    ("C014", "East",  "Grocery",    130, "2024-01-07"),
    ("C015", "West",  "Grocery",     75, "2024-01-08"),
    ("C016", "East",  "Electronics", 450, "2024-01-08"),
    ("C017", "South", "Clothing",   180, "2024-01-09"),
    ("C018", "West",  "Clothing",   160, "2024-01-09"),
    ("C019", "East",  "Grocery",     95, "2024-01-10"),
    ("C020", "South", "Grocery",    105, "2024-01-10"),
]

columns = ["cust_id", "region", "category", "amount", "txn_date"]
df = spark.createDataFrame(data, columns)

# Show original distribution
print("=== Original Distribution by Region ===")
df.groupBy("region").count().show()

# --- Stratified sampling: equal fraction per stratum ---
# sampleBy takes a column and a dict of {value: fraction}
fractions = {"East": 0.5, "West": 0.5, "South": 0.5}
stratified_equal = df.sampleBy("region", fractions, seed=42)

print("=== Stratified Sample (50% per region) ===")
stratified_equal.groupBy("region").count().show()
stratified_equal.show()

# --- Stratified sampling: different fractions per stratum ---
# Oversample minority regions, undersample majority
fractions_diff = {"East": 0.3, "West": 0.8, "South": 0.8}
stratified_diff = df.sampleBy("region", fractions_diff, seed=42)

print("=== Stratified Sample (different fractions) ===")
stratified_diff.groupBy("region").count().show()

# --- Exact N per stratum using window + row_number ---
from pyspark.sql.window import Window

n_per_group = 2
w = Window.partitionBy("region").orderBy(F.rand(seed=42))

exact_stratified = df.withColumn("rn", F.row_number().over(w)) \
    .filter(F.col("rn") <= n_per_group) \
    .drop("rn")

print(f"=== Exact {n_per_group} per Region ===")
exact_stratified.show()
exact_stratified.groupBy("region").count().show()
```

## Method 3: Weighted and Reservoir Sampling

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("WeightedSampling") \
    .master("local[*]") \
    .getOrCreate()

data = [
    ("C001", "East",  "Electronics", 500, "2024-01-01"),
    ("C002", "East",  "Clothing",     80, "2024-01-01"),
    ("C003", "West",  "Electronics", 350, "2024-01-02"),
    ("C004", "West",  "Grocery",    120, "2024-01-02"),
    ("C005", "East",  "Grocery",     65, "2024-01-03"),
    ("C006", "South", "Electronics", 420, "2024-01-03"),
    ("C007", "South", "Clothing",   150, "2024-01-04"),
    ("C008", "West",  "Clothing",   200, "2024-01-04"),
    ("C009", "East",  "Electronics", 600, "2024-01-05"),
    ("C010", "South", "Grocery",     90, "2024-01-05"),
    ("C011", "East",  "Clothing",   110, "2024-01-06"),
    ("C012", "West",  "Electronics", 280, "2024-01-06"),
    ("C013", "South", "Electronics", 550, "2024-01-07"),
    ("C014", "East",  "Grocery",    130, "2024-01-07"),
    ("C015", "West",  "Grocery",     75, "2024-01-08"),
    ("C016", "East",  "Electronics", 450, "2024-01-08"),
    ("C017", "South", "Clothing",   180, "2024-01-09"),
    ("C018", "West",  "Clothing",   160, "2024-01-09"),
    ("C019", "East",  "Grocery",     95, "2024-01-10"),
    ("C020", "South", "Grocery",    105, "2024-01-10"),
]

columns = ["cust_id", "region", "category", "amount", "txn_date"]
df = spark.createDataFrame(data, columns)

# ============================================================
# Weighted sampling: higher-amount transactions more likely
# ============================================================
# Use amount as a weight: generate a random key weighted by amount
# The trick: sort by -log(rand()) / weight (Efraimidis-Spirakis algorithm)

sample_size = 8

weighted_sample = df.withColumn(
    "weight_key", -F.log(F.rand(seed=42)) / F.col("amount")
).orderBy("weight_key").limit(sample_size)

print(f"=== Weighted Sample (top {sample_size}, weighted by amount) ===")
weighted_sample.drop("weight_key").show()

# Verify: higher amounts should appear more frequently
print("Average amount in original:", df.agg(F.avg("amount")).collect()[0][0])
print("Average amount in weighted sample:",
      weighted_sample.agg(F.avg("amount")).collect()[0][0])

# ============================================================
# Reservoir sampling simulation (for streaming / unknown size)
# ============================================================
# In PySpark, reservoir sampling can be simulated by:
# 1. Assign random keys
# 2. Take top-K by random key

reservoir_size = 5

reservoir_sample = df.withColumn("reservoir_key", F.rand(seed=123)) \
    .orderBy("reservoir_key") \
    .limit(reservoir_size) \
    .drop("reservoir_key")

print(f"=== Reservoir Sample ({reservoir_size} items) ===")
reservoir_sample.show()

# ============================================================
# Systematic sampling: every Nth row
# ============================================================
# Add a monotonically increasing id and take every Nth row
step = 3

systematic = df.withColumn("row_id", F.monotonically_increasing_id())
# Use modulo to pick every Nth row
systematic_sample = systematic.filter(F.col("row_id") % step == 0).drop("row_id")

print(f"=== Systematic Sample (every {step}rd row) ===")
systematic_sample.show()
```

## Key Concepts

| Technique | Method | When to Use |
|-----------|--------|-------------|
| **Simple random** | `df.sample(fraction)` | Quick exploration, testing |
| **Stratified** | `df.sampleBy(col, fractions)` | Maintain group proportions |
| **Exact N per group** | `row_number().over(Window)` | Fixed sample size per category |
| **Weighted** | `-log(rand()) / weight` | Bias toward important records |
| **Reservoir** | `rand() + limit(K)` | Unknown or streaming data size |
| **Systematic** | `monotonically_increasing_id % N` | Evenly spaced samples |

## Interview Tips

1. **sample() is approximate**: The `fraction` parameter is a probability, not an exact ratio. If you need exactly N rows, use `orderBy(rand()).limit(N)` or `takeSample()` on RDDs.

2. **Seed for reproducibility**: Always set a seed in production sampling pipelines to ensure reproducible results for debugging and auditing.

3. **sampleBy vs sample**: `sampleBy` allows different sampling rates per stratum (key value), while `sample` applies a uniform rate to the entire DataFrame.

4. **Weighted sampling algorithm**: The Efraimidis-Spirakis algorithm (`-log(rand())/weight`) is an elegant one-pass weighted sampling method. Be prepared to explain why it works.

5. **Performance**: `df.sample()` is a transformation (lazy), but `takeSample()` is an action that collects to the driver. For large-scale sampling, prefer DataFrame operations.

6. **Common pitfall**: Using `monotonically_increasing_id()` for systematic sampling is not guaranteed to produce consecutive IDs across partitions. Use `zipWithIndex()` on the RDD if you need truly sequential numbering.
