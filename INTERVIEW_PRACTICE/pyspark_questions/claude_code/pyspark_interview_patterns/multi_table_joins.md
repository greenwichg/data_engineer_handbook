# PySpark Implementation: Multi-Table Complex Joins

## Problem Statement
Given three tables -- **orders**, **products**, and **promotions** -- compute the
**effective price** for each order line. A promotion applies if (a) the order date falls
within the promotion's validity window, and (b) the product's category matches the
promotion's target category. When multiple promotions overlap, apply only the highest
discount. Orders with no matching promotion pay full price.

### Sample Data
```python
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

spark = SparkSession.builder.appName("MultiTableJoins").getOrCreate()

orders = spark.createDataFrame([
    (1, 101, "2024-01-10", 2),
    (2, 102, "2024-01-15", 1),
    (3, 103, "2024-01-20", 3),
    (4, 101, "2024-02-05", 1),
    (5, 104, "2024-01-25", 2),
    (6, 105, "2024-02-10", 1),
], ["order_id", "product_id", "order_date", "quantity"])

products = spark.createDataFrame([
    (101, "Wireless Mouse", "Electronics", 29.99),
    (102, "Running Shoes", "Sports", 89.99),
    (103, "Python Book", "Books", 45.00),
    (104, "Yoga Mat", "Sports", 35.00),
    (105, "USB Cable", "Electronics", 12.99),
], ["product_id", "product_name", "category", "unit_price"])

promotions = spark.createDataFrame([
    ("P1", "Electronics", 0.10, "2024-01-01", "2024-01-31"),
    ("P2", "Sports", 0.15, "2024-01-10", "2024-01-20"),
    ("P3", "Electronics", 0.20, "2024-02-01", "2024-02-28"),
    ("P4", "Books", 0.05, "2024-01-15", "2024-02-15"),
], ["promo_id", "target_category", "discount_pct", "start_date", "end_date"])
```

### Expected Output
| order_id | product_name   | category    | unit_price | discount_pct | effective_price | total   |
|----------|----------------|-------------|------------|--------------|-----------------|---------|
| 1        | Wireless Mouse | Electronics | 29.99      | 0.10         | 26.99           | 53.98   |
| 2        | Running Shoes  | Sports      | 89.99      | 0.15         | 76.49           | 76.49   |
| 3        | Python Book    | Books       | 45.00      | 0.05         | 42.75           | 128.25  |
| 4        | Wireless Mouse | Electronics | 29.99      | 0.20         | 23.99           | 23.99   |
| 5        | Yoga Mat       | Sports      | 35.00      | 0.00         | 35.00           | 70.00   |
| 6        | USB Cable      | Electronics | 12.99      | 0.20         | 10.39           | 10.39   |

---

## Method 1: Three-Way Join with Range Condition (Recommended)
```python
# Step 1 -- Join orders with products (inner join on product_id)
order_product = orders.join(products, on="product_id", how="inner")

# Step 2 -- Join with promotions using category match AND date range
#   This is a conditional/range join: the order_date must fall within
#   the promotion's start_date and end_date.
order_promo = order_product.join(
    promotions,
    on=(order_product["category"] == promotions["target_category"])
      & (order_product["order_date"] >= promotions["start_date"])
      & (order_product["order_date"] <= promotions["end_date"]),
    how="left"
)

# Step 3 -- When multiple promotions match, keep the highest discount
w = Window.partitionBy("order_id").orderBy(F.desc("discount_pct"))
best_promo = order_promo.withColumn("rn", F.row_number().over(w)) \
                        .filter(F.col("rn") == 1) \
                        .drop("rn")

# Step 4 -- Compute effective price and total
result = best_promo.withColumn(
    "discount_pct", F.coalesce(F.col("discount_pct"), F.lit(0.0))
).withColumn(
    "effective_price",
    F.round(F.col("unit_price") * (1 - F.col("discount_pct")), 2)
).withColumn(
    "total",
    F.round(F.col("effective_price") * F.col("quantity"), 2)
)

result.select(
    "order_id", "product_name", "category", "unit_price",
    "discount_pct", "effective_price", "total"
).orderBy("order_id").show(truncate=False)
```

### Step-by-Step Explanation

**Step 1 -- orders JOIN products (order_product):**
| order_id | product_id | order_date | quantity | product_name   | category    | unit_price |
|----------|------------|------------|----------|----------------|-------------|------------|
| 1        | 101        | 2024-01-10 | 2        | Wireless Mouse | Electronics | 29.99      |
| 2        | 102        | 2024-01-15 | 1        | Running Shoes  | Sports      | 89.99      |
| 3        | 103        | 2024-01-20 | 3        | Python Book    | Books       | 45.00      |
| 4        | 101        | 2024-02-05 | 1        | Wireless Mouse | Electronics | 29.99      |
| 5        | 104        | 2024-01-25 | 2        | Yoga Mat       | Sports      | 35.00      |
| 6        | 105        | 2024-02-10 | 1        | USB Cable      | Electronics | 12.99      |

