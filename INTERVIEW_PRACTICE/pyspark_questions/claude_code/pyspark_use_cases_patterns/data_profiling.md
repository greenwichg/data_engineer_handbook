# PySpark Implementation: Data Profiling

## Problem Statement

Data profiling is the process of examining a dataset to understand its structure, content, and quality. For each column, you compute statistics such as count, null percentage, distinct count, min/max values, mean, standard deviation, and value distributions. This is essential before building any data pipeline or model. Interviewers frequently ask about profiling to assess your ability to explore unfamiliar data systematically.

### Sample Data

```
id | name    | age  | salary   | department  | email              | join_date
1  | Alice   | 30   | 75000.0  | Engineering | alice@co.com       | 2022-01-15
2  | Bob     | NULL | 65000.0  | Marketing   | bob@co.com         | 2022-03-20
3  | Charlie | 45   | NULL     | Engineering | NULL               | 2023-01-10
4  | Diana   | 28   | 82000.0  | Sales       | diana@co.com       | 2022-06-01
5  | Eve     | 35   | 72000.0  | Engineering | eve@co.com         | NULL
6  | Frank   | 55   | 95000.0  | Marketing   | frank@co.com       | 2023-05-15
7  | Grace   | 30   | 68000.0  | Sales       | grace@co.com       | 2022-09-01
```

### Expected Output (Profile Summary)

| column     | data_type | total_count | null_count | null_pct | distinct_count | min   | max    |
|------------|-----------|-------------|------------|----------|----------------|-------|--------|
| id         | bigint    | 7           | 0          | 0.0      | 7              | 1     | 7      |
| name       | string    | 7           | 0          | 0.0      | 7              | Alice | Grace  |
| age        | bigint    | 7           | 1          | 14.3     | 5              | 28    | 55     |
| salary     | double    | 7           | 1          | 14.3     | 6              | 65000 | 95000  |
| department | string    | 7           | 0          | 0.0      | 3              | Eng.. | Sales  |
| email      | string    | 7           | 1          | 14.3     | 6              | ...   | ...    |
| join_date  | string    | 7           | 1          | 14.3     | 6              | ...   | ...    |

---

## Method 1: Column-by-Column Profiling

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, count, countDistinct, sum as spark_sum, when, isnull,
    min as spark_min, max as spark_max, mean, stddev,
    round as spark_round, lit, approx_count_distinct
)

# Initialize SparkSession
spark = SparkSession.builder \
    .appName("DataProfiling") \
    .master("local[*]") \
    .getOrCreate()

# Create sample data
data = [
    (1, "Alice",   30,   75000.0, "Engineering", "alice@co.com", "2022-01-15"),
    (2, "Bob",     None, 65000.0, "Marketing",   "bob@co.com",   "2022-03-20"),
    (3, "Charlie", 45,   None,    "Engineering", None,           "2023-01-10"),
    (4, "Diana",   28,   82000.0, "Sales",       "diana@co.com", "2022-06-01"),
    (5, "Eve",     35,   72000.0, "Engineering", "eve@co.com",   None),
    (6, "Frank",   55,   95000.0, "Marketing",   "frank@co.com", "2023-05-15"),
    (7, "Grace",   30,   68000.0, "Sales",       "grace@co.com", "2022-09-01"),
]

df = spark.createDataFrame(
    data,
    ["id", "name", "age", "salary", "department", "email", "join_date"]
)

total_rows = df.count()
profile_results = []

for field in df.schema.fields:
    col_name = field.name
    data_type = str(field.dataType)

    stats = df.select(
        lit(col_name).alias("column"),
        lit(data_type).alias("data_type"),
        count("*").alias("total_count"),
        spark_sum(when(isnull(col(col_name)), 1).otherwise(0)).alias("null_count"),
        spark_round(
            spark_sum(when(isnull(col(col_name)), 1).otherwise(0)) / count("*") * 100, 1
        ).alias("null_pct"),
        countDistinct(col(col_name)).alias("distinct_count"),
        spark_min(col(col_name)).cast("string").alias("min_value"),
        spark_max(col(col_name)).cast("string").alias("max_value"),
    ).collect()[0]

    profile_results.append((
        stats["column"], stats["data_type"],
        stats["total_count"], stats["null_count"],
        float(stats["null_pct"]), stats["distinct_count"],
        stats["min_value"], stats["max_value"]
    ))

profile_df = spark.createDataFrame(
    profile_results,
    ["column", "data_type", "total_count", "null_count",
     "null_pct", "distinct_count", "min_value", "max_value"]
)

print("=== Data Profile Summary ===")
profile_df.show(truncate=False)

