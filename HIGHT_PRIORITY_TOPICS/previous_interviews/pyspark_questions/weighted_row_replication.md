# PySpark Implementation: Weighted Row Replication

## Problem Statement 

Given a dataset of survey responses where each respondent has a **weight** indicating how many people they represent in the population, **replicate each row** by its weight value so that weighted analysis can be done with simple counts. This is the same core pattern as `quantity_explode` (using `array_repeat` + `explode`) but framed as a sampling/statistics problem.

### Sample Data

```
respondent_id  age_group   region   response   weight
R001           18-24       East     Yes        3
R002           25-34       West     No         1
R003           35-44       East     Yes        2
R004           18-24       West     No         4
```

**Meaning:** R001 represents 3 people with the same characteristics. R004 represents 4 people.

### Expected Output

| respondent_id | age_group | region | response | count |
|---------------|-----------|--------|----------|-------|
| R001          | 18-24     | East   | Yes      | 1     |
| R001          | 18-24     | East   | Yes      | 1     |
| R001          | 18-24     | East   | Yes      | 1     |
| R002          | 25-34     | West   | No       | 1     |
| R003          | 35-44     | East   | Yes      | 1     |
| R003          | 35-44     | East   | Yes      | 1     |
| R004          | 18-24     | West   | No       | 1     |
| R004          | 18-24     | West   | No       | 1     |
| R004          | 18-24     | West   | No       | 1     |
| R004          | 18-24     | West   | No       | 1     |

Total: 10 rows (3 + 1 + 2 + 4)

---

## Method 1: array_repeat() + explode() (Same as quantity_explode)

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, explode, array_repeat, lit

# Initialize Spark session
spark = SparkSession.builder.appName("WeightedReplication").getOrCreate()

# Sample data
data = [
    ("R001", "18-24", "East", "Yes", 3),
    ("R002", "25-34", "West", "No", 1),
    ("R003", "35-44", "East", "Yes", 2),
    ("R004", "18-24", "West", "No", 4)
]
columns = ["respondent_id", "age_group", "region", "response", "weight"]
df = spark.createDataFrame(data, columns)

# Replicate each row 'weight' times
replicated = df.withColumn(
    "replicated",
    explode(array_repeat(lit(1), col("weight")))
).drop("weight") \
 .withColumnRenamed("replicated", "count")

replicated.show(truncate=False)

# Verify: total rows should equal sum of weights
print(f"Original rows: {df.count()}")
print(f"Replicated rows: {replicated.count()}")
print(f"Sum of weights: {df.agg({'weight': 'sum'}).collect()[0][0]}")
```

### How It Works (Same Pattern as quantity_explode)

| respondent_id | weight | array_repeat(lit(1), weight) | After explode |
|---------------|--------|------------------------------|---------------|
| R001          | 3      | [1, 1, 1]                   | 3 rows        |
| R002          | 1      | [1]                          | 1 row         |
| R003          | 2      | [1, 1]                       | 2 rows        |
| R004          | 4      | [1, 1, 1, 1]                | 4 rows        |

---

## Method 2: Using sequence() (Alternative)

```python
from pyspark.sql.functions import sequence, lit

# sequence(1, weight) generates [1, 2, 3, ...weight]
# Then explode gives one row per element
replicated_v2 = df.withColumn(
    "row_num",
    explode(sequence(lit(1), col("weight")))
).drop("weight")

replicated_v2.show(truncate=False)
```

**Bonus:** This version gives you a row number within each replication group, which can be useful for assigning unique IDs.

- **Output (partial):**

  | respondent_id | age_group | region | response | row_num |
  |---------------|-----------|--------|----------|---------|
  | R001          | 18-24     | East   | Yes      | 1       |
  | R001          | 18-24     | East   | Yes      | 2       |
  | R001          | 18-24     | East   | Yes      | 3       |
  | R004          | 18-24     | West   | No       | 1       |
  | R004          | 18-24     | West   | No       | 2       |
  | R004          | 18-24     | West   | No       | 3       |
  | R004          | 18-24     | West   | No       | 4       |

---

## Method 3: Using SQL

```python
df.createOrReplaceTempView("survey")

spark.sql("""
    SELECT
        respondent_id, age_group, region, response, 1 AS count
    FROM survey
    LATERAL VIEW explode(array_repeat(1, weight)) t AS replicated
""").show(truncate=False)
```

---

## Practical Application 1: Weighted Distribution Analysis

```python
from pyspark.sql.functions import count