**Step 2 -- LEFT JOIN with promotions on category + date range (order_promo):**
| order_id | category    | order_date | promo_id | discount_pct |
|----------|-------------|------------|----------|--------------|
| 1        | Electronics | 2024-01-10 | P1       | 0.10         |
| 2        | Sports      | 2024-01-15 | P2       | 0.15         |
| 3        | Books       | 2024-01-20 | P4       | 0.05         |
| 4        | Electronics | 2024-02-05 | P3       | 0.20         |
| 5        | Sports      | 2024-01-25 | null     | null         |
| 6        | Electronics | 2024-02-10 | P3       | 0.20         |

Order 5 (Yoga Mat, 2024-01-25) has no matching promotion because P2 for Sports ended
on 2024-01-20. The left join preserves it with nulls.

**Step 3 -- Deduplication keeps highest discount per order (no change here since each
order matched at most one promotion, but handles overlap in general).**

**Step 4 -- Final calculation (see Expected Output above).**

---

## Method 2: Conditional Join Using Different Keys Based on a Flag
```python
# Scenario: Some orders have a "coupon_code" that should be joined on directly,
# while others should fall through to category-based promotions.

orders_v2 = spark.createDataFrame([
    (1, 101, "2024-01-10", 2, "P1"),       # has explicit coupon
    (2, 102, "2024-01-15", 1, None),        # no coupon, use category match
    (3, 103, "2024-01-20", 3, None),
    (4, 101, "2024-02-05", 1, "P3"),
    (5, 104, "2024-01-25", 2, None),
    (6, 105, "2024-02-10", 1, None),
], ["order_id", "product_id", "order_date", "quantity", "coupon_code"])

# Split into two groups
has_coupon = orders_v2.filter(F.col("coupon_code").isNotNull())
no_coupon = orders_v2.filter(F.col("coupon_code").isNull())

# Group 1: direct join on coupon_code = promo_id
coupon_matched = has_coupon.join(
    promotions,
    has_coupon["coupon_code"] == promotions["promo_id"],
    "left"
)

# Group 2: category + date range join (same as Method 1)
no_coupon_enriched = no_coupon.join(products, on="product_id", how="inner")
category_matched = no_coupon_enriched.join(
    promotions,
    on=(no_coupon_enriched["category"] == promotions["target_category"])
      & (no_coupon_enriched["order_date"] >= promotions["start_date"])
      & (no_coupon_enriched["order_date"] <= promotions["end_date"]),
    how="left"
)

# Enrich Group 1 with product info and union both groups
coupon_enriched = coupon_matched.join(products, on="product_id", how="inner")

# Select common columns and union
common_cols = ["order_id", "product_id", "order_date", "quantity",
               "product_name", "category", "unit_price", "discount_pct"]
final = coupon_enriched.select(*common_cols).unionByName(
    category_matched.select(*common_cols)
)
final.orderBy("order_id").show(truncate=False)
```

---

## Method 3: Range Join with Inequality (Salary Band Lookup)
```python
# A common variant: join employees to salary bands where the salary
# falls between a lower and upper bound.

employees = spark.createDataFrame([
    (1, "Alice", 55000), (2, "Bob", 72000), (3, "Carol", 95000),
    (4, "Dave", 120000), (5, "Eve", 43000),
], ["emp_id", "name", "salary"])

bands = spark.createDataFrame([
    ("Junior", 0, 50000), ("Mid", 50001, 80000),
    ("Senior", 80001, 110000), ("Principal", 110001, 200000),
], ["band", "lower", "upper"])

# Range join: salary BETWEEN lower AND upper
banded = employees.join(
    bands,
    on=(employees["salary"] >= bands["lower"])
      & (employees["salary"] <= bands["upper"]),
    how="left"
)

banded.select("emp_id", "name", "salary", "band").orderBy("salary").show()
```

### Range Join Output
| emp_id | name  | salary | band      |
|--------|-------|--------|-----------|
| 5      | Eve   | 43000  | Junior    |
| 1      | Alice | 55000  | Mid       |
| 2      | Bob   | 72000  | Mid       |
| 3      | Carol | 95000  | Senior    |
| 4      | Dave  | 120000 | Principal |

---

## Key Interview Talking Points
1. **Three-way join ordering** -- Join the two largest tables first if they share a key (orders + products on product_id), then join the result with the smaller dimension table (promotions). This minimizes shuffle size.
2. **Range/inequality joins** -- PySpark evaluates inequality conditions as a filter after a Cartesian product unless Adaptive Query Execution (AQE) or range-join optimization is enabled. For large datasets, consider bucketing or pre-filtering.
3. **Left join preserves unmatched rows** -- Using `left` ensures orders without promotions still appear. Always `coalesce` nullable join columns before arithmetic.
4. **Deduplication after fan-out** -- When an order matches multiple promotions, the join fans out rows. Use `row_number` partitioned by the primary key to pick the best match.
5. **Conditional join pattern** -- Splitting a DataFrame by a condition, joining each subset differently, and unioning the results is the standard approach when join logic depends on the data itself.
6. **coalesce for null safety** -- After a left join, discount_pct is null for unmatched rows. `F.coalesce(col, lit(0))` ensures downstream arithmetic does not produce nulls.
7. **Broadcast hint for small tables** -- If the promotions or bands table is small, use `F.broadcast(promotions)` to force a broadcast hash join and avoid shuffling the large orders table.
