# PySpark Implementation: Market Basket Analysis

## Problem Statement

Market basket analysis is a data mining technique used to discover associations between items that customers frequently purchase together. Given a dataset of retail transactions, find pairs of items that are commonly co-purchased. This is a classic interview question for data engineering roles at e-commerce and retail companies, testing your ability to perform self-joins, aggregations, and work with combinatorial data.

### Sample Data

```
transaction_id | item
1              | Bread
1              | Butter
1              | Milk
2              | Bread
2              | Butter
2              | Eggs
3              | Milk
3              | Eggs
3              | Bread
4              | Bread
4              | Butter
4              | Milk
4              | Eggs
5              | Butter
5              | Milk
```

### Expected Output

| item_a  | item_b  | co_purchase_count | support  |
|---------|---------|-------------------|----------|
| Bread   | Butter  | 3                 | 0.6      |
| Bread   | Milk    | 3                 | 0.6      |
| Bread   | Eggs    | 2                 | 0.4      |
| Butter  | Milk    | 3                 | 0.6      |
| Butter  | Eggs    | 1                 | 0.2      |
| Milk    | Eggs    | 2                 | 0.4      |

---

## Method 1: Self-Join Approach

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, countDistinct, lit

# Initialize SparkSession
spark = SparkSession.builder \
    .appName("MarketBasketAnalysis_SelfJoin") \
    .master("local[*]") \
    .getOrCreate()

# Create sample data
data = [
    (1, "Bread"), (1, "Butter"), (1, "Milk"),
    (2, "Bread"), (2, "Butter"), (2, "Eggs"),
    (3, "Milk"),  (3, "Eggs"),   (3, "Bread"),
    (4, "Bread"), (4, "Butter"), (4, "Milk"), (4, "Eggs"),
    (5, "Butter"), (5, "Milk")
]

df = spark.createDataFrame(data, ["transaction_id", "item"])

# Total number of transactions for support calculation
total_transactions = df.select("transaction_id").distinct().count()

# Self-join: join transactions with themselves on transaction_id
# Filter to avoid duplicate pairs (item_a < item_b ensures each pair appears once)
co_purchases = df.alias("a").join(
    df.alias("b"),
    (col("a.transaction_id") == col("b.transaction_id")) &
    (col("a.item") < col("b.item"))
)

# Count co-occurrences and calculate support
result = co_purchases.groupBy(
    col("a.item").alias("item_a"),
    col("b.item").alias("item_b")
).agg(
    count("*").alias("co_purchase_count")
).withColumn(
    "support", col("co_purchase_count") / lit(total_transactions)
).orderBy(col("co_purchase_count").desc())

result.show(truncate=False)

spark.stop()
```

## Method 2: Collect Set + Explode Combinations

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col, collect_set, size, explode, array_sort, count, lit, udf, arrays_zip
)
from pyspark.sql.types import ArrayType, StructType, StructField, StringType
from itertools import combinations

# Initialize SparkSession
spark = SparkSession.builder \
    .appName("MarketBasketAnalysis_CollectSet") \
    .master("local[*]") \
    .getOrCreate()

# Create sample data
data = [
    (1, "Bread"), (1, "Butter"), (1, "Milk"),
    (2, "Bread"), (2, "Butter"), (2, "Eggs"),
    (3, "Milk"),  (3, "Eggs"),   (3, "Bread"),
    (4, "Bread"), (4, "Butter"), (4, "Milk"), (4, "Eggs"),
    (5, "Butter"), (5, "Milk")
]

df = spark.createDataFrame(data, ["transaction_id", "item"])

total_transactions = df.select("transaction_id").distinct().count()

# Collect all items per transaction into a sorted set
baskets = df.groupBy("transaction_id").agg(
    array_sort(collect_set("item")).alias("items")
).filter(size("items") >= 2)  # Need at least 2 items for pairs

# UDF to generate all pairs from a basket
@udf(ArrayType(StructType([
    StructField("item_a", StringType()),
    StructField("item_b", StringType())
])))
def generate_pairs(items):
    return [{"item_a": a, "item_b": b} for a, b in combinations(sorted(items), 2)]

# Generate pairs, explode, and count
pairs_df = baskets.withColumn("pair", explode(generate_pairs("items")))

result = pairs_df.select(
    col("pair.item_a"),
    col("pair.item_b")
).groupBy("item_a", "item_b").agg(
    count("*").alias("co_purchase_count")
).withColumn(
    "support", col("co_purchase_count") / lit(total_transactions)
).orderBy(col("co_purchase_count").desc())

result.show(truncate=False)

spark.stop()
```

## Method 3: With Confidence and Lift Metrics

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, countDistinct, lit

spark = SparkSession.builder \
    .appName("MarketBasketAnalysis_FullMetrics") \
    .master("local[*]") \
    .getOrCreate()

data = [
    (1, "Bread"), (1, "Butter"), (1, "Milk"),
    (2, "Bread"), (2, "Butter"), (2, "Eggs"),
    (3, "Milk"),  (3, "Eggs"),   (3, "Bread"),
    (4, "Bread"), (4, "Butter"), (4, "Milk"), (4, "Eggs"),
    (5, "Butter"), (5, "Milk")
]

df = spark.createDataFrame(data, ["transaction_id", "item"])

total_txns = df.select("transaction_id").distinct().count()

# Get individual item frequencies
item_freq = df.groupBy("item").agg(
    countDistinct("transaction_id").alias("item_count")
)

# Self-join for co-purchases
co_purchases = df.alias("a").join(
    df.alias("b"),
    (col("a.transaction_id") == col("b.transaction_id")) &
    (col("a.item") < col("b.item"))
).groupBy(
    col("a.item").alias("item_a"),
    col("b.item").alias("item_b")
).agg(
    countDistinct("a.transaction_id").alias("co_purchase_count")
)

# Join back item frequencies for confidence and lift
result = co_purchases \
    .join(item_freq.alias("fa"), col("item_a") == col("fa.item")) \
    .join(item_freq.alias("fb"), col("item_b") == col("fb.item")) \
    .select(
        "item_a", "item_b", "co_purchase_count",
        (col("co_purchase_count") / lit(total_txns)).alias("support"),
        (col("co_purchase_count") / col("fa.item_count")).alias("confidence_a_to_b"),
        (col("co_purchase_count") / col("fb.item_count")).alias("confidence_b_to_a"),
        (
            (col("co_purchase_count") / lit(total_txns)) /
            ((col("fa.item_count") / lit(total_txns)) * (col("fb.item_count") / lit(total_txns)))
        ).alias("lift")
    ).orderBy(col("lift").desc())

result.show(truncate=False)

spark.stop()
```

## Key Concepts

- **Support**: The fraction of transactions containing both items. `support(A,B) = count(A and B) / total_transactions`.
- **Confidence**: How often B is purchased when A is purchased. `confidence(A->B) = support(A,B) / support(A)`.
- **Lift**: How much more likely items are bought together than independently. `lift(A,B) = support(A,B) / (support(A) * support(B))`. Lift > 1 means positive association.
- **Self-Join Pattern**: The `a.item < b.item` condition avoids counting (Bread, Milk) and (Milk, Bread) as separate pairs.
- **Performance**: The self-join approach can be expensive with large datasets. Consider filtering to frequent items first or using the FP-Growth algorithm from `pyspark.ml.fpm`.
- **Interview Tip**: Mention that for production workloads, PySpark MLlib provides `FPGrowth` which is much more efficient than the brute-force self-join approach.