# After replication, simple counts give weighted results
# Weighted response distribution
weighted_counts = replicated.groupBy("response").agg(
    count("*").alias("weighted_count")
)
weighted_counts.show()
```

- **Output:**

  | response | weighted_count |
  |----------|---------------|
  | Yes      | 5             |
  | No       | 5             |

  Without replication, you'd get Yes=2, No=2 (unweighted).

---

## Practical Application 2: Bootstrap Sampling

```python
# After replication, you can use standard Spark sampling
# This gives a properly weighted random sample
sample_df = replicated.sample(fraction=0.5, seed=42)
sample_df.show(truncate=False)
```

---

## Practical Application 3: Ad Impression Replication

```python
# Ad campaign data: replicate impressions for detailed analysis
ad_data = [
    ("Campaign_A", "Banner", "Mobile", 1500),
    ("Campaign_A", "Video", "Desktop", 800),
    ("Campaign_B", "Banner", "Mobile", 200)
]
ad_df = spark.createDataFrame(ad_data, ["campaign", "ad_type", "device", "impressions"])

# For large impression counts, DON'T explode — use the weight directly
# Only explode when counts are small (< 10000 per row)

# Example with small counts for demo
small_ad_data = [
    ("Campaign_A", "Banner", "Mobile", 5),
    ("Campaign_A", "Video", "Desktop", 3),
    ("Campaign_B", "Banner", "Mobile", 2)
]
small_ad_df = spark.createDataFrame(small_ad_data, ["campaign", "ad_type", "device", "impressions"])

expanded_impressions = small_ad_df.withColumn(
    "impression_id",
    explode(sequence(lit(1), col("impressions")))
).drop("impressions")

expanded_impressions.show(truncate=False)
```

---

## Edge Cases and Safety

```python
from pyspark.sql.functions import when, greatest

# Handle zero, negative, and null weights
safe_df = df.withColumn(
    "safe_weight",
    when(col("weight").isNull(), 1)
    .when(col("weight") <= 0, 1)
    .otherwise(col("weight"))
)

# Add a safety cap for very large weights
capped_df = safe_df.withColumn(
    "safe_weight",
    least(col("safe_weight"), lit(10000))  # Cap at 10,000 replications
)

# Then replicate
safe_replicated = capped_df.withColumn(
    "replicated",
    explode(array_repeat(lit(1), col("safe_weight")))
).drop("weight", "safe_weight", "replicated")

safe_replicated.show(truncate=False)
```

---

## When NOT to Replicate (Use Weight Directly)

```python
from pyspark.sql.functions import sum as spark_sum, avg as spark_avg

# For large weights, DON'T replicate — use weighted aggregation instead
# This is much more memory efficient

# Weighted average age (without replication)
age_data = [
    ("R001", 22, 3),
    ("R002", 30, 1),
    ("R003", 40, 2),
    ("R004", 20, 4)
]
age_df = spark.createDataFrame(age_data, ["id", "age", "weight"])

# Weighted average = sum(age * weight) / sum(weight)
weighted_avg = age_df.withColumn(
    "age_x_weight", col("age") * col("weight")
).agg(
    (spark_sum("age_x_weight") / spark_sum("weight")).alias("weighted_avg_age")
)
weighted_avg.show()
# Output: 25.0  (vs unweighted mean of 28.0)
```

---

## Key Interview Talking Points

1. **Same core pattern as quantity_explode:** `array_repeat(lit(1), N)` + `explode()`. The only difference is the business context — quantity vs weight vs impressions.

2. **When to replicate vs use weights directly:**
   - **Replicate** when downstream tools expect flat data (e.g., ML libraries, simple count-based reports)
   - **Use weights directly** when doing aggregations (weighted average, weighted sum) — it's much more memory efficient

3. **Memory danger:** If a single row has weight = 1,000,000, exploding it creates 1M rows. Always cap weights or filter before exploding. For large weights, use weighted aggregation instead.

4. **`array_repeat` vs `sequence`:**
   - `array_repeat(lit(1), N)` → `[1, 1, 1, ...]` (N identical values)
   - `sequence(lit(1), N)` → `[1, 2, 3, ..., N]` (sequential numbers)
   - Both produce N rows after explode. `sequence` gives you a built-in row number.

5. **Real-world use cases:**
   - Census/survey data weighting
   - Ad impression-level analysis
   - Oversampling minority classes for ML training (SMOTE-like)
   - Monte Carlo simulation input preparation
   - Converting aggregated data to row-level for visualization tools
