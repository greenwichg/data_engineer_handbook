# PySpark Implementation: Mode (Most Frequent Value) per Group

## Problem Statement
Given a table of customer transactions, find the most frequently purchased product for each customer. If there is a tie, return all tied products. This is a classic interview question testing grouping, counting, and ranking skills together.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("ModePerGroup").getOrCreate()

data = [
    (1, "Alice", "Laptop"),
    (2, "Alice", "Phone"),
    (3, "Alice", "Laptop"),
    (4, "Alice", "Laptop"),
    (5, "Alice", "Phone"),
    (6, "Bob", "Tablet"),
    (7, "Bob", "Phone"),
    (8, "Bob", "Tablet"),
    (9, "Charlie", "Laptop"),
    (10, "Charlie", "Phone"),
    (11, "Charlie", "Tablet"),
]

columns = ["txn_id", "customer", "product"]
df = spark.createDataFrame(data, columns)
df.show()
```

```
+------+--------+-------+
|txn_id|customer|product|
+------+--------+-------+
|     1|   Alice| Laptop|
|     2|   Alice|  Phone|
|     3|   Alice| Laptop|
|     4|   Alice| Laptop|
|     5|   Alice|  Phone|
|     6|     Bob| Tablet|
|     7|     Bob|  Phone|
|     8|     Bob| Tablet|
|     9| Charlie| Laptop|
|    10| Charlie|  Phone|
|    11| Charlie| Tablet|
+------+--------+-------+
```

### Expected Output
```
+--------+-------+---------+
|customer|product|buy_count|
+--------+-------+---------+
|   Alice| Laptop|        3|
|     Bob| Tablet|        2|
| Charlie| Laptop|        1|
| Charlie|  Phone|        1|
| Charlie| Tablet|        1|
+--------+-------+---------+
```
- Alice's mode is Laptop (3 purchases).
- Bob's mode is Tablet (2 purchases).
- Charlie has a 3-way tie (1 each), so all three are returned.

---

## Method 1: Window Function with rank() (Recommended)

```python
# Step 1: Count purchases per customer-product
product_counts = (
    df.groupBy("customer", "product")
    .agg(F.count("*").alias("buy_count"))
)

# Step 2: Rank by count within each customer (rank allows ties)
window_spec = Window.partitionBy("customer").orderBy(F.desc("buy_count"))
ranked = product_counts.withColumn("rnk", F.rank().over(window_spec))

# Step 3: Keep only rank 1 (the mode — including ties)
result = ranked.filter(F.col("rnk") == 1).drop("rnk")
result.orderBy("customer", "product").show()
```

### Step-by-Step Explanation

#### Step 1: Count purchases per customer-product
- **What happens:** Groups by customer and product, counts occurrences.
- **Output (product_counts):**

  | customer | product | buy_count |
  |----------|---------|-----------|
  | Alice    | Laptop  | 3         |
  | Alice    | Phone   | 2         |
  | Bob      | Phone   | 1         |
  | Bob      | Tablet  | 2         |
  | Charlie  | Laptop  | 1         |
  | Charlie  | Phone   | 1         |
  | Charlie  | Tablet  | 1         |

#### Step 2: Rank by count descending within each customer
- **What happens:** `rank()` assigns rank 1 to the highest count per customer. Ties get the same rank.
- **Output (ranked):**

  | customer | product | buy_count | rnk |
  |----------|---------|-----------|-----|
  | Alice    | Laptop  | 3         | 1   |
  | Alice    | Phone   | 2         | 2   |
  | Bob      | Tablet  | 2         | 1   |
  | Bob      | Phone   | 1         | 2   |
  | Charlie  | Laptop  | 1         | 1   |
  | Charlie  | Phone   | 1         | 1   |
  | Charlie  | Tablet  | 1         | 1   |

#### Step 3: Filter rank == 1
- **What happens:** Keeps only the most frequent product(s) per customer. Charlie's 3-way tie is preserved because `rank()` gives all three rank 1.

---

## Method 2: GroupBy with Struct Trick (Single Mode Only)

```python
# Uses struct ordering — struct compares element by element
# struct(count, product) ordered descending picks highest count, then product as tiebreaker
result_single = (
    df.groupBy("customer", "product")
    .agg(F.count("*").alias("buy_count"))
    .groupBy("customer")
    .agg(
        F.max(F.struct("buy_count", "product")).alias("mode_info")
    )
    .select(
        "customer",
        F.col("mode_info.product").alias("top_product"),
        F.col("mode_info.buy_count").alias("buy_count"),
    )
)
result_single.show()
```

- **Note:** This returns exactly one mode per customer. If there is a tie, the product that comes last alphabetically wins (because `max(struct(...))` compares fields left to right: first by count, then by product name).

---

## Method 3: Spark SQL

```python
df.createOrReplaceTempView("transactions")

result_sql = spark.sql("""
    WITH product_counts AS (
        SELECT customer, product, COUNT(*) AS buy_count
        FROM transactions
        GROUP BY customer, product
    ),
    ranked AS (
        SELECT *, RANK() OVER (PARTITION BY customer ORDER BY buy_count DESC) AS rnk
        FROM product_counts
    )
    SELECT customer, product, buy_count
    FROM ranked
    WHERE rnk = 1
    ORDER BY customer, product
""")
result_sql.show()
```

---

## Comparison of Methods

| Method | Handles Ties? | Performance | Use Case |
|--------|---------------|-------------|----------|
| rank() window | Yes — returns all tied modes | Moderate — requires sort | Default choice for interviews |
| Struct trick | No — returns one winner | Fast — no sort, two aggregations | When you need exactly one mode |
| Spark SQL | Yes — same as rank() | Same as Method 1 | When SQL is preferred |

## Key Interview Talking Points

1. **rank() vs row_number():** Use `rank()` to preserve ties; `row_number()` would arbitrarily pick one product per customer even if tied.
2. **dense_rank() also works here** since we only care about rank 1.
3. The **struct trick** is a PySpark-specific optimization — `max(struct(count, product))` avoids a window function entirely. Mention it to show depth.
4. If asked "what if there are millions of products per customer?", discuss that the window function approach requires sorting within each partition — consider `approx_count_distinct` or sampling for approximate modes on very large groups.
5. The mode is the only common statistical measure (mean, median, mode) that works on categorical (non-numeric) data.
