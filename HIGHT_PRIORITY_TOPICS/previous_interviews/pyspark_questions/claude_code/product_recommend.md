# PySpark Implementation: Product Recommendation Pairs

## Problem Statement

Find product recommendation pairs based on co-purchase frequency and association rules. Given transaction data where each order contains multiple products, identify which products are frequently bought together, compute support, confidence, and lift metrics, and generate "customers who bought X also bought Y" recommendations. This is a common interview question at e-commerce companies (Amazon, Walmart, Instacart) and tests your ability to work with self-joins, combinatorics, and association rule mining.

### Sample Data

**Order Items:**

| order_id | product_id | product_name  | category    |
|----------|------------|---------------|-------------|
| 1        | P001       | Laptop        | Electronics |
| 1        | P002       | Mouse         | Electronics |
| 1        | P003       | Keyboard      | Electronics |
| 2        | P001       | Laptop        | Electronics |
| 2        | P002       | Mouse         | Electronics |
| 3        | P002       | Mouse         | Electronics |
| 3        | P004       | Headphones    | Electronics |
| 4        | P001       | Laptop        | Electronics |
| 4        | P003       | Keyboard      | Electronics |
| 4        | P005       | Monitor       | Electronics |
| 5        | P002       | Mouse         | Electronics |
| 5        | P003       | Keyboard      | Electronics |

### Expected Output (Top Pairs)

| product_a | product_b | co_purchase_count | support | confidence_a_to_b | lift |
|-----------|-----------|-------------------|---------|-------------------|------|
| Laptop    | Mouse     | 2                 | 0.40    | 0.67              | 0.83 |
| Laptop    | Keyboard  | 2                 | 0.40    | 0.67              | 1.11 |
| Mouse     | Keyboard  | 2                 | 0.40    | 0.50              | 0.83 |

---

## Method 1: Self-Join for Co-Purchase Pairs

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

# Initialize Spark
spark = SparkSession.builder \
    .appName("Product Recommendation Pairs") \
    .master("local[*]") \
    .getOrCreate()

# --- Sample Data ---
order_items_data = [
    (1, "P001", "Laptop", "Electronics"),
    (1, "P002", "Mouse", "Electronics"),
    (1, "P003", "Keyboard", "Electronics"),
    (2, "P001", "Laptop", "Electronics"),
    (2, "P002", "Mouse", "Electronics"),
    (3, "P002", "Mouse", "Electronics"),
    (3, "P004", "Headphones", "Electronics"),
    (4, "P001", "Laptop", "Electronics"),
    (4, "P003", "Keyboard", "Electronics"),
    (4, "P005", "Monitor", "Electronics"),
    (5, "P002", "Mouse", "Electronics"),
    (5, "P003", "Keyboard", "Electronics"),
    (6, "P001", "Laptop", "Electronics"),
    (6, "P005", "Monitor", "Electronics"),
    (7, "P003", "Keyboard", "Electronics"),
    (7, "P004", "Headphones", "Electronics"),
    (8, "P002", "Mouse", "Electronics"),
    (8, "P005", "Monitor", "Electronics"),
]

order_items_df = spark.createDataFrame(
    order_items_data, ["order_id", "product_id", "product_name", "category"]
)

total_orders = order_items_df.select("order_id").distinct().count()
print(f"Total unique orders: {total_orders}")

# --- Step 1: Self-join to find product pairs in the same order ---
pairs_df = order_items_df.alias("a").join(
    order_items_df.alias("b"),
    (F.col("a.order_id") == F.col("b.order_id")) &
    (F.col("a.product_id") < F.col("b.product_id"))  # Avoid duplicates and self-pairs
).select(
    F.col("a.product_id").alias("product_a"),
    F.col("a.product_name").alias("name_a"),
    F.col("b.product_id").alias("product_b"),
    F.col("b.product_name").alias("name_b"),
    F.col("a.order_id"),
)

# --- Step 2: Count co-purchases per pair ---
co_purchases = pairs_df.groupBy("product_a", "name_a", "product_b", "name_b").agg(
    F.countDistinct("order_id").alias("co_purchase_count")
)

# --- Step 3: Compute individual product frequencies ---
product_freq = order_items_df.groupBy("product_id").agg(
    F.countDistinct("order_id").alias("order_count")
)

# --- Step 4: Compute association rule metrics ---
# Support = co_purchase_count / total_orders
# Confidence(A->B) = co_purchase_count / orders_containing_A
# Lift = confidence / (support_B)