spark.stop()
```

## Method 2: Single-Pass Profiling with Aggregation

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, count, countDistinct, sum as spark_sum, when, isnull,
    min as spark_min, max as spark_max, mean, stddev,
    round as spark_round, struct, array, explode, lit
)
from pyspark.sql.types import StructType, StructField, StringType, LongType, DoubleType

spark = SparkSession.builder \
    .appName("DataProfiling_SinglePass") \
    .master("local[*]") \
    .getOrCreate()

data = [
    (1, "Alice",   30,   75000.0, "Engineering", "alice@co.com", "2022-01-15"),
    (2, "Bob",     None, 65000.0, "Marketing",   "bob@co.com",   "2022-03-20"),
    (3, "Charlie", 45,   None,    "Engineering", None,           "2023-01-10"),
    (4, "Diana",   28,   82000.0, "Sales",       "diana@co.com", "2022-06-01"),
    (5, "Eve",     35,   72000.0, "Engineering", "eve@co.com",   None),
    (6, "Frank",   55,   95000.0, "Marketing",   "frank@co.com", "2023-05-15"),
    (7, "Grace",   30,   68000.0, "Sales",       "grace@co.com", "2022-09-01"),
]

df = spark.createDataFrame(
    data,
    ["id", "name", "age", "salary", "department", "email", "join_date"]
)

total_rows = df.count()

# Build all aggregation expressions in one pass
agg_exprs = []
for field in df.schema.fields:
    c = field.name
    agg_exprs.extend([
        spark_sum(when(isnull(col(c)), 1).otherwise(0)).alias(f"{c}__null_count"),
        countDistinct(col(c)).alias(f"{c}__distinct"),
        spark_min(col(c)).cast("string").alias(f"{c}__min"),
        spark_max(col(c)).cast("string").alias(f"{c}__max"),
    ])

# Single aggregation pass
stats_row = df.agg(*agg_exprs).collect()[0]

# Also compute numeric stats
numeric_cols = [f.name for f in df.schema.fields if str(f.dataType) in ("LongType()", "DoubleType()", "IntegerType()")]

numeric_stats = {}
if numeric_cols:
    num_agg_exprs = []
    for c in numeric_cols:
        num_agg_exprs.extend([
            spark_round(mean(col(c)), 2).alias(f"{c}__mean"),
            spark_round(stddev(col(c)), 2).alias(f"{c}__stddev"),
        ])
    num_row = df.agg(*num_agg_exprs).collect()[0]
    for c in numeric_cols:
        numeric_stats[c] = {
            "mean": num_row[f"{c}__mean"],
            "stddev": num_row[f"{c}__stddev"],
        }

# Assemble results
profile_data = []
for field in df.schema.fields:
    c = field.name
    null_count = stats_row[f"{c}__null_count"]
    null_pct = round(null_count / total_rows * 100, 1)
    mean_val = numeric_stats.get(c, {}).get("mean", None)
    stddev_val = numeric_stats.get(c, {}).get("stddev", None)

    profile_data.append((
        c, str(field.dataType), total_rows,
        null_count, null_pct,
        stats_row[f"{c}__distinct"],
        stats_row[f"{c}__min"],
        stats_row[f"{c}__max"],
        float(mean_val) if mean_val is not None else None,
        float(stddev_val) if stddev_val is not None else None,
    ))

profile_df = spark.createDataFrame(
    profile_data,
    ["column", "data_type", "total_count", "null_count", "null_pct",
     "distinct_count", "min_value", "max_value", "mean", "stddev"]
)

print("=== Complete Data Profile (Single Pass) ===")
profile_df.show(truncate=False)

spark.stop()
```

## Method 3: Value Distribution and Top-N Frequencies

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, count, desc, row_number, round as spark_round, lit
)
from pyspark.sql.window import Window

spark = SparkSession.builder \
    .appName("DataProfiling_Distributions") \
    .master("local[*]") \
    .getOrCreate()

data = [
    (1, "Alice",   30, "Engineering"),
    (2, "Bob",     25, "Marketing"),
    (3, "Charlie", 45, "Engineering"),
    (4, "Diana",   28, "Sales"),
    (5, "Eve",     35, "Engineering"),
    (6, "Frank",   55, "Marketing"),
    (7, "Grace",   30, "Sales"),
    (8, "Hank",    42, "Engineering"),
    (9, "Ivy",     33, "Sales"),
    (10, "Jack",   30, "Marketing"),
]

df = spark.createDataFrame(data, ["id", "name", "age", "department"])

total_rows = df.count()

# Top-N value frequencies for categorical columns
categorical_cols = ["department"]
top_n = 10

for col_name in categorical_cols:
    freq = df.groupBy(col_name).agg(
        count("*").alias("frequency")
    ).withColumn(
        "percentage",
        spark_round(col("frequency") / lit(total_rows) * 100, 1)
    ).orderBy(desc("frequency")).limit(top_n)

    print(f"=== Value Distribution: {col_name} ===")
    freq.show(truncate=False)

# Histogram-style distribution for numeric columns
numeric_cols = ["age"]
for col_name in numeric_cols:
    # Compute quantiles
    quantiles = df.stat.approxQuantile(col_name, [0.0, 0.25, 0.5, 0.75, 1.0], 0.01)
    print(f"=== Quantiles for {col_name} ===")
    print(f"  Min (0%):  {quantiles[0]}")
    print(f"  Q1 (25%):  {quantiles[1]}")
    print(f"  Median:    {quantiles[2]}")
    print(f"  Q3 (75%):  {quantiles[3]}")
    print(f"  Max (100%): {quantiles[4]}")
    print()

# Built-in describe for quick stats
print("=== Built-in describe() ===")
df.describe().show()

# Built-in summary with more percentiles
print("=== Built-in summary() ===")
df.select("age").summary("count", "min", "25%", "50%", "75%", "max", "mean", "stddev").show()

spark.stop()
```

## Interview Tips

- **Single-pass vs. multi-pass**: The single-pass method (Method 2) is more efficient because it computes all column statistics in one scan of the data. Multi-pass (Method 1) is simpler but executes a separate query per column.
- **approx_count_distinct**: For large datasets, use `approx_count_distinct` instead of `countDistinct` to trade a small margin of error for significant speedup (uses HyperLogLog algorithm).
- **describe() and summary()**: Spark provides built-in `df.describe()` and `df.summary()` for quick numeric profiling. Know these exist but also know their limitations (numeric columns only, no null analysis).
- **Sampling**: For very large datasets, profile a sample first: `df.sample(0.01).cache()` before running profiling queries.
- **Production tools**: Mention AWS Deequ, Great Expectations, or custom profiling frameworks that store profiles over time to detect data drift.
- **Cardinality awareness**: High-cardinality columns (like user IDs) are poor candidates for `collect_set` or `countDistinct` in profiling. Use approximate methods instead.