metrics = co_purchases \
    .join(product_freq.withColumnRenamed("product_id", "product_a")
          .withColumnRenamed("order_count", "freq_a"), "product_a") \
    .join(product_freq.withColumnRenamed("product_id", "product_b")
          .withColumnRenamed("order_count", "freq_b"), "product_b") \
    .withColumn("support", F.round(F.col("co_purchase_count") / F.lit(total_orders), 4)) \
    .withColumn("confidence_a_to_b", F.round(F.col("co_purchase_count") / F.col("freq_a"), 4)) \
    .withColumn("confidence_b_to_a", F.round(F.col("co_purchase_count") / F.col("freq_b"), 4)) \
    .withColumn(
        "lift",
        F.round(
            F.col("co_purchase_count") * F.lit(total_orders) / (F.col("freq_a") * F.col("freq_b")),
            4
        )
    )

print("=== Co-Purchase Metrics ===")
metrics.select(
    "name_a", "name_b", "co_purchase_count", "support",
    "confidence_a_to_b", "confidence_b_to_a", "lift"
).orderBy(F.desc("co_purchase_count"), F.desc("lift")).show(20)

# --- Step 5: Filter for strong recommendations ---
strong_recs = metrics.filter(
    (F.col("co_purchase_count") >= 2) &
    (F.col("lift") > 1.0)
)

print("=== Strong Recommendations (lift > 1.0, count >= 2) ===")
strong_recs.select("name_a", "name_b", "co_purchase_count", "confidence_a_to_b", "lift") \
    .orderBy(F.desc("lift")).show()

spark.stop()
```

## Method 2: SQL-Based Association Rules

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

spark = SparkSession.builder \
    .appName("Product Pairs - SQL") \
    .master("local[*]") \
    .getOrCreate()

# --- Data ---
order_items_data = [
    (1, "Laptop"), (1, "Mouse"), (1, "Keyboard"),
    (2, "Laptop"), (2, "Mouse"),
    (3, "Mouse"), (3, "Headphones"),
    (4, "Laptop"), (4, "Keyboard"), (4, "Monitor"),
    (5, "Mouse"), (5, "Keyboard"),
    (6, "Laptop"), (6, "Monitor"),
    (7, "Keyboard"), (7, "Headphones"),
    (8, "Mouse"), (8, "Monitor"),
]

df = spark.createDataFrame(order_items_data, ["order_id", "product"])
df.createOrReplaceTempView("order_items")

# --- Full association rule mining in SQL ---
result = spark.sql("""
    WITH total AS (
        SELECT COUNT(DISTINCT order_id) AS total_orders FROM order_items
    ),
    product_counts AS (
        SELECT product, COUNT(DISTINCT order_id) AS product_orders
        FROM order_items
        GROUP BY product
    ),
    pairs AS (
        SELECT
            a.product AS product_a,
            b.product AS product_b,
            COUNT(DISTINCT a.order_id) AS co_purchase_count
        FROM order_items a
        JOIN order_items b
            ON a.order_id = b.order_id
            AND a.product < b.product
        GROUP BY a.product, b.product
    )
    SELECT
        p.product_a,
        p.product_b,
        p.co_purchase_count,
        ROUND(p.co_purchase_count / t.total_orders, 4) AS support,
        ROUND(p.co_purchase_count / pa.product_orders, 4) AS confidence_a_to_b,
        ROUND(p.co_purchase_count / pb.product_orders, 4) AS confidence_b_to_a,
        ROUND(
            (p.co_purchase_count * t.total_orders) /
            (pa.product_orders * pb.product_orders), 4
        ) AS lift
    FROM pairs p
    CROSS JOIN total t
    JOIN product_counts pa ON p.product_a = pa.product
    JOIN product_counts pb ON p.product_b = pb.product
    ORDER BY lift DESC, co_purchase_count DESC
""")

print("=== Association Rules (SQL) ===")
result.show(20)

# --- Generate "You might also like" recommendations for a given product ---
target_product = "Laptop"

recs = spark.sql(f"""
    WITH target_orders AS (
        SELECT DISTINCT order_id FROM order_items WHERE product = '{target_product}'
    ),
    co_products AS (
        SELECT
            oi.product AS recommended_product,
            COUNT(DISTINCT oi.order_id) AS co_count,
            (SELECT COUNT(*) FROM target_orders) AS target_count
        FROM order_items oi
        JOIN target_orders t ON oi.order_id = t.order_id
        WHERE oi.product != '{target_product}'
        GROUP BY oi.product
    )
    SELECT
        '{target_product}' AS if_you_bought,
        recommended_product AS you_might_like,
        co_count,
        ROUND(co_count * 1.0 / target_count, 4) AS confidence
    FROM co_products
    ORDER BY confidence DESC
""")

print(f"=== Recommendations for '{target_product}' buyers ===")
recs.show()

spark.stop()
```

## Method 3: Basket Analysis with collect_set

```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import ArrayType, StringType
from itertools import combinations

spark = SparkSession.builder \
    .appName("Product Pairs - Basket Analysis") \
    .master("local[*]") \
    .getOrCreate()

# --- Data ---
order_items_data = [
    (1, "Laptop"), (1, "Mouse"), (1, "Keyboard"),
    (2, "Laptop"), (2, "Mouse"),
    (3, "Mouse"), (3, "Headphones"),
    (4, "Laptop"), (4, "Keyboard"), (4, "Monitor"),
    (5, "Mouse"), (5, "Keyboard"),
    (6, "Laptop"), (6, "Monitor"),
    (7, "Keyboard"), (7, "Headphones"),
    (8, "Mouse"), (8, "Monitor"),
]

df = spark.createDataFrame(order_items_data, ["order_id", "product"])

# --- Step 1: Create baskets (one row per order with product list) ---
baskets = df.groupBy("order_id").agg(
    F.sort_array(F.collect_set("product")).alias("products"),
    F.count("*").alias("basket_size")
)

print("=== Order Baskets ===")
baskets.show(truncate=False)

# --- Step 2: Generate pairs using UDF ---
@F.udf(ArrayType(ArrayType(StringType())))
def generate_pairs(products):
    """Generate all 2-item combinations from a basket."""
    if products is None or len(products) < 2:
        return []
    return [list(pair) for pair in combinations(sorted(products), 2)]

pairs_df = baskets.withColumn("pairs", F.explode(generate_pairs("products"))) \
    .select(
        "order_id",
        F.col("pairs")[0].alias("product_a"),
        F.col("pairs")[1].alias("product_b"),
    )

# --- Step 3: Count and rank pairs ---
pair_counts = pairs_df.groupBy("product_a", "product_b").agg(
    F.count("*").alias("co_purchase_count")
).orderBy(F.desc("co_purchase_count"))

print("=== Top Co-Purchase Pairs ===")
pair_counts.show(20)

# --- Step 4: Top-N recommendations per product ---
from pyspark.sql.window import Window

# Create bidirectional pairs for complete recommendations
all_recs = pair_counts.select(
    F.col("product_a").alias("product"),
    F.col("product_b").alias("recommended"),
    "co_purchase_count"
).union(
    pair_counts.select(
        F.col("product_b").alias("product"),
        F.col("product_a").alias("recommended"),
        "co_purchase_count"
    )
)

w = Window.partitionBy("product").orderBy(F.desc("co_purchase_count"))

top_recs = all_recs \
    .withColumn("rank", F.row_number().over(w)) \
    .filter(F.col("rank") <= 3)

print("=== Top 3 Recommendations Per Product ===")
top_recs.orderBy("product", "rank").show(20)

spark.stop()
```

## Key Concepts

- **Support**: Proportion of orders containing the pair: `co_purchase_count / total_orders`. Measures how common the pair is.
- **Confidence(A -> B)**: Probability of buying B given A was bought: `co_purchase_count / orders_containing_A`. Directional metric.
- **Lift**: `confidence / expected_probability` = `support(A,B) / (support(A) * support(B))`. Lift > 1 means positive association, lift = 1 means independence, lift < 1 means negative association.
- **Self-Join Pattern**: Join order_items with itself on order_id, with `a.product < b.product` to avoid duplicates and self-pairs.
- **Basket Analysis**: Grouping products by order into baskets, then generating combinations.

## Interview Tips

- Explain the difference between **confidence** (directional: A -> B is different from B -> A) and **lift** (symmetric).
- Mention **minimum support threshold** to prune rare pairs that aren't statistically meaningful.
- For large-scale implementations, mention the **Apriori algorithm** or **FP-Growth** (available in Spark MLlib as `pyspark.ml.fpm.FPGrowth`).
- Discuss the **scalability concern**: self-join on order_id is O(n^2) within each order. For orders with many items, this explodes. Cap basket size or sample.
- Real-world refinement: exclude "trivial" pairs (e.g., a product paired with its own accessory that's always bundled).
- Mention **collaborative filtering** as the ML-based alternative to rule-based recommendations.
